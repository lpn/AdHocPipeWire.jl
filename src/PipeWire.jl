module PipeWire

abstract type PipewireModule end

@inline function sleep_ms(time_ms)
    # use the sleep() function only for delays greater than 10ms on Linux
    # and delays greater than 16ms on other OS
    delta = Sys.islinux() ? 0.010e9 : 0.016e9

    _time_ns = time_ns()
    finish = _time_ns + time_ms*1e6
    # sleep and allow cooperative multitasking
    if (finish - delta) >= _time_ns
        t = 1e-9 * (finish - _time_ns - delta)
        if t >= 0
            sleep(t)
        end
    end
    # busy waiting
    while finish > time_ns()
    end
    nothing
end

include("./PipeTunnel.jl")
include("./Writer.jl")

end
