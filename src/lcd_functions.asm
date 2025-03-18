 setup_LCD:
	ser			r16
	out			DDRF,			r16						; set port F for output
	out			DDRA,			r16						; set port A for output
	clr			r16
	out			PORTF,			r16						; DB7~0 = 0
	out			PORTA,			r16						; RS, R/W = 0
														; defaults to instruction register write

	DO_LCD_COMMAND 0b00111000							; DB7~6 = 0, and DB5 = 1: 
														; Function Set
														; DB4 (DL) = 1: data sent to LCD in 8 bit size
														; DB3 (N) = 1, 2-line display
														; DB2 (F) = 0, 5 x 7 dot matrix
														;
	rcall		sleep_5ms								; wait more than 4.1 ms
														;
	DO_LCD_COMMAND 0b00111000							; Repeat Function Set
														;
	rcall		sleep_1ms								; wait more than 100 nano s
														;
	DO_LCD_COMMAND 0b00111000							; Repeat Function Set
														; LCD start up finish, can begin to read busy flag
														;
	DO_LCD_COMMAND 0b00111000							; Actual Function Set
	DO_LCD_COMMAND 0b00001000							; display off
	DO_LCD_COMMAND 0b00000001							; clear display
														;
	DO_LCD_COMMAND 0b00000110							; RS, R/W, DB7~3 = 0, and DB2 = 1:
														; Entry Mode Set:
														; DB1 (I/D) = 1: increment address counter by 1 for each DD RAM access
														; DB0 = 0: no shift
														;
	DO_LCD_COMMAND 0b00001110							; RS, R/W, DB7~4 = 0, and DB3 = 1:
														; Display ON/OFF Control
														; DB2 (D) = 1: Display on
														; DB1 (C) = 1: Cursor on
														; DB0 (B) = 0: Cursor blink off

    DO_LCD_DATA_IMMEDIATE 'R'
    DO_LCD_DATA_IMMEDIATE 'E'
    DO_LCD_DATA_IMMEDIATE 'S'
	DO_LCD_DATA_IMMEDIATE 'T'
    DO_LCD_DATA_IMMEDIATE 'A'
    DO_LCD_DATA_IMMEDIATE 'R'
    DO_LCD_DATA_IMMEDIATE 'T'
	rcall sleep_500ms
	REFRESH_LCD
	ret



lcd_command:
	out			PORTF,			r16
	nop
	LCD_SET LCD_E										; Set Enable bit
	nop
	nop
	nop
	LCD_CLR LCD_E										; Clear Enable bit
	nop
	nop
	nop
	ret

lcd_data:
	out			PORTF,			r16
	LCD_SET LCD_RS										; Set Register Select Bit: Data Register Write
	nop
	nop
	nop
	LCD_SET LCD_E										; Set Enable Bit
	nop
	nop
	nop
	LCD_CLR LCD_E										; Clear Enable Bit
	nop
	nop
	nop
	LCD_CLR LCD_RS										; Clear RS bit: Instruction Register Write
	ret


; wait for busy flag is cleared
lcd_wait:
	push		r16
	clr			r16
	out			DDRF,			r16						; Set Port F to Input
	; out			PORTF,			r16					; Disable Pull up (this is in the example)
	LCD_SET		LCD_RW									; Set R/W bit: Data Register Read

    lcd_wait_loop:
        nop
        LCD_SET		LCD_E									; Set Enable bit
        nop
        nop
        nop
        in			r16,			PINF					; Read from port F
        LCD_CLR		LCD_E									; Clear Enable Bit
        sbrc		r16,			7						; skip next instrucntion if bit 7 (busy flag) is cleared
        rjmp		lcd_wait_loop							;
        LCD_CLR		LCD_RW									; Clear R/W bit: Data Register Write
        ser			r16
        out			DDRF,			r16						; set port F to input 
        pop			r16
        ret

LCD_display_1_byte_number_from_r17:
	push	r16							; for divisor
	;push	r17							; for dividend (remainder)
	push	r18							; for quotient
	

	ldi		r16,			100
	rcall   extract_digit			; rcall function to extract and display digits (by power of 10)

	ldi		r16,			10
	rcall   extract_digit			; rcall function to extract and display digits (by power of 10)

	ldi		r16,			1
	rcall   extract_digit			; rcall function to extract and display digits (by power of 10)
	
	end_display:
		pop			r18
		; pop			r17
		pop			r16
		ret

	extract_digit:
		ldi     r18, 0                      	; Clear r18 for quotient
		
		divide_loop:
			cp     r17, r16                     ; Compare dividend with divisor
			brmi    store_digit                 ; If less than divisor, store digit
			sub    r17, r16                     ; Subtract divisor from dividend
			inc     r18                         ; Increment quptient
			rjmp    divide_loop                 ; Repeat division

		store_digit:
			subi    r18, -'0'                   ; Convert quotient to ASCII
			DO_LCD_DATA_REGISTER r18      		; Send digit to LCD

		ret
