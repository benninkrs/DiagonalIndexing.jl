# DiagonalIndexing.jl 
**DiagonalIndexing** provides a convenient, flexible way of selecting array diagonals in indexing expressions.

## Introduction
Julia's built-in support for diagonal indexing is rather limited.  The `diag` function allows one to extract the diagonal of a matrix, but cannot be used to assign to the diagonal.  The `diagind` function returns the indices of the diagonal elements, which are usually not themselves of interest.  Furthermore, built-in support for diagonal indexing is limited to matrices (2-dimensional arrays).

This package provides a more convenient and flexible approach to diagonal indexing.  In brief, `diagonal` may be used as an index to select the main diagonal of any `AbstractArray` (even with custom axes). More generally, `diagonal(o_1,...,o_N)` may be used in the place of N index slots to select a diagonal offset by `(o_1,...,o_N)` elements on `N` consecutive axes. Such a "diagonal index" may occur anywhere in an index list and in combination with other indices.  Indexing diagonals in this way is nearly as fast as indexing with ranges or explicit lists of indices.


## Usage

Use the exported constant `diagonal` as the sole index to select the main diagonal of an array:
```
julia>  A = [1 2 3; 4 5 6; 7 8 9; 10 11 12]
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

 julia> A[diagonal] = [-1, -5, -9]; A
 4×3 Matrix{Int64}:
 -1   2   3
  4  -5   6
  7   8  -9
 10  11  12
```
`diagonal` can also be used as the _last_ of multiple indices to select the main diagonal on the remaining axes.

More generally, `diagonal(o1,...,oN)` selects a diagonal on `N` consecutive axes, starting with element `[begin+o1, ..., begin+oN]`:
```
julia> A[diagonal(0,1)]      
2-element Vector{Int64}:
 2
 6
```
 `diagonal(0,...,0)` represents the main diagonal.  Because the number of axes involved is explicit, `diagonal(...)` can be used at any position in an index list:
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

juila> B[diagonal(0,0),3]   
3-element Vector{Int64}:
 311
 322
 333

juila> B[4,diagonal(1,0)]   
2-element Vector{Int64}:
 124
 234
``` 

## Usage Details

When used as an index, `diagonal(o1,o2,...)` is effectively mapped to `[CartesianIndex(begin[1]+o1, begin[2]+o2,...), ..., CartesianIndex(begin[1]+o1+k, begin[2]+o2+k, ...)]` where `first[j]` denotes the first index of the `j`th axis and `k` is the largest value such that the all the indices are in the range of their corresponding axes.  From this definition it follows that:

* The "diagonal" of a vector (1-dimensional array) is the vector itself.

* If the last `N` axes of an array are indexed by a diagonal specifying more than `N` axes, the extra axes are treated as having size 1.  Thus if all the offsets in the extra axes are zero the selected diagonal will have length 1; otherwise the diagonal will have length 0.  

* Indexing with `diagonal` always yields an array (never a scalar).

As an alternative to `diagonal(0,...,0)`, the equivalent (and in some cases shorter) construct `DiagIndex{N}()` may be used.


## Implementation Details

`DiagonalIndexing` exploits the fact that Julia allows any type of value to be used an index, so long as methods are provided to translate that value into a collection of integer or Cartesian indices.  `diagonal` is a function that constructs an instance of `DiagIndex{N}`, which represents a diagonal on `N` axes.  The Base function `to_indices` is extended to translate instances of `DiagIndex` to the appropriate ranges of indices of the targeted array.  In the general case, a `DiagIndex` instance is translated to a vector of `CartesianIndex` values, e.g. 
```
[CartesianIndex((1,1,...)), CartesianIndex((2,2,...)), ...]
```
However, this array is not explicitly constructed.  Instead, a custom virtual array type is used to produce the `CartesianIndex` values on demand.

If the index style of the array is `IndexLinear` and the `diagonal` index is the only index, it is translated to a range.
