using UnixIO
function compile_c(avr, c_file = avr.c_file)

    avr_flags = `-DF_CPU=$(avr.clock_hz)UL -mmcu=$(avr.device)`
    inc = avr.c_header_dir == nothing ? `` : `-I $(avr.c_header_dir)`
    c_flags = `-g -O3 $gcc_flags $avr_flags $inc`

    c_name, c_ext = splitext(c_file)

    # Compile C to ELF...
    elf_file = "$c_name.elf"
    println(stderr, "Running: ", `avr-gcc $c_flags ... $c_file`)
    UnixIO.system(`avr-gcc $c_flags -o $elf_file $c_file`)

    # Generate verbose ASM and memory dump for debug...
    S_file = "$c_name.S"
    UnixIO.system(`avr-gcc $c_flags -S --verbose-asm -o $S_file $c_file`)
    UnixIO.system(`avr-objdump -x -S -d -r -t -h $elf_file \> $c_name.dump`) 


    elf_file
end


const gcc_flags = split("""
    -std=gnu99
    -ffunction-sections
    -fdata-sections
    -Wl,--gc-sections
    -fwhole-program
    -ffreestanding
    -Werror

    -Wl,-Map,main.map
    -Wl,--relax

    -Wno-import
    -Wchar-subscripts
    -Wcomment
    -Wformat
    -Wformat-y2k
    -Wno-format-extra-args
    -Wformat-nonliteral
    -Wformat-security
    -Wformat=2
    -Wimplicit
    -Wmissing-braces
    -Wparentheses
    -Wreturn-type
    -Wtrigraphs
    -Wunused-function
    -Wunused-label
    -Wunused-variable
    -Wunused-value
    -Wunknown-pragmas
    -Wfloat-equal
    -Wshadow
    -Wpointer-arith
    -Wcast-align
    -Wcast-qual
    -Wno-unused-parameter
    -Wno-div-by-zero
    -Wswitch
""")
