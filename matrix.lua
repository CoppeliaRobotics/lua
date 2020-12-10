Matrix={}

function Matrix:rows()
    if self._t then return self._cols else return self._rows end
end

function Matrix:cols()
    if self._t then return self._rows else return self._cols end
end

function Matrix:offset(i,j)
    local h=self._t and {j,i} or {i,j}
    return self._cols*(h[1]-1)+h[2]
end

function Matrix:get(i,j)
    return self._data[self:offset(i,j)]
end

function Matrix:set(i,j,value)
    self._data[self:offset(i,j)]=value
end

function Matrix:row(i)
    local data={}
    setmetatable(data,{
        __index=function(t,j) return self:get(i,j) end,
        __len=function(t) return self:cols() end,
    })
    return Matrix:new(1,self:cols(),data)
end

function Matrix:col(j)
    local data={}
    setmetatable(data,{
        __index=function(t,i) return self:get(i,j) end,
        __len=function(t) return self:rows() end,
    })
    return Matrix:new(self:rows(),1,data)
end

function Matrix:t()
    return Matrix:new(self._rows,self._cols,self._data,not self._t)
end

function Matrix:addk(k)
    local data={}
    for i,x in ipairs(self._data) do
        table.insert(data,x+k)
    end
    return Matrix:new(self._rows,self._cols,data,self._t)
end

function Matrix:mulk(k)
    local data={}
    for i,x in ipairs(self._data) do
        table.insert(data,x*k)
    end
    return Matrix:new(self._rows,self._cols,data,self._t)
end

function Matrix:add(m)
    assert(self:rows()==m:rows() and self:cols()==m:cols(),'shape mismatch')
    local data={}
    for i=1,self:rows() do
        for j=1,self:cols() do
            table.insert(data,self:get(i,j)+m:get(i,j))
        end
    end
    return Matrix:new(self:rows(),self:cols(),data)
end

function Matrix:mul(m)
    assert(self:cols()==m:rows(),'invalid matrix shape')
    local data={}
    for i=1,self:rows() do
        for j=1,m:cols() do
            local s=0
            for k=1,self:cols() do
                s=s+self:get(i,k)*m:get(k,j)
            end
            table.insert(data,s)
        end
    end
    return Matrix:new(self:rows(),m:cols(),data)
end

function Matrix:norm()
    if self:rows()==1 then
        return math.sqrt((self*self:t()):get(1,1))
    elseif self:cols()==1 then
        return math.sqrt((self:t()*self):get(1,1))
    else
        error('supported only on vectors')
    end
end

function Matrix:__tostring()
    s='Matrix('..self:rows()..','..self:cols()..',{'
    for i=1,self:rows() do
        for j=1,self:cols() do
            s=s..(i==1 and j==1 and '' or ',')..self:get(i,j)
        end
    end
    s=s..'})'
    return s
end

function Matrix:__index(k)
    if type(k)=='number' then
        if self:rows()==1 then
            return self:get(1,k)
        else
            return self:row(k)
        end
    else
        return Matrix[k]
    end
end

function Matrix.__add(a,b)
    if getmetatable(a)==Matrix and getmetatable(b)==Matrix then
        return a:add(b)
    elseif type(a)=='number' and getmetatable(b)==Matrix then
        return b:addk(a)
    elseif getmetatable(a)==Matrix and type(b)=='number' then
        return a:addk(b)
    end
end

function Matrix.__sub(a,b)
    return a+(-1*b)
end

function Matrix.__mul(a,b)
    if getmetatable(a)==Matrix and getmetatable(b)==Matrix then
        return a:mul(b)
    elseif type(a)=='number' and getmetatable(b)==Matrix then
        return b:mulk(a)
    elseif getmetatable(a)==Matrix and type(b)=='number' then
        return a:mulk(b)
    end
end

function Matrix.__eq(a,b)
    if a:rows()~=b:rows() then return false end
    if a:cols()~=b:cols() then return false end
    for i=1,a:rows() do
        for j=1,a:cols() do
            if a:get(i,j)~=b:get(i,j) then return false end
        end
    end
    return true
end

function Matrix:new(rows,cols,data,t)
    assert(type(rows)=='number' and math.floor(rows)==rows,'rows must be an integer')
    assert(type(cols)=='number' and math.floor(cols)==cols,'cols must be an integer')
    data=data or {}
    if #data==0 then for i=1,rows*cols do table.insert(data,0) end end
    assert(#data==rows*cols,'invalid number of elements')
    return setmetatable({_rows=rows,_cols=cols,_data=data,_t=t or false},Matrix)
end

function Matrix:totable(format)
    if format==nil then
        local d={}
        for i=1,self:rows() do
            for j=1,self:cols() do
                table.insert(d,self:get(i,j))
            end
        end
        return {dims={self:rows(),self:cols()},data=d}
    elseif type(format)=='table' and #format==0 then
        local t={}
        for i=1,self:rows() do
            local row={}
            for j=1,self:cols() do
                table.insert(row,self:get(i,j))
            end
            table.insert(t,row)
        end
        return t
    end
end

function Matrix:fromtable(t)
    if t.dims~=nil and t.data~=nil then
        assert(#t.dims==2,'only 2d grids are supported by this class')
        return Matrix:new(t.dims[1],t.dims[2],t.data)
    elseif type(t[1])=='table' then
        local rows=#t
        local cols=#t[1]
        local data={}
        for i=1,rows do
            for j=1,cols do
                table.insert(data,t[i][j])
            end
        end
        return Matrix:new(rows,cols,data)
    end
end

if #arg==1 and arg[1]=='test' then
    local m=Matrix:new(
        3,4,
        {
            11,12,13,14,
            21,22,23,24,
            31,32,33,34,
        }
    )
    assert(m==Matrix:fromtable{
        dims={3,4},
        data={
            11,12,13,14,
            21,22,23,24,
            31,32,33,34,
        }
    })
    assert(m==Matrix:fromtable{
        {11,12,13,14},
        {21,22,23,24},
        {31,32,33,34},
    })
    assert(m:rows()==3)
    assert(m:cols()==4)
    assert(m:totable().dims[1]==m:rows())
    assert(m:totable().dims[2]==m:cols())
    assert(m:totable{}[3][2]==32)
    assert(m:totable{}[2][4]==24)
    for i=1,3 do
        assert(m:row(i)==Matrix:new(1,4,{i*10+1,i*10+2,i*10+3,i*10+4}))
    end
    for j=1,4 do
        assert(m:col(j)==Matrix:new(3,1,{10+j,20+j,30+j}))
    end
    assert(m:row(2)==m[2])
    for i=1,3 do
        for j=1,4 do
            assert(m:get(i,j)==i*10+j)
        end
    end
    assert(m:get(2,3)==m[2][3])
    assert(m[2][3]==m:row(2)[3])
    assert(m:t():col(2):t()==m:row(2))
    assert(m:mul(Matrix:new(4,1,{1,0,0,1}))==Matrix:new(3,1,{25,45,65}))
    assert(2*m==2*m)
    assert(m+m==2*m)
    assert(m-m==0*m)
    assert(m*m:t()==Matrix:new(3,3,{630,1130,1630,1130,2030,2930,1630,2930,4230}))
    assert(m*m:t()*m*m:t()==Matrix:new(3,3,{4330700,7781700,11232700,7781700,13982700,20183700,11232700,20183700,29134700}))
    assert(m:t()*m==Matrix:new(4,4,{1523,1586,1649,1712,1586,1652,1718,1784,1649,1718,1787,1856,1712,1784,1856,1928}))
    assert(Matrix:fromtable{{1,0,0,0}}:norm()==1)
    print('tests passed')
end
