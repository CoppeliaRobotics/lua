function sysCall_init()
    _S.path.init()
end

function sysCall_cleanup()
    _S.path.cleanup()
end

function sysCall_nonSimulation()
    _S.path.nonSimulation()
end

function sysCall_afterSimulation()
    _S.path.afterSimulation()
end

function sysCall_beforeSimulation()
    _S.path.beforeSimulation()
end

function sysCall_userConfig()
    local simStopped=sim.getSimulationState()==sim.simulation_stopped
    local xml=[[
            <group layout="form" flat="true">
            <label text="Path is closed"/>
            <checkbox text="" on-change="_S.path.closed_callback" id="1" />

            <label text="Generate extruded shape"/>
            <checkbox text="" on-change="_S.path.generateShape_callback" id="3" />

            <label text="Hide path line when simulation running"/>
            <checkbox text="" on-change="_S.path.hideDuringSimulation_callback" id="2" />

            <label text="Show orientation frames"/>
            <checkbox text="" on-change="_S.path.showOrientation_callback" id="14" />

            <label text="Smoothness"/>
            <edit on-editing-finished="_S.path.smoothness_callback" id="4" />

            <label text="Subdivisions"/>
            <edit on-editing-finished="_S.path.pointCnt_callback" id="5" />
            </group>
            
            <checkbox text="Automatic path orientation:" style="* {font-weight: bold;}" on-change="_S.path.autoOrient_callback" id="6"/>
            <group layout="form" flat="true" id="15">

            <label text="X axis along path, Y axis up"/>
            <radiobutton text="" on-click="_S.path.align_callback" id="7"/>

            <label text="X axis along path, Z axis up"/>
            <radiobutton text="" on-click="_S.path.align_callback" id="8"/>

            <label text="Y axis along path, X axis up"/>
            <radiobutton text="" on-click="_S.path.align_callback" id="9"/>

            <label text="Y axis along path, Z axis up"/>
            <radiobutton text="" on-click="_S.path.align_callback" id="10"/>

            <label text="Z axis along path, X axis up"/>
            <radiobutton text="" on-click="_S.path.align_callback" id="11"/>

            <label text="Z axis along path, Y axis up"/>
            <radiobutton text="" on-click="_S.path.align_callback" id="12"/>
            
            <label text="Up vector"/>
            <edit on-editing-finished="_S.path.upVector_callback" id="13" />
            
            </group>

            <label text="Generate from data:" style="* {font-weight: bold;}"/>
            <group layout="vbox" flat="true">

            <edit id="20" />
            <button text="Generate from position data, i.e. x,y,z,..." on-click="_S.path.generate_callback" id="21"/>
            <button text="Generate from pose data, i.e. x,y,z,qx,qy,qz,qw,..." on-click="_S.path.generate_callback" id="22"/>
            
            </group>
    ]]
    _S.path.ui=_S.path.utils.createCustomUi(xml,sim.getObjectName(_S.path.model),_S.path.previousDlgPos,true,'_S.path.removeDlg',true,false,false,'enabled="'..tostring(simStopped)..'"')
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
        if sim.getObjectParent(h)==-1 then
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

function sysCall_afterDelete(inData)
    local update=false
    for key,value in pairs(inData.objectHandles) do
        if _S.path.ctrlPtsMap[key] then
            -- This ctrl point was erased. Update the path
            update=true
            break
        end
    end
    if update then
        _S.path.setup()
    end
end

_S.path={}

function _S.path.init()
    _S.path.utils=require('utils')
    _S.path.ctrlPtsTag='ABC_PATHCTRLPT'
    _S.path.pathObjectTag='ABC_PATH_INFO'
    _S.path.pathCreationTag='ABC_PATH_CREATION'
    _S.path.shapeTag='ABC_PATHSHAPE_INFO'
    _S.path.childTag='PATH_CHILD'
    _S.path.model=sim.getObjectHandle(sim.handle_self)
    _S.path.uniqueId=sim.getStringParameter(sim.stringparam_uniqueid)
    _S.path.refreshDelayInMs=300
    _S.path.lastRefreshTimeInMs=sim.getSystemTimeInMs(-1)
    _S.path.lineCont={-1,-1}
    _S.path.tickCont={-1,-1,-1}
    _S.path.createNewIfNeeded()
    _S.path.setup()
end

function _S.path.createNewIfNeeded()
    local data=sim.readCustomDataBlock(_S.path.model,_S.path.pathCreationTag)
    if data then
        data=sim.unpackTable(data)
        sim.writeCustomDataBlock(_S.path.model,_S.path.pathCreationTag,'')  
        _S.path.createNew(data[1],false,data[2],data[3],data[4],data[5],data[6]) 
    end
end

function _S.path.createNew(ctrlPts,onlyPosData,options,pointCount,smoothing,autoOrientationMode,upVector)
    local c=_S.path.readInfo()
    c.bitCoded=options
    c.pointCnt=pointCount
    c.smoothing=smoothing
    c.autoOrientation=autoOrientationMode
    c.upVector=upVector
    _S.path.writeInfo(c)
    local tmp1=sysCall_beforeCopy
    sysCall_beforeCopy=nil
    local tmp2=sysCall_afterCopy
    sysCall_afterCopy=nil
    local tmp3=sysCall_afterCreate
    sysCall_afterCreate=nil
    local tmp4=sysCall_afterDelete
    sysCall_afterDelete=nil

    local children=sim.getObjectsInTree(_S.path.model,sim.object_dummy_type,1)
    for i=1,#children,1 do
        sim.removeObject(children[i])
    end
    
    local dof=7
    if onlyPosData then
        dof=3
    end
    local function fp(p,i)
        return {p[dof*(i-1)+1],p[dof*(i-1)+2],p[dof*(i-1)+3]}
    end
    local function fq(p,i)
        return {p[7*(i-1)+4],p[7*(i-1)+5],p[7*(i-1)+6],p[7*(i-1)+7]}
    end
    for i=1,#ctrlPts//dof,1 do
        ctrlPt=sim.createDummy(0.01,{0,0.96,0.66,0,0,0,0,0,0,0,0,0})
        sim.setObjectParent(ctrlPt,_S.path.model,true)
        sim.setObjectPosition(ctrlPt,_S.path.model,fp(ctrlPts,i))
        _S.path.setObjectName(ctrlPt,'ctrlPt')
        if onlyPosData then
            sim.setObjectQuaternion(ctrlPt,_S.path.model,{0,0,0,1})
        else
            sim.setObjectQuaternion(ctrlPt,_S.path.model,fq(ctrlPts,i))
        end
        sim.writeCustomDataBlock(ctrlPt,_S.path.ctrlPtsTag,sim.packTable({index=i}))
    end
    
    sysCall_afterDelete=tmp4
    sysCall_afterCreate=tmp3
    sysCall_afterCopy=tmp2
    sysCall_beforeCopy=tmp1
end

function _S.path.cleanup()
    if _S.path.ui then
        simUI.destroy(_S.path.ui)
    end
end

function _S.path.nonSimulation()
    if not _S.path.refresh then
        if _S.path.getCtrlPtsPoseId()~=_S.path.ctrlPtsPoseId then
            _S.path.refresh=true
        end
    end
    if _S.path.refresh and sim.getSystemTimeInMs(_S.path.lastRefreshTimeInMs)>_S.path.refreshDelayInMs then
        _S.path.setup()
    end
end

function _S.path.afterSimulation()
    _S.path.displayLine(1)
    _S.path.displayLine(2)
    for i=1,#_S.path.ctrlPts,1 do
        local h=_S.path.ctrlPts[i].handle
        local r,v=sim.getObjectInt32Parameter(_S.path.model,sim.objintparam_visibility_layer)
        sim.setObjectInt32Parameter(h,sim.objintparam_visibility_layer,v)
    end
end

function _S.path.beforeSimulation()
    _S.path.removeLine(1)
    local c=_S.path.readInfo()
    if c.bitCoded&1~=0 then
        _S.path.removeLine(2)
    end
    for i=1,#_S.path.ctrlPts,1 do
        local h=_S.path.ctrlPts[i].handle
        sim.setObjectInt32Parameter(h,sim.objintparam_visibility_layer,0)
    end
end

function _S.path.getCtrlPtsPoseId()
    local p={}
    for i=1,#_S.path.ctrlPts,1 do
        local h=_S.path.ctrlPts[i].handle
        p[2*(i-1)+1]=sim.getObjectPosition(h,sim.handle_parent)
        p[2*(i-1)+2]=sim.getObjectQuaternion(h,sim.handle_parent)
    end
    return sim.packTable(p)
end

function _S.path.setObjectName(obj,name)
    local pathName=sim.getObjectName(_S.path.model)
    local base
    local hash=''
    local index=-1
    local p=string.find(pathName,'#%d')
    if p then
        base=pathName:sub(1,p-1)
        hash='#'
        index=math.floor(tonumber(pathName:sub(p+1)))
    else
        base=pathName
    end
    base=base..'__'..name
    local cnt=-1
    local newName
    while true do
        local nm=base
        if hash=='#' then
            if cnt>=0 then
                nm=nm..cnt
            end
            nm=nm..'#'..index
            newName=nm
            cnt=cnt+1
        else
            if index>=0 then
                nm=nm..index
            end
            newName=nm
            nm=nm..'#'
            index=index+1
        end
        if sim.getObjectHandle(nm..'@silentError')==-1 then
            break
        end
    end
    sim.setObjectName(obj,newName)
end

function _S.path.setup()
    _S.path.getCtrlPts()
    if #_S.path.ctrlPts>1 then
        local c=_S.path.readInfo()
        _S.path.computePaths()
        _S.path.removeLine(1)
        _S.path.removeLine(2)
        _S.path.displayLine(1)
        _S.path.displayLine(2)
        
        local shapes=sim.getObjectsInTree(_S.path.model,sim.object_shape_type,1+2)
        for i=1,#shapes,1 do
            local dat=sim.readCustomDataBlock(shapes[i],_S.path.shapeTag)
            if dat then
                sim.removeObject(shapes[i])
            end
        end
        if _S.path.shaping and (c.bitCoded&4)~=0 then
            local m=sim.getObjectMatrix(_S.path.model,-1)
            local s=_S.path.shaping(_S.path.paths[2],(c.bitCoded&2)~=0,{m[3],m[7],m[11]})
            if sim.isHandleValid(s)==1 then
                sim.writeCustomDataBlock(s,_S.path.shapeTag,"a")
                sim.setObjectParent(s,_S.path.model,false)
                local p=sim.getObjectProperty(s)
                sim.setObjectProperty(s,p|sim.objectproperty_selectmodelbaseinstead|sim.objectproperty_dontshowasinsidemodel)
                _S.path.setObjectName(s,'shape')
                sim.writeCustomDataBlock(s,_S.path.childTag,'s')
            end
        end
        
        _S.path.refresh=false
        _S.path.lastRefreshTimeInMs=sim.getSystemTimeInMs(-1)
    else
        _S.path.removeLine(1)
        _S.path.removeLine(2)
        sysCall_afterDelete=nil
        sysCall_beforeCopy=nil
        sysCall_afterCopy=nil
        sysCall_afterCreate=nil
        sim.removeModel(_S.path.model)
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
    
    local interpolatedPath1={}
   
    local function cb(a,b)
        return sim.getConfigDistance(a,b,{1,1,1,0,0,0,0})
    end
   
    local lengths1,totL=sim.getPathLengths(path,7,cb)

    
    local ptCnt=c.pointCnt*2
    for i=1,ptCnt,1 do
        local pp
        local t=(i-1)*totL/(ptCnt-1)
        if c.smoothing==0 then
            pp=sim.getPathInterpolatedConfig(path,lengths1,t,nil,{0,0,0,2,2,2,2})
        else
            pp=sim.getPathInterpolatedConfig(path,lengths1,t,{type='quadraticBezier',forceOpen=false,strength=c.smoothing},{0,0,0,2,2,2,2})
        end
        for j=1,#pp,1 do
            interpolatedPath1[(i-1)*7+j]=pp[j]
        end
    end

    local interpolatedPath2={}
    local lengths2,totL=sim.getPathLengths(interpolatedPath1,7,cb)
    local ptCnt=c.pointCnt
    for i=1,ptCnt,1 do
        local t=(i-1)*totL/(ptCnt-1)
        local pp=sim.getPathInterpolatedConfig(interpolatedPath1,lengths2,t,nil,{0,0,0,2,2,2,2})
        for j=1,#pp,1 do
            interpolatedPath2[(i-1)*7+j]=pp[j]
        end
    end
    interpolatedPath2=_S.path.recomputeOrientations(interpolatedPath2)
    _S.path.paths={}
    _S.path.paths[1]=path
    _S.path.paths[2]=interpolatedPath2
    
    if (c.bitCoded & 2)~=0 then
        -- path is closed. Remove the last pose for storage
        handles[#handles+1]=handles[1]
    end
    
    sim.writeCustomDataBlock(_S.path.model,'PATHCTRLPTS',sim.packDoubleTable(path,0,#path-7)) -- last pose is coincident if path is closed
    sim.writeCustomDataBlock(_S.path.model,'PATH',sim.packDoubleTable(interpolatedPath2))
end

function _S.path.displayLine(index)
    _S.path.removeLine(index)
    local r,v=sim.getObjectInt32Parameter(_S.path.model,sim.objintparam_visibility_layer)
    local l=sim.getInt32Parameter(sim.intparam_visible_layers)
    local p=sim.getModelProperty(_S.path.model)
    if (p&sim.modelproperty_not_visible)==0 and v&l>0 then
        local c=_S.path.readInfo()
        local m=sim.getObjectMatrix(_S.path.model,-1)
        local path=_S.path.paths[index]
        local dr,col,s
        if index==1 then
            col={c.line.color[1]*1.2,c.line.color[2]*1.2,c.line.color[3]*1.2}
            s=1
        else
            col=c.line.color
            s=c.line.thickness
        end
        _S.path.lineCont[index]=sim.addDrawingObject(sim.drawing_lines,s,0,_S.path.model,9999,col)
        local cont=_S.path.lineCont[index]
        for i=0,(#path/7)-2,1 do
            local p1={path[i*7+1],path[i*7+2],path[i*7+3]}
            local p2={path[(i+1)*7+1],path[(i+1)*7+2],path[(i+1)*7+3]}
            p1=sim.multiplyVector(m,p1)
            p2=sim.multiplyVector(m,p2)
            local l={p1[1],p1[2],p1[3],p2[1],p2[2],p2[3]}
            sim.addDrawingObjectItem(cont,l)
        end
        if index==2 and (c.bitCoded&8)~=0 then
            _S.path.tickCont[1]=sim.addDrawingObject(sim.drawing_lines,1,0,_S.path.model,9999,{1,0,0})
            _S.path.tickCont[2]=sim.addDrawingObject(sim.drawing_lines,1,0,_S.path.model,9999,{0,1,0})
            _S.path.tickCont[3]=sim.addDrawingObject(sim.drawing_lines,1,0,_S.path.model,9999,{0,0,1})
            local p=sim.getObjectPosition(_S.path.model,-1)
            local q=sim.getObjectQuaternion(_S.path.model,-1)
            local m=Matrix4x4:frompose({p[1],p[2],p[3],q[1],q[2],q[3],q[4]})
            for i=0,(#path/7)-1,1 do
                local m0=Matrix4x4:frompose({path[i*7+1],path[i*7+2],path[i*7+3],path[i*7+4],path[i*7+5],path[i*7+6],path[i*7+7]})
                m0=m*m0
                local p2=m0*Vector({_S.path.ctrlPtsSize,0,0,1})
                local l={m0[1][4],m0[2][4],m0[3][4],p2[1],p2[2],p2[3]}
                sim.addDrawingObjectItem(_S.path.tickCont[1],l)
                local p2=m0*Vector({0,_S.path.ctrlPtsSize,0,1})
                local l={m0[1][4],m0[2][4],m0[3][4],p2[1],p2[2],p2[3]}
                sim.addDrawingObjectItem(_S.path.tickCont[2],l)
                local p2=m0*Vector({0,0,_S.path.ctrlPtsSize,1})
                local l={m0[1][4],m0[2][4],m0[3][4],p2[1],p2[2],p2[3]}
                sim.addDrawingObjectItem(_S.path.tickCont[3],l)
            end
        end
    end
end

function _S.path.removeLine(index)
    if _S.path.lineCont and _S.path.lineCont[index]~=-1 then
        sim.removeDrawingObject(_S.path.lineCont[index])
        _S.path.lineCont[index]=-1
        if index==2 and _S.path.tickCont[1]~=-1 then
            for i=1,3,1 do
                sim.removeDrawingObject(_S.path.tickCont[i])
                _S.path.tickCont[i]=-1
            end
        end
    end
end

function _S.path.getCtrlPts()
    local d=sim.getObjectsInTree(_S.path.model,sim.object_dummy_type,1)
    local pts={}
    local map={}
    for i=1,#d,1 do
        local h=d[i]
        local dat=sim.readCustomDataBlock(h,_S.path.ctrlPtsTag)
        if dat and #dat>0 then
            dat=sim.unpackTable(dat)
            dat.handle=h
            sim.writeCustomDataBlock(h,_S.path.childTag,'p')
        end
        if dat then
            pts[#pts+1]=dat
            map[dat.handle]=true
        end
    end
    table.sort(pts,function(a,b) return a.index<b.index end)
    
    local r,v=sim.getObjectInt32Parameter(_S.path.model,sim.objintparam_visibility_layer)
    
    local _max={-999,-999,-999}
    local _min={999,999,999}
    for i=1,#pts,1 do
        pts[i].index=i -- indices could be fractions and/or not contiguous
        sim.writeCustomDataBlock(pts[i].handle,_S.path.ctrlPtsTag,sim.packTable(pts[i]))
        sim.setObjectInt32Parameter(pts[i].handle,sim.objintparam_visibility_layer,v)
        local p=sim.getObjectPosition(pts[i].handle,_S.path.model)
        for j=1,3,1 do
            _max[j]=math.max(_max[j],p[j])
            _min[j]=math.min(_min[j],p[j])
        end
    end
    _S.path.ctrlPtsSize=math.max(_max[1]-_min[1],math.max(_max[2]-_min[2],_max[3]-_min[3]))/75
    for i=1,#pts,1 do
        sim.setObjectFloatParameter(pts[i].handle,sim.dummyfloatparam_size,_S.path.ctrlPtsSize)
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
        simUI.setCheckboxValue(_S.path.ui,1,((config.bitCoded & 2)==0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui,2,((config.bitCoded & 1)==0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui,3,((config.bitCoded & 4)==0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui,14,((config.bitCoded & 8)==0 and 0 or 2))
        simUI.setEditValue(_S.path.ui,4,string.format("%.2f",config.smoothing),true)
        simUI.setEditValue(_S.path.ui,5,tostring(config.pointCnt),true)
        
        simUI.setCheckboxValue(_S.path.ui,6,((config.bitCoded & 16)==0 and 0 or 2))
        simUI.setEnabled(_S.path.ui,15,(config.bitCoded & 16)~=0)
        simUI.setRadiobuttonValue(_S.path.ui,7,(config.autoOrientation==0 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui,8,(config.autoOrientation==1 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui,9,(config.autoOrientation==2 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui,10,(config.autoOrientation==3 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui,11,(config.autoOrientation==4 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui,12,(config.autoOrientation==5 and 1 or 0))
        simUI.setEditValue(_S.path.ui,13,string.format("%.2f, %.2f, %.2f",config.upVector[1],config.upVector[2],config.upVector[3]),true)
        simUI.setCurrentEditWidget(_S.path.ui,sel)
    end
end

function _S.path.getDefaultInfoForNonExistingFields(info)
    if not info.bitCoded then
        info.bitCoded=1 -- 1=show line during simulation, 2=closed, 4=generate shape, 8=show orientation frames, 16=auto orientation
    end
    if not info.autoOrientation then
        info.autoOrientation=0 -- 0=x along path, y up, 1=x along path, z up, 2=y along path, x up, etc.
    end
    if not info.pointCnt then
        info.pointCnt=200
    end
    if not info.smoothing then
        info.smoothing=1
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
    if not info.upVector then
        info.upVector={0,0,1}
    end
end

function _S.path.readInfo()
    local data=sim.readCustomDataBlock(_S.path.model,_S.path.pathObjectTag)
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
        sim.writeCustomDataBlock(_S.path.model,_S.path.pathObjectTag,sim.packTable(data))
    else
        sim.writeCustomDataBlock(_S.path.model,_S.path.pathObjectTag,'')
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

function _S.path.generateShape_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    c.bitCoded=(c.bitCoded | 4)
    if newVal==0 then
        c.bitCoded=c.bitCoded-4
    end
    _S.path.writeInfo(c)
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.hideDuringSimulation_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    c.bitCoded=(c.bitCoded | 1)
    if newVal==0 then
        c.bitCoded=c.bitCoded-1
    end
    _S.path.writeInfo(c)
    sim.announceSceneContentChange()
end

function _S.path.showOrientation_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    c.bitCoded=(c.bitCoded | 8)
    if newVal==0 then
        c.bitCoded=c.bitCoded-8
    end
    _S.path.writeInfo(c)
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.smoothness_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    local l=tonumber(newVal)
    if l then
        if l<0.05 then l=0 end
        if l>1 then l=1 end
        if l~=c.smoothing then
            c.smoothing=l
            _S.path.writeInfo(c)
            _S.path.setup()
            sim.announceSceneContentChange()
        end
    end
    _S.path.setDlgItemContent()
end

function _S.path.pointCnt_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    local l=tonumber(newVal)
    if l then
        if l<10 then l=10 end
        if l>1000 then l=1000 end
        if l~=c.pointCnt then
            c.pointCnt=l
            _S.path.writeInfo(c)
            _S.path.setup()
            sim.announceSceneContentChange()
        end
    end
    _S.path.setDlgItemContent()
end

function _S.path.upVector_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    local i=1
    local t={0,0,0}
    for token in (newVal..","):gmatch("([^,]*),") do
        t[i]=tonumber(token)
        if t[i]==nil then t[i]=0 end
        i=i+1
    end
    if t[1]~=0 or t[2]~=0 or t[3]~=0 then
        t=Vector(t):normalized():data()
        c.upVector=t
        _S.path.writeInfo(c)
        _S.path.setup()
        sim.announceSceneContentChange()
    end
    _S.path.setDlgItemContent()
end

function _S.path.autoOrient_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    c.bitCoded=(c.bitCoded | 16)
    if newVal==0 then
        c.bitCoded=c.bitCoded-16
    end
    _S.path.writeInfo(c)
    _S.path.setDlgItemContent()
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.align_callback(ui,id,newVal)
    local c=_S.path.readInfo()
    local zvect=Vector3(c.upVector)
    c.autoOrientation=id-7
    _S.path.writeInfo(c)
    _S.path.setDlgItemContent()
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.generate_callback(ui,id,newVal)
    local txt=simUI.getEditValue(ui,20)
    local v={}
    local i=1
    local err=false
    for token in (txt..","):gmatch("([^,]*),") do
        v[i]=tonumber(token)
        if v[i]==nil then
            err=true
            break
        end
        i=i+1
    end
    if not err then
        local c=_S.path.readInfo()
        if id==21 then
            if #v>=6 and 3*#v//3==#v then
                _S.path.createNew(v,true,c.bitCoded,c.pointCnt,c.smoothing,c.autoOrientation,c.upVector)
                _S.path.setup()
            else
                sim.addLog(sim.verbosity_scriptwarnings,'Provided value count is invalid')
            end
        else
            if #v>=14 and 7*#v//7==#v then
                _S.path.createNew(v,false,c.bitCoded,c.pointCnt,c.smoothing,c.autoOrientation,c.upVector)
                _S.path.setup()
            else
                sim.addLog(sim.verbosity_scriptwarnings,'Provided value count is invalid')
            end
        end
    else
        sim.addLog(sim.verbosity_scriptwarnings,'Provided data is invalid')
    end
end

function _S.path.recomputeOrientations(path)
    local c=_S.path.readInfo()
    if (c.bitCoded&16)~=0 then
        local zvect=Vector3(c.upVector)
        local mppath=Matrix(#path//7,7,path)
        mppath=mppath:slice(1,1,mppath:rows(),3)
        local retPath=Matrix(mppath:rows(),7)
        for i=1,mppath:rows(),1 do
            local p0,p1,p2
            if i~=1 then
                p0=Vector3(mppath[i-1])
            else
                if (c.bitCoded&2)~=0 then
                    p0=Vector3(mppath[mppath:rows()-1])
                end
            end
            p1=Vector3(mppath[i+0])
            if i~=mppath:rows() then
                p2=Vector3(mppath[i+1])
            else
                if (c.bitCoded&2)~=0 then
                    p2=Vector3(mppath[2])
                end
            end
            local vf
            if p0 and p2 then
                vf=(p1-p0)+(p2-p1)
            else
                if i==1 then
                    vf=(p2-p1)
                else
                    vf=(p1-p0)
                end
            end
            vf=vf/vf:norm()
            local vr=vf:cross(zvect)
            vr=vr/vr:norm()
            
            local m
            if c.autoOrientation==0 then
                m=vf
                m=m:horzcat(vr:cross(vf))
                m=m:horzcat(vr)
            end
            if c.autoOrientation==1 then
                m=vf
                m=m:horzcat(vr*-1)
                m=m:horzcat(vf:cross(vr*-1))
            end
            if c.autoOrientation==2 then
                m=vr:cross(vf)
                m=m:horzcat(vf)
                m=m:horzcat(vr*-1)
            end
            if c.autoOrientation==3 then
                m=vr
                m=m:horzcat(vf)
                m=m:horzcat(vr:cross(vf))
            end
            if c.autoOrientation==4 then
                m=vr:cross(vf)
                m=m:horzcat(vr)
                m=m:horzcat(vf)
            end
            if c.autoOrientation==5 then
                m=vr*-1
                m=m:horzcat(vr:cross(vf))
                m=m:horzcat(vf)
            end
            m=Matrix4x4:fromrotation(m)
            m[1][4]=p1[1]
            m[2][4]=p1[2]
            m[3][4]=p1[3]
            retPath[i]=Matrix4x4:topose(m)
        end
        path=retPath:data()
    end
    return path
end

return _S.path