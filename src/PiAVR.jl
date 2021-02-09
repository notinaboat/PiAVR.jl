module PiAVR

export AVRDevice


using PiAVRDude
using PiGPIOMEM
using BBSPI
BBSPI.delay(s::BBSPI.SPISlave) = PiGPIOMEM.spin(1000)

include("serial_read.jl")
include("c_compile.jl")


const init_done = Ref(false)

mutable struct AVRDevice{T}

    device::String
    clock_hz::Int32
    fuses::Vector{String}
    reset::GPIOPin
    miso::Int8
    spi::T
    isp::AVRDude
    c_file::Union{String, Nothing}
    c_header_dir::Union{String, Nothing}
    bin_file::Union{String, Nothing}
    linecache::Dict{Int, Tuple{String,String}}
    stop_monitor::Ref{Bool}

    function AVRDevice(; device = "atmega328p",
                       clock_hz = 16000000,
                          fuses = ["hfuse:w:0xdf:m", "lfuse:w:0xff:m"],
                       bin_file = nothing,
                         c_file = nothing,
                   c_header_dir = nothing,
                      reset_pin = nothing,
                        clk_pin = nothing, 
                       mosi_pin = nothing, 
                       miso_pin = nothing)

        @assert bin_file == nothing || c_file == nothing

        if !init_done[]
            gpioCfgClock(10, 1, 1); # us, PCM, ignored
            res = gpioInitialise();
            @assert(res != PI_INIT_FAILED)
            init_done[] = true
        end

        spi = BBSPI.SPISlave(cs = Ref(false),
                            clk = GPIOPin(clk_pin),
                           mosi = GPIOPin(mosi_pin),
                           miso = Ref(false))

        isp = AVRDude(device=device,
                         sck=clk_pin,
                        miso=miso_pin,
                        mosi=mosi_pin,
                       reset=reset_pin)

        avr = new{typeof(spi)}(device,
                               clock_hz,
                               fuses,
                               GPIOPin(reset_pin),
                               miso_pin,
                               spi,
                               isp,
                               c_file,
                               c_header_dir,
                               bin_file,
                               Dict{Int, Tuple{String,String}}(),
                               Ref(false))

        avr
    end
end


function Base.write(avr::AVRDevice, v)
    set_output_mode(avr.spi.clock)
    set_output_mode(avr.spi.master_out)

    BBSPI.transfer(avr.spi, v)

    set_input_mode(avr.spi.clock)
    set_input_mode(avr.spi.master_out)
end


function assert_reset(avr)
    set_output_mode(avr.reset)
    avr.reset[] = false
end

function release_reset(avr)
    set_input_mode(avr.reset)
end


function fuse(avr::AVRDevice)
    for f in avr.fuses
        PiAVRDude.fuse(avr.isp, f)
    end
end


function flash(avr::AVRDevice)
    if avr.c_file != nothing
        avr.bin_file = compile_c(avr)
    end

    PiAVRDude.flash(avr.isp, avr.bin_file)
end


end # module
