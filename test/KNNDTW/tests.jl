using TsClassification: KNNDTW
using Test: @testset, @test


const TS1::Vector{Float64} = [0.57173714, 0.03585991, 0.16263380, 0.63153396, 0.00599358, 0.63256182, 0.85341386, 0.87538411, 0.35243848, 0.27466851]
const TS2::Vector{Float64} = [0.17281271, 0.54244937, 0.35081248, 0.83846642, 0.74942411]
const TS3::Vector{Float64} = [1.00000000, 1.00000000, 1.00000000, 1.00000000, 1.00000000, 1.00000000, 0.16263380, 0.63153396, 0.00599358, 0.63256182]


@testset "KNNDTW.jl - dtw() - Full" begin
    model = KNNDTW.DTW{eltype(TS1)}()
    r1 = KNNDTW.dtw(model, TS1, TS2)
    @test r1 ≈ 0.8554589614450465

    r2 = KNNDTW.dtw(model, TS1, TS3)
    @test r2 ≈ 1.196169334904773
end

@testset "KNNDTW.jl - dtw() - SakoeChiba" begin
    model = KNNDTW.DTWSakoeChiba{eltype(TS1)}(radius=Unsigned(2))
    r1 = KNNDTW.dtw(model, TS1, TS2)
    @test r1 ≈ 0.8554589614450465

    r2 = KNNDTW.dtw(model, TS1, TS3)
    @test r2 ≈ 1.6133200246629615
end

@testset "KNNDTW.jl - dtw() - Itakura" begin
    model = KNNDTW.DTWItakura{eltype(TS1)}(slope=1.5)
    r1 = KNNDTW.dtw(model, TS1, TS2)
    @test r1 ≈ 1.0915468341537107

    r2 = KNNDTW.dtw(model, TS1, TS3)
    @test r2 ≈ 1.6803668615702465
end
