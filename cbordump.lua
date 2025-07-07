return function(b)
    local simSubprocess = require 'simSubprocess'
    local ec, out = simSubprocess.exec('cbor2pretty.rb', {}, b)
    if ec == 0 then
        print(out)
    else
        error 'cbor2pretty.rb not found'
    end
end
