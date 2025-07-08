-- tools lazy loader

return setmetatable(
    {},
    {
        __index = function(self, k)
            return require('tools.' .. k)
        end,
        __todisplay = function()
            return 'usage: tools.<toolname>(...)\n\ne.g.: tools.unittest(table)\n'
        end,
    }
)
