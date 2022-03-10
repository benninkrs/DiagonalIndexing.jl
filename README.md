# DiagonalIndexing.jl
**DiagonalIndexing** provides a convenient, intuitive way of reading and assigning array diagonals.

## Motivation
Julia's built-in `diag` function is a convenient way to read the diagonal elements of a matrix, but it cannot be used to assign to the diagonal of a matrix:
```
A = rand(4,4)
diag(A) = [1, 2, 3, 4]		# error
```
Also, `diag` cannot be used on arrays of dimension greater than 2.

## Usage
This package exports a constant, `diagonal`, which can be used in any indexing expressing to refer to the diagonal elements of an array, much as `begin` and `end` refer to the first and last elements of an array:

```
julia> using DiagonalIndexing

julia> A = [1 2 3; 4 5 6; 7 8 9; 10 11 12]
4×3 Matrix{Int64}:
  1   2   3
  4   5   6
  7   8   9
 10  11  12

julia> A[diagonal]
3-element Vector{Int64}:
 1
 5
 9

julia> A[diagonal] = [-10, -50, -90];

julia> A
4×3 Matrix{Int64}:
 -10    2    3
   4  -50    6
   7    8  -90
  10   11   12
```

`diagonal` is performant and can be used with any type of `AbstractArray` that supports either linear or Cartesian indexing, including multidimensional arrays and arrays with custom axes.  For multidimensional arrays, `A[diagonal]` refers to the vector `[A[1,1,..], A[2,2,..], .., A[k,k,..]]` where `k = minimum(size(A))`.

The two main usage restrictions are:
* `diagonal` cannot be used in conjunction with any other indices (as one might expect).
* Broadcasting with `diagonal` is not currently supported.

## Implementation Details
Whenever an indexing expression is encountered, the built-in function `to_indices` is called to convert the index (whatever type it is) into a collection of natively-supported indices. `DiagonalIndexing` first defines a singleton type `DiagonalIndex`, whose sole instance is `diagonal`. It then extends `to_indices` with methods to convert `diagonal` to an explicit collection of indices corresponding to the diagonal elements of the input array.

For an array `A` whose index style is `IndexLinear`, `diagonal` is converted to `1:stride:length(A)` for an appropriate value of `stride`.

If the index style is `IndexCartesian`, a bit more work is needed.  In principle the `diagonal` could be converted to an array of `CartesianIndex`es, e.g. 
```
[CartesianIndex((1,1,...)), CartesianIndex((2,2,...)), ...]
```
but instantiating such an array is inefficient. To avoid this, a special lazy array type is defined that produces the individual `CartesianIndex` elements on-the-fly as the destination vector is populated.