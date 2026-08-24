if _DEVMODE and false then addLog(430, 'loaded deprecated.matrixLazyLoaders') end

for _, cls in ipairs{'Matrix', 'Vector', 'Vector3', 'Vector4', 'Vector7', 'Matrix3x3', 'Matrix4x4'} do
    local function _implicitMatrixLoad()
        local sim = require 'sim'
        sim.addLog(sim.verbosity_warnings, 'module \'matrix\' was implicitly loaded.')
        require('matrix')
    end
    _G[cls] = setmetatable({}, {
        __moduleLazyLoader = true,
        __call = function(self, ...)
            _implicitMatrixLoad()
            return _G[cls](...)
        end,
        __index = function(self, k)
            if type(k) ~= 'string' then return end
            _implicitMatrixLoad()
            return _G[cls][k]
        end
    })
end
