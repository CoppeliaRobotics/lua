socket = require 'socket'

package.preload.sim = function() end
require 'actionServer-1'
require 'actions.wait-1'

package.path = package.cpath .. package.config:sub(3,3) .. '../../../lua/?.lua'
require 'tablex'

sim = {getSystemTime = os.time}
function sleep(tsec) socket.select(nil, nil, tsec) end

actionServer = ActionServer{hook_sysCall_actuation = false}
events = {}
actionServer:addListener('statusChanged', function(event, id)
    local event = id .. actionServer:getStatus(id):sub(1, 2)
    table.insert(events, event)
end)
actionServer:send('wait', {duration = 1})
id2 = actionServer:send('wait', {duration = 100})
id3 = actionServer:send('wait', {duration = 100})

actionServer:cancel(id2)

t0 = sim.getSystemTime()

while (sim.getSystemTime() - t0) < 3 do
    sleep(0.1)
    actionServer:tick()
end

actionServer:cancel(id3)
actionServer:tick()

local expected = {'1ac', '2ac', '3ac', '2ca', '1ex', '1su', '3ex', '3ca'}
assert(table.eq(events, expected))
print('ActionServer tests passed')
