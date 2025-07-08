if _DEVMODE then addLog(430, 'loaded deprecated.lazyLoaders') end

local __lazyLoadModules = {
    'sim', 'simIK', 'simUI', 'simGeom', 'simMujoco', 'simAssimp', 'simBubble', 'simCHAI3D',
    'simMTB', 'simOMPL', 'simOpenMesh', 'simQHull', 'simRRS1', 'simSDF', 'simSubprocess',
    'simSurfRec', 'simURDF', 'simVision', 'simWS', 'simZMQ', 'simIM', 'simEigen', 'simIGL',
    'simICP', 'simROS', 'simROS2',
}

require = wrap(require, function(origRequire)
    return function(...)
        local requiredName = table.unpack {...}

        for i, lazyModName in ipairs(__lazyLoadModules) do
            if lazyModName == requiredName then
                if not __inLazyLoader or __inLazyLoader == 0 then
                    if __usedLazyLoaders then
                        addLog(430, "implicit loading of modules has been disabled because " ..
                            "one known module (" ..  requiredName .. ") was loaded explicitly.")
                    end
                    _removeLazyLoaders()
                end
            end
        end

        return origRequire(...)
    end
end)

function _moduleLazyLoader(name)
    local proxy = {}
    local mt = {
        __moduleLazyLoader = {},
        __index = function(_, key)
            if __oldModeConsts[key] then error("The script does not follow the current CoppeliaSim calling conventions (backward compatibility has been dropped as of CoppeliaSim V4.10.0 rev2 and later). Adapt this script.") end
            if key == 'registerScriptFuncHook' then
                return registerScriptFuncHook
            else
                if not __inLazyLoader then __inLazyLoader = 0 end
                __inLazyLoader = __inLazyLoader + 1
                _G[name] = require(name)
                __inLazyLoader = __inLazyLoader - 1
                addLog(430, "module '" .. name .. "' was implicitly loaded.")
                __usedLazyLoaders = true
                return _G[name][key]
            end
        end,
    }
    setmetatable(proxy, mt)
    _G[name] = proxy
    return proxy
end

function _setupLazyLoaders()
    __usedLazyLoaders = false
    for i, name in ipairs(__lazyLoadModules) do
        if not _G[name] then _G[name] = _moduleLazyLoader(name) end
    end
end

function _removeLazyLoaders()
    for i, name in ipairs(__lazyLoadModules) do
        if _G[name] then
            local mt = getmetatable(_G[name])
            if mt and mt.__moduleLazyLoader then _G[name] = nil end
        end
    end
    __usedLazyLoaders = nil
end

_setupLazyLoaders()

for _, cls in ipairs{'Matrix', 'Vector', 'Vector3', 'Vector4', 'Vector7', 'Matrix3x3', 'Matrix4x4'} do
    _G[cls] = setmetatable({}, {
        __moduleLazyLoader = true,
        __call = function(self, ...)
            local sim = require 'sim'
            sim.addLog(sim.verbosity_warnings, 'module \'matrix\' was implicitly loaded.')
            require('matrix')
            return _G[cls](...)
        end
    })
end
