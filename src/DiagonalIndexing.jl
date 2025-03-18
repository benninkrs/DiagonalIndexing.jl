"""
Provides a convenient way of selecting diagonal elements of arrays.
"""
module DiagonalIndexing
export Diagnl, diagnl, DiagCartesianIndices

# TODO
# Consider naming. Currently we have diagnl (constant instance) and constructors for Diagnl{N}
# The use of both lower- and upper- case is aesthetically not bad, but maybe not ideal.
# We could instead define "diagnl" or ("diagonal") as a _function_.
# When used without parantheses, we can dispatch (probably) on typeof(diagonal).
# When used with parentheses, it returns an instance of DiagIndex{N}.
# We could still have the constructor DiagIndex{N}(), but I'm guessing diagonal(0,0,0,0) will be preferable anyway.


import Base: getindex, IndexStyle, checkbounds, checkbounds_indices, to_indices, index_ndims, size, length


# First, a helper type.
#
# In general, to_indices must return a collection of CartesionIndex's.
# But instantiating such a vector is slow.  We cannot use a generator, because
# the collection must be <: AbstractArray.
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
	Diagnl{N}

Type representing a diagonal along consecutive dimensions of an array.
Instances of `Diagnl` are intended to be used as indices in indexing expressions.

`Diagnl{N}()` represents the main diagonal on `N` consecutive dimensions.

`Diagnl{Any}()` represents the main diagonal on remaining unindexed dimensions of an array.

`Diagnl(o_1,...,o_N)` represents the diagonal `(begin+o_1, ..., begin+o_N):(1,...,1):(end,...,end)` 
on `N` consecutive dimensions.


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

julia> A[diagnl]
3-element Vector{Int64}:
 111
 222
 333

julia> A[3,diagnl]
3-element Vector{Int64}:
 113
 223
 333

julia> A[Diagnl(1,0),2] = [-8, -9, -10]; A
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
struct Diagnl{N,M}
	offsets::Tuple{Vararg{Int,M}}
	function Diagnl(offsets::Vararg{Int,N}) where {N}
		all(o -> o>=0, offsets) || error("Diagonal offsets must all be ≥ 0.  Got $offsets")
		new{N,N}(offsets)
	end
	function Diagnl{N}() where {N}
		new{N,N}(ntuple(i->0, Val(N)))
	end
	function Diagnl{Any}()
		new{Any,0}(())
	end
end



"""
	const diagnl = Diagnl{Any}()

Constant that, when used as an index, selects diagonal elements along all remaining
dimensions of an array.  See [`Diagnl`](@ref)
"""
const diagnl = Diagnl{Any}()


# Implement the indexing behavior


# Specaial case: Diagnl is the only index.
# In this case we can dispatch to fast linear indexing when supported.

to_indices(A::AbstractArray, I::Tuple{Diagnl}) = _to_indices_style(IndexStyle(A), A, I[1])

_to_indices_style(::IndexLinear, A, I) = _to_indices_linear(A, I)		# specialized linear method
_to_indices_style(::IndexCartesian, A, I) = to_indices(A, axes(A), (I,))  # fallback to general methods below



_to_indices_linear(A::AbstractArray, dind::Diagnl{Any})  = _to_indices_linear(A, Diagnl{ndims(A)}())


function _to_indices_linear(A::AbstractArray, dind::Diagnl{M}) where {M}
	# println("Checkpoint: _to_indices_linear")
	N = ndims(A)
	M >= N || error("Diagnl has more dimensions ($M) than the targeted array does ($N).")

	s = size(A)

	# step = 1
	# stride = 1
	# offset = dind.offsets[1]
	# # TODO:  Make this an inferred loop
	# for i = 2:M
	# 	stride *= s[i-1]
	# 	step += stride
	# 	offset += dind.offsets[i]*stride
	# end

	step = 0
	offset = 0
	stride = 1
	k = maximum(s)
	# TODO:  Make this an inferred loop?
	for i = 1:N
		step += stride
		o = dind.offsets[i]
		k = min(k, s[i]-o)
		offset += o*stride
		stride *= s[i]
	end
	N<M && (step += stride)
	# (firstindex(A)+offset:step:lastindex(A),)		# this is wrong when the array is not square
	start = firstindex(A) + offset
	stop = start + (k-1)*step 
	(start:step:stop,)
end


# function _to_indices_linear(A::AbstractMatrix, dind::Diagnl{M}) where {M}
# 	M == 2 || error("When used as the only index, diagonal must have the same number dimensions as the targeted array")
# 	(m, n) = size(A)
# 	offset = dind.offset[1] + dind.offset[2]*m
# 	(firstindex(A)+offset:(m+1):lastindex(A),)
# end




# General case: Diagnl is not the only index.
# These functions take axes as an argument and will be called by Base.to_indices(::AbstractArray, I)

# TODO: Handle linear indexing when DiagonalIndexing is not the only index?


# When Diagnl{Any} is the last index, take the main diagonal on all remaining axes.
function to_indices(::AbstractArray, ax, ::Tuple{Diagnl{Any}})
	(DiagCartesianIndices(ax),)
end 


# Diagnl{Any} must be used in the last position.
function to_indices(::AbstractArray, ax, ::Tuple{Diagnl{Any}, Vararg{Any}})
	error("Diagnl{Any} may only be used as the last index.")
end 


# For Diagb{N}, return the indices for the diagonal specified by the offsets 
function to_indices(A::AbstractArray, ax, I::Tuple{Diagnl{M}, Vararg{Any}}) where {M}
	# println("Checkpoint: to_indices (general)")
	o = I[1].offsets
	N = length(ax)
	if N >= M
		# Select the diagonal on the first M of N axes
		ax_off = ntuple(i -> (ax[i][1] + o[i]):ax[i][end], Val(M))
		inds = DiagCartesianIndices(ax_off)
	else
		# When M > N, select just the first element along the N axes
		# TODO: Handle the case that ax[i] is empty
		# TODO: Handle the case that o[i] !=0 for i>M (should return an empty array)
		inds = ntuple(i -> ax[i][1] + o[i], Val(M))
	end
	# println(typeof(inds))
	# println((inds, to_indices(A, ax[M+1:end], I[2:end])...))
	return (inds, to_indices(A, ax[M+1:end], I[2:end])...)
	# return (inds,)
end


end # module
