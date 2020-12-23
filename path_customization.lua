--[[
function sysCall_init()
    pathIsClosed=true
    handles={}
    for i=0,5,1 do
        handles[1+i]=sim.getObjectHandle('d'..i)
    end
    if pathIsClosed then
        handles[#handles+1]=handles[1]
    end
    model=sim.getObjectHandle(sim.handle_self)
end

function sysCall_actuation()
    if not bla then
        if shape then
            sim.removeObject(shape)
        end
        shape=nil
    path={}
    for i=1,#handles,1 do
        local p=sim.getObjectPosition(handles[i],-1)
        path[#path+1]=p[1]
        path[#path+1]=p[2]
        path[#path+1]=p[3]
    end
    
    drawPath(true,path)
    local interpolatedPath={}
   
    local lengths,totL=sim.getPathLengths(path,3)
    
    local ptCnt=100
    for i=1,ptCnt,1 do
        local pp=sim.getPathInterpolatedConfig(path,lengths,(i-1)*totL/(ptCnt-1),{type='quadraticBezier',forceOpen=false,strength=0.25})
        for j=1,#pp,1 do
            interpolatedPath[(i-1)*3+j]=pp[j]
        end
    end
    drawPath(false,interpolatedPath)
    local interpolLengths,totL=sim.getPathLengths(interpolatedPath,3,cb)
    
        local section={0.02,-0.02,0.02,0.02,-0.02,0.02,-0.02,-0.02,0.02,-0.02}
        local upVector={0,0,1}
  --      shape=sim.generateShapeFromPath(interpolatedPath,section,upVector,pathIsClosed)
    
    end
end
--]]


function sysCall_init()
    _S.path.utils=require('utils')
    _S.path.ctrlPtsTag='ABC_PATHCTRLPT'
    _S.path.model=sim.getObjectHandle(sim.handle_self)
    _S.path.uniqueId=sim.getStringParameter(sim.stringparam_uniqueid)
    _S.path.setup()
end

function sysCall_cleanup()
    if _S.path.ui then
        simUI.destroy(_S.path.ui)
    end
end

function sysCall_userConfig()
    local simStopped=sim.getSimulationState()==sim.simulation_stopped
    local xml=[[
            <label text="Path is closed"/>
            <checkbox text="" on-change="_S.path.closed_callback" id="1" />

            <label text="Visible while simulation running"/>
            <checkbox text="" on-change="_S.path.visibleDuringSimulation_callback" id="2" />

            <label text="Show time plots"/>
            <checkbox text="" on-change="_S.path.timeOnly_callback" id="3" />

            <label text="Show X/Y plots"/>
            <checkbox text="" on-change="_S.path.xyOnly_callback" id="4" />

            <label text="Show 3D curves"/>
            <checkbox text="" on-change="_S.path.xyzOnly_callback" id="8" />

            <label text="X/Y plots keep 1:1 aspect ratio"/>
            <checkbox text="" on-change="_S.path.squareXy_callback" id="5" style="* {margin-right: 100px;}"/>
            
            <label text="Update frequency"/>
            <combobox id="7" on-change="_S.path.updateFreqChanged_callback"></combobox>
            
            <label text="Preferred path position"/>
            <combobox id="6" on-change="_S.path.graphPosChanged_callback"></combobox>
    ]]
    _S.path.ui=_S.path.utils.createCustomUi(xml,sim.getObjectName(_S.path.model),_S.path.previousDlgPos,true,'_S.path.removeDlg',true,false,false,'layout="form" enabled="'..tostring(simStopped)..'"')
    _S.path.setDlgItemContent()
end

function sysCall_beforeCopy(inData)
    for key,value in pairs(inData.objectHandles) do
        if _S.path.ctrlPtsMap[key] then
            -- This ctrl point will be copied, append some temp data:
            local dat=sim.readCustomDataBlock(key,_S.path.ctrlPtsTag)
            dat=sim.unpackTable(dat)
            dat.pasteTo=_S.path.uniqueId
            sim.writeCustomDataBlock(key,_S.path.ctrlPtsTag,sim.packTable(dat))
        end
    end
end

function sysCall_afterCopy(inData)
    for key,value in pairs(inData.objectHandles) do
        if _S.path.ctrlPtsMap[key] then
            -- This ctrl point was copied. Remove the temp data previously added:
            local dat=sim.readCustomDataBlock(key,_S.path.ctrlPtsTag)
            dat=sim.unpackTable(dat)
            dat.pasteTo=nil
            sim.writeCustomDataBlock(key,_S.path.ctrlPtsTag,sim.packTable(dat))
        end
    end
end

function sysCall_afterCreate(inData)
    local pts={}
    for i=1,#inData.objectHandles,1 do
        local h=inData.objectHandles[i]
        local dat=sim.readCustomDataBlock(h,_S.path.ctrlPtsTag)
        if dat and #dat>0 then
            dat=sim.unpackTable(dat)
            if dat.pasteTo==_S.path.uniqueId then
                dat.pasteTo=nil
                pts[#pts+1]=dat
                dat.handle=h
            end
        end
    end
    if #pts>0 then
        table.sort(pts,function(a,b) return a.index<b.index end)
        local highIndex=pts[#pts].index
        for i=1,#pts,1 do
            pts[i].index=highIndex+(pts[i].index/100000)
            sim.writeCustomDataBlock(pts[i].handle,_S.path.ctrlPtsTag,sim.packTable(pts[i]))
            sim.setObjectParent(pts[i].handle,_S.path.model,true)
        end
        _S.path.setup()    
    end
end

function sysCall_nonSimulation()
    local a=_S.path.getCtrlPtsPoseId()
    if a~=_S.path.ctrlPtsPoseId then
        _S.path.setup()
    end
end

function sysCall_beforeDelete(inData)
--    print("sysCall_beforeDelete:")
--    print(inData)
end

function sysCall_afterDelete(inData)
--    print("sysCall_afterDelete:")
--    print(inData)
end

_S.path={}

function _S.path.getCtrlPtsPoseId()
    local p={}
    for i=1,#_S.path.ctrlPts,1 do
        local h=_S.path.ctrlPts[i].handle
        p[2*(i-1)+1]=sim.getObjectPosition(h,sim.handle_parent)
        p[2*(i-1)+2]=sim.getObjectQuaternion(h,sim.handle_parent)
    end
    return sim.packTable(p)
end

function _S.path.setup()
    _S.path.getCtrlPts()
    _S.path.computePaths()
    _S.path.displayLines()
    if _S.path.shaping then
        local pathPts={}
        for i=0,(#_S.path.paths[2]/7)-1,1 do
            pathPts[#pathPts+1]=_S.path.paths[2][i*7+1]
            pathPts[#pathPts+1]=_S.path.paths[2][i*7+2]
            pathPts[#pathPts+1]=_S.path.paths[2][i*7+3]
        end
        local c=_S.path.readInfo()
        local m=sim.getObjectMatrix(_S.path.model,-1)
        local s=_S.path.shaping(pathPts,{m[3],m[7],m[11]},(c.bitCoded&2)~=0)
        if sim.isHandleValid(s)==1 then
            local shapes=sim.getObjectsInTree(_S.path.model,sim.object_shape_type,1+2)
            for i=1,#shapes,1 do
                sim.removeObject(shapes[i])
            end
            sim.setObjectParent(s,_S.path.model,false)
        end
    end
end

function _S.path.computePaths()
    local c=_S.path.readInfo()
    local handles={}
    for i=1,#_S.path.ctrlPts,1 do
        handles[i]=_S.path.ctrlPts[i].handle
    end
    if (c.bitCoded & 2)~=0 then
        handles[#handles+1]=handles[1]
    end

    local path={}
    for i=1,#handles,1 do
        local p=sim.getObjectPosition(handles[i],_S.path.model)
        path[#path+1]=p[1]
        path[#path+1]=p[2]
        path[#path+1]=p[3]
        local q=sim.getObjectQuaternion(handles[i],_S.path.model)
        path[#path+1]=q[1]
        path[#path+1]=q[2]
        path[#path+1]=q[3]
        path[#path+1]=q[4]
    end
    
    local interpolatedPath={}
   
    local function cb(a,b)
        return sim.getConfigDistance(a,b,{1,1,1,0,0,0,0})
    end
   
    local lengths,totL=sim.getPathLengths(path,7,cb)
    
    local ptCnt=c.pointCnt
    for i=1,ptCnt,1 do
        local pp
        if c.interpol.smoothing==0 then
            pp=sim.getPathInterpolatedConfig(path,lengths,(i-1)*totL/(ptCnt-1),nil,{0,0,0,2,2,2,2})
        else
            pp=sim.getPathInterpolatedConfig(path,lengths,(i-1)*totL/(ptCnt-1),{type='quadraticBezier',forceOpen=false,strength=c.interpol.smoothing},{0,0,0,2,2,2,2})
        end
        for j=1,#pp,1 do
            interpolatedPath[(i-1)*7+j]=pp[j]
        end
    end
    _S.path.paths={}
    _S.path.paths[1]=path
    _S.path.paths[2]=interpolatedPath
end

function _S.path.displayLines()
    local m=sim.getObjectMatrix(_S.path.model,-1)
    for j=1,2,1 do
        local path=_S.path.paths[j]
        local dr,col,s
        if j==1 then
            col={0.8,1,1}
            s=1
        else
            col={0,0.96,0.66}
            s=3
        end
        if not _S.path.lineCont then
            _S.path.lineCont={-1,-1}
        end
        if _S.path.lineCont[j]~=-1 then
            sim.removeDrawingObject(_S.path.lineCont[j])
        end
        _S.path.lineCont[j]=sim.addDrawingObject(sim.drawing_lines,s,0,_S.path.model,9999,col)
        for i=0,(#path/7)-2,1 do
            local p1={path[i*7+1],path[i*7+2],path[i*7+3]}
            local p2={path[(i+1)*7+1],path[(i+1)*7+2],path[(i+1)*7+3]}
            p1=sim.multiplyVector(m,p1)
            p2=sim.multiplyVector(m,p2)
            local l={p1[1],p1[2],p1[3],p2[1],p2[2],p2[3]}
            sim.addDrawingObjectItem(_S.path.lineCont[j],l)
        end
    end
end

function _S.path.getCtrlPts()
    local d=sim.getObjectsInTree(_S.path.model,sim.object_dummy_type,1+2)
    local pts={}
    local map={}
    for i=1,#d,1 do
        local h=d[i]
        local dat=sim.readCustomDataBlock(h,_S.path.ctrlPtsTag)
        if dat and #dat>0 then
            dat=sim.unpackTable(dat)
            dat.handle=h
            if dat.pasteTo then
                dat=nil
            end
            --[[
        else
            dat={}
            dat.index=i
            sim.writeCustomDataBlock(h,_S.path.ctrlPtsTag,sim.packTable(dat))
            dat.handle=h
            --]]
        end
        if dat then
            pts[#pts+1]=dat
            map[dat.handle]=true
        end
    end
    table.sort(pts,function(a,b) return a.index<b.index end)
    for i=1,#pts,1 do
        pts[i].index=i -- indices could be fractions and/or not contiguous
        sim.writeCustomDataBlock(pts[i].handle,_S.path.ctrlPtsTag,sim.packTable(pts[i]))
    end
    _S.path.ctrlPts=pts
    _S.path.ctrlPtsMap=map
    _S.path.ctrlPtsPoseId=_S.path.getCtrlPtsPoseId()
end

function _S.path.removeDlg()
    local x,y=simUI.getPosition(_S.path.ui)
    _S.path.previousDlgPos={x,y}
    simUI.destroy(_S.path.ui)
    _S.path.ui=nil
end

function _S.path.setDlgItemContent()
    if _S.path.ui then
        local config=_S.path.readInfo()
        local sel=simUI.getCurrentEditWidget(_S.path.ui)
        --[[
        simUI.setCheckboxValue(_S.path.ui,1,((config['bitCoded'] & 2)==0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui,2,((config['bitCoded'] & 1)==0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui,3,((config['bitCoded'] & 4)==0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui,4,((config['bitCoded'] & 8)==0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui,5,((config['bitCoded'] & 16)==0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui,8,((config['bitCoded'] & 32)==0 and 2 or 0))
        
        local items={'bottom right','top right','top left','bottom left','center'}
        simUI.setComboboxItems(_S.path.ui,6,items,config['graphPos'])
        
        local items={'always','1/2 of time','1/4 of time','1/10 of time','1/100 of time'}
        simUI.setComboboxItems(_S.path.ui,7,items,config['updateFreq'])
--]]        
        simUI.setCurrentEditWidget(_S.path.ui,sel)
    end
end

function _S.path.getDefaultInfoForNonExistingFields(info)
    if not info.bitCoded then
        info.bitCoded=1 -- 1=show line, 2=closed, 4=generate shape
    end
    if not info.pointCnt then
        info.pointCnt=200
    end
    if not info.interpol then
        info.interpol={}
    end
    info.interpol.type=nil
    info.interpol.strength=nil
    if not info.interpol.strength then
        info.interpol.smoothing=1 -- 0-1 (0=linear interpol, other is Bezier interpol)
    end
    if not info.line then
        info.line={}
    end
    if not info.line.color then
        info.line.color={0,0.96,0.66}
    end
    if not info.line.thickness then
        info.line.thickness=3
    end
    if not info.shaping then
        info.shaping={}
    end
    if not info.shaping.enabled then
        info.shaping.enabled=false
    end
    if not info.shaping.color then
        info.shaping.color={0.85,0.85,0.85}
    end
    if not info.shaping.section then
        info.shaping.section={0.01,-0.01,0.01,0.01,-0.01,0.01,-0.01,-0.01,0.01,-0.01}
    end
end

function _S.path.readInfo()
    local data=sim.readCustomDataBlock(_S.path.model,'ABC_PATH_INFO')
    if data then
        data=sim.unpackTable(data)
    else
        data={}
    end
    _S.path.getDefaultInfoForNonExistingFields(data)
    return data
end

function _S.path.writeInfo(data)
    if data then
        sim.writeCustomDataBlock(_S.path.model,'ABC_PATH_INFO',sim.packTable(data))
    else
        sim.writeCustomDataBlock(_S.path.model,'ABC_PATH_INFO','')
    end
end

function _S.path.closed_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    c.bitCoded=(c.bitCoded | 2)
    if newVal==0 then
        c.bitCoded=c.bitCoded-2
    end
    _S.path.writeInfo(c)
    _S.path.setup()
    sim.announceSceneContentChange()
end

return _S.path