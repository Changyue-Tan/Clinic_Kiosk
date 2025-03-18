; .def temp            = r16
/*
.def temp1           = r17
.def temp2           = r18
.def temp3           = r19
.def temp4           = r20
.def input           = r21   
.def name_index      = r22   
.def last_key        = r23   
.def letter_index    = r24   
.def current_letter  = r25   
.def temp_letter     = r26   
.def temp_letter_num = r27   
*/

.macro ENTRY_MODE_PROLOGUE
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
    push    r26
    push    r27
    push    ZL
    push    ZH
    push    YL
    push    YH
.endmacro 

.macro  ENTRY_MODE_EPILOGUE
    pop     YH
    pop     YL
    pop     ZH
    pop     ZL
    pop     r27
    pop     r26
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


start_entry_mode:
    ENTRY_MODE_PROLOGUE
    INCREMENT_ONE_BYTE_IN_DATA_MEMORY Entry_Mode_Flag       ; set Entry_Mode_Flag, so that when INT0 triggers, 
                                                            ; we can return to where we left
    rcall strobe_off                                        ; turn off strobe LED, signals that
                                                            ; any update to LCD 1 will not be sent to LCD 2
    initialise_entry_mode: 
        REFRESH_LCD
        LCD_DISPLAY_STRING_FROM_PROGRAM_SPACE Entry_Mode_Prompt
        DO_LCD_COMMAND 0xC0                                     ; move cursor to start of second line
                                                                ; 0x40 + 0b10000000 = 0xC0
        clr         r22                                         ; index which letter in name string
        clr         r23                                         ; last key pressed
        clr         r24                                         ; index which letter a key is referring

        ldi         YL, low(temp_name)
        ldi         YH, high(temp_name)                         ; Y points to first char in temp_name
        ldi         r17 , 10
        clear_temp_name_loop:                                   ; temp_name is initialised to be 10 spaces
            ldi         r18, ' '    
            st          Y+, r18
            dec         r17 
            brne        clear_temp_name_loop

        ldi         YL, low(Patient_Name)
        ldi         YH, high(Patient_Name)                      ; Y points to first char in Patient_Name
        ldi         r17 , 10
        clear_Patient_Name_loop:                                ; Patient_Name is initialised to be 10 spaces
            ldi         r18, ' '    
            st          Y+, r18
            dec         r17 
            brne        clear_Patient_Name_loop
        
        clr r17

main_loop:
    rcall       take_keypad_input                           ; input from keypad stored in r21
    
    cpi         r21, '2'                                
    brlo        not_number                                  ; 1 is pressed, consider it not a number

    cpi         r21, '9'+ 1
    brsh        not_number                                  ; letters or symbols are pressed

    cp          r21, r23                                    ; compare with last pressed key
    breq        same_key                                    ; if same key is pressed, branch
                                                            ; else, different key is pressed
    mov         r23, r21                                    ; move current pressed key to last pressed key 
    clr         r24                                         ; letter_index reset to 0
    rjmp        display_current_letter

    same_key:
        ldi         r16, 0xC0                   ; move cursor back to the previous slot 
        add         r16, r22                    ; by adding start of second line with index in string
        DO_LCD_COMMAND_REGISTER r16
        inc         r24                         ; inrement letter_index. Since same key is pressed, 
                                                ; move to next letter referred by the repeatedly pressed key 

    display_current_letter:
        mov         r18, r21                    ; move input from keypad (r21) to a temporary regiester 
        subi        r18, '2'                    ; subtract ASCII of 2 from it to get the number on key pressed
        lsl         r18                         ; r18 = r18 * 2, r18 is going to be used as an index of 
                                                ; an array of pointers, each of them have 2 bytes in length 
        ldi         ZL, low(key_offsets<<1)     ; Program memory is word addressed.
        ldi         ZH, high(key_offsets<<1)    ; To address each byte in program memory
                                                ; The address is doubled, 
                                                ; if the doubled address has LSB = 0, addressed to the low byte
                                                ; if the doubled address has LSB - 1, addressed to the high byte
        clr         r1                          ; r1 will be used as 0
        add         ZL, r18                     ; add the off set to the start address of array
        adc         ZH, r1                      ; add the carry bit to the high byte

        lpm         r17, Z+                     ; r17:r18 is the address of struct contaitnig:
        lpm         r18, Z                      ;   1. the number of letters reffered by this key
                                                ;   2. the letter literals reffered by this key
        mov         ZL, r17                     
        mov         ZH, r18                     ; Z stores the address of the struct key_letters

        lsl         ZL                          ; doublw the address again 
        rol         ZH                          ; as program memory is word addressed

        lpm         r19, Z                      ; r19 stores the number of letters reffered by this key

        cp          r24, r19                    ; if letter_index < number of letters reffered by this key
        brlo        within_range                ; still in range
        clr         r24                         ; else, reset letter_index to 0

    within_range:
        mov         r20, r24                    ; move letter_index to a temporary register

                                                ; Now Z pointing to total number of letter in key
        adiw        Z, 1                        ; Now Z pointing to padding 0
        adiw        Z, 1                        ; Z pointing to the first letter (index 0)

        add         ZL, r20                     ; add the index to Z
        adc         ZH, r1                      ;

        lpm         r25, Z                      ; load that letter indexed by letter_index to r25
        
        DO_LCD_DATA_REGISTER r25                ; display that letter to the LCD

        rjmp        main_loop                   ; waiting for next key press

    not_number:                                 
        cpi         r21, '#'                    ; if '#' is presssed
        breq        accept_letter               ; the patients accepts this letter
                                                ; and is ready to enter next letter
        cpi         r21, 'D'                    ; if 'D' is presssed
        breq        commit_name                 ; the patients accepts all letters entered so far
                                                ; and is ready to confirm their name and patient number
        cpi         r21, 'C'                    ; if 'C' is pressed
        breq        clear_input                 ; clear all letters on LCD and temp_name

        cpi         r21, 'B'                    ; if 'B' is pressed
        breq        back_space                  ; backspace

        rjmp        main_loop                   ; waiting for next key press

    clear_input:
        jmp        initialise_entry_mode        ; effectively restart the entry mode

    back_space:
        dec         r22                         ; decrease name_index in name string
        ldi         YL, low(temp_name)
        ldi         YH, high(temp_name)
        add         YL, r22
        ldi         r16, ' '                    ; replace char at temp_name[name_index] with space
        st          Y, r16

        ldi         r16, 0xC0                   ; move cursor to start of second line
        add         r16, r22                    ; move cursor right name_index steps
        DO_LCD_COMMAND_REGISTER r16             ; this effectively moves the cursor bachward 1 slot
        DO_LCD_DATA_IMMEDIATE ' '               ; print a space (replace the old char)
                                                ; This increments the cursor
        ldi         r16, 0xC0                   ; move cursor to start of second line
        add         r16, r22                    ; move cursor right name_index steps
        DO_LCD_COMMAND_REGISTER r16             ; this moves the cursor bachward 1 slot again
        rjmp        main_loop                   ; waiting for next key press

    accept_letter:
        ldi         YL, low(temp_name)
        ldi         YH, high(temp_name)
        add         YL, r22                     ; add name_index to address of temp_name
        adc         YH, r1
        
        st          Y, r25                      ; temp_name[name_index] <= letter indexed by letter_index
        inc         r22                         ; name_index += 1 
        
        clr         r23                         ; reset last_key
        clr         r24                         ; reset letter_index

        rjmp        main_loop                   ; waiting for next key press

commit_name:
    CLEAR_ONE_BYTE_IN_DATA_MEMORY Entry_Mode_Flag              ; exiting Entry Mode entering stage
    INCREMENT_ONE_BYTE_IN_DATA_MEMORY Entry_Confirm_Flag       ; entering Entry Mode confirmation stage
    
    ldi         ZL, low(temp_name)
    ldi         ZH, high(temp_name)             ; Z points to first char of temp_name
    ldi         YL, low(Patient_Name)
    ldi         YH, high(Patient_Name)          ; Y points to first char of Patient_Name
    
    mov         r17,    r22                     ; move name_index to temporary register
    copy_name_loop:                             ; copy every char from temp_name to Patient_Name
        ld          r18, Z+
        st          Y+, r18
        dec         r17 
        brne        copy_name_loop      

    display_Patient_Name:
        REFRESH_LCD
        LCD_DISPLAY_STRING_FROM_PROGRAM_SPACE Entry_Mode_Complete_Message
        DO_LCD_COMMAND 0xC0                     ; mvoe cursor to bottom left
        
        rcall   enqueue                         ; enqueue the patient whose name stored in Patient_Name

        rcall   display_last_patient            ; dispaly the last patient name and patient number

        waitting_confirmation:
            rcall   take_keypad_input
            cpi     r21, 'D'                    ; if 'D' is preseed, patient has confirmed
            brne    waitting_confirmation

        CLEAR_ONE_BYTE_IN_DATA_MEMORY Entry_Confirm_Flag    ; exiting Entry Mode confirmation stage

ENTRY_MODE_EPILOGUE
ret