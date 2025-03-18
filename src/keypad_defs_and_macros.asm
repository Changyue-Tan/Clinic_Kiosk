; local constants for keypad
.equ PORTLDIR	 =	0b11110000							; use Port L for input/output from keypad: PF7-4, output, PF3-0, input
.equ INITCOLMASK =	0b11101111							; scan from the leftmost column, the value to mask output
.equ INITROWMASK =	0b00000001							; scan from the bottom row
.equ ROWMASK	 =	0b00001111							; low four bits are output from the keypad. This value mask the high 4 bits.

; local variable for keypad
.def row    = r20										; current row number
.def col    = r21										; current column number
.def rmask  = r22										; mask for current row
.def cmask	= r23										; mask for current column
.def temp1	= r24										
.def temp2  = r25


/*
The following macro is redundant as its functionality replace by a subroutine in "keypad_functins.asm" 

; data memory location to store the ascii value of the key being pressed taken as @0
.macro SCAN_KEYPAD_INPUT_AS_ASCII_TO_DATA_MEMORY
    push r16
    push r20
	push r21
	push r22
	push r23
	push r24
	push r25
    
    scan_start:
        clr r16
        clr r20
        clr r21
        clr r22
        clr r23
        clr r24
        clr r25

	ldi			cmask,			INITCOLMASK				; set cmask to 0b11101111
	clr			col										; set initial column number to 0

	colloop:
		cpi			col,			4						; if we have scanned all 4 columns, 
		breq		scan_start								; continue
															; else, start scanning the "col"th column
		STS			PORTL,			cmask					; ouput 0 to the column that we wish to scan
		rcall		sleep_5ms

		LDS			temp1,			PINL
		andi		temp1,			ROWMASK					; read from the low bits of PORTL 
		cpi			temp1,			0xF						; check if any rows are on
		breq		nextcol									; no rows are 0, hence no key is pressed, scan next column
															; else, a key is pressed, check which row it is
		ldi			rmask,			INITROWMASK				; initialise row check, set rmask to 0b00000001
		clr			row										; initial row = 0

		rowloop:
			cpi			row,			4						; check if we have scanned all 4 rows
			breq		nextcol									; if yes, scan next column
																; else, scan this row
			mov			temp2,			temp1					; temp1 is the lower bits if port L
			and			temp2,			rmask					; check the "row"th bit of temp2
			breq		convert 								; if the "row"th bit is 0, this key is pressed
																; else, scan the next row
			inc			row										; 
			lsl			rmask									; shift the mask to the next bit
			jmp			rowloop

	nextcol:
		lsl			cmask									; else get new mask by shifting and 
		inc			col										; increment column value
		jmp			colloop									; and check the next column

	convert:
		cpi			col,			3						; if column is 3 we have a letter
		breq		letters				
		cpi			row,			3						; if row is 3 we have a symbol or 0
		breq		symbols

		mov			temp1,			row						; otherwise we have a number in 1-9
		lsl			temp1					
		add			temp1,			row						; temp1 = row * 3 (row * 2 + row)
		add			temp1,			col						; add the column address to get the value
		
		subi		temp1,			-1
		
		subi		temp1,			-'0'					; add the value of character '0'
		
		jmp			convert_end

		letters:
			ldi			temp1,			'A'
			add			temp1,			row						; increment the character 'A' by the row value
			jmp			convert_end

		symbols:
			cpi			col,			0						; check if we have a star
			breq		star

			cpi			col,			1						; or if we have zero
			breq		zero	
							
			ldi			temp1,			'#'						; if not we have hash
			jmp			convert_end

		star:
			ldi			temp1,			'*'						; set to star
			jmp			convert_end

		zero:
			ldi			temp1,			'0'						; set to zero
		
	convert_end:

		mov 		r16, 			temp1
		rcall		sleep_125ms									; debouncing
	
    ldi YL, low(@0) 
	ldi YH, high(@0)
    st  Y, r16

    pop r16
	pop r25
	pop r24
	pop r23
	pop r22
	pop r21
	pop r20
.endmacro
*/