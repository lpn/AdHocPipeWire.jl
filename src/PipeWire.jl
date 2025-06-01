module PipeWire

using Timers

jl2pw(T) = error("Unsupported stream format: $T")
# jl2pw(::Type{Int8}) = :S8 # broken
jl2pw(::Type{Int16}) = :S16LE
jl2pw(::Type{Int32}) = :S32LE
jl2pw(::Type{Float32}) = :F32LE
jl2pw(::Type{Float64}) = :F64LE

struct PipeTunnel
    process::Base.Process
    stream::IOStream
    filename::String
    props::NamedTuple
end

function PipeTunnel(; name::String="julia-pw", mode=:playback, latency::T=1024, format=Float64, channels::T=2, rate::T=48000, position::String="[ FL FR ]", maypause::Bool=true, filename::String=string(tempname(), "_pipewire")) where {T<:Integer}
    ispath(filename) && error("pipe \"$filename\" already exists!")

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

Base.write(pw::PipeTunnel, xs) = write(pw.stream, xs |> htol)

function Base.Channel(pw::PipeTunnel, n=2; spawn=false)
    isfull(ch::Channel) = (ch.sz_max == 0) || (length(ch.data) == ch.sz_max)
    latency_ns = 1e9 * pw.props.latency / pw.props.rate

    Channel{Vector{pw.props.format}}(n; spawn=spawn) do buffers
        for buffer in buffers
            write(pw, buffer)
            if isfull(buffers)
                wait_until(time_ns() + latency_ns)
            end
        end
    end
end

end
