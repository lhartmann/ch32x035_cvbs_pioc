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

SYNC_SHORT  EQU 19  ; Trial an error, target 4.70us
SYNC_LONG   EQU 235 ; Trial an error, target 58.85us
H_BACK      EQU 200 ; Trial an error, target 58.85us

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

    movl    V_FRONT
    mova    LINE_COUNTER
vertical_front_porch_loop:
    call    blank_scanline
    decsz   LINE_COUNTER, F
    jmp     vertical_front_porch_loop

    movl    V_SYNC
    mova    LINE_COUNTER
vertical_sync_loop:
    call    sync_scanline
    decsz   LINE_COUNTER, F
    jmp     vertical_sync_loop

    movl    V_BACK
    mova    LINE_COUNTER
vertical_back_porch_loop:
    call    blank_scanline
    decsz   LINE_COUNTER, F
    jmp     vertical_back_porch_loop

    ; 24 lines of text, 8 scanlines each Unrolled to save ram.
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text
    call    line_of_text

    movl    0xFF
    mova    SFR_CTRL_RD

    jmp     screen

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
blank_scanline:
    call    timer_ntsc_sync
    movl    SYNC_SHORT
    jmp     gen_sync

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
sync_scanline:
    call    timer_ntsc_sync
    movl    SYNC_LONG
    jmp     gen_sync

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
line_of_text:
    INC    SFR_CTRL_RD, F ; Let the CPU know it is time to send text.
    ; Text is received by having the host write directly to R0-R31.
    ; Host better be done before we need it.
    movl    0
    mova    LINE_COUNTER

display_text_loop:
    call    timer_ntsc_sync
    movl    SYNC_SHORT
    call    gen_sync
    ; [ TODO, wait for the right time, center image horizontally ]

    movl    H_BACK
    mova    DELAY_COUNTER
display_text_horizontal_delay:
    decsz  DELAY_COUNTER, F
    jmp     display_text_horizontal_delay

    ; Loop over columns, but without a counter
    clr     SFR_DATA_EXCH       ; Start with blank pixels
    mov     SFR_DATA_REG0, A    ; Display blank, load [0]
    call    display_inner_loop
    mov     SFR_DATA_REG1, A    ; Display [0], load [1]
    call    display_inner_loop
    mov     SFR_DATA_REG2, A    ; Display [1], load [2]
    call    display_inner_loop
    mov     SFR_DATA_REG3, A    ; ...
    call    display_inner_loop
    mov     SFR_DATA_REG4, A
    call    display_inner_loop
    mov     SFR_DATA_REG5, A
    call    display_inner_loop
    mov     SFR_DATA_REG6, A
    call    display_inner_loop
    mov     SFR_DATA_REG7, A
    call    display_inner_loop
    mov     SFR_DATA_REG8, A
    call    display_inner_loop
    mov     SFR_DATA_REG9, A
    call    display_inner_loop
    mov     SFR_DATA_REG10, A
    call    display_inner_loop
    mov     SFR_DATA_REG11, A
    call    display_inner_loop
    mov     SFR_DATA_REG12, A
    call    display_inner_loop
    mov     SFR_DATA_REG13, A
    call    display_inner_loop
    mov     SFR_DATA_REG14, A
    call    display_inner_loop
    mov     SFR_DATA_REG15, A
    call    display_inner_loop
    mov     SFR_DATA_REG16, A
    call    display_inner_loop
    mov     SFR_DATA_REG17, A
    call    display_inner_loop
    mov     SFR_DATA_REG18, A
    call    display_inner_loop
    mov     SFR_DATA_REG19, A
    call    display_inner_loop
    mov     SFR_DATA_REG20, A
    call    display_inner_loop
    mov     SFR_DATA_REG21, A
    call    display_inner_loop
    mov     SFR_DATA_REG22, A
    call    display_inner_loop
    mov     SFR_DATA_REG23, A
    call    display_inner_loop
    mov     SFR_DATA_REG24, A
    call    display_inner_loop
    mov     SFR_DATA_REG25, A
    call    display_inner_loop
    mov     SFR_DATA_REG26, A
    call    display_inner_loop
    mov     SFR_DATA_REG27, A
    call    display_inner_loop
    mov     SFR_DATA_REG28, A
    call    display_inner_loop
    mov     SFR_DATA_REG29, A
    call    display_inner_loop
    mov     SFR_DATA_REG30, A
    call    display_inner_loop
    mov     SFR_DATA_REG31, A
    call    display_inner_loop
    movl    0x20                ; Display [31], load ' ' (space)
    call    display_inner_loop

    inc     LINE_COUNTER, F          ; Next row
    movl    8                   ; Loop until ROW_COUNTER == 8
    sub     LINE_COUNTER, A
    jnz     display_text_loop
    jmp     hsync               ; tail-call hsync

display_inner_loop:
    ; Display 8 pixels while loading the next 8 (ideally)
    ; Actually already displays the first pixel of next set, because timing.
    ; glyph is at 0x100
    bp2f    BO_PORT_OUT0, 6             ; (T0+1) Display pixel 6 from SFR_DATA_EXCH
    mova    SFR_INDIR_ADDR              ; (T1+1) Set pointer: 0x400 + row/2 * 256 + byte)
    bc      SFR_STATUS_REG, SB_FLAG_C   ; (T2+1)
    rcr     LINE_COUNTER, A              ; (T3+1)
    iorl    0x4                         ; (T4+1)
    nop                                 ; (T5+1 = 6)
    bp2f    BO_PORT_OUT0, 5             ; (T0+1) Display pixel 5 from SFR_DATA_EXCH
    rdcode                              ; (T1+3) Read font data: SFR_INDIR_ADDR:A <= ROM(A:SFR_INDIR_ADDR)
    btsc    LINE_COUNTER, 0              ; (T4+1 or T4+2 = 6) Add rows take from INDIR, even keep A
    mov     SFR_INDIR_ADDR              ; (T5+1 or T6+0 = 6)
    bp2f    BO_PORT_OUT0, 4             ; (T0+1) Display pixel 4 from SFR_DATA_EXCH
    call    DELAY_5                     ; (T1+5 = 6)
    bp2f    BO_PORT_OUT0, 3             ; (T0+1) Display pixel 3 from SFR_DATA_EXCH
    call    DELAY_5                     ; (T1+5 = 6)
    bp2f    BO_PORT_OUT0, 2             ; (T0+1) Display pixel 2 from SFR_DATA_EXCH
    call    DELAY_5                     ; (T1+5 = 6)
    bp2f    BO_PORT_OUT0, 1             ; (T0+1) Display pixel 1 from SFR_DATA_EXCH
    call    DELAY_5                     ; (T1+5 = 6)
    bp2f    BO_PORT_OUT0, 0             ; (T0+1) Display pixel 0 from SFR_DATA_EXCH
    mova    SFR_DATA_EXCH               ; (T1+1) Update buffer with next pixel
    call    DELAY_4                     ; (T2+4 = 6)
    bp2f    BO_PORT_OUT0, 7             ; (T0+1) Display pixel 7 from SFR_DATA_EXCH (next)
    ret                                 ; (T1+2 = 3) Outter code takes +3 for mov+call.

DELAY_5:
    nop
DELAY_4:
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; horizontal sync for "full" periods, like active scanlines.           ;;
;; Arguments:                                                           ;;
;;     A: number of sync cyles to generate. Each is 2 timer perids.     ;;
;; Clobers:                                                             ;;
;;          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hsync_full:

    ret


hsync:
    call timer_ntsc_sync
    ret

    end

