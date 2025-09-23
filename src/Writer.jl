mutable struct Writer{T,U<:PipewireModule}
    pw::U
    last_ns
    underruns::Int
end

Writer(pw::T; headroom=1.0) where {T<:PipewireModule} = Writer{pw.props.format,T}(pw, time_ns(), 0)

function (w::Writer{T,U})(buffer::Vector{T}) where {T,U<:PipewireModule}
    pw = w.pw

    latency_ns = 1e9 * pw.props.latency / pw.props.rate
    current_ns = time_ns()
    delay_ms = max(0, latency_ns - (current_ns - w.last_ns)) / 1e6

    w.underruns += (delay_ms == 0)

    sleep_ms(delay_ms)

    write(pw, buffer)

    w.last_ns = time_ns()
end

function Base.Channel(pw::T, n=2; spawn=false) where {T<:PipewireModule}
    w = Writer(pw)

    Channel{Vector{pw.props.format}}(n; spawn=spawn) do buffers
        for buffer in buffers
            w(buffer)
        end
    end
end
