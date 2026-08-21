INCLUDE     PIOC_INC.ASM

    ORG     0X0000
    DW      0X0000
    JMP     MCU_START
    DW      0X0FFF

MCU_START:
    BS      SFR_PORT_DIR, 1
    BS      SFR_PORT_DIR, 0
loop:
    BS      SFR_PORT_IO, 0
    BC      SFR_PORT_IO, 1
    INC     SFR_DATA_EXCH, F
    NOP
    BC      SFR_PORT_IO, 0
    BS      SFR_PORT_IO, 1
    JMP     loop

    END
