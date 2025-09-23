struct PipeTunnel <: PipewireModule
    process::Base.Process
    stream::IOStream
    filename::String
    props::NamedTuple
end

function PipeTunnel(; name::String="julia-pw", mode=:playback, latency::T=1024, format=Float64, channels::T=2, rate::T=48000, position::String="[ FL FR ]", maypause::Bool=true, filename::String=string(tempname(), "_pipewire")) where {T<:Integer}
    ispath(filename) && error("pipe \"$filename\" already exists!")

    jl2pw(T) = error("Unsupported stream format: $T")
    jl2pw(::Type{Int8}) = :S8
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
    Base.Libc.mkfifo(filename)
    stream = open(filename, "w")
    props = (
        name=name,
        mode=mode,
        latency=latency,
        format=format,
        channels=channels,
        rate=rate,
        position=position
    )

    PipeTunnel(process, stream, filename, props)
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
