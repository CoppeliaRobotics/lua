return function(b)
    local simSubprocess = require 'simSubprocess'
    local ok, ec, out = pcall(simSubprocess.exec, 'cbor2pretty.rb', {}, b)
    if not ok then
        local sim = require 'sim'
        sim.addLog(sim.verbosity_errors, ec)
        sim.addLog(sim.verbosity_errors, 'cbor2pretty.rb not found. install with: gem install --user-install cbor-diag')
    elseif ec ~= 0 then
        sim.addLog(sim.verbosity_errors, 'cbor2pretty.rb failed: exit code ' .. ec)
    else
        print(out)
    end
end
