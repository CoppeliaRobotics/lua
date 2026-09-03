-- this module is the one autoloaded (when using sim.xxx without explicit require)
print'sim-autoload'
local sim = require 'sim-1'
require 'deprecated.matrixLazyLoaders'
return sim
