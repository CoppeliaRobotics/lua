-- simIM lua type-checking wrapper
-- (this file is automatically generated: do not edit)
require 'checkargs'

local simIM=require('simIM')

__initFunctions=__initFunctions or {}
table.insert(__initFunctions, function()
    local function wrapFunc(funcName,wrapperGenerator)
        _G['simIM'][funcName]=wrapperGenerator(_G['simIM'][funcName])
    end

end)

return simIM
