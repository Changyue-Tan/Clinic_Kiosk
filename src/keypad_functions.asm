; keypad set up, executed only once
setup_keypad:
	push temp1
	ldi			temp1,			PORTLDIR				; 
	STS			DDRL,			temp1					; set high bits of port L to output, and low bits to input
	pop temp1
	ret


take_keypad_input:
    push r16
	push r17
    push r20
	push r22
	push r23
	push r24
	push r25
    
    scan_start:
		clr r16
		clr r17
        clr r20
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

		LDS			r17 ,			PINL
		andi		r17 ,			ROWMASK					; read from the low bits of PORTL 
		cpi			r17 ,			0xF						; check if any rows are on
		breq		nextcol									; no rows are 0, hence no key is pressed, scan next column
															; else, a key is pressed, check which row it is
		ldi			rmask,			INITROWMASK				; initialise row check, set rmask to 0b00000001
		clr			row										; initial row = 0

		rowloop:
			cpi			row,			4						; check if we have scanned all 4 rows
			breq		nextcol									; if yes, scan next column
																; else, scan this row
			mov			r18,			r17 					; r17  is the lower bits if port L
			and			r18,			rmask					; check the "row"th bit of r18
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

		mov			r17 ,			row						; otherwise we have a number in 1-9
		lsl			r17 					
		add			r17 ,			row						; r17  = row * 3 (row * 2 + row)
		add			r17 ,			col						; add the column address to get the value
		subi		r17 ,			-1
		subi		r17 ,			-'0'					; add the value of character '0'
		
		jmp			convert_end

		letters:
			ldi			r17 ,			'A'
			add			r17 ,			row						; increment the character 'A' by the row value
			jmp			convert_end

		symbols:
			cpi			col,			0						; check if we have a star
			breq		star

			cpi			col,			1						; or if we have zero
			breq		zero	
							
			ldi			r17 ,			'#'						; if not we have hash
			jmp			convert_end

		star:
			ldi			r17 ,			'*'						; set to star
			jmp			convert_end

		zero:
			ldi			r17 ,			'0'						; set to zero
		
	convert_end:
        mov 		r21, 			r17 
		rcall		sleep_125ms

    
	pop r25
	pop r24
	pop r23
	pop r22
	pop r20
	pop r17
	pop r16

    ret


