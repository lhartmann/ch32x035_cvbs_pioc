timer_ntsc_setup:
    ; set period to 63.55us for a NTSC scanline
    ; With Fcpu=48MHz, period = 3050 clocks
    movl    65                                  ; Set period to 191, i.e., start counting at 256 - 191 = 65
    mova    SFR_TMR0_INIT

    movl    SB_TMR0_FREQ_DIV16   ; Prescaled by 16, and enable
    mova    SFR_TIMER_CTRL
    bs      SFR_TIMER_CTRL, SB_TMR0_ENABLE
timer_ntsc_sync_done: ; Reuse ret
    ret

    ; Wait and return lockstep with timer
timer_ntsc_sync:
    incsz   SFR_TMR0_COUNT, A               ; T0 T1 T2 ; since timer counter to 0xFF
    jmp     timer_ntsc_sync
    nop                                     ; T2
    nop                                     ; T3
    nop                                     ; T4
    nop                                     ; T5
    nop                                     ; T6
    nop                                     ; T7
    nop                                     ; T8
    nop                                     ; T9
    nop                                     ; T10
    nop                                     ; T11
    ; nop                                     ; did I miscount? Nope, simulator mismatch.
    movl    0                               ; T12
    add     SFR_TMR0_COUNT, A               ; T13 T14 T15 ; reads 255 255 255
    add     SFR_TMR0_COUNT, A               ; T14 T15 T16 ; reads 255 255  65
    add     SFR_TMR0_COUNT, A               ; T15 T16 T17 ; reeas 255  65  65
    add     SFR_TMR0_COUNT, A               ; T16 T17 T18 ; reads  65  65  65
    andl    0x7F                            ; T17 T18 T19
    cmpz    0x42, timer_ntsc_sync_done      ; T18 T19 T20 ; True if was T21, i.e., it read () & 0x7F == 43
    cmpz    0x00, timer_ntsc_sync_done      ; T19 T20     ; True if was T21, i.e., it read () & 0x7F == 3C
    cmpz    0x3e, timer_ntsc_sync_done      ; T20         ; True if was T21, i.e., it read (0xff + 0xff + 0x65) & 0x7F == 3C
timer_ntsc_fail:
    sleep
    jmp     timer_ntsc_fail
