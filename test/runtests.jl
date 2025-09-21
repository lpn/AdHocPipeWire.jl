using PipeWire
using Test

function tone(Impl, format, length=3; conv=identity)
    pw = Impl(; latency=1024, rate=48000, format=format)

    chnl = Channel(pw, 1; spawn=false)

    @show pw

    generate(t, f=440) = sin(f * 2pi * t / pw.props.rate) * exp2(-2.25) |> conv

    latency = pw.props.latency
    iterations = div(length * pw.props.rate, latency)

    @time for i in 1:iterations
        xs = [generate(latency * i + x, 220 * exp2(ch * exp2(-6.5))) for x in 1:latency for ch in -1:2:1]
        put!(chnl, xs)
    end

    close(pw)

    true
end

tone(format::Type{T}) where {T<:Signed} = tone(format; conv=conv = x -> round(format, typemax(format) * x))

scale(T, x) = round(T, x * typemax(T))

@testset "PipeWire.jl" begin
    @testset "PipeTunnel" begin
        pw = PipeWire.PipeTunnel
        @test tone(pw, Float64)
        @test tone(pw, Float32)
        @test tone(pw, Int32; conv=x -> scale(Int32, x))
        @test tone(pw, Int16; conv=x -> scale(Int16, x))
        @test tone(pw, Int8; conv=x -> scale(Int8, x))
    end
end
