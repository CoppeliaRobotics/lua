-- tools lazy loader

return setmetatable(
    {},
    {
        __index = function(self, k)
            return require('utils.' .. k)
        end,
        __todisplay = function()
            return 'usage: utils.<toolname>(...)\n\ne.g.: utils.unittest(table)\n'
        end,
    }
)
