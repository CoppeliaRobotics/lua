return function(mod, modName)
    if type(mod) == 'string' then
        modName = mod
        mod = require(modName)
    end
    local tmp = sim.getStringProperty(sim.handle_app, 'tempPath')
    local defaults = require 'luacov.defaults'
    defaults.statsfile = tmp .. '/luacov.stats.out'
    defaults.reportfile = tmp .. '/luacov.report.html'
    defaults.reporter = 'html'
    local runner = require 'luacov.runner'
    local runnercfg = {include = {modName, modName .. '/.+'}}
    printf('luacov runner config: %s', runnercfg)
    runner(runnercfg)
    utils.unittest(mod)
    local reporter = require('luacov.reporter.' .. defaults.reporter)
    reporter.report()
    printf('Report file: %s', defaults.reportfile)
    local platform = sim.getIntProperty(sim.handle_app, 'platform')
    local openprg = ({[1] = 'open', [2] = 'xdg-open'})[platform]
    if openprg then
        local simSubprocess = require 'simSubprocess'
        simSubprocess.exec(openprg, {defaults.reportfile})
    end
end
