local sim = require('sim-2')
local class = require('middleclass')
local checkargs = require('checkargs-2')
local simEigen = require('simEigen')

-- Generates a time-optimal trajectory via TOPPRA, executed in a Python add-on.
-- Note: this class does not derive from Motion: it is a one-shot generator.
local TimeOptimalTrajectory = class('TimeOptimalTrajectory')

function TimeOptimalTrajectory:initialize()
    self._script = nil
end


function TimeOptimalTrajectory:generate(params)
    checkargs.checkfields({funcName = "TimeOptimalTrajectory"}, {
        {name = 'pathLengths', type = 'matrix', rows = -1, cols = 1},
    }, params)

    local confCnt = params.pathLengths:rows()

    if confCnt < 2 then
        error("at least 2 configurations must be provided.")
    end

    checkargs.checkfields({funcName = "TimeOptimalTrajectory"}, {
        {name = 'path', type = 'matrix', rows = -1, cols = confCnt},
    }, params)

    local dof = params.path:rows()

    checkargs.checkfields({funcName = "TimeOptimalTrajectory"}, {
        {name = 'maxVel', type = 'matrix', rows = dof, cols = 1},
        {name = 'minVel', type = 'matrix', rows = dof, cols = 1, nullable = true},
        {name = 'maxAccel', type = 'matrix', rows = dof, cols = 1},
        {name = 'minAccel', type = 'matrix', rows = dof, cols = 1, nullable = true},
        {name = 'samples', type = 'int', default = 1000},
        {name = 'boundaryCondition', type = 'string', default = 'not-a-knot'},
    }, params)

    local pM = params.path
    local minVel = params.minVel or params.maxVel * -1.0
    local minAccel = params.minAccel or params.maxAccel * -1.0
    local mmvM = minVel:horzcat(params.maxVel)
    local mmaM = minAccel:horzcat(params.maxAccel)
    sim.self:setStepping(true)

    local code = [=[
#luaExec wrapper = 'pythonWrapper-2'
def sysCall_init():
    global ta, constraint, algo, np
    import toppra as ta
    import toppra.constraint as constraint
    import toppra.algorithm as algo
    import numpy as np
    ta.setup_logging("WARNING")

def sysCall_cleanup():
    pass

def cb(req):
    try:
        resp = cbb(req)
        resp['success'] = True
    except Exception as e:
        resp = {'success': False, 'error': str(e)}
    return resp

def rs(a):
    flattened = [item for sublist in a for item in sublist]
    reshaped_matrix = [flattened[i:i + 2] for i in range(0, len(flattened), 2)]
    return reshaped_matrix

def cbb(req):
    coefficients = ta.SplineInterpolator(req['ss_waypoints'], req['waypoints'], req.get('bc_type', 'not-a-knot'))
    pc_vel = constraint.JointVelocityConstraint(req['velocity_limits'])
    pc_acc = constraint.JointAccelerationConstraint(req['acceleration_limits'], discretization_scheme=constraint.DiscretizationType.Interpolation)
    instance = algo.TOPPRA([pc_vel, pc_acc], coefficients, solver_wrapper='seidel')
    jnt_traj = instance.compute_trajectory(0, 0)
    duration = jnt_traj.duration
    n = coefficients.dof
    resp = dict(qs=[[]]*n, qds=[[]]*n, qdds=[[]]*n)
    ts = np.linspace(0, duration, req.get('samples', 100))
    for i in range(n):
        resp['qs'][i] = jnt_traj.eval(ts).tolist()
        resp['qds'][i] = jnt_traj.evald(ts).tolist()
        resp['qdds'][i] = jnt_traj.evaldd(ts).tolist()
    resp['ts'] = ts.tolist()
    return resp
]=]

    -- Reuse or create the Python script
    if not self._script then
        self._script = sim.app:createObject({type = 'script', ['script.type'] = 'addon', code = code, language = 'python'})
        self._script.addOnMenuPath = 'Motion:TimeOptimalTrajectory'
        self._script:init()
    end

    local toSend = {
        samples = params.samples,
        ss_waypoints = params.pathLengths:data(),
        waypoints = params.path.T:totable(),
        velocity_limits = mmvM:totable(),
        acceleration_limits = mmaM:totable(),
        bc_type = params.boundaryCondition,
    }
    local s, r = pcall(self._script.callFunction, self._script, 'cb', toSend)
    sim.self:setStepping(false)

    if s ~= true then
        error('Failed calling TOPPRA via the generated Python script. Make sure Python is configured for CoppeliaSim, and toppra as well as numpy are installed: ' .. sim.app.namedParam.settings.defaultInterpreters.python .. ' -m pip install pyzmq cbor2 psutil numpy toppra.')
    end

    if not r.success then
        error('toppra failed with following message: ' .. r.error)
    end
    return simEigen.Matrix(r.qs[1]).T, simEigen.Matrix(#r.ts, 1, r.ts)
end


function TimeOptimalTrajectory:remove()
    if self._script then
        self._script:remove()
        self._script = nil
    end
end


return TimeOptimalTrajectory
