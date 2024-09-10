using PipeWire
using Test

function tone(format, length=3; conv=identity)
    pw = PipeWire.PipeTunnel(; latency=1024, rate=48000, format=format)
    chnl = Channel(pw)

    @show pw

    generate(t, f=440) = sin(f * 2pi * t / pw.props.rate) * exp2(-2.25) |> conv

    latency = pw.props.latency
    iterations = div(length * pw.props.rate, latency)

    @time foreach(1:iterations) do i
        xs = [generate(latency * i + x, 220 * exp2(ch * exp2(-6.5))) for x in 1:latency for ch in -1:2:1]
        put!(chnl, xs)
    end

    close(pw)

    true
end

tone(format::Type{T}) where {T<:Signed} = tone(format; conv=conv = x -> round(format, typemax(format) * x))

@testset "PipeWire.jl" begin
    @test tone(Float64)
    @test tone(Float32)
    @test tone(Int32)
    @test tone(Int16)
end
