sim=require'sim'

function getJointGroups(modelHandle)
    local ret={}
    sim.visitTree(modelHandle,function(h)
        if h~=modelHandle and sim.getModelProperty(h)&sim.modelproperty_not_model==0 then return false end
        if sim.readCustomDataBlock(h,'__jointGroup__') then
            table.insert(ret,h)
        end
    end)
    return ret
end
