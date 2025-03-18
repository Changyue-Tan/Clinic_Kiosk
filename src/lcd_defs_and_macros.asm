.equ LCD_RS         =   7       ;   Register Select
.equ LCD_RW         =   5       ;   Signal to select Read or Write
.equ LCD_E          =   6       ;   Enable - Operation start signal for data read/write
.equ LCD_BF         =   7       ;   Busy Flag (DB7)

; RS		RW			Operation
; 0			0			Instruction Register Write
; 0			1			Busy flag(DB7) and Address Counter(DB6:DB0) read
; 1			0			Data Register Write
; 1			1			Data Register Read

; Set a particular bit in LCD control register
.macro LCD_SET
	sbi			PORTA,			@0
.endmacro

; Clear a particular bit in LCD control register
.macro LCD_CLR
	cbi			PORTA,			@0
.endmacro

.macro LCD_GO_HOME
	DO_LCD_COMMAND 0b00000010 	; return home
.endmacro

.macro REFRESH_LCD
	DO_LCD_COMMAND 0b00000001 	; clear display
	LCD_GO_HOME
.endmacro

.macro DO_LCD_COMMAND
	push r16
	ldi			r16,			@0
	rcall		lcd_command
	rcall		lcd_wait
	pop r16
.endmacro

.macro DO_LCD_COMMAND_REGISTER 
	push r16
	mov			r16,			@0
	rcall		lcd_command
	rcall		lcd_wait
	pop r16
.endmacro

.macro DO_LCD_DATA_IMMEDIATE
	push r16
	ldi			r16,			@0
	rcall		lcd_data
	rcall		lcd_wait
	pop r16
.endmacro

.macro DO_LCD_DATA_REGISTER
	push r16
	mov			r16,			@0
	rcall		lcd_data
	rcall		lcd_wait
	pop r16
.endmacro

.macro DO_LCD_DATA_MEMORY_ONE_BYTE
	DATA_MEMORY_PROLOGUE
	ldi 	YL, low(@0) 							; load the memory address to Y
	ldi 	YH, high(@0)
	ld 		r24, Y
	DO_LCD_DATA_REGISTER r24
	DATA_MEMORY_EPILOGUE
.endmacro

; @0 is address in program space
.macro LCD_DISPLAY_STRING_FROM_PROGRAM_SPACE
	push ZL
	push ZH
	push r16
	start_display_string:
		ldi 	ZL, low(@0<<1) 
		ldi 	ZH, high(@0<<1)
	dispaly_char_in_str:
		lpm 	r16, Z+
		cpi 	r16, 0
		breq 	finish_display_string
		DO_LCD_DATA_REGISTER r16
		rjmp 	dispaly_char_in_str
	finish_display_string:
	pop 	r16
	pop 	ZH
	pop 	ZL
.endmacro

.macro DO_LCD_DISPLAY_2_BYTE_NUMBER_FROM_DATA_MEMEORY_ADDRESS
	push 	YH 										; Save all conflict registers in the prologue.
	push 	YL
	push 	r16 									; counter for power of tens of digits in decimal
	push 	r24
	push 	r25 									; data to be displayed r25:r24
	push 	r26	
	push 	r27										; quotient r27:r26
	
	clr 	r16 
	clr 	r26
	clr 	r27
	
	ldi 	YL, low(@0) 							; load the memory address to Y
	ldi 	YH, high(@0)
	ld 		r24, Y+ 
	ld 		r25, Y
	
	keep_minus_10:

		tst 	r25               					; Test if the high byte is zero
		brne 	continue_minus_10 					; If r25 is non-zero, the number is greater than 10

		cpi 	r24, 10          					; Compare the low byte to 10
		brlo 	division_finish    					; Branch if r24 < 10

		continue_minus_10:
			sbiw 	r25:r24, 10
			adiw 	r27:r26, 1
			rjmp 	keep_minus_10
	
	division_finish:
		push 	r24 								; push remainder to stack
		inc		r16									; number of digits in to be displayed + 1
		movw 	r25:r24, r27:r26 					; quotient becomes the new dividend
		clr 	r26
		clr 	r27									; set new quotient to zero
		
		tst 	r25               					; Test if the high byte of new dividend is zero
		brne 	continue_minus_10 					; If r25 is non-zero, the number is greater than 10

		cpi 	r24, 10          					; Compare the low byte of new dividend to 10
		brlo 	conversion_finish    				; Branch if r24 < 10
		
		rjmp 	continue_minus_10

	conversion_finish:
		push 	r24 								; push the last digit to stack
		inc 	r16 

	display_digit_from_stack:
		cpi 	r16, 0 								; test if umber of digits in to be displayed is 0
		breq 	all_digits_displayed
		pop 	r24									; pop digit from stack to r24
		dec 	r16 								; number of digits in to be displayed - 1

		subi 	r24, -'0'
		DO_LCD_DATA_REGISTER r24

		rjmp 	display_digit_from_stack

	all_digits_displayed:
        pop 	r27
        pop 	r26
        pop 	r25
        pop 	r24 
        pop 	r16 
        pop 	YL
        pop 	YH
.endmacro

