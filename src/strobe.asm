; we only change the respective bit of Port A to turn on and off the Strobe LED
; in case any other periferical is using Port A for other purpose

strobe_off:
    push    r16
    push    r17

    clr     r16
    out     DDRA, r16           ; set port A as input
    in      r17, PINA           ; read from port A
    andi    r17, 0b11111101     ; clear bit 1 (connected to the strobe)
    ser     r16
    out     DDRA, r16           ; set port A as ouput
    out     PORTA, r17          ; ouput the original pattern to Port A, but with bit 1 cleared

    pop     r17
    pop     r16

    ret

strobe_on:
    push    r16
    push    r17

    clr     r16
    out     DDRA, r16           ; set port A as input
    in      r17, PINA           ; read from port A
    ori     r17, 0b00000010     ; set bit 1 (connected to the strobe)
    ser     r16
    out     DDRA, r16           ; set port A as ouput
    out     PORTA, r17          ; ouput the original pattern to Port A, but with bit 1 set

    pop r17
    pop r16

    ret