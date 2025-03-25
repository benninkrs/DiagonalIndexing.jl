"""
Provides a convenient way of selecting diagonal elements of arrays.
"""
module DiagonalIndexing
export diagonal, DiagIndex, DiagCartesianIndices


import Base: getindex, IndexStyle, checkbounds, checkbounds_indices, to_indices, index_ndims, size, length


# First, a helper type.
#
# In general, we need to_indices to return a collection of CartesionIndex's.
# But instantiating such a vector is slow.  And we cannot use a generator, because
# the returned collection must be <: AbstractArray.
# Thus, we define a type of lazy array of CartesianIndex's.

"""
	DiagCartesianIndices

Virtual array of `CartesianIndex`s.  Used in `DiagonalIndexing` to efficiently generate indices
for diagonal indexing.
"""
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
checkbounds(::Type{Bool}, A::AbstractArray, ::DiagCartesianIndices) = true

function checkbounds_indices(::Type{Bool}, IA::Tuple, I::Tuple{DiagCartesianIndices, Vararg{Any}})
	@inline
	# Only need to check bounds on remaining indices.
	N = length(I[1].ax)
	checkbounds_indices(Bool, IA[N+1:end], Base.tail(I))
end

# The returned CartesianIndex occupies 2 index positions.
# Not sure if this is ever used.
@inline index_ndims(::DiagCartesianIndices{<:NTuple{N}}) where N = ntuple(i->true, Val(N))



# The main export


"""
	DiagIndex{N}

Type representing a diagonal along consecutive dimensions of an array.
Instances of `DiagIndex` are intended to be used as indices in indexing expressions.

`DiagIndex{N}()` represents the main diagonal on `N` consecutive dimensions.

`DiagIndex(o_1,...,o_N)` represents the diagonal `(begin+o_1, ..., begin+o_N):(1,...,1):(end,...,end)` 
on `N` consecutive dimensions.

See ['diagonal'](@ref).
"""
struct DiagIndex{N}
	offsets::Tuple{Vararg{Int,N}}
	function DiagIndex(offsets::Vararg{Int,N}) where {N}
		all(o -> o>=0, offsets) || error("Diagonal offsets must all be ≥ 0.  Got $offsets")
		new{N}(offsets)
	end
	function DiagIndex{N}() where {N}
		new{N}(ntuple(i->0, Val(N)))
	end
end



"""
	diagonal

When used as an index, `diagonal` selects the meain diaognal or all remaining
dimensions of an array.

`diagonal(o_1,...,o_N)` creates an index the selects a diagonal with offsets o_1,...,o_N
on N consecutive axes.

# Examples

```
julia> using DiagonalIndexing

julia> A = [i+10j+100k for i=1:4, j=1:3, k=1:3];
4×3×3 Array{Int64, 3}:
[:, :, 1] =
 111  121  131
 112  122  132
 113  123  133
 114  124  134

[:, :, 2] =
 211  221  231
 212  222  232
 213  223  233
 214  224  234

[:, :, 3] =
 311  321  331
 312  322  332
 313  323  333
 314  324  334

julia> A[diagonal]
3-element Vector{Int64}:
 111
 222
 333

julia> A[3,diagonal]
3-element Vector{Int64}:
 113
 223
 333

julia> A[DiagIndex(1,0),2] = [-8, -9, -10]; A
4×3×3 Array{Int64, 3}:
[:, :, 1] =
 111  121  131
 112  122  132
 113  123  133
 114  124  134

[:, :, 2] =
 211  221  231
  -8  222  232
 213   -9  233
 214  224  -10

[:, :, 3] =
 311  321  331
 312  322  332
 313  323  333
 314  324  334
```

"""
diagonal(offsets...) = DiagIndex(offsets...)


# Implement the indexing behavior


# Specaial case: DiagIndex is the only index.
# In this case we can dispatch to fast linear indexing when supported.

@inline to_indices(A::AbstractArray, ::Tuple{typeof(diagonal)}) = _to_indices_style(IndexStyle(A), A, DiagIndex{ndims(A)}())
@inline to_indices(A::AbstractArray, I::Tuple{DiagIndex}) = _to_indices_style(IndexStyle(A), A, I[1])

@inline _to_indices_style(::IndexLinear, A, I) = _to_indices_linear(A, I)		# specialized linear method
@inline _to_indices_style(::IndexCartesian, A, I) = to_indices(A, axes(A), (I,))  # fallback to general methods below



@inline function _to_indices_linear(A::AbstractArray, dind::DiagIndex{N}) where {N}
	NA = ndims(A)
	N < NA && error("DiagIndex has fewer dimensions ($N) than the targeted array does ($NA).")


	# Calculate the start, step, and stop of the associated range of linear indices
	# (This does not seem to significantly add to the run time)
	sz = size(A)
	step = 0
	offset = 0
	stride = 1
	len = maximum(sz)

	for i = 1:NA
		step += stride
		o = dind.offsets[i]
		len = min(len, sz[i]-o)
		offset += o*stride
		stride *= sz[i]
	end

	# If N>NA, the extra axes are treated as having size 1.
	# If the extra offsets are all 0, the diagional has a single element; otherwise the diagonal is empty.
	# This is automatically achieved by computing appropriate values of offset, step, and len.
	for i = NA+1:N
		step += stride
		o = dind.offsets[i]
		len = min(len, 1-o)
		offset += o*stride
	end

	start = firstindex(A) + offset
	stop = start + (len-1)*step
	(start:step:stop,)
end


# We used to specialize for 2-dimensional array; but it doesn't seem to yield any benefit.
# @inline function _to_indices_linear(A::AbstractMatrix, dind::DiagIndex{N}) where {N}
# 	N == 2 || error("When used as the only index, diagonal must have the same number dimensions as the targeted array")
# 	m = size(A,1)
# 	offset = dind.offsets[1] + dind.offsets[2]*m
# 	(firstindex(A)+offset:(m+1):lastindex(A),)
# end



# General case: DiagIndex is not the only index.
# These functions take axes as an argument and will be called by Base.to_indices(::AbstractArray, I)

# TODO: Would it be feasible and beneficial to do linear indexing when DiagonalIndexing is not the only index?  


# When diagonal is the last index, take the main diagonal on all remaining axes.
function to_indices(::AbstractArray, ax, ::Tuple{typeof(diagonal)})
	(DiagCartesianIndices(ax),)
end 


# diagonal must be used in the last position.
function to_indices(::AbstractArray, ax, ::Tuple{typeof(diagonal), Vararg{Any}})
	error("'diagonal' without arguments may only be used as the last index.")
end 


# For DiagIndex{N}, return the indices for the diagonal specified by the offsets 
function to_indices(A::AbstractArray, ax, I::Tuple{DiagIndex{N}, Vararg{Any}}) where {N}
	o = I[1].offsets
	NA = length(ax)
	if NA >= N
		# Select the diagonal on the first N of NA axes
		ax_off = ntuple(i -> (first(ax[i]) + o[i]):ax[i][end], Val(N))
		inds = DiagCartesianIndices(ax_off)
	else
		# When N > NA, select just the first element along the NA axes
		inds = ntuple(i -> first(ax[i]) + o[i], Val(N))
	end
	return (inds, to_indices(A, ax[N+1:end], I[2:end])...)
end


end # module
