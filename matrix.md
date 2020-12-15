# matrix.lua - A linear algebra library for lua

## User guide

### Initialization

Create a matrix with:

```
> m=Matrix(2,3,{11,12,13,21,22,23})
```

(creates a 2 rows by 3 columns matrix filled with the specified data in row-major order)

Use the [`:rows`](#matrixrows) and [`:cols`](#matrixcols) methods to know the dimensions of a matrix:

```
> m:rows(), m:cols()
2	3
```

Matrices are converted to a lua representation (e.g. with `tostring()`):

```
> m
Matrix(2,3,{11,12,13,21,22,23})
```

or can be printed with the [`:print`](#matrixprint) method:

```
> m:print()
 11 12 13
 21 22 23
```

The `data` argument of the [`Matrix`](#matrixrowscolsdata) constructor can be omitted, in which case the matrix will be filled with zeros:

```
> Matrix(2,2)
Matrix(2,2,{0,0,0,0})
```

There are additional constructors for special type of matrices:
- [`Matrix3x3([data])`](#matrix3x3data) creates a 3x3 matrix
- [`Matrix4x4([data])`](#matrix4x4data) creates a 4x4 matrix
- [`Vector(n[,data])`](#vectorlendata) creates a `n`-dimensional vector (works also with [`Vector(data)`](#vectordata) in which case the dimension is guessed from table size)
- [`Vector3([data])`](#vector3data) creates a 3-dimensional vector
- [`Vector4([data])`](#vector4data) creates a 4-dimensional vector
- [`Vector7([data])`](#vector7data) creates a 7-dimensional vector

All the above constructors return an object of type `Matrix`:

```
> Vector3{1,0,0}
Matrix(3,1,{1,0,0})
```

Note: vectors are intended as *column vectors*.

The `data` argument can be a function with parameters `i`, `j`:

```
> Matrix(2,2,function(i,j) return 100*i+j end):print()
 101 102
 201 202
```

There are some convenience constructors for creating commonly used matrices:

- [`Matrix:eye(n)`](#matrixeyen) creates a `n`x`n` identity matrix
- [`Matrix:ones(m,n)`](#matrixonesrowscols) creates a `m`x`n` matrix of ones
- [`Matrix:zeros(m,n)`](#matrixzerosrowscols) creates a `m`x`n` matrix of zeros

### Basic operations

Addition with scalars:

```
> Vector{1,2,3}+1
Matrix(3,1,{2,3,4})
```

Multiplication with scalars:

```
> Vector{1,2,3}*10
Matrix(3,1,{10,20,30})
```

Matrix addition (size must match):

```
> Vector{1,0,0}+Vector{10,20,30}
Matrix(3,1,{11,20,30})
```

Matrix multiplication (dimensions must be compatible):

```
> rotate=Matrix3x3{
>> 0,1,0,
>> 0,0,1,
>> 1,0,0,
>> }
> rotate*Vector{1,2,3}
Matrix(3,1,{2,3,1})
```

Other supported operators are: scalar and matrix subtraction (`a-b`), scalar division (`m/k`), unary minus (`-a`), table length (`#a`, returns the number of rows), iteration (`ipairs(a)`).

Matrices can be transposed (rows and columns will be swapped) with the [`:t`](#matrixt) method:

```
> v=Vector{1,2,3}
> v:print()
 1
 2
 3
> v=v:t()
> v:print()
 1 2 3
```

### Getting and setting data

Use [`:get`](#matrixgetij) and [`:set`](#matrixsetijvalue) to read and write elements:

```
> m=Matrix(2,3,{11,12,13,21,22,23})
> m:get(2,1)
21
> m:set(2,1,4000)
> m:print()
   11   12   13
 4000   22   23
```

Methods [`:row`](#matrixrowi) and [`:col`](#matrixcolj) can access rows and columns:

```
> m:row(2)
Matrix(1,3,{4000,22,23})
```

Methods [`:setrow`](#matrixsetrowim) and [`:setcol`](#matrixsetcoljm) can modify whole rows or columns:

```
> m:setrow(2,Matrix:zeros(1,3))
> m:print()
 11 12 13
  0  0  0
> m:setcol(3,Matrix:ones(2,1))
> m:print()
 11 12  1
  0  0  1
```

It is possible to use square brackets to get and set elements:

```
> m[1][1]
11
> m[1][1]=99
> m:print()
 99 12  1
  0  0  1
```

### Variables assignment and copy

Variable assignment simply creates another reference to the same object, just like normal tables:

```
> a=Vector{100,200}
> b=a
> b:set(2,1,300)
> b
Matrix(2,1,{100,300})
> a
Matrix(2,1,{100,300})
```

To create a copy, use the [`:copy`](#matrixcopy) method:

```
> a=Vector{100,200}
> b=a:copy()
> b:set(2,1,300)
> b
Matrix(2,1,{100,300})
> a
Matrix(2,1,{100,200})
```

### Slicing and assigning

It is possible to get a portion of a matrix with [`:slice`](#matrixslicefromrowfromcoltorowtocol). Parameters are: start row, start column, end row, end column.

```
> m=Matrix:eye(3)
> m:print()
 1 0 0
 0 1 0
 0 0 1
> m:slice(1,2,2,3):print()
 0 0
 1 0
```

The [`:slice`](#matrixslicefromrowfromcoltorowtocol) method can also create a matrix which is bigger than the original:

```
> m:slice(1,1,3,5):print()
 1 0 0 0 0
 0 1 0 0 0
 0 0 1 0 0
```

It is possible to copy data from a matrix of different size with [`:assign`](#matrixassignstartrowstartcolm). Parameters are start row, start column, matrix.

```
> m:assign(1,2,5*Matrix:ones(2,2))
> m:print()
 1 5 5
 0 5 5
 0 0 1
```

### In-place operations

Normally, all the methods return a new matrix, so the original data is not affected.

There are a few methods that are an exception to this rule:

- [`Matrix:set(i,j,value)`](#matrixsetijvalue) modifies the specified element in place.
- [`Matrix:rowref(i)`](#matrixrowrefi) returns a *row reference*. Modifying data in the returned row modifies also the original matrix. Use [`Matrix:row(i)`](#matrixrowi) to avoid side-effect.
- [`Matrix:setrow(i,mtx)`](#matrixsetrowim) modifies the specified row.
- [`Matrix:setcol(j,mtx)`](#matrixsetcoljm) modifies the specified column.
- [`Matrix:assign(startrow,startcol,mtx)`](#matrixassignstartrowstartcolm) sets elements of this matrix, copying the values from `mtx`.

### Converting to/from tables

A 2-dimensional lua table can be converted to a matrix and vice-versa:

```
> tbl={
>> {1,2,3},
>> {4,5,6},
>> }
> m=Matrix:fromtable(tbl)
> m
Matrix(2,3,{1,2,3,4,5,6})
> m:print()
 1 2 3
 4 5 6
> tbl1=m:totable()
> #tbl1
2
> #tbl1[2]
3
> tbl1[2][1], tbl1[2][2], tbl1[2][3]
4	5	6
```

## Functions reference

#### `Matrix(rows,cols,data)`

Returns a new matrix of size `rows`x`cols`. If `data` is provided (table) the matrix will be initialized with the given data (row-major order). If `data` is a function, each element at position `i`, `j` will be initialized with the value returned by calling `data(i,j)`.

#### `Matrix:abs()`

Returns element-wise absolute value.

#### `Matrix:acos()`

Returns element-wise inverse-cosine value.

#### `Matrix:applyfunc(f)`

Returns element-wise result of function `f(x)` where `x` is if the element value.

#### `Matrix:applyfunc2(m,f)`

Returns element-pairwise result of function `f(x,y)` where `x` is the element of `self` and `y` is the element of `m` in the same position.

#### `Matrix:applyfuncidx(f)`

Returns element-wise result of function `f(i,i,x)` where `i`, `j` are element's row and column indices respectively, and `x` the element's value.

#### `Matrix:asin()`

Returns element-wise inverse-sine value.

#### `Matrix:assign(startrow,startcol,m)`

[modifies current matrix]

Copies values from matrix `m`. Element `m[1+i][1+j]` will be copied to position `startrow+i`, `startcol+j` for `i`=0,...,`m:rows()-1` and `j`=0,...,`m:cols()-1`.

Returns the matrix itself.

#### `Matrix:atan(m)`

Returns element-wise inverse-tangent value.

#### `Matrix:ceil()`

Returns element-wise ceil (smallest integral value larger than or equal to x).

#### `Matrix:col(j)`

Returns the `j`-th column.

#### `Matrix:cols()`

Returns the number of columns.

#### `Matrix:copy()`

Returns a copy of the matrix.

#### `Matrix:cos()`

Returns element-wise cosine value.

#### `Matrix:count()`

Returns the number of elements (rows * cols).

#### `Matrix:cross(m)`

Returns the cross product with 3d vectors `m`.

#### `Matrix:data()`

Returns data as a table in row-major order.

#### `Matrix:deg()`

Returns element-wise conversion from radians to degrees.

#### `Matrix:diag()`

Returns the vector of eements on the main diagonal.

#### `Matrix:dot(m)`

Returns the dot product with vector `m`.

#### `Matrix:exp()`

Returns element-wise exponential.

#### `Matrix:eye(n)`

Returns a `n`x`n` identity matrix.

#### `Matrix:floor()`

Returns element-wise floor (largest integral value smaller than or equal to x).

#### `Matrix:fmod(m)`

Returns element-wise fmod (remainder of the division of x by y that rounds the quotient towards zero) with `m`, which can be a matrix of the same size or a number.

#### `Matrix:fromtable(t)`

Returns a matrix with data from the 2d table `t`.

#### `Matrix:get(i,j)`

Returns the element's value at row `i` column `j`. Returns `nil` if `i` or `j` are out of range.

#### `Matrix:horzcat(m)`

Returns the matrix obtained by concatenating with `m` horizontally.

#### `Matrix:log(base)`

Returns element-wise logarithm. If `base` is specified, the logarithm will be computed in the specified base. The `base` argument can be a matrix of the same size or a number.

#### `Matrix:max()`

Returns `maxval`, `i`, `j` where `maxval` is the global maximum value of the matrix, and `i`, `j` its row and column indices.

#### `Matrix:max(dim)`

Returns a column-wise (`dim` = 1) or row-wise (`dim` = 2) maximum.

#### `Matrix:max(m)`

Returns pair-wise maximum with matrix `m` which must have the same size.

#### `Matrix:mean()`

Returns the mean of all the values.

#### `Matrix:mean(dim)`

Returns the column-wise (`dim` = 1) or row-wise (`dim` = 2) mean.

#### `Matrix:min()`

Returns `minval`, `i`, `j` where `minval` is the global minimum value of the matrix, and `i`, `j` its row and column indices.

#### `Matrix:min(dim)`

Returns a column-wise (`dim` = 1) or row-wise (`dim` = 2) minimum.

#### `Matrix:min(m)`

Returns pair-wise minimum with matrix `m` which must have the same size.

#### `Matrix:norm()`

Returns the vector norm of this vector.

#### `Matrix:offset(i,j)`

Returns the data offset for indices `i`, `j`. Returns `nil` if `i` or `j` are out of range.

#### `Matrix:ones(rows,cols)`

Returns a `rows`x`cols` matrix of ones.

#### `Matrix:print(elemwidth)`

Print the matrix.

#### `Matrix:rad()`

Returns element-wise conversion from degrees to radians.

#### `Matrix:random()`

Returns element-wise random numbers.

#### `Matrix:random(a)`

Returns element-wise random numbers between 1 and `a`.

#### `Matrix:random(a,b)`

Returns element-wise random numbers between `a` and `b`.

#### `Matrix:row(i)`

Returns the `i`-th row.

#### `Matrix:rowref(i)`

Returns a *reference* to the `i`-th row.

Can allow modifying the current matrix: use with caution.

#### `Matrix:rows()`

Returns the number of rows.

#### `Matrix:sameshape(m)`

Returns true if `m` has the same shape (number of rows and columns) of this matrix.

#### `Matrix:sameshape(rows,cols)`

Returns true if `m` has the given shape of `rows` and `columns`.

#### `Matrix:set(i,j,value)`

[modifies current matrix]

Sets the element's value at row `i` column `j`. Has no effect if `i` or `j` are out of range.

Returns the matrix itself.

#### `Matrix:setcol(j,m)`

[modifies current matrix]

Sets the `j`-th column with values from `m` (must be a column vector, in which case row count must match, or must be a table).

Returns the matrix itself.

#### `Matrix:setrow(i,m)`

[modifies current matrix]

Sets the `i`-th row with values from `m` (must be a row vector, in which case column count must match, or must be a table).

Returns the matrix itself.

#### `Matrix:sin()`

Returns element-wise sine value.

#### `Matrix:slice(fromrow,fromcol,torow,tocol)`

Returns a matrix obtained by copying the values from this matrix, starting at `fromrow`, `fromcol` and ending at `torow`, `tocol`.

#### `Matrix:sqrt()`

Returns element-wise square root value.

#### `Matrix:sum()`

Returns the sum of all the values.

#### `Matrix:sum(dim)`

Returns the column-wise (`dim` = 1) or row-wise (`dim` = 2) sum.

#### `Matrix:t()`

Returns a transposed matrix.

#### `Matrix:tan()`

Returns element-wise tangent value.

#### `Matrix:tointeger()`

Returns element-wise integer value.

#### `Matrix:totable(format)`

Returns a 2d table representation of this matrix.

#### `Matrix:ult(m2)`

Returns the element-wise ult (true if and only if integer m is below integer n when they are compared as unsigned integers) value.

#### `Matrix:vertcat(m)`

Returns the matrix obtained by concatenating with `m` vertically.

#### `Matrix:zeros(rows,cols)`

Returns a `rows`x`cols` matrix of zeros.

#### `Matrix3x3(data)`

Returns a new matrix of size 3x3 initialized with data from `data` (see [`Matrix(rows,cols,data)`](#matrixrowscolsdata) for how `data` is interpreted).

#### `Matrix3x3:fromeuler(e)`

Returns a rotation matrix from euler angles.

#### `Matrix3x3:fromquaternion(q)`

Returns a rotation matrix from quaternion.

#### `Matrix3x3:rotx(angle)`

Returns a rotation matrix from rotation around X axis.

#### `Matrix3x3:roty(angle)`

Returns a rotation matrix from rotation around Y axis.

#### `Matrix3x3:rotz(angle)`

Returns a rotation matrix from rotation around Z axis.

#### `Matrix3x3:toeuler(m,t)`

Returns a table of euler angles computed from this rotation matrix.

Pass `Matrix` as parameter `t` to get the result as a `Matrix` object.

#### `Matrix3x3:toquaternion(m,t)`

Returns a unit quaternion (table) computed from this rotation matrix.

Pass `Matrix` as parameter `t` to get the result as a `Matrix` object.

#### `Matrix4x4(data)`

Returns a new matrix of size 4x4 initialized with data from `data` (see [`Matrix(rows,cols,data)`](#matrixrowscolsdata) for how data is interpreted).

#### `Matrix4x4:fromeuler(e)`

Returns a transformation matrix from euler angles (null translation).

#### `Matrix4x4:frompose(p)`

Returns a transformation matrix from the given pose (a 7-dimensional vector, first 3 values for translation, last 4 values for rotation as unit quaternion).

#### `Matrix4x4:fromposition(v)`

Returns a transformation matrix from translation (null rotation).

#### `Matrix4x4:fromquaternion(q)`

Returns a transformation matrix from unit quaternion (null translation).

#### `Matrix4x4:fromrotation(m)`

Returns a transformation matrix from rotation matrix (null translation).

#### `Matrix4x4:toeuler(m,t)`

Returns a table of euler angles computed from the rotation matrix of this transformation matrix.

Pass `Matrix` as parameter `t` to get the result as a `Matrix` object.

#### `Matrix4x4:topose(m,t)`

Returns the pose (a 7-dimensional table, first 3 values for translation, last 4 values for rotation as unit quaternion) computed from this transformation matrix.

Pass `Matrix` as parameter `t` to get the result as a `Matrix` object.

#### `Matrix4x4:toposition(m,t)`

Returns the translation vector (table) computed from this transformation matrix.

Pass `Matrix` as parameter `t` to get the result as a `Matrix` object.

#### `Matrix4x4:toquaternion(m,t)`

Returns the unit quaternion (table) computed from the rotation matrix of this transformation matrix.

Pass `Matrix` as parameter `t` to get the result as a `Matrix` object.

#### `Matrix4x4:torotation(m)`

Returns the rotation matrix of this transformation matrix.

#### `Vector(len,data)`

Returns a new matrix of size `len`x`1` (i.e. a vector) initialized with data from `data` (see [`Matrix(rows,cols,data)`](#matrixrowscolsdata) for how data is interpreted).

#### `Vector(data)`

Shortcut for `Vector(#data,data)`. See [`Vector(len,data)`](#vectorlendata).

#### `Vector3(data)`

Same as `Vector(3,data)`. See [`Vector(len,data)`](#vectorlendata).

#### `Vector4(data)`

Same as `Vector(4,data)`. See [`Vector(len,data)`](#vectorlendata).

#### `Vector7(data)`

Same as `Vector(7,data)`. See [`Vector(len,data)`](#vectorlendata).

