Matrix={}

function Matrix:rows()
    if self._t then return self._cols else return self._rows end
end

function Matrix:cols()
    if self._t then return self._rows else return self._cols end
end

function Matrix:sameshape(m)
    assert(getmetatable(m)==Matrix,'argument is not a matrix')
    return self:rows()==m:rows() and self:cols()==m:cols()
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
        __newindex=function(t,j,v) self:set(i,j,v) end,
    })
    return Matrix(1,self:cols(),{ref=data})
end

function Matrix:setrow(i,m)
    assert(m:rows()==1,'bad shape')
    assert(m:cols()==self:cols(),'mismatching column count')
    for j=1,self:cols() do self:set(i,j,m:get(1,j)) end
end

function Matrix:col(j)
    local data={}
    setmetatable(data,{
        __index=function(t,i) return self:get(i,j) end,
        __len=function(t) return self:rows() end,
    })
    return Matrix(self:rows(),1,{ref=data})
end

function Matrix:setcol(j,m)
    assert(m:cols()==1,'bad shape')
    assert(m:rows()==self:rows(),'mismatching row count')
    for i=1,self:rows() do self:set(i,j,m:get(i,1)) end
end

function Matrix:data()
    local data={}
    setmetatable(data,{
        __index=function(t,i) return self:get((i-1)//self:cols()+1,(i-1)%self:cols()+1) end,
        __len=function(t) return self:rows()*self:cols() end,
    })
    return data
end

function Matrix:_minmax(dim,cmp,what)
    if dim==nil then
        if #self._data==0 then return nil end
        local mv,mi,mj=self._data[1],1,1
        for i=1,self:rows() do
            for j=1,self:cols() do
                local v=self:get(i,j)
                if cmp(v,mv) then mv,mi,mj=v,i,j end
            end
        end
        return mv,mi,mj
    elseif dim==1 then
        local m=Matrix(1,self:cols())
        for j=1,self:cols() do
            local col=self:col(j)
            m:set(1,j,col[what](col))
        end
        return m
    elseif dim==2 then
        local m=Matrix(self:rows(),1)
        for i=1,self:rows() do
            local row=self:row(i)
            m:set(i,1,row[what](row))
        end
        return m
    else
        error('invalid dimension')
    end
end

function Matrix:min(dim)
    return self:_minmax(dim,function(a,b) return a<b end,'min')
end

function Matrix:max(dim)
    return self:_minmax(dim,function(a,b) return a>b end,'max')
end

function Matrix:sum(dim)
    if dim==nil then
        local s=0
        for i=1,self:rows() do
            for j=1,self:cols() do
                s=s+self:get(i,j)
            end
        end
        return s
    elseif dim==1 then
        local m=Matrix(1,self:cols())
        for j=1,self:cols() do
            m:set(1,j,self:col(j):sum())
        end
        return m
    elseif dim==2 then
        local m=Matrix(self:rows(),1)
        for i=1,self:rows() do
            m:set(i,1,self:row(i):sum())
        end
        return m
    else
        error('invalid dimension')
    end
end

function Matrix:t()
    return Matrix(self._rows,self._cols,{ref=self._data},not self._t)
end

function Matrix:dot(m)
    assert(self:sameshape(m) or self:sameshape(m:t()),'shape mismatch')
    if self:rows()==1 and m:rows()==1 then
        return (self*m:t()):get(1,1)
    elseif self:cols()==1 and m:cols()==1 then
        return (self:t()*m):get(1,1)
    elseif self:rows()==1 and m:cols()==1 then
        return (self*m):get(1,1)
    elseif self:cols()==1 and m:rows()==1 then
        return (m*self):get(1,1)
    else
        error('supported only on vectors')
    end
end

function Matrix:cross(m)
    if self:rows()==1 and self:cols()==3 then
        assert(self:sameshape(m),'shape mismatch')
        return self:t():cross(m:t()):t()
    elseif self:rows()==3 and self:cols()==1 then
        assert(self:sameshape(m),'shape mismatch')
        return Matrix(3,1,{ref={
            self:get(2,1)*m:get(3,1)-self:get(3,1)*m:get(2,1),
            self:get(3,1)*m:get(1,1)-self:get(1,1)*m:get(3,1),
            self:get(1,1)*m:get(2,1)-self:get(2,1)*m:get(1,1),
        }})
    else
        error('supported only on 3d vectors')
    end
end

function Matrix:norm()
    return math.sqrt(self:dot(self))
end

function Matrix:__add(m)
    if type(self)=='number' then
        self,m=m,self
    end
    if type(m)=='number' then
        local data={}
        for i,x in ipairs(self._data) do
            table.insert(data,x+m)
        end
        return Matrix(self._rows,self._cols,{ref=data},self._t)
    elseif getmetatable(m)==Matrix then
        assert(self:sameshape(m),'shape mismatch')
        local data={}
        for i=1,self:rows() do
            for j=1,self:cols() do
                table.insert(data,self:get(i,j)+m:get(i,j))
            end
        end
        return Matrix(self:rows(),self:cols(),{ref=data})
    else
        error('unsupported operand')
    end
end

function Matrix:__sub(m)
    return self+(-1*m)
end

function Matrix:__mul(m)
    if type(self)=='number' then
        self,m=m,self
    end
    if type(m)=='number' then
        local data={}
        for i,x in ipairs(self._data) do
            table.insert(data,x*m)
        end
        return Matrix(self._rows,self._cols,{ref=data},self._t)
    elseif getmetatable(m)==Matrix then
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
        return Matrix(self:rows(),m:cols(),{ref=data})
    else
        error('unsupported operand')
    end
end

function Matrix:__unm()
    return -1*self
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

function Matrix:__len()
    if self:rows()==1 then
        return self:cols()
    else
        return self:rows()
    end
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

function Matrix:__newindex(k,v)
    if type(k)=='number' then
        if self:rows()==1 then
            return self:set(1,k,v)
        else
            return self:setrow(k,v)
        end
    else
        return Matrix[k]
    end
end

function Matrix.__eq(a,b)
    if not a:sameshape(b) then return false end
    for i=1,a:rows() do
        for j=1,a:cols() do
            if a:get(i,j)~=b:get(i,j) then return false end
        end
    end
    return true
end

function Matrix:__ipairs()
    if self:rows()==1 then
        local j,cols=0,self:cols()
        return function()
            j=j+1
            if j<=cols then
                return j,self:get(1,j)
            end
        end
    else
        local i,rows=0,self:rows()
        return function()
            i=i+1
            if i<=rows then
                return i,self:row(i)
            end
        end
    end
end

function Matrix:totable(format)
    if type(format)=='table' and #format==0 then
        local d={}
        for i=1,self:rows() do
            for j=1,self:cols() do
                table.insert(d,self:get(i,j))
            end
        end
        return {dims={self:rows(),self:cols()},data=d}
    elseif format==nil then
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
        return Matrix(t.dims[1],t.dims[2],t.data)
    elseif type(t[1])=='table' then
        local rows=#t
        local cols=#t[1]
        local data={}
        for i=1,rows do
            for j=1,cols do
                table.insert(data,t[i][j])
            end
        end
        return Matrix(rows,cols,{ref=data})
    end
end

function Matrix:copy()
    return Matrix:fromtable(self:totable{})
end

function Matrix:eye(size)
    return Matrix(size,size,function(i,j) return i==j and 1 or 0 end)
end

function Matrix:ones(rows,cols)
    return Matrix(rows,cols,function(i,j) return 1 end)
end

function Matrix:zeros(rows,cols)
    return Matrix(rows,cols,function(i,j) return 0 end)
end

function Matrix:print(elemwidth)
    elemwidth=elemwidth or 10
    for i=1,self:rows() do
        local row=''
        for j=1,self:cols() do
            row=row..string.format('%'..tostring(elemwidth)..'s',tostring(self:get(i,j)))
        end
        print(row)
    end
end

setmetatable(Matrix,{__call=function(self,rows,cols,data,t)
    assert(type(rows)=='number' and math.floor(rows)==rows,'rows must be an integer')
    assert(type(cols)=='number' and math.floor(cols)==cols,'cols must be an integer')
    local datagen,origdata=function() return 0 end,data
    if type(data)=='table' then
        if data.ref~=nil then
            -- take data by reference
            data,datagen=data.ref,nil
        elseif #data==rows*cols then
            data,datagen=nil,function(i,j) return origdata[(i-1)*cols+j] end
        else
            error('invalid number of elements')
        end
    elseif type(data)=='function' then
        data,datagen=nil,data
    end
    if data==nil then
        data={}
        for i=1,rows do
            for j=1,cols do
                table.insert(data,datagen(i,j))
            end
        end
    end
    assert(#data==rows*cols,'invalid number of elements')
    return setmetatable({_rows=rows,_cols=cols,_data=data,_t=t or false},self)
end})

if arg and #arg==1 and arg[1]=='test' then
    local m=Matrix(
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
    assert(m:totable{}.dims[1]==m:rows())
    assert(m:totable{}.dims[2]==m:cols())
    assert(m:totable()[3][2]==32)
    assert(m:totable()[2][4]==24)
    for i=1,3 do
        assert(m:row(i)==Matrix(1,4,{i*10+1,i*10+2,i*10+3,i*10+4}))
    end
    for j=1,4 do
        assert(m:col(j)==Matrix(3,1,{10+j,20+j,30+j}))
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
    assert(m*Matrix(4,1,{1,0,0,1})==Matrix(3,1,{25,45,65}))
    assert(2*m==2*m)
    assert(m+m==2*m)
    assert(m-m==0*m)
    assert(m*m:t()==Matrix(3,3,{630,1130,1630,1130,2030,2930,1630,2930,4230}))
    assert(m*m:t()*m*m:t()==Matrix(3,3,{4330700,7781700,11232700,7781700,13982700,20183700,11232700,20183700,29134700}))
    assert(m:t()*m==Matrix(4,4,{1523,1586,1649,1712,1586,1652,1718,1784,1649,1718,1787,1856,1712,1784,1856,1928}))
    assert(Matrix:fromtable{{1,0,0,0}}:norm()==1)
    assert(Matrix(3,1,{3,4,0}):norm()==5)
    assert(Matrix(3,1,{3,4,0}):dot(Matrix(3,1,{-4,3,5}))==0)
    assert(Matrix(3,1,{3,4,0}):data()[1]==3)
    assert(Matrix(3,1,{3,4,0}):data()[2]==4)
    assert(Matrix(1,3,{3,4,0}):data()[1]==3)
    assert(Matrix(1,3,{3,4,0}):data()[2]==4)
    local x,y,z=Matrix(3,1,{1,0,0}),Matrix(3,1,{0,1,0}),Matrix(3,1,{0,0,1})
    assert(x:dot(y:cross(z))~=0)
    assert(y:dot(y:cross(z))==0)
    assert(z:dot(y:cross(z))==0)
    assert(Matrix(2,2,{2,-2,4,-4})==-Matrix(2,2,{-2,2,-4,4}))
    local i=Matrix(3,3)
    i:setcol(1,Matrix(3,1,{1,0,0}))
    i:setcol(2,Matrix(3,1,{0,2,0}))
    i:setcol(3,Matrix(3,1,{0,0,3}))
    assert(i==Matrix(3,3,{1,0,0,0,2,0,0,0,3}))
    i:setrow(1,Matrix(1,3,{0,1,1}))
    i:setrow(2,Matrix(1,3,{2,0,2}))
    i:setrow(3,Matrix(1,3,{3,3,0}))
    assert(i==Matrix(3,3,{0,1,1,2,0,2,3,3,0}))
    local m1=Matrix(2,2,{1,0,0,1})
    local m2=m1
    m2:set(1,1,6)
    assert(m1:get(1,1)==6)
    local m3=m1:copy()
    m3:set(1,1,9)
    assert(m3:get(1,1)==9)
    assert(m1:get(1,1)==6)
    -- data should be copied, not referenced:
    local d={100,200,300}
    m4=Matrix(3,1,d)
    table.remove(d)
    assert(pcall(function() tostring(m4) end))
    m5=Matrix:fromtable{
        {1,20,5,3},
        {10,2,28,4},
        {2,5,7,9},
    }
    assert(m5:min()==1)
    minVal,minRow,minCol=m5:min()
    maxVal,maxRow,maxCol=m5:max()
    assert(minVal==1)
    assert(minRow==1)
    assert(minCol==1)
    assert(maxVal==28)
    assert(maxRow==2)
    assert(maxCol==3)
    assert(m5:min(1)==Matrix(1,4,{1,2,5,3}))
    assert(m5:max(1)==Matrix(1,4,{10,20,28,9}))
    assert(m5:min(2)==Matrix(3,1,{1,2,2}))
    assert(m5:max(2)==Matrix(3,1,{20,28,9}))
    assert(m5:sum()==96)
    assert(m5:sum(1)==Matrix(1,4,{13,27,40,16}))
    assert(m5:sum(2)==Matrix(3,1,{29,44,23}))
    print('tests passed')
end
