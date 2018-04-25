function AddStatusbarMessage(txt)
    return sim.addStatusbarMessage(txt)
end

function GetObjectPosition(objHandle,relObjHandle)
    return sim.getObjectPosition(objHandle,relObjHandle)
end

function GetObjectHandle(objName)
    return sim.getObjectHandle(objName..'#')
end

function StartSimulation()
    return sim.startSimulation()
end

function StopSimulation()
    return sim.stopSimulation()
end

function GetVisionSensorImage(objHandle,greyScale)
    if greyScale then
        objHandle=objHandle+sim.handleflag_greyscale
    end
    local img,x,y=sim.getVisionSensorCharImage(objHandle)
    return {{x,y},img}
end

function SetVisionSensorImage(objHandle,greyScale,img)
    if greyScale then
        objHandle=objHandle+sim.handleflag_greyscale
    end
    return sim.setVisionSensorCharImage(objHandle,img)
end

function Synchronous(enable)
    if enable and not syncMode then
        syncModeWait=true
    end
    syncMode=enable
    return true
end

function SynchronousTrigger()
    syncModeWait=false
    return true
end

function GetSimulationStepDone()
    local retVal={}
    retVal.simulationTime=sim.getSimulationTime()
    return retVal
end

function GetSimulationStepStarted()
    local retVal={}
    retVal.simulationTime=sim.getSimulationTime()
    return retVal
end

function DisconnectClient(clientId)
    local val=allPublishers[clientId]
    if val then
        for topic,value in pairs(val) do
            if value.handle~=defaultPublisher then
                simB0.cleanupSocket(value.handle)
                simB0.destroyPublisher(value.handle)
            end
        end
        allPublishers[clientId]=nil
    end
    local val=dedicatedSubscribers[clientId]
    if val then
        for topic,value in pairs(val) do
            simB0.cleanupSocket(value.handle)
            simB0.destroySubscriber(value.handle)
        end
        dedicatedSubscribers[clientId]=nil
    end
    allClients[clientId]=nil
end

function Ping()
    return 'Pong'
end


-----------------------------------------
-----------------------------------------

function PCALL(func,...)
    local res=true
    local val
    res,val=pcall(func,...)
    if val==nil then val=true end -- make sure we have 2 ret arguments
--    val=func(...)
--    print(res,val)
    return res,val
end

function createNode()
    if not b0Node then
        if not initStg then
            local xml = [[ <ui closeable="false" resizable="false" title="BlueZero" modal="true">
                    <label text="Looking for BlueZero resolver..." style="* {font-size: 20px; font-weight: bold; margin-left: 20px; margin-right: 20px;}"/>
                    <label text="This can take several seconds." style="* {font-size: 20px; font-weight: bold; margin-left: 20px; margin-right: 20px;}"/>
                    </ui> ]]
            local ui=simUI.create(xml)
            if not simB0.pingResolver() then
                print('B0 Remote API: B0 resolver was not detected. Launching it from here...')
                sim.launchExecutable('b0_resolver','',1)
            end
            simUI.destroy(ui)
            
            if simB0.pingResolver() then
                messagePack=require('MessagePack')
                if modelData.packStrAsBin then
                    messagePack.set_string('binary')
                else
                    messagePack.set_string('string')
                end
                initStg=1
            else
                initStg=0
                print(b0RemoteApiServerNameDebug..': B0 resolver could not be launched.')
            end
        end

        if initStg==1 then
            b0Node=simB0.create(modelData.nodeName)
            serviceServer=simB0.createServiceServer(b0Node,modelData.channelName..'SerX','serviceServer_callback')
            defaultPublisher=simB0.createPublisher(b0Node,modelData.channelName..'PubX')
            defaultSubscriber=simB0.createSubscriber(b0Node,modelData.channelName..'SubX','defaultSubscriber_callback')
            dedicatedSubscribers={} -- key is clientId, value is a map with: key is subscriberTopic, value is another map: handle
            allPublishers={} -- key is clientId, value is a map with: key is publisherTopic, value is another map: pubHandle, cmds=listOfRegisteredCmds 
            simB0.init(b0Node)
            allClients={}
            allSubscribers={}
        end
    end
end

function destroyNode()
    if b0Node then
        local clients={}
        for key,val in pairs(allClients) do
            clients[#clients+1]=key
        end
        for i=1,#clients,1 do
            DisconnectClient(clients[i])
        end
        
        simB0.cleanup(b0Node)
        simB0.destroyPublisher(defaultPublisher)
        simB0.destroySubscriber(defaultSubscriber)
        simB0.destroyServiceServer(serviceServer)
        simB0.destroy(b0Node)
    end
    allPublishers={}
    dedicatedSubscribers={}
    allClients={}
    b0Node=nil
end

function sendAndSpin(calledMoment)

    local retVal=true
    local publishSimulationStepFinished_ClientAnddata={}
    local publishSimulationStepStarted_ClientAnddata={}
    local publisherCntForClients={}
    local executedFunctions=''
    local manyExecutedFunctions=false
        
    if b0Node then
        -- Handle subscriber(s) and service calls:
        simB0.spinOnce(b0Node)
        for clientId,val in pairs(dedicatedSubscribers) do
            for topic,value in pairs(val) do
                local msg=''
                while simB0.pollSocket(value.handle) do
                    msg=simB0.readSocket(value.handle)
                    if not value.dropMessages then
                        dedicatedSubscriber_callback(msg)
                    end
                end
                if value.dropMessages and #msg>0 then
                    dedicatedSubscriber_callback(msg)
                end
--                simB0.spinOnceSocket(value.handle)
            end
        end

        -- Handle publishing:
        local clientsToRemove={}
        for clientId,val in pairs(allPublishers) do
            if not hasClientReachedMaxInactivityTime(clientId) then
                -- Ok, that client appears to be still active
                for topic,value in pairs(val) do
                    local publisher=value.handle
                    local triggerInterval=value.triggerInterval
                    local cmdList=value.cmds
                    for i=1,#cmdList,1 do
                        local cmd=cmdList[i]
                        if triggerInterval==0 or calledMoment==0 or (nextSimulationStepUnderway and not (sim.getSimulationState()==sim.simulation_paused)) or cmd.func=='GetSimulationStepStarted' then
                            cmd.triggerIntervalCnt=cmd.triggerIntervalCnt-1
                            if cmd.triggerIntervalCnt<=0 then
                                cmd.triggerIntervalCnt=triggerInterval
                                if not manyExecutedFunctions then
                                    if #executedFunctions>0 then
                                        executedFunctions=executedFunctions..'|'
                                    end
                                    if #executedFunctions<130 then
                                        executedFunctions=executedFunctions..cmd.func
                                    else
                                        executedFunctions=executedFunctions..'...'
                                        manyExecutedFunctions=true
                                    end
                                end
                                local result,retVal=PCALL(_G[cmd.func],unpack(cmd.args))
                                retVal=messagePack.pack({topic,{result,retVal}})
                                if cmd.func=='GetSimulationStepDone' then
                                    publishSimulationStepFinished_ClientAnddata[clientId]={publisher,retVal} -- publish this one last! (further down)
                                else
                                    if cmd.func=='GetSimulationStepStarted' then
                                        publishSimulationStepStarted_ClientAnddata[clientId]={publisher,retVal} -- publish this one last! (further down)
                                    else
                                        if not publisherCntForClients[clientId] then
                                            publisherCntForClients[clientId]=1
                                        else
                                            publisherCntForClients[clientId]=publisherCntForClients[clientId]+1
                                        end
                                        simB0.publish(publisher,retVal)
                                    end
                                end
                            
                            
                            end
                        end
                    end
                    
                end
            else
                clientsToRemove[#clientsToRemove+1]=clientId
            end
        end
        
        -- Remove publishers of inactive clients:
        for i=1,#clientsToRemove,1 do
            local clientId=clientsToRemove[i]
            DisconnectClient(clientId)
            if modelData.debugMessages then
                print(string.format(b0RemoteApiServerNameDebug..": destroyed all streaming commands for client [%s] after detection of inactivity",clientId))
            end
        end
    end
    
    if calledMoment==1 then -- i.e. before main script
        if nextSimulationStepUnderway then
            -- Handle publishing of simulationStepFinished here (special):
            for key,value in pairs(publishSimulationStepFinished_ClientAnddata) do
                if not publisherCntForClients[key] then
                    publisherCntForClients[key]=1
                else
                    publisherCntForClients[key]=publisherCntForClients[key]+1
                end
                simB0.publish(value[1],value[2])
            end
        end
    
        if syncMode then
            if syncModeWait then
                retVal=false
            else
                syncModeWait=true
            end
        end
        if retVal then
            nextSimulationStepUnderway=true
            -- Handle publishing of simulationStepStarted here (special):
            for key,value in pairs(publishSimulationStepStarted_ClientAnddata) do
                if not publisherCntForClients[key] then
                    publisherCntForClients[key]=1
                else
                    publisherCntForClients[key]=publisherCntForClients[key]+1
                end
                simB0.publish(value[1],value[2])
            end
        else
            nextSimulationStepUnderway=false
        end
    end
    
    local msgCnt=0
    local clientCnt=0
    for key,value in pairs(publisherCntForClients) do
        clientCnt=clientCnt+1
        msgCnt=msgCnt+value
    end
    if msgCnt>0 and modelData.debugMessages then
        print(string.format(b0RemoteApiServerNameDebug..": published %i message(s) to %i client(s): %s",msgCnt,clientCnt,executedFunctions))
    end

    return retVal
end

function updateClientLastActivityTime(clientId)
    if not allClients[clientId] then
        allClients[clientId]={maxInactivityTimeMs=60*1000}
    end
    local val=allClients[clientId]
    val.lastActivityTimeMs=sim.getSystemTimeInMs(-1)
end

function setClientMaxInactivityTime(clientId,maxInactivityTime)
    local val=allClients[clientId]
    val.maxInactivityTimeMs=maxInactivityTime*1000
end

function hasClientReachedMaxInactivityTime(clientId)
    local val=allClients[clientId]
    return sim.getSystemTimeInMs(val.lastActivityTimeMs)>val.maxInactivityTimeMs
end

function serviceServer_callback(receiveMsg)
    local result=true
    local data=true
    receiveMsg=messagePack.unpack(receiveMsg)
    local funcName=receiveMsg[1][1]
    local clientId=receiveMsg[1][2]
    local topic=receiveMsg[1][3]
    local funcArgs=receiveMsg[2]
    updateClientLastActivityTime(clientId)
    
    if funcName=='createSubscriber' then
        local subscr=simB0.createSubscriber(b0Node,funcArgs[1],'dedicatedSubscriber_callback',false,true)
   --     simB0.setSocketOption(subscr,'conflate',1)
        simB0.initSocket(subscr);
        if not dedicatedSubscribers[clientId] then
            dedicatedSubscribers[clientId]={}
        end
        dedicatedSubscribers[clientId][funcArgs[1]]={handle=subscr,dropMessages=funcArgs[2]}
        if modelData.debugMessages then
            print(string.format(b0RemoteApiServerNameDebug..": creating subscriber for client [%s] with topic [%s]",clientId,funcArgs[1]))
        end
    elseif funcName=='createPublisher' then
        local pub=simB0.createPublisher(b0Node,funcArgs[1],false,true)
    --    simB0.setSocketOption(pub,'conflate',1)
        simB0.initSocket(pub);
        if not allPublishers[clientId] then
            allPublishers[clientId]={}
        end
        allPublishers[clientId][funcArgs[1]]={handle=pub,cmds={},triggerInterval=funcArgs[2]}
        if modelData.debugMessages then
            print(string.format(b0RemoteApiServerNameDebug..": creating publisher for client [%s] with topic [%s]",clientId,funcArgs[1]))
        end
    elseif funcName=='setDefaultPublisherPubInterval' then
        if not allPublishers[clientId] then
            allPublishers[clientId]={}
        end
        if not allPublishers[clientId][funcArgs[1]] then
            allPublishers[clientId][funcArgs[1]]={handle=defaultPublisher,cmds={},triggerInterval=funcArgs[2]}
        end
    elseif funcName=='inactivityTolerance' then
        setClientMaxInactivityTime(clientId,funcArgs[1])
    else
        if modelData.debugMessages then
            print(string.format(b0RemoteApiServerNameDebug..": service call from client [%s]: %s",clientId,receiveMsg[1][1]))
        end
        result,data=PCALL(_G[funcName],unpack(funcArgs))
    end
    return messagePack.pack({result,data})
end

function defaultSubscriber_callback(msg)
    msg=messagePack.unpack(msg)
    local funcName=msg[1][1]
    local clientId=msg[1][2]
    local task=msg[1][4] -- 0=serviceCall, 1=received on default subscriber, 2=register streaming cmd on default publisher, 3=received on dedicated subscriber, 4=register streaming cmd on dedicated publisher
    local topic=msg[1][3]
    local funcArgs=msg[2]
    updateClientLastActivityTime(clientId)
    
    if task==1 then
        -- We simply want to execute the function and forget (no return)
        if modelData.debugMessages then
            print(string.format(b0RemoteApiServerNameDebug..": command message from client [%s]: %s",clientId,funcName))
        end
        PCALL(_G[funcName],unpack(funcArgs))
    elseif task==2 then
        -- We want to register a command to be constantly executed on the default publisher:
        if not allPublishers[clientId] then
            allPublishers[clientId]={}
        end
        if not allPublishers[clientId][topic] then
            allPublishers[clientId][topic]={handle=defaultPublisher,cmds={},triggerInterval=1}
        end
        local val=allPublishers[clientId][topic]
        val.cmds[#val.cmds+1]={func=funcName,args=funcArgs,triggerIntervalCnt=1}
        if modelData.debugMessages then
            print(string.format(b0RemoteApiServerNameDebug..": registering streaming command [%s] for client [%s] on topic [%s] (default publisher)",funcName,clientId,topic))
        end
    elseif task==4 then
        -- We want to register a command to be constantly executed on a dedicated publisher:
        if allPublishers[clientId] and  allPublishers[clientId][topic] then
            local val=allPublishers[clientId][topic]
            allCmds=val.cmds
            allCmds[#allCmds+1]={func=funcName,args=funcArgs,triggerIntervalCnt=1}
            if modelData.debugMessages then
                print(string.format(b0RemoteApiServerNameDebug..": registering streaming command [%s] for client [%s] on topic [%s] (dedicated publisher)",funcName,clientId,topic))
            end
        end
    else
    
    end
end    
    
    
function dedicatedSubscriber_callback(msg)
    msg=messagePack.unpack(msg)
    local funcName=msg[1][1]
    local clientId=msg[1][2]
    local topic=msg[1][3]
    local funcArgs=msg[2]
    updateClientLastActivityTime(clientId)
    print("Hello from dedicated subscriber")
    -- We simply want to execute the function and forget (no return)
    if modelData.debugMessages then
        print(string.format(b0RemoteApiServerNameDebug..": command message from client [%s]: %s",clientId,funcName))
    end
    PCALL(_G[funcName],unpack(funcArgs))
end    

function onConfigNodeNameChanged(ui,id,newVal)
    if #newVal>2 then
        local newValue=''
        for i=1,#newVal,1 do
            local v=newVal:sub(i,i)
            if (v>='0' and v<='9') or (v>='a' and v<='z') or (v>='A' and v<='Z') or v=='_' or v=='-' then
                newValue=newValue..v
            else
                newValue=newValue..'_'
            end
        end
        configUiData.nodeName=newValue
    end
    simUI.setEditValue(configUiData.dlg,1,configUiData.nodeName)
end

function onConfigChannelNameChanged(ui,id,newVal)
    if #newVal>2 then
        local newValue=''
        for i=1,#newVal,1 do
            local v=newVal:sub(i,i)
            if (v>='0' and v<='9') or (v>='a' and v<='z') or (v>='A' and v<='Z') or v=='_' or v=='-' then
                newValue=newValue..v
            else
                newValue=newValue..'_'
            end
        end
        configUiData.channelName=newValue
    end
    simUI.setEditValue(configUiData.dlg,2,configUiData.channelName)
end

function onDebugMsgChanged(ui,id,newval)
    configUiData.debugMsg=not configUiData.debugMsg
    modelData.debugMessages=not modelData.debugMessages
    sim.writeCustomDataBlock(model,modelTag,sim.packTable(modelData))
end

function onSimOnlyChanged(ui,id,newval)
    configUiData.duringSimulationOnly=not configUiData.duringSimulationOnly
    modelData.duringSimulationOnly=not modelData.duringSimulationOnly
    sim.writeCustomDataBlock(model,modelTag,sim.packTable(modelData))
    if modelData.duringSimulationOnly then
        destroyNode()
    else
        createNode()
    end
end

function onPackStrAsBinChanged(ui,id,newval)
    configUiData.packStrAsBin=not configUiData.packStrAsBin
    modelData.packStrAsBin=not modelData.packStrAsBin
    sim.writeCustomDataBlock(model,modelTag,sim.packTable(modelData))
    if modelData.packStrAsBin then
        messagePack.set_string('binary')
    else
        messagePack.set_string('string')
    end
end

function onConfigRestartNode(ui,id,newVal)
    modelData.nodeName=configUiData.nodeName
    modelData.channelName=configUiData.channelName
    sim.writeCustomDataBlock(model,modelTag,sim.packTable(modelData))
    if not modelData.duringSimulationOnly then
        destroyNode()
        createNode()
    end
end

function createConfigDlg()
    if not configUiData then
        local xml = [[
        <ui title="BlueZero-based remote API, server-side configuration" closeable="false" resizable="false" activate="false">
        <group layout="form" flat="true">
        <label text="Node name"/>
        <edit on-editing-finished="onConfigNodeNameChanged" id="1"/>
        <label text="Channel name"/>
        <edit on-editing-finished="onConfigChannelNameChanged" id="2"/>
        <label text=""/>
        <button text="Restart node with above names" checked="false" on-click="onConfigRestartNode" />
        
        <label text="Pack strings as binary"/>
        <checkbox text="" on-change="onPackStrAsBinChanged" id="4" />
        <label text="Enabled during simulation only"/>
        <checkbox text="" on-change="onSimOnlyChanged" id="5" />
        <label text="Debug messages"/>
        <checkbox text="" on-change="onDebugMsgChanged" id="3" />
        </group>
        </ui>
        ]]
        configUiData={}
        configUiData.dlg=simUI.create(xml)
        if previousConfigDlgPos then
            simUI.setPosition(configUiData.dlg,previousConfigDlgPos[1],previousConfigDlgPos[2],true)
        end
        configUiData.nodeName=modelData.nodeName
        configUiData.channelName=modelData.channelName
        configUiData.debugMsg=modelData.debugMessages
        configUiData.packStrAsBin=modelData.packStrAsBin
        configUiData.duringSimulationOnly=modelData.duringSimulationOnly
        simUI.setEditValue(configUiData.dlg,1,configUiData.nodeName)
        simUI.setEditValue(configUiData.dlg,2,configUiData.channelName)
        simUI.setCheckboxValue(configUiData.dlg,3,configUiData.debugMsg and 2 or 0)
        simUI.setCheckboxValue(configUiData.dlg,4,configUiData.packStrAsBin and 2 or 0)
        simUI.setCheckboxValue(configUiData.dlg,5,configUiData.duringSimulationOnly and 2 or 0)
    end
end

function removeConfigDlg()
    if configUiData then
        local x,y=simUI.getPosition(configUiData.dlg)
        previousConfigDlgPos={x,y}
        simUI.destroy(configUiData.dlg)
        configUiData=nil
    end
end

function sysCall_init()
    local res
    res,model=PCALL(sim.getObjectAssociatedWithScript,sim.handle_self) -- if call made directly, will fail with add-on script
    local abort=false
    if not res or model==-1 then
        -- We are running this script via an Add-On script
        
        model=-1
        b0RemoteApiServerNameDebug='B0 Remote API (add-on)'
        modelData={nodeName='b0RemoteApi_V-REP-addOn',channelName='b0RemoteApiAddOn',debugMessages=false,packStrAsBin=false,duringSimulationOnly=false}
    else
        -- We are probably running this script via a customization script
        modelTag='b0-remoteApi'
        b0RemoteApiServerNameDebug='B0 Remote API'
--        sim.writeCustomDataBlock(model,modelTag,sim.packTable({nodeName='b0RemoteApi_V-REP',channelName='b0RemoteApi',debugMessages=true,packStrAsBin=false,duringSimulationOnly=false}))
        
        local objs=sim.getObjectsWithTag(modelTag,true)
        if #objs>1 then
            sim.removeModel(model)
            sim.removeObjectFromSelection(sim.handle_all)
            objs=sim.getObjectsWithTag(modelTag,true)
            sim.addObjectToSelection(sim.handle_single,objs[1])
            abort=true
        else
            modelData=sim.unpackTable(sim.readCustomDataBlock(model,modelTag))
        end
    end
    syncMode=false
    if not abort then
        createNode()
    end
end

function sysCall_cleanup()
    destroyNode()
    removeConfigDlg()
end

function sysCall_nonSimulation()
    local s=sim.getObjectSelection()
    if s and #s==1 and s[1]==model then
        createConfigDlg()
    else
        removeConfigDlg()
    end
    sendAndSpin(0)
end

function sysCall_beforeMainScript()
    if not sendAndSpin(1) then
        return {doNotRunMainScript=true}
    end
end

function sysCall_suspended()
    sendAndSpin(2)
end

function sysCall_beforeSimulation()
    removeConfigDlg()
    if modelData.duringSimulationOnly then
        createNode()
    end
end

function sysCall_afterSimulation()
    if modelData.duringSimulationOnly then
        destroyNode()
    end
    syncMode=false
end

function sysCall_beforeInstanceSwitch()
    if model>=0 then
        destroyNode()
        removeConfigDlg()
    end
end

function sysCall_afterInstanceSwitch()
    if model>=0 then
        if not modelData.duringSimulationOnly then
            createNode()
        end
        createNode()
    end
end

function sysCall_addOnScriptSuspend()
    destroyNode()
end

function sysCall_addOnScriptResume()
    if not modelData.duringSimulationOnly then
        createNode()
    end
end
