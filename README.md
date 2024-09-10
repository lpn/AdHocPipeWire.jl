# AdHocPipeWire.jl

An ad hoc [PipeWire](https://www.pipewire.org/) audio playback client for [Julia](https://julialang.org/).

This module spawns a `pw-cli` [Unix Pipe Tunnel](https://docs.pipewire.org/page_module_pipe_tunnel.html)
process and terminates it upon closing.
