module PiAVR

export AVRDevice


using PiAVRDude
using PiGPIOMEM
using BBSPI
BBSPI.delay(s::BBSPI.SPISlave) = PiGPIOMEM.spin(1000)

const ENABLE_GPIOC = false

include("serial_read.jl")
include("c_compile.jl")


@static if ENABLE_GPIOC
const gpioc_init_done = Ref(false)
end

mutable struct AVRDevice{T}

    device::String
    clock_hz::Int32
    fuses::Vector{String}
    reset::Union{GPIOPin, Nothing}
    miso::Union{Int8, Nothing}
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
                       miso_pin = nothing,
                       usb_port = nothing)

        @assert bin_file == nothing || c_file == nothing

        if bin_file == nothing
            f = replace(c_file, r".c$" => ".hex")
            if isfile(f)
                bin_file = f
            end
            f = replace(c_file, r".c$" => ".elf")
            if isfile(f)
                bin_file = f
            end
        end

        @static if ENABLE_GPIOC
            if !gpioc_init_done[]
                gpioCfgClock(10, 1, 1); # us, PCM, ignored
                res = gpioInitialise();
                @assert(res != PI_INIT_FAILED)
                gpioc_init_done[] = true
            end
        end

        spi = if usb_port == nothing
            BBSPI.SPISlave(cs = Ref(false),
                          clk = GPIOPin(clk_pin),
                         mosi = GPIOPin(mosi_pin),
                         miso = Ref(false))
        else
            nothing
        end

        isp = AVRDude(device=device,
                         sck=clk_pin,
                        miso=miso_pin,
                        mosi=mosi_pin,
                       reset=reset_pin,
                    usb_port=usb_port)

        avr = new{typeof(spi)}(device,
                               clock_hz,
                               fuses,
                               reset_pin == nothing ? nothing :
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

function reset(avr)
    assert_reset(avr)
    sleep(0.5)
    release_reset(avr)
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


function flash_c_file(avr::AVRDevice, c_file)
    PiAVRDude.flash(avr.isp, compile_c(avr, c_file))
end


function eeprom(avr::AVRDevice)
    PiAVRDude.eeprom(avr.isp, avr.bin_file)
end


end # module
