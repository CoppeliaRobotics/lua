Matrix={}

function Matrix:rows()
    if self._t then return self._cols else return self._rows end
end

function Matrix:cols()
    if self._t then return self._rows else return self._cols end
end

function Matrix:count()
    return self._rows*self._cols
end

function Matrix:sameshape(m)
    if getmetatable(m)==Matrix then
        return self:rows()==m:rows() and self:cols()==m:cols()
    elseif type(m)=='table' and m[1] and m[2] then
        return self:rows()==m[1] and self:cols()==m[2]
    else
        error('argument is not a matrix')
    end
end

function Matrix:offset(i,j)
    if j==nil then
        if self._rows<1 or self._cols<1 then return end
        local o=i
        i,j=(i-1)//self:cols()+1,(i-1)%self:cols()+1
    end
    if i>=1 and j>=1 and i<=self:rows() and j<=self:cols() then
        if self._t then i,j=j,i end
        return self._cols*(i-1)+j
    end
end

function Matrix:get(i,j)
    local offset=self:offset(i,j)
    if not offset then return end
    return self._data[offset]
end

function Matrix:set(i,j,value)
    local offset=self:offset(i,j)
    if offset then
        if self._copyonwrite then
            self._copyonwrite=false
            local d={}
            for i,x in ipairs(self._data) do table.insert(d,x) end
            self._data=d
        end
        self._data[offset]=value
    end
    return self
end

function Matrix:row(i)
    if i<1 or i>self:rows() then return Matrix(0,0) end
    local r=Matrix(1,self:cols())
    for j=1,self:cols() do r:set(1,j,self:get(i,j)) end
    return r
end

function Matrix:rowref(i)
    if i<1 or i>self:rows() then return Matrix(0,0) end
    local data={}
    setmetatable(data,{
        __index=function(t,j) return self:get(i,j) end,
        __len=function(t) return self:cols() end,
        __newindex=function(t,j,v) self:set(i,j,v) end,
    })
    return Matrix(1,self:cols(),{ref=data})
end

function Matrix:setrow(i,m)
    if i<1 or i>self:rows() then return self end
    if getmetatable(m)==Matrix then
        assert(m:rows()==1,'bad shape')
        assert(m:cols()==self:cols(),'mismatching column count')
        for j=1,self:cols() do self:set(i,j,m:get(1,j)) end
    elseif type(m)=='table' then
        for j=1,self:cols() do self:set(i,j,m[j] or 0) end
    else
        error('bad type')
    end
    return self
end

function Matrix:col(j)
    if j<1 or j>self:cols() then return Matrix(0,0) end
    local r=Matrix(self:rows(),1)
    for i=1,self:rows() do r:set(i,1,self:get(i,j)) end
    return r
end

function Matrix:setcol(j,m)
    if j<1 or j>self:cols() then return self end
    if getmetatable(m)==Matrix then
        assert(m:cols()==1,'bad shape')
        assert(m:rows()==self:rows(),'mismatching row count')
        for i=1,self:rows() do self:set(i,j,m:get(i,1)) end
    elseif type(m)=='table' then
        for i=1,self:rows() do self:set(i,j,m[i] or 0) end
    else
        error('bad type')
    end
    return self
end

function Matrix:slice(fromrow,fromcol,torow,tocol)
    local m=Matrix(math.max(0,1+torow-fromrow),math.max(0,1+tocol-fromcol))
    for i=fromrow,torow do
        for j=fromcol,tocol do
            m:set(i-fromrow+1,j-fromcol+1,self:get(i,j) or 0)
        end
    end
    return m
end

function Matrix:droprow(i)
    local m,n=self:rows(),self:cols()
    assert(i>=1 and i<=m,'out of bounds')
    return Matrix.vertcat(self:slice(1,1,i-1,n),self:slice(i+1,1,m,n))
end

function Matrix:dropcol(j)
    local m,n=self:rows(),self:cols()
    assert(j>=1 and j<=n,'out of bounds')
    return Matrix.horzcat(self:slice(1,1,m,j-1),self:slice(1,j+1,m,n))
end

function Matrix:at(rowidx,colidx)
    assert(getmetatable(rowidx)==Matrix and getmetatable(colidx)==Matrix,'bad type')
    return rowidx:applyfunc2(colidx,function(i,j) return self:get(i,j) end)
end

function Matrix:horzcat(...)
    local args={...}
    if getmetatable(self)==Matrix then table.insert(args,1,self) end
    assert(#args>0,'not enough args')
    local self=args[1]
    local cols=0
    for _,arg in ipairs(args) do
        assert(self:rows()==arg:rows(),'row count mismatch')
        cols=cols+arg:cols()
    end
    local r=Matrix(self:rows(),cols)
    local j=1
    for _,arg in ipairs(args) do
        r:assign(1,j,arg)
        j=j+arg:cols()
    end
    return r
end

function Matrix:vertcat(...)
    local args={...}
    if getmetatable(self)==Matrix then table.insert(args,1,self) end
    assert(#args>0,'not enough args')
    local self=args[1]
    local rows=0
    for _,arg in ipairs(args) do
        assert(self:cols()==arg:cols(),'column count mismatch')
        rows=rows+arg:rows()
    end
    local r=Matrix(rows,self:cols())
    local i=1
    for _,arg in ipairs(args) do
        r:assign(i,1,arg)
        i=i+arg:rows()
    end
    return r
end

function Matrix:assign(startrow,startcol,m)
    for i=1,m:rows() do
        for j=1,m:cols() do
            self:set(i+startrow-1,j+startcol-1,m:get(i,j) or 0)
        end
    end
    return self
end

function Matrix:applyfuncidx(f)
    return Matrix(self:rows(),self:cols(),function(i,j) return f(i,j,self:get(i,j)) end)
end

function Matrix:applyfunc(f)
    return self:applyfuncidx(function(i,j,x) return f(x) end)
end

function Matrix:applyfunc2(m2,f)
    assert(self:sameshape(m2),'shape mismatch')
    return self:applyfuncidx(function(i,j,x) return f(x,m2:get(i,j)) end)
end

function Matrix:binop(m,op)
    if type(m)=='number' then
        return self:applyfunc(function(x) return op(x,m) end)
    elseif getmetatable(m)==Matrix then
        assert(self:sameshape(m),'shape mismatch')
        return self:applyfunc2(m,op)
    else
        error('unsupported operand')
    end
end

function Matrix:abs()
    return self:applyfunc(math.abs)
end

function Matrix:acos()
    return self:applyfunc(math.acos)
end

function Matrix:asin()
    return self:applyfunc(math.asin)
end

function Matrix:atan(m)
    if m then
        return self:applyfunc2(m,math.atan)
    else
        return self:applyfunc(math.atan)
    end
end

function Matrix:ceil()
    return self:applyfunc(math.ceil)
end

function Matrix:cos()
    return self:applyfunc(math.cos)
end

function Matrix:deg()
    return self:applyfunc(math.deg)
end

function Matrix:exp()
    return self:applyfunc(math.exp)
end

function Matrix:floor()
    return self:applyfunc(math.floor)
end

function Matrix:fmod(m)
    return self:binop(m,math.fmod)
end

function Matrix:log(base)
    if base==nil then
        return self:applyfunc(math.log)
    elseif type(base)=='number' then
        return self:applyfunc(function(x) return math.log(x,base) end)
    elseif getmetatable(base)==Matrix then
        return self:applyfunc2(base,math.log)
    else
        error('unsupported operand type')
    end
end

function Matrix:rad()
    return self:applyfunc(math.rad)
end

function Matrix:random(a,b)
    if a and b then
        return self:applyfunc(function() return math.random(a,b) end)
    elseif a then
        return self:applyfunc(function() return math.random(a) end)
    else
        return self:applyfunc(math.random)
    end
end

function Matrix:sin()
    return self:applyfunc(math.sin)
end

function Matrix:sqrt()
    return self:applyfunc(math.sqrt)
end

function Matrix:tan()
    return self:applyfunc(math.tan)
end

function Matrix:tointeger()
    return self:applyfunc(math.tointeger)
end

function Matrix:ult(m2)
    return self:applyfunc2(math.ult)
end

function Matrix:data()
    local data={}
    for i=1,self:count() do
        table.insert(data,self:get(i))
    end
    return data
end

function Matrix:dataref()
    local data={}
    setmetatable(data,{
        __index=function(t,i) return self:get(i) end,
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

function Matrix:min(dim_or_mtx2)
    if dim_or_mtx2==nil or math.type(dim_or_mtx2)=='integer' then
        return self:_minmax(dim_or_mtx2,function(a,b) return a<b end,'min')
    elseif getmetatable(dim_or_mtx2)==Matrix then
        return self:applyfunc2(dim_or_mtx2,math.min)
    end
end

function Matrix:max(dim_or_mtx2)
    if dim_or_mtx2==nil or math.type(dim_or_mtx2)=='integer' then
        return self:_minmax(dim_or_mtx2,function(a,b) return a>b end,'max')
    elseif getmetatable(dim_or_mtx2)==Matrix then
        return self:applyfunc2(dim_or_mtx2,math.max)
    end
end

function Matrix:fold(dim,start,op)
    if dim==nil then
        local s=start
        for i=1,self:rows() do
            for j=1,self:cols() do
                s=op(s,self:get(i,j))
            end
        end
        return s
    elseif dim==1 then
        local m=Matrix(1,self:cols())
        for j=1,self:cols() do
            m:set(1,j,self:col(j):fold(nil,start,op))
        end
        return m
    elseif dim==2 then
        local m=Matrix(self:rows(),1)
        for i=1,self:rows() do
            m:set(i,1,self:row(i):fold(nil,start,op))
        end
        return m
    else
        error('invalid dimension')
    end
end

function Matrix:sum(dim)
    return self:fold(dim,0,function(a,b) return a+b end)
end

function Matrix:prod(dim)
    return self:fold(dim,1,function(a,b) return a*b end)
end

function Matrix:mean(dim)
    local c
    if dim==nil then
        c=self:count()
    elseif dim==1 then
        c=self:rows()
    elseif dim==2 then
        c=self:cols()
    else
        error('invalid dimension')
    end
    return self:sum(dim)/c
end

function Matrix:add(m)
    return self:binop(m,function(a,b) return a+b end)
end

function Matrix:sub(m)
    return self:binop(m,function(a,b) return a-b end)
end

function Matrix:mul(m)
    if type(m)=='number' then
        return self:applyfunc(function(x) return x*m end)
    elseif getmetatable(m)==Matrix then
        assert(self:cols()==m:rows(),'incompatible matrix dimensions')
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

function Matrix:mult(v)
    if getmetatable(v)==Matrix then
        assert(self:sameshape{4,4},'not a 4x4 matrix')
        assert(v:sameshape{3,1},'operand not a 3d vector')
        return self:mul(v:hom()):nonhom()
    else
        error('unsupported operand')
    end
end

function Matrix:axis(which)
    assert(self:sameshape{3,3} or self:sameshape{4,4},'not a 3x3 or 4x4 matrix')
    local c=({[1]=1,[2]=2,[3]=3,['x']=1,['y']=2,['z']=3})[which]
    if not c then error('invalid argument') end
    return self:slice(1,c,3,c)
end

function Matrix:div(m)
    return self:binop(m,function(a,b) return a/b end)
end

function Matrix:idiv(m)
    return self:binop(m,function(a,b) return a//b end)
end

function Matrix:pow(m)
    return self:binop(m,function(a,b) return a^b end)
end

function Matrix:mod(m)
    return self:binop(m,function(a,b) return a%b end)
end

function Matrix:times(m)
    return self:binop(m,function(a,b) return a*b end)
end

function Matrix:power(k)
    assert(self:rows()==self:cols(),'must be square matrix')
    assert(math.type(k)=='integer','only integer matrix power are allowed')
    assert(k>=0,'only non-negative matrix powers are allowed')
    local r=Matrix:eye(self:rows())
    for i=1,m do r=r*self end
    return r
end

function Matrix:eq(m)
    return self:binop(m,function(a,b) return a==b and 1 or 0 end)
end

function Matrix:ne(m)
    return self:binop(m,function(a,b) return a~=b and 1 or 0 end)
end

function Matrix:lt(m)
    return self:binop(m,function(a,b) return a<b and 1 or 0 end)
end

function Matrix:gt(m)
    return self:binop(m,function(a,b) return a>b and 1 or 0 end)
end

function Matrix:le(m)
    return self:binop(m,function(a,b) return a<=b and 1 or 0 end)
end

function Matrix:ge(m)
    return self:binop(m,function(a,b) return a>=b and 1 or 0 end)
end

function Matrix:all(f)
    f=f or function(x) return x~=0 end
    for i=1,self:rows() do
        for j=1,self:cols() do
            if not f(self:get(i,j)) then return false end
        end
    end
    return true
end

function Matrix:any(f)
    f=f or function(x) return x~=0 end
    for i=1,self:rows() do
        for j=1,self:cols() do
            if f(self:get(i,j)) then return true end
        end
    end
    return false
end

function Matrix:nonzero()
    local r={}
    for i=1,self:rows() do
        for j=1,self:cols() do
            if self:get(i,j)~=0 then
                table.insert(r,{i,j})
            end
        end
    end
    return Matrix:fromtable(r)
end

function Matrix:where(cond,x,y)
    assert(cond:sameshape(x) and cond:sameshape(y),'shape mismatch')
    return cond:times(x)+(1-cond):times(y)
end

function Matrix:t()
    self._copyonwrite=true
    return Matrix(self._rows,self._cols,{ref=self._data,copyonwrite=true},not self._t)
end

function Matrix:dot(m)
    assert(self:cols()==1,'supported only on vectors')
    assert(self:sameshape(m),'shape mismatch')
    return (self:t()*m):get(1,1)
end

function Matrix:cross(m)
    assert(self:sameshape{3,1},'supported only on 3d vectors')
    assert(self:sameshape(m),'shape mismatch')
    return Matrix(3,1,{ref={
        self:get(2,1)*m:get(3,1)-self:get(3,1)*m:get(2,1),
        self:get(3,1)*m:get(1,1)-self:get(1,1)*m:get(3,1),
        self:get(1,1)*m:get(2,1)-self:get(2,1)*m:get(1,1),
    }})
end

function Matrix:kron(m)
    local r=Matrix(self:rows()*m:rows(),self:cols()*m:cols())
    for i=1,self:rows() do
        for j=1,self:cols() do
            r:assign(m:rows()*(i-1)+1,m:cols()*(j-1)+1,self:get(i,j)*m)
        end
    end
    return r
end

function Matrix:hom()
    if self:rows()==3 then
        return self:vertcat(Matrix:ones(1,self:cols()))
    else
        error('invalid shape')
    end
end

function Matrix:nonhom()
    if self:rows()==4 then
        return self:slice(1,1,3,self:cols()):applyfuncidx(function(i,j,x) return x/self:get(4,j) end)
    else
        error('invalid shape')
    end
end

function Matrix:norm()
    return math.sqrt(self:dot(self))
end

function Matrix:normalized()
    return self/self:norm()
end

function Matrix:diag(t)
    if t then
        -- called as static, creates a matrix from diagonal elements
        if getmetatable(t)==Matrix then
            assert(t:cols()==1,'argument must be a vector')
            return Matrix:diag(t:data())
        elseif type(t)=='table' then
            local r=Matrix(#t,#t)
            for i,x in ipairs(t) do r:set(i,i,x) end
            return r
        else
            error('bad argument type')
        end
    else
        -- called as matrix method, returns the main diagonal
        local r=Matrix(math.min(self:rows(),self:cols()),1)
        for ij=1,r:rows() do r:set(ij,1,self:get(ij,ij)) end
        return r
    end
end

function Matrix:trace()
    assert(self:rows()==self:cols(),'only defined on square matrices')
    return self:diag():sum()
end

function Matrix:gauss(jordan)
    assert(self:cols()>=self:rows(),'number of columns must be greater or equal to the number of rows')
    local n=self:rows()
    local r=self:copy()
    local det=1
    local function swaprows(i1,i2)
        if i1==i2 then return end
        r1,r2=r:row(i1),r:row(i2)
        r:setrow(i1,r2)
        r:setrow(i2,r1)
        det=-det
    end
    local function multrow(i,k)
        r:setrow(i,k*r:row(i))
        det=det/k
    end
    local function addrow(i1,k,i2)
        r:setrow(i1,r:row(i1)+k*r:row(i2))
    end
    for j=1,r:rows() do
        local pivotvalue,pivotindex=r:get(j,j),j
        for i=j,n do
            if math.abs(r:get(i,j))>math.abs(pivotvalue) then
                pivotvalue,pivotindex=r:get(i,j),i
            end
        end
        if pivotvalue~=0 then
            if math.abs(pivotvalue)>math.abs(r:get(j,j)) then swaprows(j,pivotindex) end
            multrow(j,1/r:get(j,j))
            for i=j+1,r:rows() do
                if r:get(i,j)~=0 then
                    addrow(i,-r:get(i,j)/r:get(j,j),j)
                end
            end
        end
    end
    if jordan then
        for j=r:rows(),2,-1 do
            for i=j-1,1,-1 do
                addrow(i,-r:get(i,j),j)
            end
        end
    end
    det=det*r:diag():prod() -- in case some element on the diagonal is zero
    return r,det
end

function Matrix:det()
    assert(self:rows()==self:cols(),'only defined on square matrices')
    local n=self:rows()
    if n==1 then
        return self:get(1,1)
    elseif n==2 then
        local a,b,c,d=table.unpack(self:data())
        return a*d-b*c
    elseif n==3 then
        local a,b,c,d,e,f,g,h,i=table.unpack(self:data())
        return a*e*i+b*f*g+c*d*h-c*e*g-a*f*h-b*d*i
    elseif false then -- very slow method
        local d,r1=0,self:slice(2,1,n,n)
        for j=1,n do d=d+(-1)^(1+j)*self:get(1,j)*r1:dropcol(j):det() end
        return d
    else
        local _,d=self:gauss()
        return d
    end
end

function Matrix:inv()
    assert(self:rows()==self:cols(),'must be square')
    local n=self:rows()
    local w,d=Matrix.horzcat(self,Matrix:eye(n)):gauss(true)
    if math.abs(d)<1e-11 then
        error('matrix is not invertible')
    end
    return w:slice(1,1+n,n,n+n)
end

function Matrix:__add(m)
    if type(self)=='number' then
        self,m=m,self
    end
    return self:add(m)
end

function Matrix:__sub(m)
    if type(self)=='number' then
        return m*(-1)+self
    end
    return self:sub(m)
end

function Matrix:__mul(m)
    if type(self)=='number' then
        self,m=m,self
    end
    return self:mul(m)
end

function Matrix:__div(k)
    return self:div(k)
end

function Matrix:__idiv(k)
    return self:idiv(k)
end

function Matrix:__mod(k)
    return self:mod(k)
end

function Matrix:__unm()
    return -1*self
end

function Matrix:__pow(m)
    if type(self)=='number' then
        return m:applyfunc(function(x) return math.pow(self,x) end)
    elseif type(m)=='number' then
        return self:power(m)
    elseif self:sameshape{3,1} and self:sameshape(m) then
        return self:cross(m)
    else
        error('unsupported operand')
    end
end

function Matrix:__concat(m)
    if self:cols()==1 and self:sameshape(m) then
        return self:dot(m)
    else
        error('unsupported operand')
    end
end

function Matrix:__tostring()
    s='Matrix('..self:rows()..','..self:cols()..',{'
    for i=1,self:rows() do
        for j=1,self:cols() do
            s=s..(i==1 and j==1 and '' or ',')..tostring(self:get(i,j))
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
        elseif self:cols()==1 then
            return self:get(k,1)
        else
            return self:rowref(k)
        end
    else
        return Matrix[k]
    end
end

function Matrix:__newindex(k,v)
    if type(k)=='number' then
        if self:rows()==1 then
            return self:set(1,k,v)
        elseif self:cols()==1 then
            return self:set(k,1,v)
        else
            return self:setrow(k,v)
        end
    else
        return Matrix[k]
    end
end

function Matrix:__eq(m)
    return self:eq(m):all()
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
    assert(type(t)=='table','bad type')
    if t.dims~=nil and t.data~=nil then
        assert(#t.dims==2,'only 2d grids are supported by this class')
        return Matrix(t.dims[1],t.dims[2],t.data)
    elseif type(t[1])=='table' then
        local rows=#t
        local cols=#t[1]
        local data={}
        for i=1,rows do
            for j=1,cols do
                assert(#t[i]==cols,'inconsistent number of columns in table data')
                table.insert(data,t[i][j])
            end
        end
        return Matrix(rows,cols,{ref=data})
    elseif #t==0 then
        return Matrix(0,0)
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
    if not elemwidth then
        elemwidth={}
        for j=1,self:cols() do
            for i=1,self:rows() do
                elemwidth[j]=math.max(elemwidth[j] or 0,#tostring(self:get(i,j)))
            end
            elemwidth[j]=elemwidth[j]+2
        end
    elseif type(elemwidth)=='number' then
        elemwidth={elemwidth+2}
        for j=1,self:cols() do
            elemwidth[j]=elemwidth[1]
        end
    end
    for i=1,self:rows() do
        local row=''
        for j=1,self:cols() do
            row=row..string.format('%'..tostring(elemwidth[j])..'s',tostring(self:get(i,j)))
        end
        print(row)
    end
end

setmetatable(Matrix,{__call=function(self,rows,cols,data,t)
    assert(math.type(rows)=='integer' and rows>=0,'rows must be a positive integer')
    assert(math.type(cols)=='integer' and cols>=0,'cols must be a positive integer')
    local copyonwrite=false
    local datagen,origdata=function() return 0 end,data
    if type(data)=='table' then
        if data.ref~=nil then
            -- take data by reference
            if data.copyonwrite then copyonwrite=true end
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
                table.insert(data,datagen(i,j) or 0)
            end
        end
    end
    assert(#data==rows*cols,'invalid number of elements')
    return setmetatable({
        _rows=rows,
        _cols=cols,
        _data=data,
        _t=t or false,
        _copyonwrite=copyonwrite,
    },self)
end})

Vector={}

function Vector:range(start,stop,step)
    step=step or 1
    if not stop then start,stop=1,start end
    local data={}
    for i=start,stop,step do table.insert(data,i) end
    return Vector(#data,{ref=data})
end

function Vector:linspace(start,stop,num,endpoint)
    num=num or 50
    local normrange=num-1
    if endpoint==false then normrange=normrange+1 end
    local range=(stop-start)/normrange
    local r=start+Vector:range(0,num-1)*range
    local step=#r>1 and r[2]-r[1] or 0
    return r,step
end

function Vector:logspace(start,stop,num,endpoint,base)
    base=base or 10.0
    return base^Vector:linspace(start,stop,num,endpoint)
end

function Vector:geomspace(start,stop,num,endpoint)
    k=math.pow(stop/start,1/(num-1))
    return start*(k^Vector:linspace(0,num-1,num,endpoint))
end

setmetatable(Vector,{__call=function(self,len,data)
    if type(len)=='table' then
        data=len
        len=#data
    end
    assert(len>0,'length must be greater than zero')
    return Matrix(len,1,data)
end})

Vector3={}

function Vector3:hom(v)
    if getmetatable(v)==Matrix then
        assert(v:sameshape{3,1},'must be Vector3')
        return v:slice(1,1,4,1):set(4,1,1)
    elseif type(v)=='table' then
        assert(#v==3,'must have 3 elements')
        return Vector4{v[1],v[2],v[3],1.0}
    else
        error('unsupported type')
    end
end

function Vector3:random()
    local rand=function() return math.tan((math.random()-0.5)*2*math.pi*0.99) end
    return Vector3{rand(),rand(),rand()}
end

function Vector3:unitrandom()
    local theta=math.random()*math.pi
    local phi=math.random()*math.pi*2
    return Vector3{
        math.sin(theta)*math.cos(phi),
        math.sin(theta)*math.sin(phi),
        math.cos(theta)
    }
end

setmetatable(Vector3,{__call=function(self,data)
    return Vector(3,data)
end})

Vector4={}

function Vector4:hom(v)
    if getmetatable(v)==Matrix then
        assert(v:sameshape{4,1},'must be Vector4')
        return v/v:get(4,1)
    elseif type(v)=='table' then
        assert(#v==4,'must have 4 elements')
        return Vector4{v[1]/v[4],v[2]/v[4],v[3]/v[4],1.0}
    else
        error('unsupported type')
    end
end

setmetatable(Vector4,{__call=function(self,data)
    return Vector(4,data)
end})

Vector7={}

setmetatable(Vector7,{__call=function(self,data)
    return Vector(7,data)
end})

Matrix3x3={}

function Matrix3x3:rotx(angle)
    local s,c=math.sin(angle),math.cos(angle)
    return Matrix(3,3,{1,0,0,0,c,-s,0,s,c})
end

function Matrix3x3:roty(angle)
    local s,c=math.sin(angle),math.cos(angle)
    return Matrix(3,3,{c,0,s,0,1,0,-s,0,c})
end

function Matrix3x3:rotz(angle)
    local s,c=math.sin(angle),math.cos(angle)
    return Matrix(3,3,{c,-s,0,s,c,0,0,0,1})
end

function Matrix3x3:fromquaternion(q)
    if q.x and q.y and q.z and q.w then
        local n=1/math.sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w)
        local qx,qy,qz,qw=n*q.x,n*q.y,n*q.z,n*q.w
        return Matrix(3,3,{
            1-2*qy*qy-2*qz*qz, 2*qx*qy-2*qz*qw,   2*qx*qz+2*qy*qw,
            2*qx*qy+2*qz*qw,   1-2*qx*qx-2*qz*qz, 2*qy*qz-2*qx*qw,
            2*qx*qz-2*qy*qw,   2*qy*qz+2*qx*qw,   1-2*qx*qx-2*qy*qy,
        })
    elseif getmetatable(q)==Matrix then
        assert(q:sameshape{4,1},'incorrect shape')
        return Matrix3x3:fromquaternion{w=q[4],x=q[1],y=q[2],z=q[3]}
    elseif #q==4 and q[1] and q[2] and q[3] and q[4] then
        return Matrix3x3:fromquaternion{w=q[4],x=q[1],y=q[2],z=q[3]}
    else
        error('unsupported type')
    end
end

function Matrix3x3:fromeuler(e)
    if e.x and e.y and e.z then
        return Matrix3x3:rotx(e.x)*Matrix3x3:roty(e.y)*Matrix3x3:rotz(e.z)
    elseif getmetatable(e)==Matrix then
        return Matrix3x3:fromeuler{x=e[1],y=e[2],z=e[3]}
    elseif #e==3 and e[1] and e[2] and e[3] then
        return Matrix3x3:fromeuler{x=e[1],y=e[2],z=e[3]}
    else
        error('unsupported type')
    end
end

function Matrix3x3:fromaxisangle(axis,angle)
    axis=axis:normalized()
    local c=math.cos(angle)
    local s=math.sin(angle)
    local t=1.0-c
    local m=Matrix3x3()
    m[1][1]=c+axis[1]*axis[1]*t
    m[2][2]=c+axis[2]*axis[2]*t
    m[3][3]=c+axis[3]*axis[3]*t
    local tmp1=axis[1]*axis[2]*t
    local tmp2=axis[3]*s
    m[2][1]=tmp1+tmp2
    m[1][2]=tmp1-tmp2
    tmp1=axis[1]*axis[3]*t
    tmp2=axis[2]*s
    m[3][1]=tmp1-tmp2
    m[1][3]=tmp1+tmp2
    tmp1=axis[2]*axis[3]*t
    tmp2=axis[1]*s
    m[3][2]=tmp1+tmp2
    m[2][3]=tmp1-tmp2
    return m
end

function Matrix3x3:toquaternion(m,t)
    assert(getmetatable(m)==Matrix,'not a matrix')
    assert(m:sameshape{3,3},'incorrect shape')
    local q={}
    local tr=m:trace()
    if tr>0 then
        local s=math.sqrt(tr+1.0)*2
        q.w=0.25*s
        q.x=(m[3][2]-m[2][3])/s
        q.y=(m[1][3]-m[3][1])/s
        q.z=(m[2][1]-m[1][2])/s
    elseif m[1][1]>m[2][2] and m[1][1]>m[3][3] then
        local s=math.sqrt(1.0+m[1][1]-m[2][2]-m[3][3])*2
        q.w=(m[3][2]-m[2][3])/s
        q.x=0.25*s
        q.y=(m[1][2]+m[2][1])/s
        q.z=(m[1][3]+m[3][1])/s
    elseif m[2][2]>m[3][3] then
        local s=math.sqrt(1.0+m[2][2]-m[1][1]-m[3][3])*2
        q.w=(m[1][3]-m[3][1])/s
        q.x=(m[1][2]+m[2][1])/s
        q.y=0.25*s
        q.z=(m[2][3]+m[3][2])/s
    else
        local s=math.sqrt(1.0+m[3][3]-m[1][1]-m[2][2])*2
        q.w=(m[2][1]-m[1][2])/s
        q.x=(m[1][3]+m[3][1])/s
        q.y=(m[2][3]+m[3][2])/s
        q.z=0.25*s
    end
    q={q.x,q.y,q.z,q.w}
    if t==Matrix then return Vector4{ref=q} end
    return q
end

function Matrix3x3:toeuler(m,t)
    assert(getmetatable(m)==Matrix,'not a matrix')
    assert(m:sameshape{3,3},'incorrect shape')
    local e={
        math.atan2(m:get(3,2),m:get(3,3)),
        math.atan2(-m:get(3,1),math.sqrt(m:get(3,2)*m:get(3,2)+m:get(3,3)*m:get(3,3))),
        math.atan2(m:get(2,1),m:get(1,1)),
    }
    if t==Matrix then return Vector3{ref=e} end
    return e
end

function Matrix3x3:random()
    return Matrix3x3:fromaxisangle(Vector3:unitrandom(),math.random()*math.pi*2)
end

setmetatable(Matrix3x3,{__call=function(self,data)
    return Matrix(3,3,data)
end})

Matrix4x4={}

function Matrix4x4:fromrotation(m)
    assert(getmetatable(m)==Matrix,'not a matrix')
    assert(m:sameshape{3,3},'not a 3x3 matrix')
    local r=Matrix:eye(4)
    for i=1,3 do for j=1,3 do r:set(i,j,m:get(i,j)) end end
    return r
end

function Matrix4x4:fromquaternion(q)
    local r=Matrix3x3:fromquaternion(q)
    return Matrix4x4:fromrotation(r)
end

function Matrix4x4:fromeuler(e)
    local r=Matrix3x3:fromeuler(e)
    return Matrix4x4:fromrt(r,Vector{0,0,0})
end

function Matrix4x4:fromposition(v)
    local r=Matrix:eye(4)
    for i=1,3 do r:set(i,4,v[i]) end
    return r
end

function Matrix4x4:fromrt(r,t)
    assert(r:sameshape{3,3},'r is not a 3x3 matrix')
    assert(t:sameshape{3,1},'t is not a 3x1 matrix')
    local m=Matrix(4,4)
    m:assign(1,1,r)
    m:assign(1,4,t)
    m:set(4,4,1)
    return m
end

function Matrix4x4:frompose(p)
    local m=Matrix4x4:fromquaternion{p[4],p[5],p[6],p[7]}
    m:set(1,4,p[1])
    m:set(2,4,p[2])
    m:set(3,4,p[3])
    return m
end

function Matrix4x4:torotation(m)
    assert(getmetatable(m)==Matrix,'not a matrix')
    assert(m:sameshape{4,4},'not a 4x4 matrix')
    local r=Matrix3x3()
    for i=1,3 do for j=1,3 do r:set(i,j,m:get(i,j)) end end
    return r
end

function Matrix4x4:toquaternion(m,t)
    assert(getmetatable(m)==Matrix,'not a matrix')
    assert(m:sameshape{4,4},'not a 4x4 matrix')
    local r=Matrix4x4:torotation(m)
    return Matrix3x3:toquaternion(r,t)
end

function Matrix4x4:toeuler(m,t)
    assert(getmetatable(m)==Matrix,'not a matrix')
    assert(m:sameshape{4,4},'not a 4x4 matrix')
    local r=Matrix4x4:torotation(m)
    return Matrix3x3:toeuler(r,t)
end

function Matrix4x4:toposition(m,t)
    assert(getmetatable(m)==Matrix,'not a matrix')
    assert(m:sameshape{4,4},'not a 4x4 matrix')
    local d={m:get(1,4),m:get(2,4),m:get(3,4)}
    if t==Matrix then return Vector3{ref=d} end
    return d
end

function Matrix4x4:topose(m,t)
    local p=Matrix4x4:toposition(m)
    local q=Matrix4x4:toquaternion(m)
    local v={p[1],p[2],p[3],q[1],q[2],q[3],q[4]}
    if t==Matrix then return Vector7{ref=v} end
    return v
end

function Matrix4x4:inv(m)
    local rt=m:slice(1,1,3,3):t()
    local t=m:slice(1,4,3,4)
    return Matrix4x4:fromrt(rt,-rt*t)
end

function Matrix4x4:random(m)
    return Matrix4x4:fromrt(Matrix3x3:random(),Vector3:random())
end

setmetatable(Matrix4x4,{__call=function(self,data)
    if type(data)=='table' and #data==12 then
        -- special case of a homogeneous transform matrix from CoppeliaSim
        return Matrix(3,4,data):vertcat(Vector{0,0,0,1}:t())
    end
    return Matrix(4,4,data)
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
    assert(m:count()==12)
    assert(m:sameshape{3,4})
    assert(m:sameshape(Matrix(3,4)))
    assert(m:offset(2,2)==6)
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
    assert(Vector{2.1,7,8.2}//2==Vector{1,3,4})
    assert(Vector{1,2,3}:eq(Vector{1,2,2})==Vector{1,1,0})
    assert(Vector{1,2,3}:ne(Vector{1,2,2})==Vector{0,0,1})
    assert(Vector{1,2,3}:lt(Vector{1,2,2})==Vector{0,0,0})
    assert(Vector{1,2,3}:gt(Vector{1,2,2})==Vector{0,0,1})
    assert(Vector{1,2,3}:le(Vector{1,2,2})==Vector{1,1,0})
    assert(Vector{1,2,3}:ge(Vector{1,2,2})==Vector{1,1,1})
    assert(not Vector{1,2,3}:lt(Vector{1,2,2}):any())
    assert(Vector{1,2,3}:ge(Vector{1,2,2}):all())
    assert(Vector{1,2,3}:le(Vector{1,2,2}):any())
    assert(not Vector{1,2,3}:le(Vector{1,2,2}):all())
    assert(Matrix:where(Vector:range(5):lt(3),Vector{10,20,30,40,50},Vector{5,4,3,2,1})==Vector{10,20,3,2,1})
    assert(Matrix:fromtable{{1,0,0,0}}:t():norm()==1)
    assert(Matrix(3,1,{3,4,0}):norm()==5)
    assert(Matrix:diag{1,2,3}==Matrix(3,3,{1,0,0,0,2,0,0,0,3}))
    assert(Matrix:diag(Vector{1,2,3})==Matrix(3,3,{1,0,0,0,2,0,0,0,3}))
    assert(Vector{1,2,3}==Matrix(3,3,{1,0,0,0,2,0,0,0,3}):diag())
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
    i:set(1,1,9)
    i:set(2,2,9)
    i:set(3,3,9)
    assert(i==Matrix(3,3,{9,1,1,2,9,2,3,3,9}))
    local s=Matrix(3,3,{1,2,3,4,5,6,7,8,9})
    local temp=s:row(1)
    s:setrow(1,s:row(2))
    s:setrow(2,temp)
    assert(s==Matrix(3,3,{4,5,6,1,2,3,7,8,9}))
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
    assert(m5:prod()==423360000)
    assert(m5:prod(1)==Matrix(1,4,{20,200,980,108}))
    assert(m5:prod(2)==Matrix(3,1,{300,2240,630}))
    -- verify copy-on-write:
    a=Matrix(2,2,{10,20,30,40})
    b=a:t():t()
    a[1][1]=11
    b[2][2]=44
    assert(a[1][1]==11)
    assert(b[1][1]==10)
    assert(a[2][2]==40)
    assert(b[2][2]==44)
    -- repeat the above test using :set / :get
    a=Matrix(2,2,{10,20,30,40})
    b=a:t():t()
    a:set(1,1,11)
    b:set(2,2,44)
    assert(a:get(1,1)==11)
    assert(b:get(1,1)==10)
    assert(a:get(2,2)==40)
    assert(b:get(2,2)==44)
    m=Matrix(4,4,{
        11,12,13,14,
        21,22,23,24,
        31,32,33,34,
        41,42,43,44,
    })
    assert(m:slice(2,2,3,3)==Matrix(2,2,{22,23,32,33}))
    assert(m:slice(1,4,2,5)==Matrix(2,2,{14,0,24,0}))
    m:assign(1,2,m:slice(1,1,4,1))
    m:assign(1,3,m:slice(1,1,4,1))
    m:assign(1,4,m:slice(1,1,4,1))
    assert(Matrix(3,3,{1,1,1,2,2,2,3,3,3}):droprow(2)==Matrix(2,3,{1,1,1,3,3,3}))
    assert(Matrix(3,3,{1,1,1,2,2,2,3,3,3}):dropcol(2)==Matrix(3,2,{1,1,2,2,3,3}))
    assert(m==Matrix(4,4,{11,11,11,11,21,21,21,21,31,31,31,31,41,41,41,41}))
    function approxEq(a,b,tol)
        tol=tol or 1e-5
        if type(a)=='number' and type(b)=='number' then
            return math.abs(a-b)<tol
        elseif getmetatable(a)==Matrix and getmetatable(b)==Matrix then
            return (a-b):abs():max()<tol
        elseif type(a)=='table' and type(b)=='table' then
            return approxEq(Vector(a),Vector(b))
        else
            error('incorrect or mismatching type(s)')
        end
    end
    assert(approxEq(m5:mean(),8))
    assert(approxEq(m5:mean(1),Vector{13,27,40,16}:t()/3))
    assert(approxEq(m5:mean(2),Vector{7.25,11,5.75}))
    rot_e=Matrix3x3:fromeuler{0.7853982,0.5235988,1.5707963}
    rot_m=Matrix(3,3,{
        0.0000000,-0.8660254,0.5000000,
        0.7071068,-0.3535534,-0.6123725,
        0.7071068,0.3535534,0.6123725,
    })
    rot_q=Matrix3x3:fromquaternion{0.4304593,-0.092296,0.7010574,0.5609855}
    assert(approxEq(rot_e,rot_m))
    assert(approxEq(rot_e,rot_q))
    assert(approxEq(rot_m,rot_q))
    --assert(approxEq(Matrix3x3:toeuler(rot_m),{0.7853982,0.5235988,1.5707963}))
    assert(approxEq(Matrix3x3:toquaternion(rot_m),{0.4304593,-0.092296,0.7010574,0.5609855}))
    assert(approxEq(Matrix4x4:frompose{0,0,0,0,0,0,1},Matrix:eye(4)))
    assert(approxEq(Matrix3x3:toquaternion(Matrix(3,3,{-1,0,0,0,-1,0,0,0,1})),{0,0,1,0}))
    assert(Matrix(2,2,{1,2,3,4}):kron(Matrix(2,2,{0,5,6,7}))==Matrix(4,4,{0,5,0,10,6,7,12,14,0,15,0,20,18,21,24,28}))
    assert(Matrix(2,3,{1,-4,7,-2,3,3}):kron(Matrix(4,4,{8,-9,-6,5,1,-3,-4,7,2,8,-8,-3,1,2,-5,-1}))==Matrix(8,12,{8,-9,-6,5,-32,36,24,-20,56,-63,-42,35,1,-3,-4,7,-4,12,16,-28,7,-21,-28,49,2,8,-8,-3,-8,-32,32,12,14,56,-56,-21,1,2,-5,-1,-4,-8,20,4,7,14,-35,-7,-16,18,12,-10,24,-27,-18,15,24,-27,-18,15,-2,6,8,-14,3,-9,-12,21,3,-9,-12,21,-4,-16,16,6,6,24,-24,-9,6,24,-24,-9,-2,-4,10,2,3,6,-15,-3,3,6,-15,-3}))
    assert(Vector{1,1,1}:all())
    assert(not Vector{1,0,1}:all())
    assert(Vector{1,0,1}:any())
    assert(not Vector{0,0,0}:any())
    assert(Matrix:fromtable(Matrix(3,3,{0,1,0,0,1,0,0,0,1}):nonzero())==Matrix(3,2,{1,2,2,2,3,3}))
    assert(Matrix:fromtable(Vector{1,0,2}:nonzero())==Matrix(2,2,{1,1,3,1}))
    assert(approxEq(Vector:geomspace(1,1000,4),Vector{1,10,100,1000}))
    assert(approxEq(Vector:geomspace(1,1000,3,false),Vector{1,10,100}))
    assert(approxEq(Vector:geomspace(1,1000,4,false),Vector{1,5.62341325,31.6227766,177.827941}))
    assert(approxEq(Vector:logspace(2,3,4),Vector{100,215.443469,464.15888336,1000}))
    assert(approxEq(Vector:logspace(2,3,4,false),Vector{100,177.827941,316.22776602,562.34132519}))
    assert(approxEq(Vector:logspace(2,3,4,true,2),Vector{4,5.0396842,6.34960421,8}))
    m=Matrix(4,4,function(i,j) return 10*i+j end)
    i,j=Matrix(2,2,{1,1,2,2}),Matrix(2,2,{1,2,3,4})
    assert(m:at(i,j)==Matrix(2,2,{11,12,23,24}))
    assert(Matrix:horzcat(Vector{1,0,0},Vector{0,1,0},Vector{0,0,1})==Matrix:eye(3))
    assert(Matrix:vertcat(Matrix:ones(4,3),Matrix:eye(3)):col(2)==Vector{1,1,1,1,0,1,0})
    assert(Matrix:ones(2,3):applyfuncidx(function(i,j,x) return 100*x+10*i+j end)==Matrix(2,3,{111,112,113,121,122,123}))
    assert(Matrix:ones(2,3):applyfunc(function(x) return 100*x end)==Matrix(2,3,{100,100,100,100,100,100}))
    assert(Matrix:ones(2,2):applyfunc2(Matrix:eye(2),function(x,y) return x-2*y end)==Matrix(2,2,{-1,1,1,-1}))
    assert(Vector{1,2,3}:binop(Vector{4,5,6},function(x,y) return 2*x-y end)==Vector{-2,-1,0})
    assert(Vector{-1,0,90,-4}:abs()==Vector{1,0,90,4})
    assert(Vector{-0.6,0.3}:acos()==Vector{math.acos(-0.6),math.acos(0.3)})
    assert(-24==Matrix(4,4,{1,3,0,1,0,0,3,2,2,0,3,2,1,2,1,0}):det())
    assert(0==Matrix(4,4,{0,0,0,0,1,0,3,3,1,1,1,3,1,0,3,1}):det())
    assert(-22==Matrix(5,5,{3,2,2,1,3,0,3,0,1,3,3,0,4,3,2,2,2,1,2,2,4,3,3,1,4}):det())
    for n,c in ipairs{0,1000,1000,500,200,100,30,10} do
        for i=1,c do
            local m=Matrix(n,n):random(-10,10)
            g,d=m:gauss()
            --assert(approxEq(m:det(),d)) -- meaningful only if using slow :det implementation
            if math.abs(d)>1e-5 then
                i=m:inv()
                assert(approxEq(i*m,Matrix:eye(n)))
                assert(approxEq(m*i,Matrix:eye(n)))
            end
        end
    end
    for i=1,1000 do
        local m=Matrix4x4:random()
        local mi=Matrix4x4:inv(m)
        assert(approxEq(m*mi,Matrix:eye(4)))
        assert(approxEq(mi*m,Matrix:eye(4)))
    end
    print('tests passed')
end
