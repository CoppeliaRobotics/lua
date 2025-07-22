local codeEditorInfos = require('sim-ce-x')

local sim2Specific = [[
sim.initScript(int scriptHandle = sim.handle_self)
]]

registerCodeEditorInfos("sim-2", codeEditorInfos .. sim2Specific)
