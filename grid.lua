Grid={}

function Grid:dims()
    return self._dims
end

function Grid:stride(dim)
    if dim>=#self._dims then return 1 end
    return self._dims[dim+1]*self:stride(dim+1)
end

function Grid:offset(index)
    assert(#index==#self._dims,'invalid index length')
    local offset=1
    for i=1,#index do offset=offset+(index[i]-1)*self:stride(i) end
    return offset
end

function Grid:get(index)
    return self._data[self:offset(index)]
end

function Grid:set(index,value)
    self._data[self:offset(index)]=value
end

function Grid:project(dim,val)
    local otherDims={}
    for i=1,#self._dims do
        if i~=dim then
            table.insert(otherDims,self._dims[i])
        end
    end
    -- TODO:
    error('not implemented')
end

function Grid:addk(k)
    local data={}
    for i,x in ipairs(self._data) do
        table.insert(data,x+k)
    end
    return Grid:new(self._dims,data)
end

function Grid:mulk(k)
    local data={}
    for i,x in ipairs(self._data) do
        table.insert(data,x*k)
    end
    return Grid:new(self._dims,data)
end

function Grid:add(m)
    assert(self._dims==m._dims,'shape mismatch')
    for i=1,#self._dims do assert(self._dims[i]==m._dims[i],'shape mismatch') end
    local data={}
    for i=1,#self._data do
        table.insert(data,self._data[i]+m._data[i])
    end
    return Grid:new(self._dims,data)
end

function Grid:__tostring()
    s='Grid({'
    for i=1,#self._dims do
        s=s..(i==1 and '' or ',')..self._dims[i]
    end
    s=s..'},{'
    for i=1,#self._data do
        s=s..(i==1 and '' or ',')..self._data[i]
    end
    s=s..'})'
    return s
end

function Grid:__index(k)
    return Grid[k]
end

function Grid.__add(a,b)
    if getmetatable(a)==Grid and getmetatable(b)==Grid then
        return a:add(b)
    elseif type(a)=='number' and getmetatable(b)==Grid then
        return b:addk(a)
    elseif getmetatable(a)==Grid and type(b)=='number' then
        return a:addk(b)
    end
end

function Grid.__sub(a,b)
    return a+(-1*b)
end

function Grid.__mul(a,b)
    if type(a)=='number' and getmetatable(b)==Grid then
        return b:mulk(a)
    elseif getmetatable(a)==Grid and type(b)=='number' then
        return a:mulk(b)
    else
        error('unsupported operand types')
    end
end

function Grid.__eq(a,b)
    if #a._dims~=#b._dims then return false end
    for i=1,#a._dims do if a._dims[i]~=b._dims[i] then return false end end
    for i=1,#a._data do if a._data[i]~=b._data[i] then return false end end
    return true
end

function Grid:new(dims,data)
    assert(type(dims)=='table','dims must be a table')
    for i,dim in ipairs(dims) do assert(type(dim)=='number' and math.floor(dim)==dim,'dims must be a table of integers') end
    data=data or {}
    local dimsProd=1; for _,dim in ipairs(dims) do dimsProd=dimsProd*dim end
    if #data==0 then for i=1,dimsProd do table.insert(data,0) end end
    assert(#data==dimsProd,'invalid number of elements')
    return setmetatable({_dims=dims,_data=data},Grid)
end

function Grid:totable(format,_dim,_index)
    if format==nil then
        return {dims=self._dims,data=self._data}
    elseif type(format)=='table' and #format==0 then
        if _dim then
            if _dim>#self._dims then return self:get(_index) end
            local t={}
            for i=1,self._dims[_dim] do
                _index[_dim]=i
                table.insert(t,self:totable(format,_dim+1,_index))
            end
            return t
        else
            local index={}; for i=1,#self._dims do table.insert(index,1) end
            return self:totable(format,1,index)
        end
    end
end

function Grid:fromtable(t)
    if t.dims~=nil and t.data~=nil then
        return Grid:new(t.dims,t.data)
    elseif type(t)=='table' then
        -- TODO:
        error('not implemented')
    end
end

if #arg==1 and arg[1]=='test' then
    local g=Grid:new(
        {2,3,4},
        {
            111,112,113,114,
            121,122,123,124,
            131,132,133,134,

            211,212,213,214,
            221,222,223,224,
            231,232,233,234,
        }
    )
    assert(g==Grid:fromtable{
        dims={2,3,4},
        data={
            111,112,113,114,
            121,122,123,124,
            131,132,133,134,

            211,212,213,214,
            221,222,223,224,
            231,232,233,234,
        }
    })
    assert(g:get{1,3,2}==132)
    assert(g:dims()[1]==2)
    local t=g:totable{}
    if not table.tostring then
        function table.tostring(t)
            local s='{'
            for i=1,#t do
                s=s..(i>1 and ',' or '')..(type(t[i])=='table' and table.tostring(t[i]) or tostring(t[i]))
            end
            return s..'}'
        end
    end
    assert(table.tostring(t)==table.tostring{
        {
            {111,112,113,114},
            {121,122,123,124},
            {131,132,133,134},
        },
        {
            {211,212,213,214},
            {221,222,223,224},
            {231,232,233,234},
        }
    })
    print('tests passed')
end
