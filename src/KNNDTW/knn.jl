module _KNN

import MLJModelInterface
using CategoricalArrays: AbstractCategoricalArray, CatArrOrSub
using VectorizedStatistics: vsum
using LoopVectorization: @turbo
using .._DTW: DTWType, DTW, dtw!
using .._LB: LBType, LBNone, lower_bound!
using .._Utils: FastHeap

export KNNDTWModel

MLJModelInterface.@mlj_model mutable struct KNNDTWModel <: MLJModelInterface.Probabilistic
    K::Int64 = 1::(0 < _)
    weights::Symbol = :uniform::(_ in (:uniform, :distance))
    distance::DTWType = DTW{AbstractFloat}()
    bounding::LBType = LBNone()
end

function MLJModelInterface.reformat(::KNNDTWModel, (X, type))
    @assert type in (:row_based, :column_based)

    (MLJModelInterface.matrix(X, transpose = type == :row_based),)
end

function MLJModelInterface.reformat(::KNNDTWModel, (X, type), y)
    @assert type in (:row_based, :column_based)

    (MLJModelInterface.matrix(X, transpose = type == :row_based), MLJModelInterface.categorical(y))
end

function MLJModelInterface.reformat(::KNNDTWModel, (X, type), y, w)
    @assert type in (:row_based, :column_based)

    (MLJModelInterface.matrix(X, transpose = type == :row_based), MLJModelInterface.categorical(y), w)
end

MLJModelInterface.selectrows(::KNNDTWModel, I, Xmatrix) = (view(Xmatrix, :, I),)
MLJModelInterface.selectrows(::KNNDTWModel, I, Xmatrix, y) = (view(Xmatrix, :, I), view(y, I))
MLJModelInterface.selectrows(::KNNDTWModel, I, Xmatrix, y, w) = (view(Xmatrix, :, I), view(y, I), view(w, I))

function MLJModelInterface.fit(::KNNDTWModel, ::Any, X::AbstractMatrix{T}, y::Union{AbstractCategoricalArray, SubArray{<:Any, <:Any, <:AbstractCategoricalArray}}, w = nothing) where {T <: AbstractFloat}
    return ((X, y, w), nothing, nothing)
end

macro conditional_threads(cond, ex)
    :(
        if $(esc(cond))
            Threads.@threads $(esc(ex))
        else
            $(esc(ex))
        end
    )
end

@inbounds function MLJModelInterface.predict(model::KNNDTWModel, (X, y, w), Xnew::AbstractMatrix{T}) where {T <: AbstractFloat}
    heaps = [
        FastHeap{T, Tuple{eltype(y), typeof(w) == Nothing ? Nothing : eltype(w)}}(model.K, :max)
        for _ in 1:Threads.nthreads()
    ]
    classes = MLJModelInterface.classes(y)
    probas = zeros(T, length(classes), size(Xnew, 2))

    # Parallelize thought training dataset when the training dataset is larger than the requested dataset and the other way around 
    parallel_on_new = size(Xnew, 2) >= size(X, 2)
    @conditional_threads (parallel_on_new) for q in axes(Xnew, 2)
        @conditional_threads (!parallel_on_new) for i in axes(X, 2)
            heap = heaps[Threads.threadid()]

            if !isempty(heap) && (@views lower_bound!(model.bounding, Xnew[:, q], X[:, i], update_envelope=i == 1)) > first(heap)[1]
                continue
            end

            dtw_distance = @views dtw!(model.distance, Xnew[:, q], X[:, i])

            if isempty(heap) || dtw_distance < first(heap)[1]
                push!(heap, (dtw_distance, (y[i], w === nothing ? nothing : w[i])))
            end
        end

        # Merge heaps from threads into one
        final_heap = heaps[1]
        for heap in @views heaps[2:end]
            for el in heap.data
                if el[1] < first(final_heap)[1]
                    push!(final_heap, el)
                end
            end
        end

        # Calculate probabilities
        if model.weights == :uniform
            for (_, (label, weight)) in @views final_heap.data[begin:length(final_heap)]
                ww = (w === nothing ? 1 : weight)
                probas[findfirst(==(label), classes), q] = one(T) / model.K * ww
            end
        elseif model.weights == :distance
            for (dist, (label, weight)) in @views final_heap.data[begin:length(final_heap)]
                ww = (w === nothing ? 1 : weight)
                probas[findfirst(==(label), classes), q] = one(T) / (dist + sqrt(nextfloat(zero(Float64)))) * ww
            end
        end

        @turbo probas[:, q] ./= vsum(@views probas[:, q])
        empty!.(heaps)
    end

    return MLJModelInterface.UnivariateFinite(classes, transpose(probas))
end

function MLJModelInterface.fitted_params(::KNNDTWModel, fitresults)
    fitresults
end

end
