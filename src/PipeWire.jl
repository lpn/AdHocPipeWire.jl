module PipeWire

using Timers

abstract type PipewireModule end

include("./PipeCat.jl")
include("./PipeTunnel.jl")
include("./Simple.jl")
include("./Writer.jl")

end
