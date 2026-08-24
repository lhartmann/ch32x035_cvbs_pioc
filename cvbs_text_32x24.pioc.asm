INCLUDE     PIOC_INC.ASM

    ORG   0X0000
    DW    0X0000
    JMP   MCU_START
    DW    0X0FFF

; Memory goes from 0x000 to 0x7FF
; Code   goes from 0x000 to 0x3FF
; Glyphs go   from 0x400 to 0x7FF

; SFR_DATA_REG0..SFR_DATA_REG31 are the tileids for each column
; SFR_INDIR_ADDR2 is the pointer that runs through columns
; SFR_DATA_EXCH is the current 8 bits on display
; SFR_INDIR_ADDR is required for rdcode

; SFR_TMR0_COUNT may be general purpose
; SFR_CTRL_RD can be user as general purpose ram, if nothing needs to be sent to host

; OUT0 is for black/white
; OUT1 is SYNC signal

INCLUDE     PIOC_INC.ASM
;INCLUDE    font.asm

; Local variables
LINE_COUNTER  EQU SFR_INDIR_ADDR2 ; used for vertical counts, scanlines or lines of text
DELAY_COUNTER EQU SFR_DATA_EXCH ; used for horizontal counts, but only blanked area.

; Constants
V_BACK      EQU 48
V_ACTIVE    EQU 192
V_FRONT     EQU 19
V_SYNC      EQU 3

SYNC_SHORT  EQU 19  ; Trial and error, target 4.70us
SYNC_LONG   EQU 235 ; Trial and error, target 58.85us
H_BACK      EQU 150 ; Trial and error, center text on screen

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MCU_START:
    call    timer_ntsc_setup
    mova2f  0x02                ; Set GPIO as SYNC high, LUMA low
    mova1f  0x03                ; Set both GPIO as outputs
    jmp     screen

INCLUDE timer_ntsc.asm

screen:
    ;; HACK BEGIN : Sync tuning
;     movl    SYNC_SHORT
;     call    gen_sync
;     jmp     screen
;
    ;; HACK END

    ; HACK BEGIN : scanline test
; hack_loop:
;     call    sync_scanline
;     jmp     hack_loop
    ; HACK END
    movl    0xFF            ; Signal vblank by sending 0xFF
    mova    SFR_CTRL_RD
    bs      SFR_SYS_CFG, SB_INT_REQ

    ; vertical front porch
    movl    V_FRONT
    mova    LINE_COUNTER
vertical_front_porch_loop:
    call    blank_scanline
    decsz   LINE_COUNTER, F
    jmp     vertical_front_porch_loop

    ; vertical sync pulse
    movl    V_SYNC
    mova    LINE_COUNTER
vertical_sync_loop:
    call    sync_scanline
    decsz   LINE_COUNTER, F
    jmp     vertical_sync_loop

    ; Vertical back porch
    movl    V_BACK
    mova    LINE_COUNTER
vertical_back_porch_loop:
    call    blank_scanline
    decsz   LINE_COUNTER, F
    jmp     vertical_back_porch_loop

    ; Start active scanlines counter, and publicize to host.
    clr     SFR_CTRL_RD

    ; Default command, text mode, gliph line 0, no scanline interrupt
    clr     SFR_CTRL_WR

    ; First active scanline always interrupts
    bs      SFR_SYS_CFG, SB_INT_REQ

    clr     LINE_COUNTER

active_scanline_loop:
    call    active_scanline

    ; Enter vblank after 192 active scanlines
    inc     SFR_CTRL_RD, A
    cmpl    192
    btsc    SFR_STATUS_REG, SB_FLAG_Z
    jmp     screen

    ; Increment scanline as visible from host
    inc     SFR_CTRL_RD, F

    ; SP_GB_BIT_X is used to flag need for an interrupt
    btsc    SFR_STATUS_REG, SB_GP_BIT_X
    bs      SFR_SYS_CFG, SB_INT_REQ
    bc      SFR_STATUS_REG, SB_GP_BIT_X

    jmp     active_scanline_loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gen_sync:
    mova    DELAY_COUNTER
    bc      SFR_PORT_IO, SB_PORT_OUT1
gen_sync_loop:
    nop     ; Number of nops enough that long sync is less then 255 loops.
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    decsz   DELAY_COUNTER, F
    jmp     gen_sync_loop
    bs      SFR_PORT_IO, SB_PORT_OUT1
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
blank_scanline:
    call    timer_ntsc_sync
    movl    SYNC_SHORT
    jmp     gen_sync        ; tail call

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
sync_scanline:
    call    timer_ntsc_sync
    movl    SYNC_LONG
    jmp     gen_sync        ; tail call

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
active_scanline:
    call    timer_ntsc_sync
    movl    SYNC_SHORT
    call    gen_sync

    ; Horizontal back porch
    movl    H_BACK
    mova    DELAY_COUNTER
display_text_horizontal_delay:
    decsz   DELAY_COUNTER, F
    jmp     display_text_horizontal_delay

    btss    SFR_CTRL_WR, 7      ; (T1+1 or T1+2) CMD bit 7 means bitmap scanline
    jmp     text_scanline       ; (T2+2 or ----)

    ; bitmap_scanline
    ; We need a delay to compensate for the text_scanline latency.
    ; Both modes output on T0==T8 clock cycle.
    ; Text mode is delayed by 7 pixels, though.
    call    DELAY_5             ; (T3+5=8)
    call    DELAY_8             ; (T0+8)
    call    DELAY_8             ; (T0+8)
    call    DELAY_8             ; (T0+8)
    call    DELAY_8             ; (T0+8)
    call    DELAY_8             ; (T0+8)
    call    DELAY_8             ; (T0+8)
    nop                         ; (T0+1)
    nop                         ; (T1+1)
    movl    SFR_DATA_REG0       ; (T2+1) Initiaize pointer to SFRs
    mova    SFR_INDIR_ADDR      ; (T3+1)

    ; Loop over columns, but without a counter
    call    bitmap_out_byte     ; (T4+2)
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte
    call    bitmap_out_byte

    call    DELAY_4                     ; (T4+4 = 8)
    bc      SFR_PORT_IO, 0              ; Enter blanking

    ; bitmap lines always pend interrupts
    bs      SFR_STATUS_REG, SB_GP_BIT_X

    ret

bitmap_out_byte:
    mov     SFR_INDIR_PORT, A           ; (T6+1)
    mova    SFR_DATA_EXCH               ; (T7+1=8)
    bp2f    BO_PORT_OUT0, 7             ; (T0+1) Display pixel 7 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 6             ; (T0+1) Display pixel 6 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 5             ; (T0+1) Display pixel 5 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 4             ; (T0+1) Display pixel 4 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 3             ; (T0+1) Display pixel 3 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 2             ; (T0+1) Display pixel 2 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 1             ; (T0+1) Display pixel 1 from SFR_DATA_EXCH
    inc     SFR_INDIR_ADDR, F           ; (T1+1)
    call    DELAY_6                     ; (T2+7 = 8)
    bp2f    BO_PORT_OUT0, 0             ; (T0+1) Display pixel 0 from SFR_DATA_EXCH
    ret                                 ; (T1+2) Calling back here takes 2 more clocks


text_scanline:
    ; Loop over columns, but without a counter
    clr     SFR_DATA_EXCH       ; (T4+1) Start with blank pixels
    mov     SFR_DATA_REG0, A    ; (T5+1) Display blank, load [0]
    call    text_glyph_loop     ; (T6+2=8)
    mov     SFR_DATA_REG1, A    ; (T5+1) Display [0], load [1]
    call    text_glyph_loop     ; (T6+2=8)
    mov     SFR_DATA_REG2, A    ; (T5+1) Display [1], load [2]
    call    text_glyph_loop
    mov     SFR_DATA_REG3, A    ; ...
    call    text_glyph_loop
    mov     SFR_DATA_REG4, A
    call    text_glyph_loop
    mov     SFR_DATA_REG5, A
    call    text_glyph_loop
    mov     SFR_DATA_REG6, A
    call    text_glyph_loop
    mov     SFR_DATA_REG7, A
    call    text_glyph_loop
    mov     SFR_DATA_REG8, A
    call    text_glyph_loop
    mov     SFR_DATA_REG9, A
    call    text_glyph_loop
    mov     SFR_DATA_REG10, A
    call    text_glyph_loop
    mov     SFR_DATA_REG11, A
    call    text_glyph_loop
    mov     SFR_DATA_REG12, A
    call    text_glyph_loop
    mov     SFR_DATA_REG13, A
    call    text_glyph_loop
    mov     SFR_DATA_REG14, A
    call    text_glyph_loop
    mov     SFR_DATA_REG15, A
    call    text_glyph_loop
    mov     SFR_DATA_REG16, A
    call    text_glyph_loop
    mov     SFR_DATA_REG17, A
    call    text_glyph_loop
    mov     SFR_DATA_REG18, A
    call    text_glyph_loop
    mov     SFR_DATA_REG19, A
    call    text_glyph_loop
    mov     SFR_DATA_REG20, A
    call    text_glyph_loop
    mov     SFR_DATA_REG21, A
    call    text_glyph_loop
    mov     SFR_DATA_REG22, A
    call    text_glyph_loop
    mov     SFR_DATA_REG23, A
    call    text_glyph_loop
    mov     SFR_DATA_REG24, A
    call    text_glyph_loop
    mov     SFR_DATA_REG25, A
    call    text_glyph_loop
    mov     SFR_DATA_REG26, A
    call    text_glyph_loop
    mov     SFR_DATA_REG27, A
    call    text_glyph_loop
    mov     SFR_DATA_REG28, A
    call    text_glyph_loop
    mov     SFR_DATA_REG29, A
    call    text_glyph_loop
    mov     SFR_DATA_REG30, A
    call    text_glyph_loop
    mov     SFR_DATA_REG31, A
    call    text_glyph_loop
    movl    0x20                ; Display [31], load ' ' (space)
    call    text_glyph_loop

    inc     LINE_COUNTER, F     ; Next line of glyph data

    ; Pend an interrupt if
    btss    LINE_COUNTER, 3         ; Rolled out of glyph data or
    btsc    SFR_CTRL_WR, 3          ; Host Requested int per scanline.
    bs      SFR_STATUS_REG, SB_GP_BIT_X

    ret

text_glyph_loop:
    ; Display 8 pixels while loading the next 8 (ideally)
    ; Actually already displays the first pixel of next set, because timing.
    ; glyph is at 0x100
    bp2f    BO_PORT_OUT0, 6             ; (T0+1) Display pixel 6 from SFR_DATA_EXCH
    mova    SFR_INDIR_ADDR              ; (T1+1) Set pointer: 0x400 + row/2 * 256 + byte)
    rcr     LINE_COUNTER, A             ; (T2+1)
    andl    0x03                        ; (T3+1)
    call    DELAY_4                     ; (T4+4 = 8)
    bp2f    BO_PORT_OUT0, 5             ; (T0+1) Display pixel 5 from SFR_DATA_EXCH
    iorl    0x4                         ; (T1+1)
    rdcode                              ; (T2+3) Read font data: SFR_INDIR_ADDR:A <= ROM(A:SFR_INDIR_ADDR)
    btsc    LINE_COUNTER, 0             ; (T5+1 or T5+2 = 7) Add rows take from INDIR, even keep A
    mov     SFR_INDIR_ADDR, A           ; (T6+1 or T7+0 = 7)
    nop                                 ; (T7+1 = 8)
    bp2f    BO_PORT_OUT0, 4             ; (T0+1) Display pixel 4 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 3             ; (T0+1) Display pixel 3 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 2             ; (T0+1) Display pixel 2 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 1             ; (T0+1) Display pixel 1 from SFR_DATA_EXCH
    call    DELAY_7                     ; (T1+7 = 8)
    bp2f    BO_PORT_OUT0, 0             ; (T0+1) Display pixel 0 from SFR_DATA_EXCH
    mova    SFR_DATA_EXCH               ; (T1+1) Update buffer with next pixel
    call    DELAY_6                     ; (T2+6 = 8)
    bp2f    BO_PORT_OUT0, 7             ; (T0+1) Display pixel 7 from SFR_DATA_EXCH (next)
    jmp     DELAY_4                     ; (T1+4 = 5) Outter code takes +3 for mov+call.

DELAY_8:
    nop
DELAY_7:
    nop
DELAY_6:
    nop
DELAY_5:
    nop
DELAY_4:
    ret


INCLUDE fonts/zx81_ascii_font.inc


    end

