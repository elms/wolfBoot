OUTPUT_ARCH( "powerpc" )

ENTRY( _reset )

/*
RESET_ADDR = 0x0FFFFFFFC;
HARD_RESET = 0x000F0000;
*/
RESET_ADDR = 0x00000000effffffc;
HARD_RESET = 0x00000000effff000;
START = 0x00000000eff40000;

PHDRS
{
    text PT_LOAD;
    bss  PT_LOAD;
}

MEMORY
{
    FLASH (rx) : ORIGIN = START, LENGTH = ##WOLFBOOT_PARTITION_BOOT_ADDRESS##
    RAM (rwx) : ORIGIN = 0xfdd00000, LENGTH = 0x00002000
}

SECTIONS
{
    .text :
    {
        *(.text*)
        *(.rodata*)
        *(.sdata*)
    } > FLASH

    . = ALIGN(4);

    .boot HARD_RESET :
    {
        KEEP(*(.boot))
    } :text = 0xffff

    .reset RESET_ADDR :
    {
        KEEP(*(.reset))
    } :text = 0xffff
    . = 0xeffffffc + 0x4;

    .data :
    {
        _start_data = .;
        KEEP(*(.data*))
        . = ALIGN(4);
        KEEP(*(.ramcode))
        . = ALIGN(4);
        _end_data = .;
    } > RAM

    .bss (NOLOAD) :
    {
        _start_bss = .;
        __bss_start__ = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _end_bss = .;
        __bss_end__ = .;
        _end = .;
    } > RAM

}
