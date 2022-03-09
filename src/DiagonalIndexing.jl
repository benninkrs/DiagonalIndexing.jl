"""
Provides a convenient way of selecting diagonal elements of arrays.
"""
module DiagonalIndexing
export diagonal


import Base: getindex, to_indices, IndexStyle, index_ndims, checkbounds, size, length


# First, a helper type.
#
# For arrays whose index style is IndexCartesion, to_indices must return a
# a collection of CartesionIndex's.  Instantiating a vector is slow, and
# we cannot use a generator; the collection must be <: AbstractArray.
# Thus, we define a type of lazy array of CartesianIndex's.

struct DiagCartesianIndices{T} <: AbstractArray{Int64,1} 
	ax::T
end


# indexing by a linear index returns a CartesianIndex
function getindex(ind::DiagCartesianIndices, i::Int)
	t = getindex.(ind.ax, i)
	CartesianIndex(t)
end

# Define additional indexing properties
IndexStyle(::DiagCartesianIndices) = IndexLinear()
length(ind::DiagCartesianIndices) = minimum(length.(ind.ax))
size(ind::DiagCartesianIndices) = (length(ind),)

# By construction, DiagCartesianIndices are always inbounds
checkbounds(A::AbstractArray, ::DiagCartesianIndices) = nothing

# The returned CartesianIndex occupies 2 index positions
@inline index_ndims(::DiagCartesianIndices{<:NTuple{N}}) where N = ntuple(i->true, Val(N))



# The main export


"""
Singleton type representing the diagonal of an array.
"""
struct DiagonalIndex
end


"""
Singleton object that, when used as an index, selects the diagonal
elements of an array.

`A[diagonal]` selects A[1,1,...], A[2,2,...], ..., A[k,k,...] where
k = minimum(size(A)).

# Examples

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

to_indices(A::AbstractArray, d::Tuple{DiagonalIndex}) = _to_indices(IndexStyle(A), A, d)
function to_indices(A::AbstractVector, d::Tuple{DiagonalIndex})
	(length(A) > 0 ? [firstindex(A)] : [], )
end 


function _to_indices(::IndexLinear, A::AbstractMatrix, ::Tuple{DiagonalIndex})
	(m, n) = size(A)
	(1:m+1:m*min(m,n),)
end


function _to_indices(::IndexLinear, A::AbstractArray, ::Tuple{DiagonalIndex})
	s = size(A)
	step = 1
	stride = 1
	k = s[1]
	for i = 2:ndims(A)
		stride *= s[i-1]
		step += stride
		k = min(k, s[i])
	end
	(1:step:1+step*(k-1),)
end


function _to_indices(::IndexCartesian, A::AbstractArray, ::Tuple{DiagonalIndex})
	(DiagCartesianIndices(axes(A)),)
end

end # module
