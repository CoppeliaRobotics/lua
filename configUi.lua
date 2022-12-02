require'configUi-common'
local backend=sim.getNamedStringParam('configUi.backend') or sim.getSettingString('configUi.backend') or 'simUI'
if backend=='simQML' then
    require'configUi-simQML'
elseif backend=='simUI' then
    require'configUi-simUI'
else
    error('invalid backend: '..backend)
end