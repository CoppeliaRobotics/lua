local codeEditorInfos = [[
sim.app
sim.scene
sim.self

sim.appFlavor.edu
sim.appFlavor.lite
sim.appFlavor.pro

sim.bullet_constraintsolvertype_dantzig
sim.bullet_constraintsolvertype_nncg
sim.bullet_constraintsolvertype_projectedgaussseidel
sim.bullet_constraintsolvertype_sequentialimpulse

sim.vortex_bodyfrictionmodel_box
sim.vortex_bodyfrictionmodel_neutral
sim.vortex_bodyfrictionmodel_none
sim.vortex_bodyfrictionmodel_prophigh
sim.vortex_bodyfrictionmodel_proplow
sim.vortex_bodyfrictionmodel_scaledbox
sim.vortex_bodyfrictionmodel_scaledboxfast

sim.forceSensorFilter.average
sim.forceSensorFilter.median

sim.handle.all

sim.headlessMode.disabled
sim.headlessMode.emulated
sim.headlessMode.enabled

sim.jointDynamicsCtrlMode.free
sim.jointDynamicsCtrlMode.force
sim.jointDynamicsCtrlMode.position
sim.jointDynamicsCtrlMode.velocity
sim.jointDynamicsCtrlMode.spring
sim.jointDynamicsCtrlMode.custom

sim.jointMode.dependent
sim.jointMode.dynamic
sim.jointMode.kinematic

sim.physicsEngine.bullet
sim.physicsEngine.drake
sim.physicsEngine.mujoco
sim.physicsEngine.newton
sim.physicsEngine.ode
sim.physicsEngine.vortex

sim.platform.linux
sim.platform.macos
sim.platform.windows

sim.primitiveType.capsule
sim.primitiveType.cone
sim.primitiveType.cuboid
sim.primitiveType.cylinder
sim.primitiveType.disc
sim.primitiveType.heightfield
sim.primitiveType.none
sim.primitiveType.plane
sim.primitiveType.spheroid

sim.renderMode.codedImg
sim.renderMode.colorCoded
sim.renderMode.extRenderer
sim.renderMode.oglImg
sim.renderMode.openGl
sim.renderMode.openGl3
sim.renderMode.povray

sim.scriptExecOrder.first
sim.scriptExecOrder.last
sim.scriptExecOrder.normal

sim.scriptState.ended
sim.scriptState.error
sim.scriptState.initialized
sim.scriptState.suspended
sim.scriptState.uninitialized
sim.scriptState.unloaded

sim.simulationState.lastBeforeStop
sim.simulationState.paused
sim.simulationState.running
sim.simulationState.stopped

sim.stringType.binary
sim.stringType.buffer
sim.stringType.text

sim.textureApplyMode.add
sim.textureApplyMode.decal
sim.textureApplyMode.modulate

sim.verbosity.debug
sim.verbosity.errors
sim.verbosity.infos
sim.verbosity.loadInfos
sim.verbosity.none
sim.verbosity.questions
sim.verbosity.scriptErrors
sim.verbosity.scriptInfos
sim.verbosity.scriptWarnings
sim.verbosity.traceAll
sim.verbosity.traceLua
sim.verbosity.useGlobal
sim.verbosity.warnings


sim.propertyinfo_constant
sim.propertyinfo_deprecated
sim.propertyinfo_largedata
sim.propertyinfo_modelhashexclude
sim.propertyinfo_notreadable
sim.propertyinfo_notwritable
sim.propertyinfo_removable
sim.propertyinfo_silent

sim.propertytype_array
sim.propertytype_bool
sim.propertytype_buffer
sim.propertytype_color
sim.propertytype_color3
sim.propertytype_enum
sim.propertytype_float
sim.propertytype_floatarray
sim.propertytype_group
sim.propertytype_handle
sim.propertytype_handlearray
sim.propertytype_int
sim.propertytype_intarray
sim.propertytype_intarray2
sim.propertytype_long
sim.propertytype_map
sim.propertytype_matrix
sim.propertytype_method
sim.propertytype_null
sim.propertytype_object
sim.propertytype_objectarray
sim.propertytype_objectmap
sim.propertytype_pose
sim.propertytype_quaternion
sim.propertytype_string
sim.propertytype_stringarray
sim.propertytype_table
sim.propertytype_vector3

sim.syscb_actuation
sim.syscb_aftercopy
sim.syscb_aftercreate
sim.syscb_afterdelete
sim.syscb_afterinstanceswitch
sim.syscb_aftersimulation
sim.syscb_aos_resume
sim.syscb_aos_suspend
sim.syscb_beforecopy
sim.syscb_beforedelete
sim.syscb_beforeinstanceswitch
sim.syscb_beforemainscript
sim.syscb_beforesimulation
sim.syscb_cleanup
sim.syscb_contact
sim.syscb_data
sim.syscb_dyn
sim.syscb_init
sim.syscb_joint
sim.syscb_moduleentry
sim.syscb_nonsimulation
sim.syscb_resume
sim.syscb_selchange
sim.syscb_sensing
sim.syscb_suspend
sim.syscb_suspended
sim.syscb_thread
sim.syscb_trigger
sim.syscb_userconfig
sim.syscb_vision


sim.ruckig_nosync
sim.ruckig_phasesync
sim.ruckig_timesync

sim.markerType.axes
sim.markerType.cubes
sim.markerType.custom
sim.markerType.cylinders
sim.markerType.discs
sim.markerType.lines
sim.markerType.points
sim.markerType.spheres
sim.markerType.squares
sim.markerType.triangles
sim.markerType.tubes

]]

registerCodeEditorInfos("sim-2", codeEditorInfos)
