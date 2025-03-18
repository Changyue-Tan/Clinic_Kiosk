/*
.equ MAX_NAME_LENGTH = 10             
.def temp_char = r16                   
.def loop_counter = r17                
.def digit = r18                       
.def temp_id = r19                     
.def temp = r20                        
.def leds = r21                       
*/

.macro DISPLAY_PATIENT_PROLOGUE
    push    r16
    push    r17
    push    r18
    push    r19
    push    r20
    push    r21
    push    r22
    push    r23
    push    r24
    push    r25
    push    ZL
    push    ZH
.endmacro 

.macro  DISPLAY_PATIENT_EPILOGUE
    pop     ZH
    pop     ZL
    pop     r25
    pop     r24
    pop     r23
    pop     r22
    pop     r21
    pop     r20
    pop     r19
    pop     r18
	pop     r17
    pop     r16
.endmacro  

; The following are implemented by JinG Yuan Xue, commented and linked to main by Changyeu Tan

.macro DISPLAY_PATIENT_INFO
    ld      r16, Z+
    ld      r17, Z                                  ; load address of next_patient to r17:r16
    mov     ZL, r16
    mov     ZH, r17                                 ; mov address of next_patient to ZH:ZL
    ldi     r17, 10                                 ; will load 10 chars in total

    display_name_loop_fixed:
        ld      r16, Z+                             ; load 1 char from next_patient
        DO_LCD_DATA_REGISTER r16                    ; Dispaly that char to LCD
        dec     r17                                 ; one less char to be loaded
        brne    display_name_loop_fixed             ; if r17 is not zero, continue load and display chars

        ldi     r17, 3                              ; add three spaces (seperate name and patient number)
        add_spaces_loop_fixed:
            cpi     r17, 0                          ; if all three spaces are printed
            breq    display_id_fixed                ; go to display patient number
            ldi     r16, ' '                        ; load ASCII of space to r16
            DO_LCD_DATA_REGISTER r16                ; Display ' ' to LCD
            dec     r17                             
            rjmp    add_spaces_loop_fixed           

    display_id_fixed:
        nop
.endmacro


display_next_patient:
    DISPLAY_PATIENT_PROLOGUE

    REFRESH_LCD
    LCD_DISPLAY_STRING_FROM_PROGRAM_SPACE Display_Mode_Message
    DO_LCD_COMMAND 0xC0                             ; set cursor to bottom left

    rcall   strobe_on                               ; turn on strobe LED signals connection with LCD 2
                                                    ; any update to LCD 1 will be mirrored to LCD 2

    ldi     ZL, low(Next_Patient)
    ldi     ZH, high(Next_Patient)
    DISPLAY_PATIENT_INFO
    lds     r17, Next_Patient_Number                ; load Next_Patient_Number to r17
    rcall   LCD_display_1_byte_number_from_r17      ; print Next_Patient_Number to LCD
    
    DISPLAY_PATIENT_EPILOGUE
    ret

display_last_patient:
    DISPLAY_PATIENT_PROLOGUE
    
    REFRESH_LCD
    LCD_DISPLAY_STRING_FROM_PROGRAM_SPACE Entry_Mode_Complete_Message
    DO_LCD_COMMAND 0xC0                             ; set cursor to bottom left

    ldi     ZL, low(Last_Patient)
    ldi     ZH, high(Last_Patient)
    DISPLAY_PATIENT_INFO
    lds     r17, Last_Patient_Number                ; load Last_Patient_Number to r17
    rcall   LCD_display_1_byte_number_from_r17      ; print Last_Patient_Number to LCD
    
    DISPLAY_PATIENT_EPILOGUE
    ret





