function compile_c(avr)

    avr_flags = `-DF_CPU=$(avr.clock_hz)UL -mmcu=$(avr.device)`
    inc = avr.c_header_dir == nothing ? `` : `-I $(avr.c_header_dir)`
    c_flags = `-g -O3 $gcc_flags $avr_flags $inc`

    c_dir = dirname(avr.c_file)

    # Compile C to ELF...
    elf_file = joinpath(c_dir, "main.elf")
    println("Running: ", `avr-gcc $c_flags ... $(avr.c_file)`)
    run(`avr-gcc $c_flags -o $elf_file $(avr.c_file)`)

    # Generate verbose ASM and memory dump for debug...
    S_file = joinpath(c_dir, "main.S")
    run(`avr-gcc $c_flags -S --verbose-asm -o $S_file $(avr.c_file)`)
    write(joinpath(c_dir, "main.dump"), 
          read(`avr-objdump -x -S -d -r -t -h $elf_file`))

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
