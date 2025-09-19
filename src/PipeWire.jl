module PipeWire

using Timers

abstract type PipewireModule end

struct PipeCat <: PipewireModule
    process::Base.Process
    props::NamedTuple
end

function PipeCat(; mode=:playback, latency::T=1024, format=Float32, channels::T=2, rate::T=48000, position::String="[ FL FR ]") where {T<:Integer}
    jl2pw(T) = error("Unsupported stream format: $T")
    jl2pw(::Type{Int8}) = :s8
    jl2pw(::Type{Int16}) = :s16
    jl2pw(::Type{Int32}) = :s32
    jl2pw(::Type{Float32}) = :f32
    # jl2pw(::Type{Float64}) = :f64 # broken?

    cmd = Cmd(`pw-cat \
        --playback \
        --rate=$rate \
        --latency=$latency \
        --channels=$channels \
        --format=$(jl2pw(format)) \
        --raw -
    `)

    proc = open(cmd, "w")

    props = (
        mode=mode,
        latency=latency,
        format=format,
        channels=channels,
        rate=rate,
        position=position
    )

    PipeCat(proc, props)
end

function Base.close(p::PipeCat)
    kill(p.process)
end

function Base.write(pw::PipeCat, xs)
    write(pw.process, xs)
    flush(pw.process)
end

struct PipeTunnel <: PipewireModule
    process::Base.Process
    stream::IOStream
    filename::String
    props::NamedTuple
end

function PipeTunnel(; name::String="julia-pw", mode=:playback, latency::T=1024, format=Float64, channels::T=2, rate::T=48000, position::String="[ FL FR ]", maypause::Bool=true, filename::String=string(tempname(), "_pipewire")) where {T<:Integer}
    ispath(filename) && error("pipe \"$filename\" already exists!")

    jl2pw(T) = error("Unsupported stream format: $T")
    # jl2pw(::Type{Int8}) = :S8 # broken
    jl2pw(::Type{Int16}) = :S16LE
    jl2pw(::Type{Int32}) = :S32LE
    jl2pw(::Type{Float32}) = :F32LE
    jl2pw(::Type{Float64}) = :F64LE

    cmd = Cmd(`pw-cli -m \
        load-module libpipewire-module-pipe-tunnel \
        node.name=\"$name\" \
        pipe.filename=\"$filename\" \
        tunnel.mode=$mode \
        tunnel.may-pause=$maypause \
        node.latency=$latency \
        audio.channels=$channels \
        audio.rate=$rate \
        audio.position=$position \
        audio.format=$(jl2pw(format))`)

    process = run(cmd; wait=false)
    run(`mkfifo $filename`)
    handle = open(filename, "w")
    props = (
        name=name,
        mode=mode,
        latency=latency,
        format=format,
        channels=channels,
        rate=rate,
        position=position
    )

    PipeTunnel(process, handle, filename, props)
end

function Base.close(p::PipeTunnel)
    close(p.stream)
    kill(p.process)
    rm(p.filename)
end

function Base.write(pw::PipeTunnel, xs)
    write(pw.stream, xs |> htol)
    flush(pw.stream)
end

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
    d = max(0, latency_ns - (current_ns - w.last_ns)) / 1e6

    if d == 0
        w.underruns += 1
    end

    sleep_ms(d * 3 / 4)

    write(pw, buffer)

    sleep_ms(d / 4)

    w.last_ns = time_ns()
end

function Base.Channel(pw::T, n=2; spawn=false) where {T<:PipewireModule}
    # isfull(ch::Channel) = (ch.sz_max == 0) || (length(ch.data) >= ch.sz_max - 1)
    w = Writer(pw)

    Channel{Vector{pw.props.format}}(n; spawn=spawn) do buffers
        # @show typeof(buffers)
        for buffer in buffers
            # @show typeof(buffer)
            w(buffer)
        end
    end
end

end
