module _Utils

import Base
using LoopVectorization: @turbo

export sorted_unique_counts, logspace, RangeAsArray

function sorted_unique_counts(arr::Vector{T})::Tuple{Vector{T}, Vector{Int64}} where {T}
    if isempty(arr)
        return T[], Int64[]
    end

    uniq_count = 1
    @inbounds @turbo for i in 2:length(arr)
        uniq_count += arr[i] != arr[i-1]
    end

    unq = similar(arr, uniq_count)
    cnt = zeros(Int64, uniq_count)

    @inbounds unq[1] = arr[1]
    @inbounds cnt[1] = 1

    pos = 1
    @inbounds for x in @views arr[2:end]
        if x == unq[pos]
            cnt[pos] += 1
        else
            pos += 1
            unq[pos] = x
            cnt[pos] = 1
        end
    end

    return unq, cnt
end

@inline logspace(start::Real, stop::Real, n::Real; base::Real = 10) = @turbo @fastmath base .^ range(start, stop, n)

# This is terrinle hack that makes the code look much nicer unless you look bellow the hood to make the ChunkSplitters.chunks work well with ranges as well 
struct RangeAsArray <: AbstractArray{Nothing, 0}
    rage::UnitRange
end

Base.firstindex(rage::RangeAsArray) = Base.firstindex(rage.rage)
Base.lastindex(rage::RangeAsArray) = Base.lastindex(rage.rage)
Base.length(rage::RangeAsArray) = Base.length(rage.rage)

end
