mutable struct Writer{T,U<:PipewireModule}
    pw::U
    last_ns::UInt64
    underruns::Int
end

Writer(pw::T) where {T<:PipewireModule} = Writer{pw.props.format,T}(pw, time_ns(), 0)

function (w::Writer{T,U})(buffer::Vector{T}) where {T,U<:PipewireModule}
    pw = w.pw

    latency_ns = 1e9 * pw.props.latency / pw.props.rate
    current_ns = time_ns()
    delay_ms = max(zero(latency_ns), latency_ns - (current_ns - w.last_ns)) / 1e6

    w.underruns += iszero(delay_ms)

    # sleep_ms(delay_ms)
    wait_until(w.last_ns + latency_ns)

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
