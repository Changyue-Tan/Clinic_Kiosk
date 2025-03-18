.macro BLINK_PROLOGUE
    push    r16
.endmacro

.macro BLINK_EPILOGUE
    pop     r16
.endmacro

; turn on bell (motor) and all LEDs
led_bell_high:
    BLINK_PROLOGUE
    ser     r16
	out     PORTC,  r16         ; led
    out     PORTG,  r16         ; led
    sts     PORTH,  r16	        ; montor

    BLINK_EPILOGUE
    ret

; turn off bell (motor) and all LEDs
led_bell_low:
    BLINK_PROLOGUE
    clr     r16
	out     PORTC,  r16
    out     PORTG,  r16
    sts     PORTH,  r16	

    BLINK_EPILOGUE
    ret