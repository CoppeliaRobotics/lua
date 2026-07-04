local sim = require 'sim-2'
local class = require('middleclass')
local copy = require('copy')
local checkargs = require('checkargs-2')
local simEigen = require('simEigen')
local simIK = require('simIK-1')

local Path = class('Path')

function Path:initialize(ctrlPoints, opt)
    ctrlPoints = checkargs.checkargsEx({funcName = 'Path:new'}, {
        {type = 'matrix', nullable = true},
    }, ctrlPoints)
    opt = opt or {}
    opt.ctrlPoints = opt.ctrlPoints or {}
    opt.pathPoints = opt.pathPoints or {}
    checkargs.checkfields({funcName = 'Path:new'}, {
        {name = 'pointType', enum = {none = 0, sphere = 1, cube = 2}, default = 'cube'},
        {name = 'lineType', enum = {none = 0, line = 1, tube = 2}, default = 'line'},
        {name = 'pointColor', type = 'color', default = Color('#ffff00')},
        {name = 'showAxes', type = 'bool', default = false},
        {name = 'pointRadius', type = 'float', default = 0.005},
        {name = 'lineColor', type = 'color', default = Color('#ff8800')},
        {name = 'tubeRadius', type = 'float', default = 0.0025},
        {name = 'duplicateThreshold', type = 'float', default = 0.02},
        {name = 'linearityTolerance', type = 'float', default = 0.001}, -- in percent
    }, opt.ctrlPoints)
    checkargs.checkfields({funcName = 'Path:new'}, {
        {name = 'pointType', enum = {none = 0, sphere = 1, cube = 2}, default = 'none'},
        {name = 'lineType', enum = {none = 0, line = 1, tube = 2}, default = 'line'},
        {name = 'pointColor', type = 'color', default = Color('#000000')},
        {name = 'showAxes', type = 'bool', default = false},
        {name = 'pointRadius', type = 'float', default = 0.002},
        {name = 'lineColor', type = 'color', default = Color('#050505')},
        {name = 'tubeRadius', type = 'float', default = 0.0025},
        {name = 'samplingDistance', type = 'float', default = 0.02},
        {name = 'bezierSmoothing', type = 'float', range = {0.05, 1.0}, default = 1.0},
        {name = 'type', enum = {linear = 0, quadraticBezier = 1}, default = 1},
    }, opt.pathPoints)
    checkargs.checkfields({funcName = 'Path:new'}, {
        {name = 'onlyCtrlPoints', type = 'bool', default = false},
        {name = 'closed', type = 'bool', default = false},
        {name = 'closedRepeatsStart', type = 'bool', default = false},
    }, opt)
    
    if ctrlPoints then
        opt.dim = ctrlPoints:rows()
        assert(opt.dim > 0, 'invalid control points')
        if (opt.types == nil) and (opt.dim == 7) then
            opt.types = {'lin', 'lin', 'lin', 'quat', 'quat', 'quat', 'quat'}
        end
        checkargs.checkfields({funcName = 'Path:new'}, {
            {name = 'metric', type = 'vector', size = opt.dim, default = simEigen.Vector(opt.dim, 1.0)},
            {name = 'types', type = 'table', size = opt.dim, default = table.rep('lin', opt.dim)},
            {name = 'bounds', type = 'table', size = opt.dim, default = table.rep({}, opt.dim)},
        }, opt)
    else
        checkargs.checkfields({funcName = 'Path:new'}, {
            {name = 'types', type = 'table', range = '1..*'}, -- in this case not optional
        }, opt)
        opt.dim = #opt.types
        checkargs.checkfields({funcName = 'Path:new'}, {
            {name = 'metric', type = 'vector', size = opt.dim, default = simEigen.Vector(opt.dim, 1.0)},
            {name = 'bounds', type = 'table', size = opt.dim, default = table.rep({}, opt.dim)},
        }, opt)
        ctrlPoints = simEigen.Matrix(opt.dim, 0, {})
    end
    local quatC = 0
    for i = 1, opt.dim do
        if opt.types[i] == 'lin' then
            if quatC ~= 0 then
                error("invalid 'types' array")
            end
            opt.types[i] = 0
        elseif opt.types[i] == 'ang' then
            if quatC ~= 0 then
                error("invalid 'types' array")
            end
            opt.types[i] = 1
        elseif opt.types[i] == 'quat' then
            opt.bounds[i] = {}
            opt.types[i] = 2
            quatC = quatC + 1
            if quatC == 4 then
                quatC = 0
            end
        else
            error("invalid 'types' array")
        end
        local b = opt.bounds[i]
        if #b > 0 then
            if #b > 2 then
                error("invalid 'bounds' array")
            else
                if (type(b[1]) ~= 'number') or (type(b[2]) ~= 'number') or (b[2] < b[1]) or (opt.types[i] == 2) then
                    error("invalid 'bounds' array")
                end
            end
        end
    end
    if quatC ~= 0 then
        error("invalid 'types' array")
    end

    local data = {}
    self._data = data
    data.ctrlPoints = {}
    data.pathPoints = {}
    data.ctrlPoints.opt = opt.ctrlPoints
    data.pathPoints.opt = opt.pathPoints

    data.opt = copy.deepcopy(opt)
    data.opt.ctrlPoints = nil
    data.opt.pathPoints = nil

    if data.opt.joints then
        data.opt.displDim = -1
    else
        if (data.opt.dim > 1) and (data.opt.types[1] == 0) and (data.opt.types[2] == 0) then
            if (data.opt.dim > 2) and (data.opt.types[3] == 0) then
                if (data.opt.dim > 6) and (data.opt.types[4] == 2) and (data.opt.types[5] == 2) and (data.opt.types[6] == 2) and (data.opt.types[7] == 2) then
                    data.opt.displDim = 7
                else
                    data.opt.displDim = 3
                end
            else
                data.opt.displDim = 2
            end
        else
            data.opt.displDim = 0
        end
    end
    self:setPoints(ctrlPoints, true)
end

function Path.fromJoints(endEffector, base, opt)
    endEffector, base = checkargs.checkargsEx({funcName = 'fromJoints'}, {
        {type = 'handle'},
        {type = 'handle', nullable = true},
    }, endEffector, base)
    opt = opt or {}
    local jointList = {}
    local obj = endEffector.parent
    while obj ~= base do
        if obj.type == 'joint' then
            jointList[#jointList + 1] = obj
        end
        obj = obj.parent
    end
    opt.joints = table.reversed(jointList)
    opt.tip = endEffector
    opt.base = base
    opt.types = {}
    opt.bounds = {}
    for i = 1, #opt.joints do
        if opt.joints[i].joint.type == 'prismatic' then
            opt.types[i] = 'lin'
        elseif opt.joints[i].joint.type == 'revolute' then
            opt.types[i] = 'ang'
        else
            opt.types[i] = 'quat'
        end
        opt.bounds[i] = opt.joints[i].bounds
    end
    return Path(nil, opt)
end

function Path.fromObject(obj, opt)
    obj = checkargs.checkargsEx({funcName = 'fromObject'}, {
        {type = 'handle'},
    }, obj)
    opt = opt or {}
    opt.object = obj
    opt.types = {'lin', 'lin', 'lin', 'quat', 'quat', 'quat', 'quat'}
    return Path(nil, opt)
end

function Path:setPoints(ctrlPoints, noArgCheck)
    sim.self:setStepping(true)
    local data = self._data
    if not noArgCheck then
        ctrlPoints = checkargs.checkargsEx({funcName = 'setPoints'}, {
            {type = 'matrix', rows = data.opt.dim, nullable = true},
        }, ctrlPoints)
    end
    if ctrlPoints == nil then
        ctrlPoints = simEigen.Matrix(data.opt.dim, 0, {})
    end
    
    if ctrlPoints:cols() > 1 then
        if data.ctrlPoints.opt.duplicateThreshold > 0.0 then
            ctrlPoints = self:_removeDuplicates(ctrlPoints)
        end
        if data.ctrlPoints.opt.linearityTolerance > 0.0 then
            ctrlPoints = self:_removeColinearSegments(ctrlPoints)
        end
    end
    data.ctrlPoints.points = ctrlPoints
    if data.ctrlPoints.points:cols() > 1 then
        data.ctrlPoints.arcLengths, data.ctrlPoints.distancesAlongPath, data.ctrlPoints.pathLength = self:_computeArcLengths(data.ctrlPoints.points)
        if not data.opt.onlyCtrlPoints then
            data.pathPoints.points = self:_resample(data.ctrlPoints.points)
            data.pathPoints.arcLengths, data.pathPoints.distancesAlongPath, data.pathPoints.pathLength = self:_computeArcLengths(data.pathPoints.points)
        end
    else 
        if ctrlPoints:cols() == 1 then
            data.ctrlPoints.distancesAlongPath = simEigen.Vector{0.0}
            if not data.opt.onlyCtrlPoints then
                data.pathPoints.points = copy.copy(ctrlPoints)
                data.pathPoints.distancesAlongPath = simEigen.Vector{0.0}
            end
        else
            data.ctrlPoints.distancesAlongPath = simEigen.Vector{}
            if not data.opt.onlyCtrlPoints then
                data.pathPoints.points = simEigen.Matrix(data.opt.dim, 0, {})
                data.pathPoints.distancesAlongPath = simEigen.Vector{}
            end
        end
        data.ctrlPoints.arcLengths = simEigen.Vector{}
        data.ctrlPoints.pathLength = 0.0
        if not data.opt.onlyCtrlPoints then
            data.pathPoints.arcLengths = simEigen.Vector{}
            data.pathPoints.pathLength = 0.0
        end
    end
    self:_updateMarkers()
    sim.self:setStepping(false)
end

function Path:appendPoints(ctrlPoints, update)
    if update == nil then
        update = true
    end
    local data = self._data
    ctrlPoints = checkargs.checkargsEx({funcName = 'setPoints'}, {
        {type = 'matrix', rows = data.opt.dim},
    }, ctrlPoints)
    assert(ctrlPoints:cols() > 0, 'invalid points')

    data.ctrlPoints.toUpdate = data.ctrlPoints.toUpdate or data.ctrlPoints.points
    data.ctrlPoints.toUpdate = data.ctrlPoints.toUpdate:horzcat(ctrlPoints)
    if update then
        self:update()
    end
end

function Path:appendFromJoints(update)
    if update == nil then
        update = true
    end
    local data = self._data
    assert(data.opt.joints, 'no joints specified')
    ctrlPoints = {}
    for i = 1, data.opt.dim do
        if data.opt.types[i] ~= 2 then
            ctrlPoints[#ctrlPoints + 1] = data.opt.joints[i].joint.position
        else
            table.add(ctrlPoints, data.opt.joints[i].joint.quaternion:data())
        end
    end
    local toUpdate = data.ctrlPoints.toUpdate or data.ctrlPoints.points
    local newPt = simEigen.Vector(ctrlPoints)
    if data.ctrlPoints.opt.duplicateThreshold > 0.0 then
        if toUpdate:cols() > 0 then
            if self:distance(toUpdate:block(1, toUpdate:cols(), -1, 1), newPt, true) < data.ctrlPoints.opt.duplicateThreshold then
                newPt = nil
            end
        end
    end
    if newPt then
        data.ctrlPoints.toUpdate = toUpdate:horzcat(newPt)
        if update then
            self:update()
        end
    end
end

function Path:appendFromObject(update)
    if update == nil then
        update = true
    end
    local data = self._data
    assert(data.opt.object, 'no object specified')
    local toUpdate = data.ctrlPoints.toUpdate or data.ctrlPoints.points
    local newPt = simEigen.Vector(data.opt.object.worldPose:data())
    if data.ctrlPoints.opt.duplicateThreshold > 0.0 then
        if toUpdate:cols() > 0 then
            if self:distance(toUpdate:block(1, toUpdate:cols(), -1, 1), newPt, true) < data.ctrlPoints.opt.duplicateThreshold then
                newPt = nil
            end
        end
    end
    if newPt then
        data.ctrlPoints.toUpdate = toUpdate:horzcat(newPt)
        if update then
            self:update()
        end
    end
end

function Path:update()
    local data = self._data
    if data.ctrlPoints.toUpdate then
        self:setPoints(data.ctrlPoints.toUpdate)
        data.ctrlPoints.toUpdate = nil
    end
end

function Path:clearPoints()
    self.data.ctrlPoints.toUpdate = nil
    self:setPoints(nil, true)
end

function Path:data()
    self:update()
    local retVal = self._data
    if retVal.opt.closed and retVal.opt.closedRepeatsStart then
        retVal = copy.deepcopy(self._data)
        local dummyVal
        if retVal.ctrlPoints.points:rows() > 1 then
            retVal.ctrlPoints.points = retVal.ctrlPoints.points:horzcat(retVal.ctrlPoints.points:block(1, 1, -1, 1))
            dummyVal, retVal.ctrlPoints.distancesAlongPath, retVal.ctrlPoints.pathLength = self:_computeArcLengths(retVal.ctrlPoints.points)
        end
        if retVal.pathPoints.points:rows() > 1 then
            retVal.pathPoints.points = retVal.pathPoints.points:horzcat(retVal.pathPoints.points:block(1, 1, -1, 1))
            dummyVal, retVal.pathPoints.distancesAlongPath, retVal.pathPoints.pathLength = self:_computeArcLengths(retVal.pathPoints.points)
        end
    end
    return retVal
end

function Path:_removeDuplicates(points)
    local data = self._data
    local pts = points

    local function __removeDuplicates(inPoints)
        local retVal = inPoints:copy()
        local removed = 0
        local minPtCnt = 2

        -- temp. append the first point with closed paths:
        if data.opt.closed then
            retVal = retVal:horzcat(retVal:block(1, 1, -1, 1))
            minPtCnt = 3
        end

        if retVal:cols() > minPtCnt then
            -- Remove points close to the first point:
            local firstPoint = retVal:block(1, 1, -1, 1)
            local i = 2
            while i <= retVal:cols() - 1 do
                local p = retVal:block(1, i, -1, 1)
                if self:distance(firstPoint, p, true) < data.ctrlPoints.opt.duplicateThreshold then
                    retVal = retVal:block(1, 1, -1, i - 1):horzcat(retVal:block(1, i + 1, - 1, -1))
                    removed = removed + 1
                else
                    break
                end
                i = i + 1
            end

            if retVal:cols() > minPtCnt then
                -- Remove points close to the last point:
                local lastPoint = retVal:block(1, retVal:cols(), -1, 1)
                local i = retVal:cols() - 1
                while i >= 2 do
                    local p = retVal:block(1, i, -1, 1)
                    if self:distance(lastPoint, p, true) < data.ctrlPoints.opt.duplicateThreshold then
                        retVal = retVal:block(1, 1, -1, i - 1):horzcat(retVal:block(1, i + 1, - 1, -1))
                        removed = removed + 1
                    else
                        break
                    end
                    i = i - 1
                end

                if retVal:cols() > minPtCnt then
                    -- merge points pairwise:
                    local points = retVal
                    retVal = firstPoint
                    local p0, p1
                    local i = 2
                    if points:cols() == 3 then
                        retVal = retVal:horzcat(points:block(1, 2, -1, 1))
                    else
                        while i <= points:cols() - 2 do
                            p0 = points:block(1, i, -1, 1)
                            p1 = points:block(1, i + 1, -1, 1)
                            local d = self:distance(p0, p1, true)
                            if d >= data.ctrlPoints.opt.duplicateThreshold then
                                retVal = retVal:horzcat(p0)
                            else
                                retVal = retVal:horzcat(self:interpolate(p0, p1, 0.5, true))
                                removed = removed + 1
                                p1 = nil
                                i = i + 1
                            end
                            i = i + 1
                        end
                    end
                    if p1 then
                        retVal = retVal:horzcat(p1)
                    end
                    retVal = retVal:horzcat(lastPoint)
                end
            end
        end

        -- Remove the last point (coincident with the first point), with closed paths:
        if data.opt.closed then
            retVal = retVal:block(1, 1, -1, retVal:cols() - 1)
        end

        return retVal, removed
    end

    local cnt = 0
    local ret = pts
    while true do
        local r
        ret, r = __removeDuplicates(ret)
        if r == 0 then
            break
        end
        cnt = cnt + r
    end
    return ret, cnt
end

function Path:_removeColinearSegments(points)
    local data = self._data
    local pts = points

    local function __removeColinearSegments(inPoints)
        local pts = inPoints:copy()

        -- temp. append the first point with closed paths:
        if data.opt.closed then
            pts = pts:horzcat(pts:block(1, 1, -1, 1))
        end

        local toPrune = {}
        for i = 1, pts:cols() - 3 do
            local p0 = pts:block(1, i, -1, 1)
            local p1 = pts:block(1, i + 1, -1, 1)
            local p2 = pts:block(1, i + 2, -1, 1)
            local d0 = self:distance(p0, p1, true)
            local d1 = self:distance(p1, p2, true)
            local t = d0 / (d0 + d1)
            local proj = self:interpolate(p0, p2, t, true)
            local relDist = self:distance(proj, p1, true) / self:distance(p0, p2, true)
            if relDist < data.ctrlPoints.opt.linearityTolerance then
                toPrune[#toPrune + 1] = {pos = i + 1, val = relDist}
            end
        end
        table.sort(toPrune, function(a, b) return a.val < b.val end)
        local colsToRemove = {}
        for i = 1, #toPrune do
            if toPrune[i].ignore == nil then
                local r = toPrune[i].pos
                colsToRemove[r] = true
                -- ignore those that needs to be recomputed:
                for j = i + 1, #toPrune do
                    if math.abs(toPrune[j].pos - r) == 1 then
                        toPrune[j].ignore = true
                    end
                end
            end
        end
        local retVal = simEigen.Matrix(pts:rows(), 0, {})
        local removed = 0
        for i = 1, pts:cols() do
            if colsToRemove[i] then
                removed = removed + 1
            else
                retVal = retVal:horzcat(pts:block(1, i, -1, 1))
            end
        end
        -- Remove the last point (coincident with the first point), with closed paths:
        if data.opt.closed then
            retVal = retVal:block(1, 1, -1, retVal:cols() - 1)
        end
        return retVal, removed
    end

    local cnt = 0
    local ret = pts
    while true do
        local r
        ret, r = __removeColinearSegments(ret)
        if r == 0 then
            break
        end
        cnt = cnt + r
    end
    return ret, cnt
end

function Path:_computeArcLengths(points)
    local data = self._data
    local pts = points

    local l = 0.0
    local distances = {l}
    local tot = {}
    for i = 1, pts:cols() - 1 do
        local p0 = pts:block(1, i, -1, 1)
        local p1 = pts:block(1, i + 1, -1, 1)
        local d = self:distance(p0, p1, true)
        tot[#tot + 1] = d
        l = l + d
        distances[#distances + 1] = l
    end
    if data.opt.closed then
        local p0 = pts:block(1, pts:cols(), -1, 1)
        local p1 = pts:block(1, 1, -1, 1)
        local d = self:distance(p0, p1, true)
        tot[#tot + 1] = d
        l = l + d
    end
    return simEigen.Vector(tot), simEigen.Vector(distances), l
end

function Path:distance(conf1, conf2, noArgCheck)
    local data = self._data
    local confA = conf1
    local confB = conf2
    if not noArgCheck then
        confA, confB = checkargs.checkargsEx({funcName = 'distance'}, {
            {type = 'vector', size = data.opt.dim},
            {type = 'vector', size = data.opt.dim},
        }, conf1, conf2)
    end
    confA = confA:data()
    confB = confB:data()
    local d = 0
    local qcnt = 0
    for j = 1, #confA, 1 do
        local dd = 0
        if (data.opt.types[j] == 0) or (#data.opt.bounds[j] == 2) then
            dd = (confB[j] - confA[j]) * data.opt.metric[j] -- e.g. joint with limits
        elseif data.opt.types[j] == 1 then
            local dx = math.atan2(math.sin(confB[j] - confA[j]), math.cos(confB[j] - confA[j]))
            dd = math.abs(dx) * data.opt.metric[j]
            --[[
            local dx = math.atan2(math.sin(confB[j] - confA[j]), math.cos(confB[j] - confA[j]))
            local v = confA[j] + dx
            dd = math.atan2(math.sin(v), math.cos(v)) * data.opt.metric[j] -- cyclic rev. joint (-pi;pi)
            --]]
        elseif data.opt.types[j] == 2 then
            qcnt = qcnt + 1
            if qcnt == 4 then
                qcnt = 0
                local q1 = simEigen.Quaternion({confA[j - 3], confA[j - 2], confA[j - 1], confA[j - 0]})
                local q2 = simEigen.Quaternion({confB[j - 3], confB[j - 2], confB[j - 1], confB[j - 0]})
                local axis, angle = q1:axisangle(q2)
                dd = angle * data.opt.metric[j - 3]
            end
        end
        d = d + dd * dd
    end
    return math.sqrt(d)
end

function Path:interpolate(conf1, conf2, t, noArgCheck)
    local data = self._data
    local confA = conf1
    local confB = conf2
    if not noArgCheck then
        confA, confB, t = checkargs.checkargsEx({funcName = 'interpolate'}, {
            {type = 'vector', size = data.opt.dim},
            {type = 'vector', size = data.opt.dim},
            {type = 'float'},
        }, conf1, conf2, t)
    end
    confA = confA:data()
    confB = confB:data()

    local retVal = {}
    local qcnt = 0
    for i = 1, #confA, 1 do
        if (data.opt.types[i] == 0) or (#data.opt.bounds[i] == 2) then
            retVal[i] = confA[i] * (1 - t) + confB[i] * t -- e.g. joint with limits
        elseif data.opt.types[i] == 1 then
            local dx = math.atan2(math.sin(confB[i] - confA[i]), math.cos(confB[i] - confA[i]))
            local v = confA[i] + dx * t
            retVal[i] = math.atan2(math.sin(v), math.cos(v)) -- cyclic rev. joint (-pi;pi)
        elseif data.opt.types[i] == 2 then
            qcnt = qcnt + 1
            if qcnt == 4 then
                qcnt = 0
                local q1 = simEigen.Quaternion({confA[i - 3], confA[i - 2], confA[i - 1], confA[i - 0]})
                local q2 = simEigen.Quaternion({confB[i - 3], confB[i - 2], confB[i - 1], confB[i - 0]})
                local q = q1:slerp(t, q2)
                retVal = table.add(retVal, q:data())
            end
        end
    end
    return simEigen.Vector(retVal)
end

function Path:configs(conf, noArgCheck)
    local data = self._data
    if not noArgCheck then
        conf = checkargs.checkargsEx({funcName = 'configs'}, {
            {type = 'vector', size = data.opt.dim},
        }, conf)
    end
    local inputConfig = conf:data()
    sim.self:setStepping(true)
    
    local lowLimits = table.rep(0.0, #inputConfig)
    local ranges = table.rep(0.0, #inputConfig)
    for i = 1, #inputConfig do
        if data.opt.types[i] == 1 then
            if #data.opt.bounds[i] == 2 then
                local r = data.opt.bounds[i][2] - data.opt.bounds[i][1]
                if r > 2.0 * math.pi then
                    ranges[i] = r
                end
            end
        end
    end

    function _loopThroughAltConfigSolutions(confS, x, index)
        if index > #confS then
            return {copy.deepcopy(confS)}
        else
            local c = copy.deepcopy(confS)
            local solutions = {}
            while c[index] <= x[index][2] do
                local s = _loopThroughAltConfigSolutions(c, x, index + 1)
                for i = 1, #s, 1 do solutions[#solutions + 1] = s[i] end
                c[index] = c[index] + math.pi * 2.0
            end
            return solutions
        end
    end

    local x = {}
    local confS = {}
    local configs = {}
    local err = false
    for i = 1, #ranges do
        if ranges[i] > 0.0 then
            local pi2 = math.pi * 2.0
            while inputConfig[i] > lowLimits[i] + ranges[i] do
                inputConfig[i] = inputConfig[i] - pi2
            end
            while inputConfig[i] < lowLimits[i] do
                inputConfig[i] = inputConfig[i] + pi2
            end
            if (inputConfig[i] >= lowLimits[i]) and (inputConfig[i] <= lowLimits[i] + ranges[i]) then
                if inputConfig[i] - pi2 >= lowLimits[i] or inputConfig[i] + pi2 <= lowLimits[i] + ranges[i] then
                    local y = inputConfig[i]
                    while y - pi2 >= lowLimits[i] do 
                        y = y - pi2 
                    end
                    x[i] = {y, lowLimits[i] + ranges[i]}
                else
                    ranges[i] = 0.0
                end
            else
                err = true
            end
        end
        if x[i] == nil then
            x[i] = {inputConfig[i], inputConfig[i]} -- there's no alternative position for this joint
        end
        confS[i] = x[i][1]
    end
    if not err then
        configs = _loopThroughAltConfigSolutions(confS, x, 1)
    end
    local retVal = simEigen.Matrix(configs).T
    sim.self:setStepping(false)
    return retVal
end

function Path:_resample(points, resamplingType)
    local data = self._data
    local pts = points
    if data.opt.closed then
        pts = pts:horzcat(pts:block(1, 1, -1, 1))
    end
    local arcL, distances, totalL = self:_computeArcLengths(pts)
    local retPts
    resamplingType = resamplingType or data.pathPoints.opt.type 
    if resamplingType == 0 then
        retPts = pts:block(1, 1, -1, 1)
        local cnt = math.floor(totalL / data.pathPoints.opt.samplingDistance)
        local sd = totalL / (cnt + 1.0)
        local l = 0.0
        local paInd = 1
        for i = 1, cnt do
            l = l + sd
            while l > distances[paInd + 1] do
                paInd = paInd + 1
            end
            local pa = pts:block(1, paInd, -1, 1)
            local pb = pts:block(1, paInd + 1, -1, 1)
            local r = (l - distances[paInd + 0]) / (distances[paInd + 1] - distances[paInd + 0])
            retPts = retPts:horzcat(self:interpolate(pa, pb, r, true))
        end
        if not data.opt.closed then
            retPts = retPts:horzcat(pts:block(1, pts:cols(), -1, 1))
        end
    else
        local function getBezierPt(a, b, c, t)
            local pia = self:interpolate(a, b, 0.5, true)
            local pib = self:interpolate(b, c, 0.5, true)
            if data.pathPoints.opt.bezierSmoothing < 0.999 then
                pia = self:interpolate(b, pia, data.pathPoints.opt.bezierSmoothing, true)
                pib = self:interpolate(b, pib, data.pathPoints.opt.bezierSmoothing, true)
            end

            local p1 = self:interpolate(pia, b, t, true)
            local p2 = self:interpolate(b, pib, t, true)
            return self:interpolate(p1, p2, t, true)
        end
        retPts = simEigen.Matrix(data.opt.dim, 0, {})
        if data.opt.closed then
            pts = pts:horzcat(pts:block(1, 2, -1, 1))
            pts = pts:block(1, pts:cols() - 2, -1, 1):horzcat(pts)
        else
            local a = pts:block(1, pts:cols() - 1, -1, 1)
            local b = pts:block(1, pts:cols() - 0, -1, 1)
            pts = pts:horzcat(self:interpolate(a, b, 2.0, true))
            local a = pts:block(1, 2, -1, 1)
            local b = pts:block(1, 1, -1, 1)
            pts = self:interpolate(a, b, 2.0, true):horzcat(pts)
        end
        local cnt = math.floor(totalL * 2.0 / data.pathPoints.opt.samplingDistance) + 1.0 -- first a smaller sampling
        local sd = totalL / cnt
        local l = 0.0
        local paInd = 1
        for i = 1, cnt + 1 do
            while (l > distances[paInd + 1]) and (distances:rows() > paInd + 1) do
                paInd = paInd + 1
            end
            local px = pts:block(1, paInd + 0, -1, 1)
            local pa = pts:block(1, paInd + 1, -1, 1)
            local pb = pts:block(1, paInd + 2, -1, 1)
            local py = pts:block(1, paInd + 3, -1, 1)
            local r = (l - distances[paInd + 0]) / (distances[paInd + 1] - distances[paInd + 0])
            local pi
            if r >= 0.5 then
                pi = getBezierPt(pa, pb, py, r - 0.5)
            else
                pi = getBezierPt(px, pa, pb, r + 0.5)
            end
            retPts = retPts:horzcat(pi)
            l = l + sd
        end
        if not data.opt.closed then
            retPts = retPts:horzcat(pts:block(1, pts:cols() - 1, -1, 1))
        end
        retPts = self:_resample(retPts, 0)
    end
    return retPts
end

function Path:createShape(opt)
    self:update()
    local data = self._data
    local pts
    if data.opt.onlyCtrlPoints then
        pts = data.ctrlPoints.points
    else
        pts = data.pathPoints.points
    end
    assert(data.opt.dim >= 2 and pts:cols() >= 2 and data.opt.types[1] == 0 and data.opt.types[2] == 0, 'path not appropriate for shape creation.')
    local w = 2
    if data.opt.dim >= 3 and data.opt.types[3] == 0 then
        w = 3
        if data.opt.dim >= 7 then
            w = 7
            for i = 4, 7 do
                if data.opt.types[i] ~= 2 then
                    w = 3
                    break
                end
            end
        end
    end
    pts = pts:block(1, 1, w, -1)
    if w == 2 then
        pts = pts:vertcat(simEigen.Matrix(1, pts:cols(), 0.0))
        w = 3
    end
    if w == 3 then
        pts = pts:vertcat(simEigen.Matrix(3, pts:cols(), 0.0))
        pts = pts:vertcat(simEigen.Matrix(1, pts:cols(), 1.0))
    end
    if data.opt.closed then
        pts = pts:horzcat(pts:block(1, 1, -1, 1))
    end
    
    return callMethod(-1, 'createShapeFromPath', pts, opt)
end

function Path:closest(point)
    local data = self._data
    if not noArgCheck then
        point = checkargs.checkargsEx({funcName = 'closest'}, {
            {type = 'vector', size = data.opt.dim},
        }, point)
    end
    self:update()
    local pts, arcLengths, distancesAlongPath, pathLength
    if data.opt.onlyCtrlPoints then
        pts = data.ctrlPoints.points
        arcLengths = data.ctrlPoints.arcLengths
        distancesAlongPath = data.ctrlPoints.distancesAlongPath
        pathLength = data.ctrlPoints.pathLength
    else
        pts = data.pathPoints.points
        arcLengths = data.pathPoints.arcLengths
        distancesAlongPath = data.pathPoints.distancesAlongPath
        pathLength = data.pathPoints.pathLength
    end
    assert(pts:cols() > 0, 'path is empty.')
    if pts:cols() == 1 then
        return pts:copy(), 0.0
    else
        if data.opt.closed then
            pts = pts:horzcat(pts:block(1, 1, -1, 1))
        end
        opt = {metric = data.opt.metric}
        opt.types = {}
        for i = 1, data.opt.dim do
            if (data.opt.types[i] == 0) or (#data.opt.bounds[i] == 2) then
                opt.types[i] = 0
            else
                opt.types[i] = data.opt.types[i]
            end
        end
        local pt, ind = callMethod(-1, 'getClosestOnPath', pts, point, opt)
        local pt1 = pts:block(1, ind + 1, -1, 1)
        local pt2 = pts:block(1, ind + 2, -1, 1)
        local t = self:distance(pt1, pt) / self:distance(pt1, pt2)
        local l = distancesAlongPath[ind + 1] + t * arcLengths[ind + 1]
        return pt, l / pathLength
    end
end

function Path:getPoint(distance)
    local data = self._data
    if not noArgCheck then
        distance = checkargs.checkargsEx({funcName = 'getPoint'}, {
            {type = 'float'},
        }, distance)
    end
    self:update()
    if distance < 0.0 then
        distance = 0.0
    end
    if distance > 1.0 then
        distance = 1.0
    end
    local pts, arcLengths, distancesAlongPath, pathLength
    if data.opt.onlyCtrlPoints then
        pts = data.ctrlPoints.points
        arcLengths = data.ctrlPoints.arcLengths
        distancesAlongPath = data.ctrlPoints.distancesAlongPath
        pathLength = data.ctrlPoints.pathLength
    else
        pts = data.pathPoints.points
        arcLengths = data.pathPoints.arcLengths
        distancesAlongPath = data.pathPoints.distancesAlongPath
        pathLength = data.pathPoints.pathLength
    end
    assert(pts:cols() > 0, 'path is empty.')
    if pts:cols() == 1 then
        return pts:copy()
    else
        local l = distance * pathLength
        if data.opt.closed then
            pts = pts:horzcat(pts:block(1, 1, -1, 1))
            distancesAlongPath = distancesAlongPath:horzcat(simEigen.Matrix(1, 1, {pathLength}))
        end
        local retVal
        for i = 1, distancesAlongPath:rows() - 1 do
            if distancesAlongPath[i + 1] > l then
                local d2 = distancesAlongPath[i + 1] - distancesAlongPath[i + 0]
                local d1 = l - distancesAlongPath[i + 0]
                retVal = self:interpolate(pts:block(1, i, -1, 1), pts:block(1, i + 1, -1, 1), d1 / d2)
                break
            end
        end
        if retVal == nil then
            if data.opt.closed then
                retVal = pts:block(1, 1, -1, 1)
            else
                retVal = pts:block(1, pts:cols(), -1, 1)
            end
        end
        return retVal
    end
end

function Path:createMarkers()
    self:update()
    local data = self._data
    self:removeMarkers()
    data.ctrlPoints.markers = self:_createMarkers(data.ctrlPoints.points, data.ctrlPoints.opt)
    if not data.opt.onlyCtrlPoints then
        data.pathPoints.markers = self:_createMarkers(data.pathPoints.points, data.pathPoints.opt)
    end
end

function Path:_updateMarkers()
    local data = self._data
    if data.ctrlPoints.markers then
        self:__updateMarkers(data.ctrlPoints.markers, data.ctrlPoints.points)
    end
    if data.pathPoints.markers then
        self:__updateMarkers(data.pathPoints.markers, data.pathPoints.points)
    end
end

function Path:_createMarkers(points, opt)
    local data = self._data
    local retPointMarker, retLineMarker, retRefMarker
    if data.opt.displDim ~= 0 then
        if opt.pointType ~= 0 or opt.showAxes then
            if opt.pointType ~= 0 then
                local t = 'spheres'
                if opt.pointType == 2 then
                    t = 'cubes'
                end
                retPointMarker = sim.scene:createObject({type = 'marker', ['marker.type'] = t, ['local'] = true, itemSize = table.rep(opt.pointRadius * 2.0, 3), itemColor = opt.pointColor})
            end
            if opt.showAxes then
                retRefMarker = sim.scene:createObject({type = 'marker', ['marker.type'] = 'axes', ['local'] = true, itemSize = table.rep(opt.pointRadius * 2.0, 3)})
            end
        end
        if opt.lineType ~= 0 then
            local t = 'lines'
            if opt.lineType == 2 then
                t = 'tubes'
            end
            retLineMarker = sim.scene:createObject({type = 'marker', ['marker.type'] = t, ['local'] = true, itemSize = table.rep(opt.tubeRadius * 2.0, 3), itemColor = opt.lineColor})
        end
    end
    local markers = {pointMarker = retPointMarker, lineMarker = retLineMarker, axesMarker = retRefMarker}
    self:__updateMarkers(markers, points)
    return markers
end

function Path:__updateMarkers(markers, points)
    local data = self._data
    if markers.pointMarker then
        markers.pointMarker:clearItems()
    end
    if markers.axesMarker then
        markers.axesMarker:clearItems()
    end
    if markers.lineMarker then
        markers.lineMarker:clearItems()
    end
    if points:cols() > 0 then
        if data.opt.joints then
            if data.opt.ik == nil then
                data.opt.ik = {}
                data.opt.ik.ikEnv = simIK.createEnvironment()
                local group = simIK.createGroup(data.opt.ik.ikEnv)
                local b = -1
                if data.opt.base then
                    b = data.opt.base.handle
                end
                local element, mapping = simIK.addElementFromScene(data.opt.ik.ikEnv, group, b, data.opt.tip.handle, data.opt.tip.handle, 0)
                data.opt.ik.joints = {}
                for i = 1, data.opt.dim do
                    data.opt.ik.joints[i] = mapping[data.opt.joints[i].handle]
                end
                data.opt.ik.tip = mapping[data.opt.tip.handle]
            end
            if data.opt.base then
                simIK.setObjectPose(data.opt.ik.ikEnv, data.opt.ik.base, data.opt.base.worldPose:data())
            else
                simIK.setObjectPose(data.opt.ik.ikEnv, data.opt.ik.joints[1], data.opt.joints[1].worldPose:data())
            end
            local firstDat, lastDat
            for i = 1, points:cols() do
                local off = 1
                for j = 1, #data.opt.ik.joints do
                    if data.opt.types[j] == 2 then
                        simIK.setJointQuaternion(data.opt.ik.ikEnv, data.opt.ik.joints[j], points:block(off, i, 4, 1):data())
                        off = off + 4
                    else
                        simIK.setJointPosition(data.opt.ik.ikEnv, data.opt.ik.joints[j], points:item(off, i))
                        off = off + 1
                    end
                end
                local ppos, qq = simIK.getObjectTransformation(data.opt.ik.ikEnv, data.opt.ik.tip)
                local dat = simEigen.Vector(ppos)
                local quat = simEigen.Vector(qq)
                if markers.pointMarker then
                    markers.pointMarker:addItems(dat, {quaternions = quat})
                end
                if markers.axesMarker then
                    markers.axesMarker:addItems(dat, {quaternions = quat})
                end
                if markers.lineMarker then
                    if firstDat then
                        markers.lineMarker:addItems(lastDat:horzcat(dat))
                    else
                        firstDat = dat
                    end
                    lastDat = dat
                    if data.opt.closed and (i == points:cols()) then
                        markers.lineMarker:addItems(lastDat:horzcat(firstDat))
                    end
                end
            end
        else
            if markers.pointMarker or markers.axesMarker then
                local dat
                local quat
                if data.opt.displDim == 2 then
                    dat = points:block(1, 1, 2, -1):vertcat(simEigen.Matrix(1, points:cols(), 0.0))
                elseif data.opt.displDim == 3 then
                    dat = points:block(1, 1, 3, -1)
                elseif data.opt.displDim == 7 then
                    dat = points:block(1, 1, 3, -1)
                    quat = points:block(4, 1, 4, -1)
                end
                if markers.pointMarker then
                    markers.pointMarker:addItems(dat, {quaternions = quat})
                end
                if markers.axesMarker then
                    markers.axesMarker:addItems(dat, {quaternions = quat})
                end
            end
            if markers.lineMarker then
                local dat
                if data.opt.displDim == 2 then
                    dat = points:block(1, 1, 2, -1):vertcat(simEigen.Matrix(1, points:cols(), 0.0))
                else
                    dat = points:block(1, 1, 3, -1)
                end
                local lines = simEigen.Matrix(dat:rows(), 0, {})
                for i = 1, dat:cols() - 1 do
                    lines = lines:horzcat(dat:block(1, i, -1, 2))
                end
                if data.opt.closed then
                    lines = lines:horzcat(dat:block(1, dat:cols(), -1, 1))
                    lines = lines:horzcat(dat:block(1, 1, -1, 1))
                end
                markers.lineMarker:addItems(lines)
            end
        end
    end
end

function Path:removeMarkers()
    local data = self._data
    if data.ctrlPoints.markers then
        self:_removeMarkers(data.ctrlPoints.markers)
        data.ctrlPoints.markers = nil
    end
    if data.pathPoints.markers then
        self:_removeMarkers(data.pathPoints.markers)
        data.pathPoints.markers = nil
    end
    if data.opt.ik then
        simIK.eraseEnvironment(data.opt.ik.ikEnv)
        data.opt.ik = nil
    end
end

function Path:_removeMarkers(m)
    if m then
        if m.pointMarker and m.pointMarker:isValid() then
            m.pointMarker:remove()
            m.pointMarker = nil
        end
        if m.lineMarker and m.lineMarker:isValid()  then
            m.lineMarker:remove()
            m.lineMarker = nil
        end
        if m.axesMarker and m.axesMarker:isValid()  then
            m.axesMarker:remove()
            m.axesMarker = nil
        end
    end
end

return Path
