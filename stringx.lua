function string.gsplit(text,pattern,plain)
    local splitStart,length=1,#text
    return function()
        if splitStart then
            local sepStart,sepEnd=string.find(text,pattern,splitStart,plain)
            local ret
            if not sepStart then
                ret=string.sub(text,splitStart)
                splitStart=nil
            elseif sepEnd<sepStart then
                -- empty separator
                ret=string.sub(text,splitStart,sepStart)
                if sepStart<length then
                    splitStart=sepStart+1
                else
                    splitStart=nil
                end
            else
                ret=sepStart>splitStart and string.sub(text,splitStart,sepStart-1) or ''
                splitStart=sepEnd+1
            end
            return ret
        end
    end
end

function string.split(text,pattern,plain)
    local ret={}
    for match in string.gsplit(text,pattern,plain) do
        table.insert(ret,match)
    end
    return ret
end

function string.startswith(s,prefix)
    return s:sub(1,#prefix)==prefix
end

function string.endswith(s,suffix)
    return ending=='' or s:sub(-#suffix)==suffix
end

if arg and #arg==1 and arg[1]=='test' then
    require'tablex'
    assert(table.eq(string.split('a%b%c','%',true),{'a','b','c'}))
    assert(table.eq(string.split('a','%',true),{'a'}))
    assert(table.eq(string.split('a%','%',true),{'a',''}))
    assert(table.eq(string.split('a%--b','%-',true),{'a','-b'}))
    assert(string.startswith('abcde','abc'))
    assert(string.startswith('abc','abc'))
    assert(not string.startswith('bcde','abc'))
    assert(string.endswith('abcde','cde'))
    assert(string.endswith('abc','abc'))
    assert(not string.endswith('bcde','bcd'))
    print(debug.getinfo(1,'S').source,'tests passed')
end
