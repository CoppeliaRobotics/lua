local sim = table.update({}, require 'sim')

removeLazyLoaders()

require('sim.Object').extend(sim)

sim.addLog(sim.verbosity_warnings, 'sim-2 has been loaded')

return sim
