module PipeWire

using Timers

abstract type PipewireModule end

include("./PipeTunnel.jl")
include("./Writer.jl")

end
