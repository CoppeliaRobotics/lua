require'configUi-common'
local backend=sim.getNamedStringParam('configUi.backend') or sim.getSettingString('configUi.backend') or 'simUI'
if not (backend=='simQML' or backend=='simUI') then
    error('invalid backend: '..backend)
end
require(string.format('configUi-%s',backend))
