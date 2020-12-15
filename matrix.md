# matrix.lua - A linear algebra library for lua

## User guide

### Initialization

You can create a matrix with:

```
> m=Matrix(2,3,{11,12,13,21,22,23})
```

(creates a 2 rows by 3 columns matrix filled with the specified data in row-major order)

Use the `:rows` and `:cols` methods to know the dimensions of a matrix:

```
> m:rows(), m:cols()
2	3
```

Matrices are converted to a lua representation (e.g. with `tostring()`):

```
> m
Matrix(2,3,{11,12,13,21,22,23})
```

or can be printed with the `:print` method:

```
> m:print()
 11 12 13
 21 22 23
```

The `data` argument of the `Matrix` constructor can be omitted, in which case the matrix will be filled with zeros:

```
> Matrix(2,2)
Matrix(2,2,{0,0,0,0})
```

There are additional constructors for special type of matrices:
- `Matrix3x3([data])` creates a 3x3 matrix
- `Matrix4x4([data])` creates a 4x4 matrix
- `Vector(n[,data])` creates a `n`-dimensional vector (works also with `Vector(data)` in which case the dimension is guessed from table size)
- `Vector3([data])` creates a 3-dimensional vector
- `Vector4([data])` creates a 4-dimensional vector
- `Vector7([data])` creates a 7-dimensional vector

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

- `Matrix:eye(n)` creates a `n`x`n` identity matrix
- `Matrix:ones(m,n)` creates a `m`x`n` matrix of ones
- `Matrix:zeros(m,n)` creates a `m`x`n` matrix of zeros

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

Matrices can be transposed (rows and columns will be swapped) with the `:t` method:

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

### Assignment and copy

Assignment simply creates another reference to the same object, just like normal tables:

```
> a=Vector{100,200}
> b=a
> b:set(2,1,300)
> b
Matrix(2,1,{100,300})
> a
Matrix(2,1,{100,300})
```

To create a copy, use the `:copy` method:

```
> a=Vector{100,200}
> b=a:copy()
> b:set(2,1,300)
> b
Matrix(2,1,{100,300})
> a
Matrix(2,1,{100,200})
```

### Getting and setting data

Use `:get` and `:set` to read and write elements:

```
> m=Matrix(2,3,{11,12,13,21,22,23})
> m:get(2,1)
21
> m:set(2,1,4000)
> m:print()
   11   12   13
 4000   22   23
```

Methods `:row` and `:col` can access rows and columns:

```
> m:row(2)
Matrix(1,3,{4000,22,23})
```

Methods `:setrow` and `:setcol` can modify whole rows or columns:

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

### Slicing and assigning

It is possible to get a portion of a matrix with `:slice`. Parameters are: start row, start column, end row, end column.

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

The `:slice` mathod can also create a matrix which is bigger than the original:

```
> m:slice(1,1,3,5):print()
 1 0 0 0 0
 0 1 0 0 0
 0 0 1 0 0
```

It is possible to copy data from a matrix of different size with `:assign`. Parameters are start row, start column, matrix.

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

- `Matrix:set(i,j,value)` modifies the specified element in place.
- `Matrix:rowref(i)` returns a *row reference*. Modifying data in the returned row modifies also the original matrix. Use `Matrix:row(i)` to avoid side-effect.
- `Matrix:setrow(i,mtx)` modifies the specified row.
- `Matrix:setcol(j,mtx)` modifies the specified column.
- `Matrix:assign(startrow,startcol,mtx)` sets elements of this matrix, copying the values from `mtx`.
