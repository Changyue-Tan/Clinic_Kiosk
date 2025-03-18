.macro DATA_MEMORY_PROLOGUE
	push YL
	push YH
	push r16
    push r24
    push r25
.endmacro

.macro DATA_MEMORY_EPILOGUE
	pop r25
	pop r24
    pop r16
	pop YH
	pop YL
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Two byte operations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Data space address taken as @0
.macro CLEAR_TWO_BYTE_IN_DATA_MEMORY
	DATA_MEMORY_PROLOGUE
	ldi YL, low(@0) 
	ldi YH, high(@0)
	clr r16
	st Y+, r16 
	st Y, r16
	DATA_MEMORY_EPILOGUE
.endmacro

; Data space address taken as @0
; Lower byte to be stored taken as @1
; Higher byte to be stored taken as @2
.macro STORE_TWO_BYTE_IN_DATA_MEMORY
	DATA_MEMORY_PROLOGUE
	ldi YL, low(@0) 
	ldi YH, high(@0)
	st Y+, @1 
	st Y, @2
	DATA_MEMORY_EPILOGUE
.endmacro

; Data space address taken as @0
.macro INCREMENT_TWO_BYTE_IN_DATA_MEMORY
	DATA_MEMORY_PROLOGUE
	ldi YL, low(@0) 
	ldi YH, high(@0)
	ld r24, Y+ 
	ld r25, Y
	adiw r25:r24, 1 
	st Y, r25 
	st -Y, r24
	DATA_MEMORY_EPILOGUE
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; One byte operations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Data space address taken as @0
.macro CLEAR_ONE_BYTE_IN_DATA_MEMORY
	DATA_MEMORY_PROLOGUE
	ldi YL, low(@0) 
	ldi YH, high(@0)
	clr r16
	st Y, r16 
	DATA_MEMORY_EPILOGUE
.endmacro

; Data space address taken as @0
; Byte to be stored taken as @1
.macro STORE_ONE_BYTE_IN_DATA_MEMORY
	DATA_MEMORY_PROLOGUE
	ldi YL, low(@0) 
	ldi YH, high(@0)
	st Y, @1 
	DATA_MEMORY_EPILOGUE
.endmacro

; Data space address taken as @0
.macro INCREMENT_ONE_BYTE_IN_DATA_MEMORY
	DATA_MEMORY_PROLOGUE
	ldi YL, low(@0) 
	ldi YH, high(@0)
	ld r16, Y
	inc r16
	st Y, r16
	DATA_MEMORY_EPILOGUE
.endmacro