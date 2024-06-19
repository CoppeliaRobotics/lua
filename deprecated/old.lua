-- Old stuff, mainly for backward compatibility:
----------------------------------------------------------

function simRMLMoveToJointPositions(...)
    require("sim_old")
    return simRMLMoveToJointPositions(...)
end

function simRMLMoveToPosition(...)
    require("sim_old")
    return simRMLMoveToPosition(...)
end

local old = {}

function old.extend(sim)

sim.getQHull = sim._qhull
sim.handleChildScripts = sim.handleSimulationScripts
sim.switchThread = sim.yield
sim.getModuleName = sim.getPluginName
sim.getModuleInfo = sim.getPluginInfo
sim.setModuleInfo = sim.setPluginInfo
sim.moduleinfo_extversionstr = sim.plugininfo_extversionstr
sim.moduleinfo_builddatestr = sim.plugininfo_builddatestr
sim.moduleinfo_extversionint = sim.plugininfo_extversionint
sim.moduleinfo_verbosity = sim.plugininfo_verbosity
sim.moduleinfo_statusbarverbosity = sim.plugininfo_statusbarverbosity
sim.setThreadSwitchAllowed = setYieldAllowed
sim.getThreadSwitchAllowed = getYieldAllowed
sim.setThreadAutomaticSwitch = setAutoYield
sim.getThreadAutomaticSwitch = getAutoYield

function sim.getMatchingPersistentDataTags(...)
    local pattern = checkargs({{type = 'string'}}, ...)
    local result = {}
    for index, value in ipairs(sim.getPersistentDataTags()) do
        if value:match(pattern) then result[#result + 1] = value end
    end
    return result
end

function sim.setThreadSwitchTiming(dtInMs)
    sim.setAutoYieldDelay(dtInMs / 1000.0)
end

function sim.getThreadSwitchTiming()
    return sim.getAutoYieldDelay() * 1000.0
end

function sim.getIsRealTimeSimulation()
    local ret = 0
    if sim.getRealTimeSimulation() then
        ret = 1
    end
    return ret
end

function sim.readCustomDataBlock(obj, tag) 
    return sim.readCustomStringData(obj, tag)
end

function sim.writeCustomDataBlock(obj, tag, data)
    return sim.writeCustomStringData(obj, tag, data)
end

function sim.readCustomDataBlockTags(obj)
    local retVal = sim.readCustomDataTags(obj)
    if #retVal == 0 then
        retVal = nil
    end
    return retVal
end

function sim.rmlMoveToJointPositions(...)
    require("sim_old")
    return sim.rmlMoveToJointPositions(...)
end

function sim.rmlMoveToPosition(...)
    require("sim_old")
    return sim.rmlMoveToPosition(...)
end

function sim.boolOr32(...)
    require("sim_old")
    return sim.boolOr32(...)
end

function sim.boolAnd32(...)
    require("sim_old")
    return sim.boolAnd32(...)
end

function sim.boolXor32(...)
    require("sim_old")
    return sim.boolXor32(...)
end

function sim.boolOr16(...)
    require("sim_old")
    return sim.boolOr16(...)
end

function sim.boolAnd16(...)
    require("sim_old")
    return sim.boolAnd16(...)
end

function sim.boolXor16(...)
    require("sim_old")
    return sim.boolXor16(...)
end

function sim.setSimilarName(...)
    require("sim_old")
    return sim.setSimilarName(...)
end

function sim.tubeRead(...)
    require("sim_old")
    return sim.tubeRead(...)
end

function sim.getObjectHandle_noErrorNoSuffixAdjustment(...)
    require("sim_old")
    return sim.getObjectHandle_noErrorNoSuffixAdjustment(...)
end

function sim.moveToPosition(...)
    require("sim_old")
    return sim.moveToPosition(...)
end

function sim.moveToJointPositions(...)
    require("sim_old")
    return sim.moveToJointPositions(...)
end

function sim.moveToObject(...)
    require("sim_old")
    return sim.moveToObject(...)
end

function sim.followPath(...)
    require("sim_old")
    return sim.followPath(...)
end

function sim.include(...)
    require("sim_old")
    return sim.include(...)
end

function sim.includeRel(...)
    require("sim_old")
    return sim.includeRel(...)
end

function sim.includeAbs(...)
    require("sim_old")
    return sim.includeAbs(...)
end

function sim.canScaleObjectNonIsometrically(...)
    require("sim_old")
    return sim.canScaleObjectNonIsometrically(...)
end

function sim.canScaleModelNonIsometrically(...)
    require("sim_old")
    return sim.canScaleModelNonIsometrically(...)
end

function sim.scaleModelNonIsometrically(...)
    require("sim_old")
    return sim.scaleModelNonIsometrically(...)
end

function sim.UI_populateCombobox(...)
    require("sim_old")
    return sim.UI_populateCombobox(...)
end

function sim.displayDialog(...)
    require("sim_old")
    return sim.displayDialog(...)
end

function sim.endDialog(...)
    require("sim_old")
    return sim.endDialog(...)
end

function sim.getDialogInput(...)
    require("sim_old")
    return sim.getDialogInput(...)
end

function sim.getDialogResult(...)
    require("sim_old")
    return sim.getDialogResult(...)
end

end -- end of old.extend

return old