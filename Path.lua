local sim = require 'sim-2'
local class = require('middleclass')
local copy = require('copy')
local checkargs = require('checkargs-2')
local simEigen = require('simEigen')

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
        {name = 'linearityTolerance', type = 'float', default = 0.05}, -- in percent
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
        {name = 'closed', type = 'bool', default = false},
        {name = 'closedRepeatsStart', type = 'bool', default = false},
    }, opt)
    
    if ctrlPoints then
        assert(ctrlPoints:cols() > 0, 'invalid control points')
        if (opt.types == nil) and (ctrlPoints:cols() == 7) then
            opt.types = {'scal', 'scal', 'scal', 'quat', 'quat', 'quat', 'quat'}
        end
        checkargs.checkfields({funcName = 'Path:new'}, {
            {name = 'metric', type = 'matrix', rows = 1, cols = ctrlPoints:cols(), default = simEigen.Matrix(1, ctrlPoints:cols(), 1.0)},
            {name = 'types', type = 'table', size = ctrlPoints:cols(), default = table.rep('scal', ctrlPoints:cols())},
        }, opt)
    else
        checkargs.checkfields({funcName = 'Path:new'}, {
            {name = 'types', type = 'table', range = '1..*'}, -- in this case not optional
        }, opt)
        checkargs.checkfields({funcName = 'Path:new'}, {
            {name = 'metric', type = 'matrix', rows = 1, cols = #opt.types, default = simEigen.Matrix(1, #opt.types, 1.0)},
        }, opt)
        ctrlPoints = simEigen.Matrix(0, #opt.types, {})
    end
    local quatC = 0
    for i = 1, #opt.types do
        if opt.types[i] == 'scal' then
            if quatC ~= 0 then
                error("invalid 'types' array")
            end
            opt.types[i] = 0
        elseif opt.types[i] == 'cycl' then
            if quatC ~= 0 then
                error("invalid 'types' array")
            end
            opt.types[i] = 1
        elseif opt.types[i] == 'quat' then
            opt.types[i] = 2
            quatC = quatC + 1
            if quatC == 4 then
                quatC = 0
            end
        else
            error("invalid 'types' array")
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

    if (#data.opt.types > 1) and (data.opt.types[1] == 0) and (data.opt.types[2] == 0) then
        if (#data.opt.types > 2) and (data.opt.types[3] == 0) then
            if (#data.opt.types > 6) and (data.opt.types[4] == 2) and (data.opt.types[5] == 2) and (data.opt.types[6] == 2) and (data.opt.types[7] == 2) then
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

    self:setCtrlPoints(ctrlPoints, true)
end

function Path:setCtrlPoints(ctrlPoints, noArgCheck)
    local data = self._data
    if not noArgCheck then
        ctrlPoints = checkargs.checkargsEx({funcName = 'setCtrlPoints'}, {
            {type = 'matrix', cols = #data.opt.types, nullable = true},
        }, ctrlPoints)
    end
    if ctrlPoints == nil then
        ctrlPoints = simEigen.Matrix(0, #data.opt.types, {})
    end
    
    if ctrlPoints:rows() > 1 then
        if data.ctrlPoints.opt.duplicateThreshold > 0.0 then
            ctrlPoints = self:_removeDuplicates(ctrlPoints)
        end
        if data.ctrlPoints.opt.linearityTolerance > 0.0 then
            ctrlPoints = self:_removeColinearSegments(ctrlPoints)
        end
    end
    data.ctrlPoints.points = ctrlPoints
    if data.ctrlPoints.points:rows() > 1 then
        data.ctrlPoints.arcLengths, data.ctrlPoints.distancesAlongPath, data.ctrlPoints.pathLength = self:_computeArcLengths(data.ctrlPoints.points)
        data.pathPoints.points = self:_resample(data.ctrlPoints.points)
        data.pathPoints.arcLengths, data.pathPoints.distancesAlongPath, data.pathPoints.pathLength = self:_computeArcLengths(data.pathPoints.points)
    else 
        if ctrlPoints:rows() == 1 then
            data.pathPoints.points = copy.copy(ctrlPoints)
            data.ctrlPoints.distancesAlongPath = simEigen.Vector{0.0}
            data.pathPoints.distancesAlongPath = simEigen.Vector{0.0}
        else
            data.pathPoints.points = simEigen.Matrix(0, #data.opt.types, {})
            data.ctrlPoints.distancesAlongPath = simEigen.Vector{}
            data.pathPoints.distancesAlongPath = simEigen.Vector{}
        end
        data.ctrlPoints.arcLengths = simEigen.Vector{}
        data.ctrlPoints.pathLength = 0.0
        data.pathPoints.arcLengths = simEigen.Vector{}
        data.pathPoints.pathLength = 0.0
    end
    self:_updateMarkers()
end

function Path:data()
    local retVal = self._data
    if retVal.opt.closed and retVal.opt.closedRepeatsStart then
        retVal = copy.deepcopy(self._data)
        local dummyVal
        if retVal.ctrlPoints.points:rows() > 1 then
            retVal.ctrlPoints.points = retVal.ctrlPoints.points:vertcat(retVal.ctrlPoints.points:block(1, 1, 1, -1))
            dummyVal, retVal.ctrlPoints.distancesAlongPath, retVal.ctrlPoints.pathLength = self:_computeArcLengths(retVal.ctrlPoints.points)
        end
        if retVal.pathPoints.points:rows() > 1 then
            retVal.pathPoints.points = retVal.pathPoints.points:vertcat(retVal.pathPoints.points:block(1, 1, 1, -1))
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
            retVal = retVal:vertcat(retVal:block(1, 1, 1, -1))
            minPtCnt = 3
        end

        if retVal:rows() > minPtCnt then
            -- Remove points close to the first point:
            local firstPoint = retVal:block(1, 1, 1, -1)
            local i = 2
            while i <= retVal:rows() - 1 do
                local p = retVal:block(i, 1, 1, -1)
                if self:dist(firstPoint, p, true) < data.ctrlPoints.opt.duplicateThreshold then
                    retVal = retVal:block(1, 1, i - 1, -1):vertcat(retVal:block(i + 1, 1, - 1, -1))
                    removed = removed + 1
                else
                    break
                end
                i = i + 1
            end

            if retVal:rows() > minPtCnt then
                -- Remove points close to the last point:
                local lastPoint = retVal:block(retVal:rows(), 1, 1, -1)
                local i = retVal:rows() - 1
                while i >= 2 do
                    local p = retVal:block(i, 1, 1, -1)
                    if self:dist(lastPoint, p, true) < data.ctrlPoints.opt.duplicateThreshold then
                        retVal = retVal:block(1, 1, i - 1, -1):vertcat(retVal:block(i + 1, 1, - 1, -1))
                        removed = removed + 1
                    else
                        break
                    end
                    i = i - 1
                end

                if retVal:rows() > minPtCnt then
                    -- merge points pairwise:
                    local points = retVal
                    retVal = firstPoint
                    local p0, p1
                    local i = 2
                    if points:rows() == 3 then
                        retVal = retVal:vertcat(points:block(2, 1, 1, -1))
                    else
                        while i <= points:rows() - 2 do
                            p0 = points:block(i, 1, 1, -1)
                            p1 = points:block(i + 1, 1, 1, -1)
                            local d = self:dist(p0, p1, true)
                            if d >= data.ctrlPoints.opt.duplicateThreshold then
                                retVal = retVal:vertcat(p0)
                            else
                                retVal = retVal:vertcat(self:lerp(p0, p1, 0.5, true))
                                removed = removed + 1
                                p1 = nil
                                i = i + 1
                            end
                            i = i + 1
                        end
                    end
                    if p1 then
                        retVal = retVal:vertcat(p1)
                    end
                    retVal = retVal:vertcat(lastPoint)
                end
            end
        end

        -- Remove the last point (coincident with the first point), with closed paths:
        if data.opt.closed then
            retVal = retVal:block(1, 1, retVal:rows() - 1, -1)
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
            pts = pts:vertcat(pts:block(1, 1, 1, -1))
        end

        local toPrune = {}
        for i = 1, pts:rows() - 3 do
            local p0 = pts:block(i, 1, 1, -1)
            local p1 = pts:block(i + 1, 1, 1, -1)
            local p2 = pts:block(i + 2, 1, 1, -1)
            local d0 = self:dist(p0, p1, true)
            local d1 = self:dist(p1, p2, true)
            local t = d0 / (d0 + d1)
            local proj = self:lerp(p0, p2, t, true)
            local relDist = self:dist(proj, p1, true) / self:dist(p0, p2, true)
            if relDist < data.ctrlPoints.opt.linearityTolerance then
                toPrune[#toPrune + 1] = {pos = i + 1, val = relDist}
            end
        end
        table.sort(toPrune, function(a, b) return a.val < b.val end)
        local rowsToRemove = {}
        for i = 1, #toPrune do
            if toPrune[i].ignore == nil then
                local r = toPrune[i].pos
                rowsToRemove[r] = true
                -- ignore those that needs to be recomputed:
                for j = i + 1, #toPrune do
                    if math.abs(toPrune[j].pos - r) == 1 then
                        toPrune[j].ignore = true
                    end
                end
            end
        end
        local retVal = simEigen.Matrix(0, pts:cols(), {})
        local removed = 0
        for i = 1, pts:rows() do
            if rowsToRemove[i] then
                removed = removed + 1
            else
                retVal = retVal:vertcat(pts:block(i, 1, 1, -1))
            end
        end
        -- Remove the last point (coincident with the first point), with closed paths:
        if data.opt.closed then
            retVal = retVal:block(1, 1, retVal:rows() - 1, -1)
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
    for i = 1, pts:rows() - 1 do
        local p0 = pts:block(i, 1, 1, -1)
        local p1 = pts:block(i + 1, 1, 1, -1)
        local d = self:dist(p0, p1, true)
        tot[#tot + 1] = d
        l = l + d
        distances[#distances + 1] = l
    end
    if data.opt.closed then
        local p0 = pts:block(pts:rows(), 1, 1, -1)
        local p1 = pts:block(1, 1, 1, -1)
        local d = self:dist(p0, p1, true)
        tot[#tot + 1] = d
        l = l + d
    end
    return simEigen.Vector(tot), simEigen.Vector(distances), l
end

function Path:dist(conf1, conf2, noArgCheck)
    local data = self._data
    local confA = conf1
    local confB = conf2
    if not noArgCheck then
        confA, confB = checkargs.checkargsEx({funcName = 'dist'}, {
            {type = 'vector'},
            {type = 'vector'},
        }, conf1, conf2)
        assert( (confA:rows() == #data.opt.types) and (confA:rows() == confB:rows()), 'invalid points')
    end
    confA = confA:data()
    confB = confB:data()
    local d = 0
    local qcnt = 0
    for j = 1, #confA, 1 do
        local dd = 0
        if data.opt.types[j] == 0 then
            dd = (confB[j] - confA[j]) * data.opt.metric[j] -- e.g. joint with limits
        end
        if data.opt.types[j] == 1 then
            local dx = math.atan2(math.sin(confB[j] - confA[j]), math.cos(confB[j] - confA[j]))
            local v = confA[j] + dx
            dd = math.atan2(math.sin(v), math.cos(v)) * data.opt.metric[j] -- cyclic rev. joint (-pi;pi)
        end
        if data.opt.types[j] == 2 then
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

function Path:lerp(conf1, conf2, t, noArgCheck)
    local data = self._data
    local confA = conf1
    local confB = conf2
    if not noArgCheck then
        confA, confB, t = checkargs.checkargsEx({funcName = 'lerp'}, {
            {type = 'vector'},
            {type = 'vector'},
            {type = 'float'},
        }, conf1, conf2, t)
        assert( (confA:rows() == #data.opt.types) and (confA:rows() == confB:rows()), 'invalid points')
    end
    confA = confA:data()
    confB = confB:data()

    local retVal = {}
    local qcnt = 0
    for i = 1, #confA, 1 do
        if data.opt.types[i] == 0 then
            retVal[i] = confA[i] * (1 - t) + confB[i] * t -- e.g. joint with limits
        end
        if data.opt.types[i] == 1 then
            local dx = math.atan2(math.sin(confB[i] - confA[i]), math.cos(confB[i] - confA[i]))
            local v = confA[i] + dx * t
            retVal[i] = math.atan2(math.sin(v), math.cos(v)) -- cyclic rev. joint (-pi;pi)
        end
        if data.opt.types[i] == 2 then
            qcnt = qcnt + 1
            if qcnt == 4 then
                qcnt = 0
                local q1 = simEigen.Quaternion({confA[i - 3], confA[i - 2], confA[i - 1], confA[i - 0]})
                local q2 = simEigen.Quaternion({confB[i - 3], confB[i - 2], confB[i - 1], confB[i - 0]})
                local q = q1:slerp(t, q2)
                retVal[i - 3] = q[1]
                retVal[i - 2] = q[2]
                retVal[i - 1] = q[3]
                retVal[i - 0] = q[4]
            end
        end
    end
    return simEigen.Matrix(1, #retVal, retVal)
end

function Path:_resample(points, resamplingType)
    local data = self._data
    local pts = points
    if data.opt.closed then
        pts = pts:vertcat(pts:block(1, 1, 1, -1))
    end
    local arcL, distances, totalL = self:_computeArcLengths(pts)
    local retPts
    resamplingType = resamplingType or data.pathPoints.opt.type 
    if resamplingType == 0 then
        retPts = pts:block(1, 1, 1, -1)
        local cnt = math.floor(totalL / data.pathPoints.opt.samplingDistance)
        local sd = totalL / (cnt + 1.0)
        local l = 0.0
        local paInd = 1
        for i = 1, cnt do
            l = l + sd
            while l > distances[paInd + 1] do
                paInd = paInd + 1
            end
            local pa = pts:block(paInd, 1, 1, -1)
            local pb = pts:block(paInd + 1, 1, 1, -1)
            local r = (l - distances[paInd + 0]) / (distances[paInd + 1] - distances[paInd + 0])
            retPts = retPts:vertcat(self:lerp(pa, pb, r, true))
        end
        if not data.opt.closed then
            retPts = retPts:vertcat(pts:block(pts:rows(), 1, 1, -1))
        end
    else
        local function getBezierPt(a, b, c, t)
            local pia = self:lerp(a, b, 0.5, true)
            local pib = self:lerp(b, c, 0.5, true)
            if data.pathPoints.opt.bezierSmoothing < 0.999 then
                pia = self:lerp(b, pia, data.pathPoints.opt.bezierSmoothing, true)
                pib = self:lerp(b, pib, data.pathPoints.opt.bezierSmoothing, true)
            end

            local p1 = self:lerp(pia, b, t, true)
            local p2 = self:lerp(b, pib, t, true)
            return self:lerp(p1, p2, t, true)
        end
        retPts = simEigen.Matrix(0, pts:cols(), {})
        if data.opt.closed then
            pts = pts:vertcat(pts:block(2, 1, 1, -1))
            pts = pts:block(pts:rows() - 2, 1, 1, -1):vertcat(pts)
        else
            local a = pts:block(pts:rows() - 1, 1, 1, -1)
            local b = pts:block(pts:rows() - 0, 1, 1, -1)
            pts = pts:vertcat(self:lerp(a, b, 2.0, true))
            local a = pts:block(2, 1, 1, -1)
            local b = pts:block(1, 1, 1, -1)
            pts = self:lerp(a, b, 2.0, true):vertcat(pts)
        end
        local cnt = math.floor(totalL * 2.0 / data.pathPoints.opt.samplingDistance) + 1.0 -- first a smaller sampling
        local sd = totalL / cnt
        local l = 0.0
        local paInd = 1
        for i = 1, cnt + 1 do
            while (l > distances[paInd + 1]) and (distances:rows() > paInd + 1) do
                paInd = paInd + 1
            end
            local px = pts:block(paInd + 0, 1, 1, -1)
            local pa = pts:block(paInd + 1, 1, 1, -1)
            local pb = pts:block(paInd + 2, 1, 1, -1)
            local py = pts:block(paInd + 3, 1, 1, -1)
            local r = (l - distances[paInd + 0]) / (distances[paInd + 1] - distances[paInd + 0])
            local pi
            if r >= 0.5 then
                pi = getBezierPt(pa, pb, py, r - 0.5)
            else
                pi = getBezierPt(px, pa, pb, r + 0.5)
            end
            retPts = retPts:vertcat(pi)
            l = l + sd
        end
        if not data.opt.closed then
            retPts = retPts:vertcat(pts:block(pts:rows() - 1, 1, 1, -1))
        end
        retPts = self:_resample(retPts, 0)
    end
    return retPts
end

function Path:createMarkers()
    local data = self._data
    self:removeMarkers()
    data.ctrlPoints.markers = self:_createMarkers(data.ctrlPoints.points, data.ctrlPoints.opt)
    data.pathPoints.markers = self:_createMarkers(data.pathPoints.points, data.pathPoints.opt)
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
    if data.opt.displDim > 0 then
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
    if points:rows() > 0 then
        if markers.pointMarker or markers.axesMarker then
            local dat
            local quat
            if data.opt.displDim == 2 then
                dat = points:block(1, 1, -1, 2):horzcat(simEigen.Matrix(points:rows(), 1, 0.0))
            elseif data.opt.displDim == 3 then
                dat = points:block(1, 1, -1, 3)
            elseif data.opt.displDim == 7 then
                dat = points:block(1, 1, -1, 3)
                quat = {quaternion = points:block(1, 4, -1, 4)}
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
                dat = points:block(1, 1, -1, 2):horzcat(simEigen.Matrix(points:rows(), 1, 0.0))
            else
                dat = points:block(1, 1, -1, 3)
            end
            local lines = simEigen.Matrix(0, dat:cols(), {})
            for i = 1, dat:rows() - 1 do
                lines = lines:vertcat(dat:block(i, 1, 2, -1))
            end
            if data.opt.closed then
                lines = lines:vertcat(dat:block(dat:rows(), 1, 1, -1))
                lines = lines:vertcat(dat:block(1, 1, 1, -1))
            end
            markers.lineMarker:addItems(lines)
        end
    end
end

function Path:removeMarkers()
    local data = self._data
    if data.ctrlPoints.markers then
        self:_removeMarkers(data.ctrlPoints.markers)
    end
    if data.pathPoints.markers then
        self:_removeMarkers(data.pathPoints.markers)
    end
end

function Path:_removeMarkers(m)
    if m then
        if m.pointMarker then
            m.pointMarker:remove()
            m.pointMarker = nil
        end
        if m.lineMarker then
            m.lineMarker:remove()
            m.lineMarker = nil
        end
        if m.axesMarker then
            m.axesMarker:remove()
            m.axesMarker = nil
        end
    end
end

return {
    Path = Path,
}
