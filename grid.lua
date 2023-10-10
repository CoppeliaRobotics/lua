Grid = {}

function Grid:dims()
    return self._dims
end

function Grid:stride(dim)
    if dim >= #self._dims then return 1 end
    return self._dims[dim + 1] * self:stride(dim + 1)
end

function Grid:offset(index)
    assert(#index == #self._dims, 'invalid index length')
    local offset = 1
    for i = 1, #index do offset = offset + (index[i] - 1) * self:stride(i) end
    return offset
end

function Grid:get(index)
    return self._data[self:offset(index)]
end

function Grid:set(index, value)
    self._data[self:offset(index)] = value
end

function Grid:project(dim, val)
    local otherDims = {}
    for i = 1, #self._dims do if i ~= dim then table.insert(otherDims, self._dims[i]) end end
    -- TODO:
    error('not implemented')
end

function Grid:__add(m)
    if type(self) == 'number' then self, m = m, self end
    if type(m) == 'number' then
        local data = {}
        for i, x in ipairs(self._data) do table.insert(data, x + m) end
        return Grid(self._dims, data)
    elseif getmetatable(m) == Grid then
        assert(self._dims == m._dims, 'shape mismatch')
        for i = 1, #self._dims do assert(self._dims[i] == m._dims[i], 'shape mismatch') end
        local data = {}
        for i = 1, #self._data do table.insert(data, self._data[i] + m._data[i]) end
        return Grid(self._dims, data)
    else
        error('unsupported operand')
    end
end

function Grid:__sub(m)
    return self + (-1 * m)
end

function Grid:__mul(m)
    if type(self) == 'number' then self, m = m, self end
    if type(m) == 'number' then
        local data = {}
        for i, x in ipairs(self._data) do table.insert(data, x * m) end
        return Grid(self._dims, data)
    else
        error('unsupported operand')
    end
end

function Grid:__unm()
    return -1 * self
end

function Grid:__tostring()
    s = 'Grid({'
    for i = 1, #self._dims do s = s .. (i == 1 and '' or ',') .. self._dims[i] end
    s = s .. '},{'
    for i = 1, #self._data do s = s .. (i == 1 and '' or ',') .. self._data[i] end
    s = s .. '})'
    return s
end

function Grid:__index(k)
    return Grid[k]
end

function Grid.__eq(a, b)
    if #a._dims ~= #b._dims then return false end
    for i = 1, #a._dims do if a._dims[i] ~= b._dims[i] then return false end end
    for i = 1, #a._data do if a._data[i] ~= b._data[i] then return false end end
    return true
end

function Grid:totable(format, _dim, _index)
    if type(format) == 'table' and #format == 0 then
        return {dims = self._dims, data = self._data}
    elseif format == nil then
        if _dim then
            if _dim > #self._dims then return self:get(_index) end
            local t = {}
            for i = 1, self._dims[_dim] do
                _index[_dim] = i
                table.insert(t, self:totable(format, _dim + 1, _index))
            end
            return t
        else
            local index = {};
            for i = 1, #self._dims do table.insert(index, 1) end
            return self:totable(format, 1, index)
        end
    end
end

function Grid:fromtable(t, _depth, _t, _dims, _data)
    if t.dims ~= nil and t.data ~= nil then
        return Grid(t.dims, t.data)
    elseif type(t) == 'table' then
        if _t then
            if type(_t) == 'table' then
                if _dims[_depth] == nil then _dims[_depth] = #_t end
                if #_t ~= _dims[_depth] then error('inconsistent size') end
                for _, st in ipairs(_t) do
                    self:fromtable(t, _depth + 1, st, _dims, _data)
                end
            else
                table.insert(_data, _t)
            end
        else
            local dims, data = {}, {}
            self:fromtable(t, 1, t, dims, data)
            return Grid(dims, data)
        end
    end
end

function Grid:copy()
    return Grid:fromtable(self:totable{})
end

setmetatable(
    Grid, {
        __call = function(self, dims, data)
            assert(type(dims) == 'table', 'dims must be a table')
            for i, dim in ipairs(dims) do
                assert(
                    type(dim) == 'number' and math.floor(dim) == dim,
                    'dims must be a table of integers'
                )
            end
            data = data or {}
            local dimsProd = 1;
            for _, dim in ipairs(dims) do dimsProd = dimsProd * dim end
            if #data == 0 then for i = 1, dimsProd do table.insert(data, 0) end end
            assert(#data == dimsProd, 'invalid number of elements')
            return setmetatable({_dims = dims, _data = data}, self)
        end,
    }
)

if arg and #arg == 1 and arg[1] == 'test' then
    local g = Grid({2, 3, 4}, {
        111, 112, 113, 114,
        121, 122, 123, 124,
        131, 132, 133, 134,
        211, 212, 213, 214,
        221, 222, 223, 224,
        231, 232, 233, 234,
    })
    local n = {
        {{111, 112, 113, 114}, {121, 122, 123, 124}, {131, 132, 133, 134}},
        {{211, 212, 213, 214}, {221, 222, 223, 224}, {231, 232, 233, 234}},
    }
    assert(
        g == Grid:fromtable{
            dims = {2, 3, 4},
            data = {
                111, 112, 113, 114,
                121, 122, 123, 124,
                131, 132, 133, 134,
                211, 212, 213, 214,
                221, 222, 223, 224,
                231, 232, 233, 234,
            },
        }
    )
    assert(g:get{1, 3, 2} == 132)
    assert(g:dims()[1] == 2)
    if not table.tostring then
        function table.tostring(t)
            local s = '{'
            for i = 1, #t do
                s = s .. (i > 1 and ',' or '') ..
                        (type(t[i]) == 'table' and table.tostring(t[i]) or tostring(t[i]))
            end
            return s .. '}'
        end
    end
    assert(table.tostring(g:totable()) == table.tostring(n))
    assert(Grid:fromtable(n) == g)
    print(debug.getinfo(1, 'S').source, 'tests passed')
end
