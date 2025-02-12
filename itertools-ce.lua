registerCodeEditorInfos('itertools', [[
function chainedIter = itertools.chain(function i1, function i2, ...)
function chainedIter = itertools.ichain(function i1, function i2, ...)
table p = itertools.product(table table_of_tables)
table p = itertools.permutations(table t, int length)
table p = itertools.combinations(table t, int length)
table p = itertools.combinations_with_replacement(table t, int length)
]])
