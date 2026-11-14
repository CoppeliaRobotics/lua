local codeEditorInfos = [[
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

sim.app
sim.scene
sim.self

sim.Vector
sim.Matrix
sim.Quaternion
sim.Pose

sim.appFlavor
sim.appFlavor.edu
sim.appFlavor.lite
sim.appFlavor.pro

sim.forceSensorFilter
sim.forceSensorFilter.average
sim.forceSensorFilter.median

sim.handle
sim.handle.all
sim.handle.app
sim.handle.scene
sim.handle.self

sim.headlessMode
sim.headlessMode.disabled
sim.headlessMode.emulated
sim.headlessMode.enabled

sim.jointDynamicsCtrlMode
sim.jointDynamicsCtrlMode.free
sim.jointDynamicsCtrlMode.force
sim.jointDynamicsCtrlMode.position
sim.jointDynamicsCtrlMode.velocity
sim.jointDynamicsCtrlMode.spring
sim.jointDynamicsCtrlMode.custom

sim.jointMode
sim.jointMode.dependent
sim.jointMode.dynamic
sim.jointMode.kinematic

sim.physicsEngine
sim.physicsEngine.bullet
sim.physicsEngine.drake
sim.physicsEngine.mujoco
sim.physicsEngine.newton
sim.physicsEngine.ode
sim.physicsEngine.vortex

sim.platform
sim.platform.linux
sim.platform.macos
sim.platform.windows

sim.primitiveType
sim.primitiveType.capsule
sim.primitiveType.cone
sim.primitiveType.cuboid
sim.primitiveType.cylinder
sim.primitiveType.disc
sim.primitiveType.heightfield
sim.primitiveType.none
sim.primitiveType.plane
sim.primitiveType.spheroid

sim.renderMode
sim.renderMode.openGl
sim.renderMode.colorCoded
sim.renderMode.openGl3
sim.renderMode.openGl3ColorCoded
sim.renderMode.povray

sim.scriptExecOrder
sim.scriptExecOrder.first
sim.scriptExecOrder.last
sim.scriptExecOrder.normal

sim.scriptState
sim.scriptState.ended
sim.scriptState.initialized
sim.scriptState.suspended
sim.scriptState.unloaded

sim.simulationState
sim.simulationState.lastBeforeStop
sim.simulationState.paused
sim.simulationState.running
sim.simulationState.stopped

sim.stringType
sim.stringType.binary
sim.stringType.buffer
sim.stringType.text

sim.textureApplyMode
sim.textureApplyMode.add
sim.textureApplyMode.decal
sim.textureApplyMode.modulate

sim.verbosity
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

sim.jointType
sim.jointType.prismatic
sim.jointType.revolute
sim.jointType.spherical

sim.lightType
sim.lightType.omnidirection
sim.lightType.spot
sim.lightType.directional

sim.dummyType
sim.dummyType.dynLoopClosure
sim.dummyType.dynTendon
sim.dummyType.neutral
sim.dummyType.assembly

sim.proximitySensorType
sim.proximitySensorType.pyramid
sim.proximitySensorType.cylinder
sim.proximitySensorType.disc
sim.proximitySensorType.cone
sim.proximitySensorType.ray

sim.shapeType
sim.shapeType.simple
sim.shapeType.compound

sim.bulletConstrSolverType
sim.bulletConstrSolverType.dantzig
sim.bulletConstrSolverType.nncg
sim.bulletConstrSolverType.projectedGaussSeidel
sim.bulletConstrSolverType.sequentialImpulse

sim.vortexBodyFrictionModel
sim.vortexBodyFrictionModel.box
sim.vortexBodyFrictionModel.scaledBox
sim.vortexBodyFrictionModel.propLow
sim.vortexBodyFrictionModel.propHigh
sim.vortexBodyFrictionModel.scaledBoxFast
sim.vortexBodyFrictionModel.neutral
sim.vortexBodyFrictionModel.none

sim.propertyInfoFlags
sim.propertyInfoFlags.notWritable
sim.propertyInfoFlags.notReadable
sim.propertyInfoFlags.removable
sim.propertyInfoFlags.modelHashExclude
sim.propertyInfoFlags.deprecated
sim.propertyInfoFlags.silent
sim.propertyInfoFlags.constant
sim.propertyInfoFlags.largeData
sim.propertyInfoFlags.retMethodsOnly

sim.propertyType
sim.propertyType.boolean
sim.propertyType.int32
sim.propertyType.real
sim.propertyType.string
sim.propertyType.buffer
sim.propertyType.vector3
sim.propertyType.quaternion
sim.propertyType.pose
sim.propertyType.color3
sim.propertyType.realArray
sim.propertyType.table
sim.propertyType.int32Array
sim.propertyType.int32Array2
sim.propertyType.int64Array
sim.propertyType.int64
sim.propertyType.null
sim.propertyType.matrix
sim.propertyType.array
sim.propertyType.map
sim.propertyType.handle
sim.propertyType.handleArray
sim.propertyType.stringArray
sim.propertyType.group
sim.propertyType.enumeration
sim.propertyType.color
sim.propertyType.method

sim.ruckig
sim.ruckig.noSync
sim.ruckig.phaseSync
sim.ruckig.timeSync

sim.markerOptions
sim.markerOptions.local
sim.markerOptions.cyclic
sim.markerOptions.overlay
sim.markerOptions.notShaded

sim.markerType
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
