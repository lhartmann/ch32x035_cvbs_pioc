INCLUDE     PIOC_INC.ASM

    ORG   0X0000
    DW    0X0000
    JMP   MCU_START
    DW    0X0FFF

MCU_START:
loop:
    INC     SFR_DATA_EXCH, F
    JMP     loop

    end

