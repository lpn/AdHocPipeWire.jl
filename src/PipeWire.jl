module PipeWire

using Timers

abstract type PipewireModule end

include("./PipeCat.jl")
include("./PipeTunnel.jl")

Writer(pw::T; headroom=1.0) where {T<:PipewireModule} = Writer{pw.props.format,T}(pw, time_ns(), 0)

function (w::Writer{T,U})(buffer::Vector{T}) where {T,U<:PipewireModule}
    pw = w.pw

    latency_ns = 1e9 * pw.props.latency / pw.props.rate
    current_ns = time_ns()
    d = max(0, latency_ns - (current_ns - w.last_ns)) / 1e6

    if d == 0
        w.underruns += 1
    end

    sleep_ms(d * 8 / 16)

    write(pw, buffer)

    sleep_ms(d * 8 / 16)

    w.last_ns = time_ns()
end

function Base.Channel(pw::T, n=2; spawn=false) where {T<:PipewireModule}
    # isfull(ch::Channel) = (ch.sz_max == 0) || (length(ch.data) >= ch.sz_max - 1)
    w = Writer(pw)

    Channel{Vector{pw.props.format}}(n; spawn=spawn) do buffers
        for buffer in buffers
            w(buffer)
        end
    end
end

end
