local sim = require 'sim-2'
local class = require('middleclass')
local copy = require('copy')
local checkargs = require('checkargs-2')
local simEigen = require('simEigen')
local simIK = require('simIK-1')

local Path = class('Path')

local sin, cos, atan2, acos, sqrt, abs, floor =
    math.sin, math.cos, math.atan2, math.acos,
    math.sqrt, math.abs, math.floor

local function pointTableFromMatrix(m)
    local t = {}
    for i = 1, m:cols() do
        t[i] = m:block(1, i, -1, 1):data()
    end
    return t
end

local function matrixFromPointTable(rows, t)
    if #t == 0 then
        return simEigen.Matrix(rows, 0, {})
    end
    return simEigen.Matrix(t).T
end

-- Copies only the outer table. Individual point tables are treated as
-- immutable once installed in a path cache.
local function copyPointTable(t)
    local r = {}
    for i = 1, #t do
        r[i] = t[i]
    end
    return r
end

function Path:_initializeRuntimeCache()
    local data = self._data
    local opt = data.opt

    local cache = {
        dim = opt.dim,
        metric = opt.metric:data(),
        modes = {},
        ctrlPoints = {},
        pathPoints = {},
    }

    -- 0: linear/bounded angular
    -- 1: cyclic angular
    -- 2: first component of quaternion
    -- 3: remaining quaternion component, skipped by kernels
    local i = 1
    while i <= opt.dim do
        if opt.types[i] == 2 then
            cache.modes[i] = 2
            cache.modes[i + 1] = 3
            cache.modes[i + 2] = 3
            cache.modes[i + 3] = 3
            i = i + 4
        elseif opt.types[i] == 0 or #opt.bounds[i] == 2 then
            cache.modes[i] = 0
            i = i + 1
        else
            cache.modes[i] = 1
            i = i + 1
        end
    end

    self._cache = cache
end

function Path:_rebuildPointCache(name)
    local src = self._data[name]
    local dst = self._cache[name]

    dst.points = pointTableFromMatrix(src.points)

    if src.arcLengthsTable then
        dst.arcLengths = src.arcLengthsTable
    elseif src.arcLengths then
        dst.arcLengths = src.arcLengths:data()
    else
        dst.arcLengths = {}
    end

    if src.distancesAlongPathTable then
        dst.distancesAlongPath = src.distancesAlongPathTable
    elseif src.distancesAlongPath then
        dst.distancesAlongPath = src.distancesAlongPath:data()
    else
        dst.distancesAlongPath = {}
    end

    dst.pathLength = src.pathLength or 0.0
end

function Path:_rebuildRuntimePointCaches()
    self:_rebuildPointCache('ctrlPoints')

    if not self._data.opt.onlyCtrlPoints then
        self:_rebuildPointCache('pathPoints')
    end
end

function Path:_selectedPointCache()
    if self._data.opt.onlyCtrlPoints then
        return self._cache.ctrlPoints
    end
    return self._cache.pathPoints
end

function Path:initialize(ctrlPoints, opt, data)
    if data then
        self._data = data

        -- Runtime-only cache is deliberately not serialized:
        self:_initializeRuntimeCache()
        self:_rebuildRuntimePointCaches()
        return
    else
        ctrlPoints = checkargs.checkargsEx({funcName = 'Path:new'}, {
            {type = 'matrix', nullable = true},
        }, ctrlPoints)
        opt = opt or {}
        opt.ctrlPoints = opt.ctrlPoints or {}
        opt.pathPoints = opt.pathPoints or {}
        -- opt.upVector
        opt.forwardAndUpAxes = opt.forwardAndUpAxes or 'xz'
        checkargs.checkfields({funcName = "Path:new, options field 'ctrlPoints'"}, {
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
        checkargs.checkfields({funcName = "Path:new, options field 'pathPoints'"}, {
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
        checkargs.checkfields({funcName = 'Path:new, options argument'}, {
            {name = 'onlyCtrlPoints', type = 'bool', default = false},
            {name = 'closed', type = 'bool', default = false},
            {name = 'closedRepeatsStart', type = 'bool', default = false},
            {name = 'forwardAndUpAxes', type = 'string', default = 'xz'},
            {name = 'upVector', type = 'vector3', nullable = true},
        }, opt)

        if ctrlPoints then
            opt.dim = ctrlPoints:rows()
            assert(opt.dim > 0, 'invalid control points')
            if (opt.types == nil) and (opt.dim == 7) then
                opt.types = {'lin', 'lin', 'lin', 'quat', 'quat', 'quat', 'quat'}
            end
            checkargs.checkfields({funcName = 'Path:new, options argument'}, {
                {name = 'metric', type = 'vector', size = opt.dim, default = simEigen.Vector(opt.dim, 1.0)},
                {name = 'types', type = 'table', size = opt.dim, default = table.rep('lin', opt.dim)},
                {name = 'bounds', type = 'table', size = opt.dim, default = table.rep({}, opt.dim)},
            }, opt)
        else
            checkargs.checkfields({funcName = 'Path:new, options argument'}, {
                {name = 'types', type = 'table', range = '1..*'}, -- in this case not optional
            }, opt)
            opt.dim = #opt.types
            checkargs.checkfields({funcName = 'Path:new, options argument'}, {
                {name = 'metric', type = 'vector', size = opt.dim, default = simEigen.Vector(opt.dim, 1.0)},
                {name = 'bounds', type = 'table', size = opt.dim, default = table.rep({}, opt.dim)},
            }, opt)
            ctrlPoints = simEigen.Matrix(opt.dim, 0, {})
        end
        if (opt.forwardAndUpAxes ~= 'xy') and (opt.forwardAndUpAxes ~= 'xz') and
            (opt.forwardAndUpAxes ~= 'yx') and (opt.forwardAndUpAxes ~= 'yz') and
            (opt.forwardAndUpAxes ~= 'zx') and (opt.forwardAndUpAxes ~= 'zy') then
            error("invalid 'forwardAxis' string")
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
    self:_initializeRuntimeCache()
    self:setPoints(ctrlPoints, true)
    end
end

function Path.fromBuffer(buff, objects)
    local data = sim.app:unpack(buff)
    objects = objects or {}
    for k, v in pairs(objects) do
        data.opt[k] = v
    end
    return Path(nil, nil, data)
end

function Path.fromJoints(endEffector, base, opt)
    endEffector, base = checkargs.checkargsEx({funcName = 'Path.fromJoints'}, {
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
    obj = checkargs.checkargsEx({funcName = 'Path.fromObject'}, {
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
        ctrlPoints = checkargs.checkargsEx({funcName = 'Path:setPoints'}, {
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
        data.ctrlPoints.points = self:_orientPosesAlongPath(data.ctrlPoints.points)
        data.ctrlPoints.arcLengths, data.ctrlPoints.distancesAlongPath, data.ctrlPoints.pathLength, data.ctrlPoints.arcLengthsTable, data.ctrlPoints.distancesAlongPathTable = self:_computeArcLengths(data.ctrlPoints.points)
        if not data.opt.onlyCtrlPoints then
            data.pathPoints.points = self:_resample(data.ctrlPoints.points)
            data.pathPoints.points = self:_orientPosesAlongPath(data.pathPoints.points)
            data.pathPoints.arcLengths, data.pathPoints.distancesAlongPath, data.pathPoints.pathLength, data.pathPoints.arcLengthsTable, data.pathPoints.distancesAlongPathTable = self:_computeArcLengths(data.pathPoints.points)
        end
    else
        if ctrlPoints:cols() == 1 then
            data.ctrlPoints.distancesAlongPath = simEigen.Vector{0.0}
            data.ctrlPoints.distancesAlongPathTable = {0.0}
            data.ctrlPoints.arcLengthsTable = {}

            if not data.opt.onlyCtrlPoints then
                data.pathPoints.points = copy.copy(ctrlPoints)
                data.pathPoints.distancesAlongPath = simEigen.Vector{0.0}
                data.pathPoints.distancesAlongPathTable = {0.0}
                data.pathPoints.arcLengthsTable = {}
            end
        else
            data.ctrlPoints.distancesAlongPath = simEigen.Vector{}
            data.ctrlPoints.distancesAlongPathTable = {}
            data.ctrlPoints.arcLengthsTable = {}

            if not data.opt.onlyCtrlPoints then
                data.pathPoints.points =
                    simEigen.Matrix(data.opt.dim, 0, {})
                data.pathPoints.distancesAlongPath = simEigen.Vector{}
                data.pathPoints.distancesAlongPathTable = {}
                data.pathPoints.arcLengthsTable = {}
            end
        end

        data.ctrlPoints.arcLengths = simEigen.Vector{}
        data.ctrlPoints.pathLength = 0.0

        if not data.opt.onlyCtrlPoints then
            data.pathPoints.arcLengths = simEigen.Vector{}
            data.pathPoints.pathLength = 0.0
        end
    end
    self:_rebuildRuntimePointCaches()
    self:_updateMarkers()
    sim.self:setStepping(false)
end

function Path:appendPoints(ctrlPoints, update)
    if update == nil then
        update = true
    end
    local data = self._data
    ctrlPoints = checkargs.checkargsEx({funcName = 'Path:appendPoints'}, {
        {type = 'matrix', rows = data.opt.dim},
    }, ctrlPoints)
    assert(ctrlPoints:cols() > 0, 'invalid points')

    local toUpdate = data.ctrlPoints.toUpdate
    if not toUpdate then
        toUpdate = copyPointTable(self._cache.ctrlPoints.points)
    end

    local newPoints = pointTableFromMatrix(ctrlPoints)
    for i = 1, #newPoints do
        toUpdate[#toUpdate + 1] = newPoints[i]
    end

    data.ctrlPoints.toUpdate = toUpdate

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
    local ctrlPoint = {}
    for i = 1, data.opt.dim do
        if data.opt.types[i] ~= 2 then
            ctrlPoint[#ctrlPoint + 1] = data.opt.joints[i].joint.position
        else
            table.add(ctrlPoint, data.opt.joints[i].joint.quaternion:data())
        end
    end
    local toUpdate = data.ctrlPoints.toUpdate
    if not toUpdate then
        -- Do not mutate the installed cache while points are pending.
        toUpdate = copyPointTable(self._cache.ctrlPoints.points)
    end
    local newPt = ctrlPoint
    if data.ctrlPoints.opt.duplicateThreshold > 0.0 then
        if #toUpdate > 0 then
            if self:_distanceTables(toUpdate[#toUpdate], newPt) < data.ctrlPoints.opt.duplicateThreshold then
                newPt = nil
            end
        end
    end
    if newPt then
        toUpdate[#toUpdate + 1] = newPt
        data.ctrlPoints.toUpdate = toUpdate
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
    local toUpdate = data.ctrlPoints.toUpdate
    if not toUpdate then
        -- Do not mutate the installed cache while points are pending.
        toUpdate = copyPointTable(self._cache.ctrlPoints.points)
    end
    local newPt = data.opt.object.worldPose:data()
    if data.ctrlPoints.opt.duplicateThreshold > 0.0 then
        if #toUpdate > 0 then
            if self:_distanceTables(toUpdate[#toUpdate], newPt) < data.ctrlPoints.opt.duplicateThreshold then
                newPt = nil
            end
        end
    end
    if newPt then
        toUpdate[#toUpdate + 1] = newPt
        data.ctrlPoints.toUpdate = toUpdate
        if update then
            self:update()
        end
    end
end

function Path:update()
    local data = self._data
    if data.ctrlPoints.toUpdate then
        -- generate the matrix from the accumulated table-of-tables, in one go:
        self:setPoints(matrixFromPointTable(data.opt.dim, data.ctrlPoints.toUpdate))
        data.ctrlPoints.toUpdate = nil
    end
end

function Path:clearPoints()
    self._data.ctrlPoints.toUpdate = nil
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

    -- operates on a table-of-tables (one inner table per point):
    local function __removeDuplicates(pts)
        local removed = 0
        local minPtCnt = 2

        -- temp. append the first point with closed paths:
        if data.opt.closed then
            pts[#pts + 1] = pts[1]
            minPtCnt = 3
        end

        if #pts > minPtCnt then
            -- Remove points close to the first point:
            local firstPoint = simEigen.Vector(pts[1])
            local i = 2
            while i <= #pts - 1 do
                local p = simEigen.Vector(pts[i])
                if self:distance(firstPoint, p, true) < data.ctrlPoints.opt.duplicateThreshold then
                    table.remove(pts, i)
                    removed = removed + 1
                else
                    break
                end
                i = i + 1
            end

            if #pts > minPtCnt then
                -- Remove points close to the last point:
                local lastPoint = simEigen.Vector(pts[#pts])
                local i = #pts - 1
                while i >= 2 do
                    local p = simEigen.Vector(pts[i])
                    if self:distance(lastPoint, p, true) < data.ctrlPoints.opt.duplicateThreshold then
                        table.remove(pts, i)
                        removed = removed + 1
                    else
                        break
                    end
                    i = i - 1
                end

                if #pts > minPtCnt then
                    -- merge points pairwise:
                    local points = pts
                    local merged = {points[1]}
                    local i = 2
                    if #points == 3 then
                        merged[#merged + 1] = points[2]
                    else
                        while i <= #points - 2 do
                            local p0 = simEigen.Vector(points[i])
                            local p1 = simEigen.Vector(points[i + 1])
                            local d = self:distance(p0, p1, true)
                            if d >= data.ctrlPoints.opt.duplicateThreshold then
                                merged[#merged + 1] = points[i]
                            else
                                merged[#merged + 1] = self:interpolate(p0, p1, 0.5, true):data()
                                removed = removed + 1
                                i = i + 1
                            end
                            i = i + 1
                        end
                    end
                    if i == #points - 1 then
                        merged[#merged + 1] = points[i]
                    end
                    merged[#merged + 1] = points[#points] -- last point
                    pts = merged
                end
            end
        end

        -- Remove the last point (coincident with the first point), with closed paths:
        if data.opt.closed then
            table.remove(pts)
        end

        return pts, removed
    end

    local cnt = 0
    local ret = pointTableFromMatrix(points)
    while true do
        local r
        ret, r = __removeDuplicates(ret)
        if r == 0 then
            break
        end
        cnt = cnt + r
    end
    return matrixFromPointTable(data.opt.dim, ret), cnt
end

function Path:_removeColinearSegments(points)
    local data = self._data

    -- operates on a table-of-tables (one inner table per point):
    local function __removeColinearSegments(pts)
        -- temp. append the first point with closed paths:
        if data.opt.closed then
            pts[#pts + 1] = pts[1]
        end

        local toPrune = {}
        for i = 1, #pts - 3 do
            local p0 = simEigen.Vector(pts[i])
            local p1 = simEigen.Vector(pts[i + 1])
            local p2 = simEigen.Vector(pts[i + 2])
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
        local retVal = {}
        local removed = 0
        for i = 1, #pts do
            if colsToRemove[i] then
                removed = removed + 1
            else
                retVal[#retVal + 1] = pts[i]
            end
        end
        -- Remove the last point (coincident with the first point), with closed paths:
        if data.opt.closed then
            table.remove(retVal)
        end
        return retVal, removed
    end

    local cnt = 0
    local ret = pointTableFromMatrix(points)
    while true do
        local r
        ret, r = __removeColinearSegments(ret)
        if r == 0 then
            break
        end
        cnt = cnt + r
    end
    return matrixFromPointTable(data.opt.dim, ret), cnt
end

function Path:_computeArcLengths(points)
    local pts = pointTableFromMatrix(points)
    local count = #pts

    local totalLength = 0.0
    local arcLengths = {}
    local distances = {}

    if count > 0 then
        distances[1] = 0.0
    end

    for i = 1, count - 1 do
        local d = self:_distanceTables(pts[i], pts[i + 1])
        arcLengths[i] = d
        totalLength = totalLength + d
        distances[i + 1] = totalLength
    end

    if self._data.opt.closed and count > 1 then
        local d = self:_distanceTables(pts[count], pts[1])
        arcLengths[count] = d
        totalLength = totalLength + d
    end

    return simEigen.Vector(arcLengths),
        simEigen.Vector(distances),
        totalLength,
        arcLengths,
        distances
end

function Path:_distanceTables(a, b)
    local cache = self._cache
    local modes = cache.modes
    local metric = cache.metric
    local dim = cache.dim

    local squaredDistance = 0.0
    local i = 1

    while i <= dim do
        local mode = modes[i]

        if mode == 0 then
            local d = (b[i] - a[i]) * metric[i]
            squaredDistance = squaredDistance + d * d
            i = i + 1

        elseif mode == 1 then
            local delta = b[i] - a[i]
            local d = abs(atan2(sin(delta), cos(delta))) * metric[i]
            squaredDistance = squaredDistance + d * d
            i = i + 1

        else -- quaternion
            local dot =
                a[i]     * b[i] +
                a[i + 1] * b[i + 1] +
                a[i + 2] * b[i + 2] +
                a[i + 3] * b[i + 3]

            -- q and -q represent the same orientation.
            dot = abs(dot)
            if dot > 1.0 then
                dot = 1.0
            end

            local d = 2.0 * acos(dot) * metric[i]
            squaredDistance = squaredDistance + d * d
            i = i + 4
        end
    end

    return sqrt(squaredDistance)
end

function Path:distance(conf1, conf2, noArgCheck)
    local data = self._data
    local confA, confB = conf1, conf2

    if not noArgCheck then
        confA, confB = checkargs.checkargsEx(
            {funcName = 'Path:distance'},
            {
                {type = 'vector', size = data.opt.dim},
                {type = 'vector', size = data.opt.dim},
            },
            conf1, conf2
        )
    end

    return self:_distanceTables(confA:data(), confB:data())
end

function Path:_interpolatePose(points, i1, i2, t)
    local ax = points:item(1, i1)
    local ay = points:item(2, i1)
    local az = points:item(3, i1)
    local aqx = points:item(4, i1)
    local aqy = points:item(5, i1)
    local aqz = points:item(6, i1)
    local aqw = points:item(7, i1)

    local bx = points:item(1, i2)
    local by = points:item(2, i2)
    local bz = points:item(3, i2)
    local bqx = points:item(4, i2)
    local bqy = points:item(5, i2)
    local bqz = points:item(6, i2)
    local bqw = points:item(7, i2)

    local dot = aqx * bqx + aqy * bqy + aqz * bqz + aqw * bqw
    if dot < 0.0 then
        bqx, bqy, bqz, bqw = -bqx, -bqy, -bqz, -bqw
        dot = -dot
    end
    if dot > 1.0 then
        dot = 1.0
    end

    local qx, qy, qz, qw

    if dot > 0.9995 then
        qx = aqx + (bqx - aqx) * t
        qy = aqy + (bqy - aqy) * t
        qz = aqz + (bqz - aqz) * t
        qw = aqw + (bqw - aqw) * t

        local invNorm = 1.0 / math.sqrt(
            qx * qx + qy * qy + qz * qz + qw * qw
        )
        qx, qy, qz, qw =
            qx * invNorm, qy * invNorm, qz * invNorm, qw * invNorm
    else
        local theta = math.acos(dot)
        local invSinTheta = 1.0 / math.sin(theta)
        local s1 = math.sin((1.0 - t) * theta) * invSinTheta
        local s2 = math.sin(t * theta) * invSinTheta

        qx = aqx * s1 + bqx * s2
        qy = aqy * s1 + bqy * s2
        qz = aqz * s1 + bqz * s2
        qw = aqw * s1 + bqw * s2
    end

    return simEigen.Vector {
        ax + (bx - ax) * t,
        ay + (by - ay) * t,
        az + (bz - az) * t,
        qx, qy, qz, qw,
    }
end

function Path:_interpolateTables(a, b, t, out)
    local cache = self._cache
    local modes = cache.modes
    local dim = cache.dim

    out = out or {}

    local omt = 1.0 - t
    local i = 1

    while i <= dim do
        local mode = modes[i]

        if mode == 0 then
            out[i] = a[i] * omt + b[i] * t
            i = i + 1

        elseif mode == 1 then
            local dx = atan2(
                sin(b[i] - a[i]),
                cos(b[i] - a[i])
            )
            local v = a[i] + dx * t
            out[i] = atan2(sin(v), cos(v))
            i = i + 1

        else -- quaternion
            local ax, ay, az, aw =
                a[i], a[i + 1], a[i + 2], a[i + 3]
            local bx, by, bz, bw =
                b[i], b[i + 1], b[i + 2], b[i + 3]

            local dot = ax * bx + ay * by + az * bz + aw * bw

            if dot < 0.0 then
                bx, by, bz, bw = -bx, -by, -bz, -bw
                dot = -dot
            end

            if dot > 1.0 then
                dot = 1.0
            end

            local x, y, z, w

            if dot > 0.9995 then
                x = ax + (bx - ax) * t
                y = ay + (by - ay) * t
                z = az + (bz - az) * t
                w = aw + (bw - aw) * t

                local n2 = x * x + y * y + z * z + w * w
                if n2 > 0.0 then
                    local invNorm = 1.0 / sqrt(n2)
                    x, y, z, w =
                        x * invNorm,
                        y * invNorm,
                        z * invNorm,
                        w * invNorm
                else
                    x, y, z, w = ax, ay, az, aw
                end
            else
                local theta = acos(dot)
                local invSinTheta = 1.0 / sin(theta)
                local s1 = sin(omt * theta) * invSinTheta
                local s2 = sin(t * theta) * invSinTheta

                x = ax * s1 + bx * s2
                y = ay * s1 + by * s2
                z = az * s1 + bz * s2
                w = aw * s1 + bw * s2
            end

            out[i] = x
            out[i + 1] = y
            out[i + 2] = z
            out[i + 3] = w
            i = i + 4
        end
    end

    return out
end

function Path:interpolate(conf1, conf2, t, noArgCheck)
    local data = self._data
    local confA, confB = conf1, conf2

    if not noArgCheck then
        confA, confB, t = checkargs.checkargsEx(
            {funcName = 'Path:interpolate'},
            {
                {type = 'vector', size = data.opt.dim},
                {type = 'vector', size = data.opt.dim},
                {type = 'float'},
            },
            conf1, conf2, t
        )
    end

    return simEigen.Vector(
        self:_interpolateTables(confA:data(), confB:data(), t)
    )
end

function Path:configs(conf, noArgCheck)
    local data = self._data
    if not noArgCheck then
        conf = checkargs.checkargsEx({funcName = 'Path:configs'}, {
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

function Path:_orientPosesAlongPath(points)
    local data = self._data
    local opt = data.opt

    -- Preserve the previous behavior unless explicitly applicable:
    if opt.upVector == nil or opt.displDim ~= 7 or points:cols() < 2 then
        return points
    end

    local axesSpec = opt.forwardAndUpAxes
    local validAxes = {
        xy = true, xz = true,
        yx = true, yz = true,
        zx = true, zy = true,
    }
    assert(validAxes[axesSpec], "invalid 'forwardAndUpAxes' string")

    local forwardAxis = axesSpec:sub(1, 1)
    local upAxis = axesSpec:sub(2, 2)
    local closed = opt.closed
    local count = points:cols()

    local sqrt, abs = math.sqrt, math.abs
    local eps = 1e-12

    local function dot(a, b)
        return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
    end

    local function cross(a, b)
        return {
            a[2] * b[3] - a[3] * b[2],
            a[3] * b[1] - a[1] * b[3],
            a[1] * b[2] - a[2] * b[1],
        }
    end

    local function normalized(v)
        local n2 = dot(v, v)
        if n2 <= eps then
            return nil
        end
        local s = 1.0 / sqrt(n2)
        return {
            v[1] * s,
            v[2] * s,
            v[3] * s,
        }
    end

    local function subtractProjection(v, onto)
        local d = dot(v, onto)
        return {
            v[1] - onto[1] * d,
            v[2] - onto[2] * d,
            v[3] - onto[3] * d,
        }
    end

    local function wrappedIndex(index)
        return ((index - 1) % count) + 1
    end

    local function positionAt(index)
        if closed then
            index = wrappedIndex(index)
        else
            index = math.max(1, math.min(count, index))
        end

        return {
            points:item(1, index),
            points:item(2, index),
            points:item(3, index),
        }
    end

    local function positionDifference(indexA, indexB)
        local a = positionAt(indexA)
        local b = positionAt(indexB)
        return {
            a[1] - b[1],
            a[2] - b[2],
            a[3] - b[3],
        }
    end

    local function quaternionAt(index)
        return {
            points:item(4, index),
            points:item(5, index),
            points:item(6, index),
            points:item(7, index),
        }
    end

    -- Returns one local orientation axis expressed in world coordinates.
    -- Quaternion layout is {x, y, z, w}.
    local function quaternionAxis(q, axis)
        local x, y, z, w = q[1], q[2], q[3], q[4]

        -- Normalize defensively:
        local n2 = x * x + y * y + z * z + w * w
        if n2 <= eps then
            if axis == 'x' then
                return {1.0, 0.0, 0.0}
            elseif axis == 'y' then
                return {0.0, 1.0, 0.0}
            else
                return {0.0, 0.0, 1.0}
            end
        end

        local s = 1.0 / sqrt(n2)
        x, y, z, w = x * s, y * s, z * s, w * s

        if axis == 'x' then
            return {
                1.0 - 2.0 * (y * y + z * z),
                2.0 * (x * y + z * w),
                2.0 * (x * z - y * w),
            }
        elseif axis == 'y' then
            return {
                2.0 * (x * y - z * w),
                1.0 - 2.0 * (x * x + z * z),
                2.0 * (y * z + x * w),
            }
        else
            return {
                2.0 * (x * z + y * w),
                2.0 * (y * z - x * w),
                1.0 - 2.0 * (x * x + y * y),
            }
        end
    end

    -- xAxis, yAxis and zAxis are the columns of the rotation matrix.
    local function axesToQuaternion(xAxis, yAxis, zAxis)
        local m00, m01, m02 = xAxis[1], yAxis[1], zAxis[1]
        local m10, m11, m12 = xAxis[2], yAxis[2], zAxis[2]
        local m20, m21, m22 = xAxis[3], yAxis[3], zAxis[3]

        local x, y, z, w
        local trace = m00 + m11 + m22

        if trace > 0.0 then
            local s = sqrt(trace + 1.0) * 2.0
            w = 0.25 * s
            x = (m21 - m12) / s
            y = (m02 - m20) / s
            z = (m10 - m01) / s
        elseif m00 > m11 and m00 > m22 then
            local s = sqrt(1.0 + m00 - m11 - m22) * 2.0
            w = (m21 - m12) / s
            x = 0.25 * s
            y = (m01 + m10) / s
            z = (m02 + m20) / s
        elseif m11 > m22 then
            local s = sqrt(1.0 + m11 - m00 - m22) * 2.0
            w = (m02 - m20) / s
            x = (m01 + m10) / s
            y = 0.25 * s
            z = (m12 + m21) / s
        else
            local s = sqrt(1.0 + m22 - m00 - m11) * 2.0
            w = (m10 - m01) / s
            x = (m02 + m20) / s
            y = (m12 + m21) / s
            z = 0.25 * s
        end

        local n = sqrt(x * x + y * y + z * z + w * w)
        return {
            x / n,
            y / n,
            z / n,
            w / n,
        }
    end

    local upVector
    if type(opt.upVector) == 'table' then
        upVector = {
            opt.upVector[1],
            opt.upVector[2],
            opt.upVector[3],
        }
    else
        local u = opt.upVector:data()
        upVector = {u[1], u[2], u[3]}
    end

    upVector = assert(
        normalized(upVector),
        "'upVector' must be non-zero"
    )

    -- Prefer a centered tangent. If it is degenerate, search outward for
    -- the nearest non-coincident path point.
    local function tangentAt(index)
        if closed or (index > 1 and index < count) then
            local tangent = normalized(
                positionDifference(index + 1, index - 1)
            )
            if tangent then
                return tangent
            end
        end

        -- Search forward:
        for offset = 1, count - 1 do
            local other = index + offset
            if not closed and other > count then
                break
            end

            local tangent = normalized(
                positionDifference(other, index)
            )
            if tangent then
                return tangent
            end
        end

        -- Search backward. Keep the direction pointing along increasing
        -- path index by subtracting the previous point from this point.
        for offset = 1, count - 1 do
            local other = index - offset
            if not closed and other < 1 then
                break
            end

            local tangent = normalized(
                positionDifference(index, other)
            )
            if tangent then
                return tangent
            end
        end

        return nil
    end

    -- Build only the replacement quaternion matrix. Positions and any
    -- components after row 7 remain in matrix form throughout.
    local quaternionRows = {
        {}, -- qx
        {}, -- qy
        {}, -- qz
        {}, -- qw
    }

    local previousForward
    local previousQuaternion

    for i = 1, count do
        local oldQuaternion = quaternionAt(i)
        local forward = tangentAt(i) or previousForward
        local q = oldQuaternion

        if forward then
            previousForward = forward

            -- This is the direction closest to upVector that remains
            -- perpendicular to the exact forward direction.
            local adjustedUp = normalized(
                subtractProjection(upVector, forward)
            )

            -- If forward and upVector are parallel, preserve the existing
            -- pose's roll to the extent possible.
            if adjustedUp == nil then
                local oldUp = quaternionAxis(oldQuaternion, upAxis)
                adjustedUp = normalized(
                    subtractProjection(oldUp, forward)
                )
            end

            -- Deterministic fallback if the existing up axis is also
            -- unusable.
            if adjustedUp == nil then
                local fallback

                if abs(forward[1]) <= abs(forward[2]) and
                   abs(forward[1]) <= abs(forward[3]) then
                    fallback = {1.0, 0.0, 0.0}
                elseif abs(forward[2]) <= abs(forward[3]) then
                    fallback = {0.0, 1.0, 0.0}
                else
                    fallback = {0.0, 0.0, 1.0}
                end

                adjustedUp = assert(normalized(
                    subtractProjection(fallback, forward)
                ))
            end

            local axis = {}
            axis[forwardAxis] = forward
            axis[upAxis] = adjustedUp

            -- Complete the right-handed frame according to x × y = z.
            if axis.x == nil then
                axis.x = assert(normalized(cross(axis.y, axis.z)))
            elseif axis.y == nil then
                axis.y = assert(normalized(cross(axis.z, axis.x)))
            else
                axis.z = assert(normalized(cross(axis.x, axis.y)))
            end

            -- Recompute the secondary axis to remove numerical
            -- non-orthogonality without changing the forward axis.
            if upAxis == 'x' then
                axis.x = assert(normalized(cross(axis.y, axis.z)))
            elseif upAxis == 'y' then
                axis.y = assert(normalized(cross(axis.z, axis.x)))
            else
                axis.z = assert(normalized(cross(axis.x, axis.y)))
            end

            q = axesToQuaternion(axis.x, axis.y, axis.z)

            -- Select a consistent quaternion hemisphere.
            if previousQuaternion then
                local d =
                    previousQuaternion[1] * q[1] +
                    previousQuaternion[2] * q[2] +
                    previousQuaternion[3] * q[3] +
                    previousQuaternion[4] * q[4]

                if d < 0.0 then
                    q = {-q[1], -q[2], -q[3], -q[4]}
                end
            end
        end

        quaternionRows[1][i] = q[1]
        quaternionRows[2][i] = q[2]
        quaternionRows[3][i] = q[3]
        quaternionRows[4][i] = q[4]
        previousQuaternion = q
    end

    local result = points:block(1, 1, 3, count)
        :vertcat(simEigen.Matrix(quaternionRows))

    -- Although displDim is 7, dim can potentially be greater than 7.
    -- Preserve all additional configuration components.
    if points:rows() > 7 then
        result = result:vertcat(
            points:block(8, 1, points:rows() - 7, count)
        )
    end

    return result
end

function Path:_resample(points, resamplingType)
    -- Faster version. Original version is above
    local data = self._data
    local dim = data.opt.dim
    local closed = data.opt.closed
    local samplingDistance = data.pathPoints.opt.samplingDistance
    local bezierSmoothing = data.pathPoints.opt.bezierSmoothing
    local doSmooth = bezierSmoothing < 0.999
    resamplingType = resamplingType or data.pathPoints.opt.type

    local sin, cos, atan2, acos, sqrt, abs, floor =
        math.sin, math.cos, math.atan2, math.acos, math.sqrt, math.abs, math.floor

    -- Precompute per-component handling mode once, instead of re-checking
    -- types/bounds for every component of every interpolated point:
    -- 0: linear, 1: cyclic angular, 2: quaternion (first of 4 components)
    local modes = {}
    do
        local types, bounds = data.opt.types, data.opt.bounds
        local i = 1
        while i <= dim do
            if types[i] == 2 then
                modes[i] = 2
                i = i + 4 -- validated in initialize: always groups of 4
            elseif (types[i] == 0) or (#bounds[i] == 2) then
                modes[i] = 0
                i = i + 1
            else
                modes[i] = 1
                i = i + 1
            end
        end
    end
    local metric = data.opt.metric:data() -- plain table, no per-element C calls

    -- distance on plain tables (equivalent to Path:distance):
    local function dist(a, b)
        local d = 0.0
        for j = 1, dim do
            local m = modes[j]
            if m == 0 then
                local dd = (b[j] - a[j]) * metric[j]
                d = d + dd * dd
            elseif m == 1 then
                local dd = abs(atan2(sin(b[j] - a[j]), cos(b[j] - a[j]))) * metric[j]
                d = d + dd * dd
            elseif m == 2 then
                -- angle between quaternions: 2*acos(|dot|) (shortest arc)
                local dot = a[j] * b[j] + a[j + 1] * b[j + 1] + a[j + 2] * b[j + 2] + a[j + 3] * b[j + 3]
                if dot < 0.0 then dot = -dot end
                if dot > 1.0 then dot = 1.0 end
                local dd = 2.0 * acos(dot) * metric[j]
                d = d + dd * dd
            end
        end
        return sqrt(d)
    end

    -- interpolation on plain tables (equivalent to Path:interpolate),
    -- with pure-Lua slerp (no simEigen.Quaternion object creation):
    local function interp(a, b, t)
        local r = {}
        for j = 1, dim do
            local m = modes[j]
            if m == 0 then
                r[j] = a[j] * (1 - t) + b[j] * t
            elseif m == 1 then
                local dx = atan2(sin(b[j] - a[j]), cos(b[j] - a[j]))
                local v = a[j] + dx * t
                r[j] = atan2(sin(v), cos(v))
            elseif m == 2 then
                local ax, ay, az, aw = a[j], a[j + 1], a[j + 2], a[j + 3]
                local bx, by, bz, bw = b[j], b[j + 1], b[j + 2], b[j + 3]
                local dot = ax * bx + ay * by + az * bz + aw * bw
                if dot < 0.0 then
                    bx, by, bz, bw, dot = -bx, -by, -bz, -bw, -dot
                end
                local x, y, z, w
                if dot > 0.9995 then -- nearly identical: nlerp
                    x = ax + (bx - ax) * t
                    y = ay + (by - ay) * t
                    z = az + (bz - az) * t
                    w = aw + (bw - aw) * t
                    local n = sqrt(x * x + y * y + z * z + w * w)
                    x, y, z, w = x / n, y / n, z / n, w / n
                else
                    local th0 = acos(dot)
                    local sth0 = sin(th0)
                    local s1 = sin((1.0 - t) * th0) / sth0
                    local s2 = sin(t * th0) / sth0
                    x = ax * s1 + bx * s2
                    y = ay * s1 + by * s2
                    z = az * s1 + bz * s2
                    w = aw * s1 + bw * s2
                end
                r[j], r[j + 1], r[j + 2], r[j + 3] = x, y, z, w
            end
        end
        return r
    end

    -- cumulative distances along a table-of-points:
    local function arcLengths(pts)
        local l = 0.0
        local distances = {0.0}
        for i = 1, #pts - 1 do
            l = l + dist(pts[i], pts[i + 1])
            distances[i + 1] = l
        end
        return distances, l
    end

    -- linear resampling, table in / table out:
    local function resampleLinear(pts)
        if closed then
            pts[#pts + 1] = pts[1]
        end
        local distances, totalL = arcLengths(pts)
        local ret = {pts[1]}
        local cnt = floor(totalL / samplingDistance)
        local sd = totalL / (cnt + 1.0)
        local l = 0.0
        local paInd = 1
        for i = 1, cnt do
            l = l + sd
            while l > distances[paInd + 1] do
                paInd = paInd + 1
            end
            local r = (l - distances[paInd]) / (distances[paInd + 1] - distances[paInd])
            ret[#ret + 1] = interp(pts[paInd], pts[paInd + 1], r)
        end
        if not closed then
            ret[#ret + 1] = pts[#pts]
        end
        return ret
    end

    local pts = pointTableFromMatrix(points)

    if resamplingType == 0 then
        return matrixFromPointTable(dim, resampleLinear(pts))
    end

    -- Bezier resampling:
    if closed then
        pts[#pts + 1] = pts[1]
    end
    local distances, totalL = arcLengths(pts)
    -- extend by one point at each end:
    local n = #pts
    if closed then
        pts[n + 1] = pts[2]
        table.insert(pts, 1, pts[n - 1])
    else
        pts[n + 1] = interp(pts[n - 1], pts[n], 2.0)
        table.insert(pts, 1, interp(pts[2], pts[1], 2.0))
    end

    -- the two Bezier tangent points only depend on the segment triple, not
    -- on t; since many consecutive samples share the same triple, cache them
    -- (keyed by the index of the middle point):
    local biasCache = {}
    local function getBias(ib)
        local c = biasCache[ib]
        if not c then
            local b = pts[ib]
            local pia = interp(pts[ib - 1], b, 0.5)
            local pib = interp(b, pts[ib + 1], 0.5)
            if doSmooth then
                pia = interp(b, pia, bezierSmoothing)
                pib = interp(b, pib, bezierSmoothing)
            end
            c = {pia, pib}
            biasCache[ib] = c
        end
        return c[1], c[2]
    end

    local ret = {}
    local cnt = floor(totalL * 2.0 / samplingDistance) + 1.0 -- first a smaller sampling
    local sd = totalL / cnt
    local l = 0.0
    local paInd = 1
    local nd = #distances
    for i = 1, cnt + 1 do
        while (l > distances[paInd + 1]) and (nd > paInd + 1) do
            paInd = paInd + 1
        end
        local r = (l - distances[paInd]) / (distances[paInd + 1] - distances[paInd])
        local t, ib
        if r >= 0.5 then
            t, ib = r - 0.5, paInd + 2
        else
            t, ib = r + 0.5, paInd + 1
        end
        local pia, pib = getBias(ib)
        local b = pts[ib]
        local p1 = interp(pia, b, t)
        local p2 = interp(b, pib, t)
        ret[#ret + 1] = interp(p1, p2, t)
        l = l + sd
    end
    if not closed then
        ret[#ret + 1] = pts[#pts - 1]
    end

    -- final pass: stay in table land, convert to matrix only once at the end:
    return matrixFromPointTable(dim, resampleLinear(ret))
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

function Path:closest(point, noArgCheck)
    local data = self._data
    if not noArgCheck then
        point = checkargs.checkargsEx({funcName = 'Path:closest'}, {
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
        local opt = {metric = data.opt.metric}
        opt.types = {}
        for i = 1, data.opt.dim do
            if (data.opt.types[i] == 0) or (#data.opt.bounds[i] == 2) then
                opt.types[i] = 0
            else
                opt.types[i] = data.opt.types[i]
            end
        end
        local pt, ind = callMethod(-1, 'getClosestOnPath', pts, point, opt)
        local selectedCache = self:_selectedPointCache()
        local pTable = pt:data()
        local p1Table = selectedCache.points[ind + 1]

        local nextIndex = ind + 2
        if nextIndex > #selectedCache.points then
            nextIndex = 1
        end

        local p2Table = selectedCache.points[nextIndex]
        local segmentLength = self:_distanceTables(p1Table, p2Table)

        local t = 0.0
        if segmentLength > 0.0 then
            t = self:_distanceTables(p1Table, pTable) / segmentLength
        end

        local l = selectedCache.distancesAlongPath[ind + 1] + t * selectedCache.arcLengths[ind + 1]

        return pt, l / pathLength
    end
end

function Path:getPoint(distance, noArgCheck)
    if not noArgCheck then
        distance = checkargs.checkargsEx(
            {funcName = 'Path:getPoint'},
            {
                {type = 'float'},
            },
            distance
        )
    end

    self:update()

    if distance < 0.0 then
        distance = 0.0
    elseif distance > 1.0 then
        distance = 1.0
    end

    local pointData = self:_selectedPointCache()
    local points = pointData.points
    local pointCount = #points

    assert(pointCount > 0, 'path is empty.')

    if pointCount == 1 then
        return simEigen.Vector(points[1])
    end

    local closed = self._data.opt.closed
    local pathLength = pointData.pathLength
    local distances = pointData.distancesAlongPath
    local arcLengths = pointData.arcLengths
    local l = distance * pathLength

    if pathLength <= 0.0 then
        if closed then
            return simEigen.Vector(points[1])
        end
        return simEigen.Vector(points[pointCount])
    end

    if l >= pathLength then
        if closed then
            return simEigen.Vector(points[1])
        end
        return simEigen.Vector(points[pointCount])
    end

    -- Find the first stored point distance strictly greater than l.
    local lo = 2
    local hi = #distances
    local upper = hi + 1

    while lo <= hi do
        local mid = floor((lo + hi) * 0.5)

        if distances[mid] > l then
            upper = mid
            hi = mid - 1
        else
            lo = mid + 1
        end
    end

    local segmentIndex
    local nextPointIndex
    local segmentStart
    local segmentLength

    if upper <= #distances then
        segmentIndex = upper - 1
        nextPointIndex = upper
        segmentStart = distances[segmentIndex]
        segmentLength = arcLengths[segmentIndex]
    elseif closed then
        segmentIndex = pointCount
        nextPointIndex = 1
        segmentStart = distances[pointCount]
        segmentLength = arcLengths[pointCount]
    else
        return simEigen.Vector(points[pointCount])
    end

    if segmentLength <= 0.0 then
        return simEigen.Vector(points[segmentIndex])
    end

    local t = (l - segmentStart) / segmentLength

    return simEigen.Vector(
        self:_interpolateTables(
            points[segmentIndex],
            points[nextPointIndex],
            t
        )
    )
end

function Path:toBuffer()
    self:update()
    -- Do not serialize objects!
    local objectStr = {'object', 'tip', 'base', 'joints'}
    local objects = {}
    for i = 1, #objectStr do
        objects[objectStr[i]] = self._data.opt[objectStr[i]]
        self._data.opt[objectStr[i]] = nil
    end
    local ctrlPtMarkers = self._data.ctrlPoints.markers
    self._data.ctrlPoints.markers = nil
    local pathPtMarkers = self._data.pathPoints.markers
    self._data.pathPoints.markers = nil
    local retVal = sim.app:pack(self._data)
    self._data.ctrlPoints.markers = ctrlPtMarkers
    self._data.pathPoints.markers = pathPtMarkers
    for k, v in pairs(objects) do
        self._data.opt[k] = v
    end
    return retVal, objects
end

function Path:createMarkers()
    self:update()
    local data = self._data
    self:removeMarkers()
    data.ctrlPoints.markers = self:_createMarkers(data.ctrlPoints.points, data.ctrlPoints.opt)
    if not data.opt.onlyCtrlPoints then
        data.pathPoints.markers = self:_createMarkers(data.pathPoints.points, data.pathPoints.opt)
    end
    return {ctrlPointMarkers = data.ctrlPoints.markers, pathPointMarkers = data.pathPoints.markers}
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
                retPointMarker.selectable = false
            end
            if opt.showAxes then
                retRefMarker = sim.scene:createObject({type = 'marker', ['marker.type'] = 'axes', ['local'] = true, itemSize = table.rep(opt.pointRadius * 2.0, 3)})
                retRefMarker.selectable = false
            end
        end
        if opt.lineType ~= 0 then
            local t = 'lines'
            if opt.lineType == 2 then
                t = 'tubes'
            end
            retLineMarker = sim.scene:createObject({type = 'marker', ['marker.type'] = t, ['local'] = true, itemSize = table.rep(opt.tubeRadius * 2.0, 3), itemColor = opt.lineColor})
            retLineMarker.selectable = false
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
                -- accumulate line segment points in a table, build matrix once:
                local lineTab = {}
                for i = 1, dat:cols() - 1 do
                    lineTab[#lineTab + 1] = dat:block(1, i, -1, 1):data()
                    lineTab[#lineTab + 1] = dat:block(1, i + 1, -1, 1):data()
                end
                if data.opt.closed then
                    lineTab[#lineTab + 1] = dat:block(1, dat:cols(), -1, 1):data()
                    lineTab[#lineTab + 1] = dat:block(1, 1, -1, 1):data()
                end
                markers.lineMarker:addItems(matrixFromPointTable(dat:rows(), lineTab))
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
