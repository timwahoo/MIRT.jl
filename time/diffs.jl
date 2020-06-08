# diffs.jl

import MIRT
using LinearMapsAA: LinearMapAA
using Random: seed!
using BenchmarkTools: @btime

"""
`d = diff2d_forw(X)`

2D finite differences along both dimensions, for anisotropic TV regularization.
Performs the same operations as
d = ``[(I_N \\otimes D_M); (D_N \\otimes I_M)] X[:]``
where ``D_N`` denotes the ``N-1 \\times N`` 1D finite difference matrix
and ``\\otimes`` denotes the Kronecker product,
but does it efficiently
without using `spdiagm` (or any `SparseArrays` function).

in
- `X`		`M x N` array (typically a 2D image).
It cannot be a Vector!  (But it can be a `Mx1` or `1xN` 2D array.)

out
- `d`		vector of length `N*(M-1) + (N-1)*M`
"""
function diff2d_forw(x::AbstractMatrix{<:Number})
	return [diff(x,dims=1)[:]; diff(x,dims=2)[:]]
end


"""
`z =  diff2d_adj(d, M, N; out2d=false)`

Adjoint of 2D finite differences along both dimensions.
Performs the same operations as
``z = [(I_N \\otimes D_M); (D_N \\otimes I_M)]' * d``
where D_N denotes the N-1 x N 1D finite difference matrix
and \\otimes denotes the Kronecker product,
but does it efficiently without using spdiagm (or any SparseArrays function).

in
- `d`		vector of length `N*(M-1) + (N-1)*M`
- `M,N`		desired output size

option
- `out2d`	if true then return `M x N` array, else `M*N` vector

out
- `z`		`M*N` vector or `M x N` array (typically a 2D image)

"""
function diff2d_adj(d::AbstractVector{<:Number}, M::Int, N::Int ; out2d=false)

	length(d) != N*(M-1) + (N-1)*M && throw("length(d)")

	dx = d[1:(N*(M-1))]
	dx = reshape(dx, M-1, N)
	dy = d[1+(N*(M-1)):end]
	dy = reshape(dy, M, N-1)
	zx = [-transpose(dx[1,:]);
		(@views dx[1:end-1,:] - dx[2:end,:]);
		transpose(dx[end,:])]
	zy = [-dy[:,1] (@views dy[:,1:end-1] - dy[:,2:end]) dy[:,end]]
	z = zx + zy # M by N

	return out2d ? z : z[:] # array or vector?
end


"""
`T = diff2d_map(M::Int, N::Int)`
"""
function diff2d_map(M::Int, N::Int)
	return LinearMapAA(
        x -> diff2d_forw(reshape(x,M,N)),
        d -> diff2d_adj(d, M, N),
        (N*(M-1)+M*(N-1), N*M), (name="diff2_map",))
end


function diff_map_time( ; M::Int=2^7, N::Int=2^7)
    seed!(0)
    x = randn(M * N)
    T2d = diff2d_map(M, N)
    Tnd = MIRT.diff_map(M, N)

    # time diff_forw
    d2d = @btime $T2d * $x
    dnd = @btime $Tnd * $x 
    @assert d2d == dnd
    # time diff_adj
    d = d2d
    y2d = @btime $T2d' * $d
    ynd = @btime $Tnd' * $d
    @assert y2d == ynd
end

#= ir71 with 1.4.2
  98.381 μs (16 allocations: 762.73 KiB)
  58.344 μs (18 allocations: 508.77 KiB)
  159.237 μs (39 allocations: 1.00 MiB)
  102.423 μs (115 allocations: 384.05 KiB)
=#

diff_map_time()
