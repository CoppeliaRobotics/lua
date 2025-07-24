local codeEditorInfos = require('sim-ce-x')

local sim2Specific = [[
sim.initScript(int scriptHandle = sim.handle_self)
sim.addForce(int shapeHandle, vector3 position, vector3 force)
sim.addForceAndTorque(int shapeHandle, vector3 force = {0.0, 0.0, 0.0}, vector3 torque = {0.0, 0.0, 0.0})
]]

registerCodeEditorInfos("sim-2", codeEditorInfos .. sim2Specific)
