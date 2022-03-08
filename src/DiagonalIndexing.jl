"""
Provides a convenient way of selecting diagonal elements of arrays.
"""
module DiagonalIndexing
export diagonal

# TODO:  Generalize to multidimensional arrays


import Base: getindex, to_indices, IndexStyle, index_ndims, checkbounds, size, length


# First, a helper type.
#
# For arrays whose index style is IndexCartesion, to_indices must return a
# a collection of CartesionIndex's.  Instantiating a vector is slow, and
# we cannot use a generator; the collection must be <: AbstractArray.
# Thus, we define a type of lazy array of CartesianIndex's.

struct DiagCartesianIndices <: AbstractArray{Int64,1} 
	ax::NTuple{2, Base.OneTo{Int64}}
end


# indexing by a linear index returns a CartesianIndex
function getindex(ind::DiagCartesianIndices, i::Int)
	t = getindex.(ind.ax, i)
	CartesianIndex(t)
end

# Define additional indexing properties
IndexStyle(::DiagCartesianIndices) = IndexLinear()
length(ind::DiagCartesianIndices) = min(length(ind.ax[1]), length(ind.ax[2]))
size(ind::DiagCartesianIndices) = (length(ind),)

# By construction, DiagCartesianIndices are always inbounds
checkbounds(A::AbstractArray, ::DiagCartesianIndices) = nothing

# The returned CartesianIndex occupies 2 index positions
@inline index_ndims(::DiagCartesianIndices) = (true, true)



# The main export


"""
Singleton type representing the diagonal of an array.
"""
struct DiagonalIndex
end


"""
Singleton object that, when used as an index, selects the diagonal
elements of an array.

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
"""
const diagonal = DiagonalIndex()


# Implement the indexing behavior

to_indices(A::AbstractMatrix, d::Tuple{DiagonalIndex}) = _to_indices(IndexStyle(A), A, d)

function _to_indices(::IndexLinear, A::AbstractMatrix, ::Tuple{DiagonalIndex})
	(m, n) = size(A)
	(1:m+1:m*min(m,n),)
end


function _to_indices(::IndexCartesian, A::AbstractMatrix, ::Tuple{DiagonalIndex})
	(DiagCartesianIndices(axes(A)),)
end

end # module
