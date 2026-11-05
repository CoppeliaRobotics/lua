local sim = require 'sim-1'
sim.addLog(sim.verbosity_warnings | sim.verbosity_once, 'simCBOR is deprecated. use sim.cbor')
return require 'sim.cbor'
