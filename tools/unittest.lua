return function(mod)
    if mod.unittest == nil then
        print('module does not define a unittest() function')
        return
    end
    if type(mod.unittest) == 'function' then
        mod.unittest()
    end
end
