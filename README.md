# DiagonalIndexing.jl 
**DiagonalIndexing** provides a convenient, flexible way of selecting array diagonals in indexing expressions.

## Introduction
Julia's built-in support for diagonal indexing is rather limited.  The `diag` function allows one to extract the diagonal of a matrix, but cannot be used to assign to the diagonal.  The `diagind` function returns the indices of the diagonal elements, which are usually not themsleves of interest.  Furthermore, built-in support for diagonal indexing is limited to matrices (2-dimensional arrays).

This package provides a more convenient and flexible approach to diagonal indexing.  In brief, the constant `diagnl` may be used in the index list to select the main diagonal of any array. Similarly, `Diagnl(o_1,...,o_N)` may be used in the place of N indices to select a diagonal offset by (o_1,...,o_N) elements along N consecutive axes. Such a "diagonal index" may occur anywhere in an index list and in combination with other indices.  Indexing diagonals in this way is essentially as fast as indexing with ranges or explicit lists of indices.


## Usage

Use the exported constant `diagnl` as an index to select the main diagonal of an array:
```
julia>  A = [1 2 3; 4 5 6; 7 8 9; 10 11 12]
4×3 Matrix{Int64}:
  1   2   3
  4   5   6
  7   8   9
 10  11  12

julia> A[diagnl]
3-element Vector{Int64}:
 1
 5
 9

 julia> A[diagnl] = [-1, -5, -9]; A
 4×3 Matrix{Int64}:
 -1   2   3
  4  -5   6
  7   8  -9
 10  11  12
```
`diagnl` can also be used as the last of multiple indices to select the main diagonal on the remaining axes.

More generally, `Diagnl(o1,...,oN)` represents a diagonal on `N` consecutive axes, starting with element `[begin+o1, ..., begin+oN]`:
```
julia> A[Diagnl(0,1)]      
2-element Vector{Int64}:
 2
 6
```
 `Diagnl(0,...,0)` represents the main diagonal, and can be obtained by the alternative (in some cases, shorter) constructor `Diagnl{N}()`.
 
 Unlike `diagnl`, instances of `Diagnl` with specific dimensionality can be used at any position in an indexing expression:
```
juila> B = [i+10j+100k for i=1:4, j=1:3, k=1:3]
4×3×3 Array{Int64, 3}:
[:, :, 1] =
 111  121  131
 112  122  132
 113  123  133
 114  124  134

 ⋮

[:, :, 3] =
 311  321  331
 312  322  332
 313  323  333
 314  324  334

juila> B[Diagnl(0,0), 3]   
3-element Vector{Int64}:
 311
 322
 333
``` 


## Usage Details

* When applied to a set of axes, `Diagnl(o1,o2,...)` nominally maps to `[CartesianIndex(first[1]+o1, first[2]]+o2,...), ..., CartesianIndex(first[1]+o1+k, first[2]+o2+k, ...)]` where `first[j]` denotes the first index of the `j`th axis and `k` is the largest value such that the all the indices are in the range of their corresponding axes.

* Whereas the diagonal of an $n\times 1$ matrix is just the first element, the "diagonal" of a vector (1-dimensional array) is the vector itself.

* `diagnl` is an alias for `Diagnl{Any}()`.

## Implementation Details

`DiagonalIndexing` exploits the fact that Julia allows any type of value to be used an index, so long as methods are provided to translate that value into a range or collections of integers.
This package extends the Base function `to_indices` to translate instances of `Diagnl` to appropriate ranges of indices of the targeted array.

In the general case, a `Diagnl` index is translated to a vector of `CartesianIndex` values, e.g. 
```
[CartesianIndex((1,1,...)), CartesianIndex((2,2,...)), ...]
```
However, this array is not explicitly constructed.  Instead, a custom virtual array type is used to produce the `CartesianIndex` values on demand.

If the index style of the array is `IndexLinear` and the `Diagnl` index is the only index, it is translated to a range `firstindex(A)+offset:step:lastindex(A)` for suitable values of `offset` and `step`.