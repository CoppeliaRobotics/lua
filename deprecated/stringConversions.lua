function _S.tableToString(x, opts)
    local sim = require 'sim-1'
    sim.addLog(sim.verbosity_warnings | sim.verbosity_once, '_S.tableToString is deprecated. use table.tostring')
    return table.tostring(x, opts)
end

function _S.anyToString(x, opts)
    local sim = require 'sim-1'
    sim.addLog(sim.verbosity_warnings | sim.verbosity_once, '_S.anyToString is deprecated. use string.anytostring')
    return string.anytostring(x, opts)
end

function _S.numberToString(x, opts)
    local sim = require 'sim-1'
    sim.addLog(sim.verbosity_warnings | sim.verbosity_once, '_S.numberToString is deprecated. use string.numbertostring')
    return string.numbertostring(x, opts)
end

function _S.getShortString(x, opts)
    local sim = require 'sim-1'
    sim.addLog(sim.verbosity_warnings | sim.verbosity_once, '_S.getShortString is deprecated. use string.getshortstring')
    return string.getshortstring(x, opts)
end

function _S.isIdentifier(x)
    local sim = require 'sim-1'
    sim.addLog(sim.verbosity_warnings | sim.verbosity_once, '_S.isIdentifier is deprecated. use string.isidentifier')
    return string.isidentifier(x)
end

function _S.tableKeyToString(x)
    local sim = require 'sim-1'
    sim.addLog(sim.verbosity_warnings | sim.verbosity_once, '_S.tableKeyToString is deprecated')
    error 'not implemented'
end
