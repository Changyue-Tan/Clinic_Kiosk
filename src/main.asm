/*
 *
 *  Created: 2024/11/16 16:17:54
 *  Author: Changyue Tan
 *  
 *  This is a major project for UNSW COMP9032 Microprocessors and Interfacing in 2024 Term 3
 *
 *  It aims to mimic a self serving kiosk that can often be found in clinics.
 *  It is written in AVR Assembly and supposed to be run on UNSW's custom designed developlment board
 *  The project uses the LCD screen, LED bar, Strobe LED, DC motor and 4x4 Keypad to simulate real world hardware
 *
 */ 

; Example of how the kiosk funtions: 
;
; When patients arrive at the clinic:
;   They enter their name into the kiosk
;   The kiosk asks the patient to confirm their name assigned patient number
;   The kiosk enqueue the patient 
; When doctor ready to see next patient:
;   The doctor calls for next patient, the kisosk entering calling mode
;   The kisok screen and another screen will display the next patient's number 
;       If somem one is trying to enqueue themselves at the kiosk, their progress will be paused and saved.
;       This allows them to continue enqueueing themselves once the doctor stops calling for next patient
;   A bell (motor) will ring and LED bar will flash to draw people's attention
;   If no one repond to the call, the doctor can choose to continue waitting and calling, or cancel this patient's appoinment
;   After cancellation, the next patient following the patient whose appoinment has just been canceled will be called
;   If the patient arrives, the doctor will stop the bell and flashing LEDS.
;   The kiosk screen will exit callling mode and return to entry mode after some time
;   The LED bar will display the approximate remainning time of current consultation

;   The board use Atmega2560 System on Chip
.include "m2560def.inc"

; -------------------------------------------------------------------------------------------------------------------------------
; ---------------------------------------------- External Definitions and Macros ------------------------------------------------
; ------------------------------------------------------------------------------------------------------------------------------- 

.include "data_memory_macros.asm"
.include "keypad_defs_and_macros.asm"
.include "lcd_defs_and_macros.asm"

; ------------------------------------------------------------------------------------------------------------------------------- 
; ---------------------------------------------- Data Memroy Space Variables ----------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------

.dseg

; For Keypad 
temp_name:              .byte 10        ; after # is pressed, input from keypad is stored here after # is pressed            
Patient_Name:			.byte 10		; after D is pressed, temp_name is moved here 

; For queue data structure
Patients_Queue:			.byte 2560		; max number of patients per day: 255 (patient 0 is not used)
Next_Patient:			.byte 2			; pointer to the next patient in queue data structure 
Last_Patient:			.byte 2			; pointer to the last patient in queue data structure
Space_For_New_Patient:	.byte 2			; pointer to the next avaliable space ready to enqueue the next patient
Next_Patient_Number:	.byte 1			; a number between 0 - 255
Last_Patient_Number:	.byte 1			; a number between 0 - 255

; For record of time elapsed 
Temp_Counter:    		.byte 2         ; Incremented every 0.001   second (1 millisecond)
Seconds_Counter:		.byte 2         ; Incremented every 1       second, used to counter how many seconds since start of consultation
Blink_Timer:            .byte 1         ; Incremented every 0.5     seconds, as certain blink pattern requires 0.5 s intervals

; Flag for entry mode
Entry_Mode_Flag:        .byte 1         ; 1 if patient is typing, 0 otherwise
Entry_Confirm_Flag:     .byte 1         ; 1 if waiting for patient to confirm name and assigned patient number, 0 otherwise


; ------------------------------------------------------------------------------------------------------------------------------- 
; ---------------------------------------------- Interrupt Vectors --------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------

.cseg

.org 0x0000
	rjmp RESET                          ; Reset Interrupt

.org INT0addr
    rjmp EXT_INT0                       ; External Interrupt 0

.org OVF0addr
	jmp Timer0OVF                       ; Timer 0 Overflow Interrupt

; ------------------------------------------------------------------------------------------------------------------------------- 
; ---------------------------------------------- External Functions -------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------

.include "sleep_functions.asm"
.include "keypad_functions.asm"
.include "lcd_functions.asm"
.include "patients_queue_functions.asm"
.include "display_mode_functions.asm"
.include "entry_mode_functions.asm"
.include "blink_functions.asm"
.include "strobe.asm"

; ------------------------------------------------------------------------------------------------------------------------------- 
; ---------------------------------------------- Program Memroy Constants ------------------------------------------------------- 
; ------------------------------------------------------------------------------------------------------------------------------- 

; Strings to be displayed on LCD Screens
Entry_Mode_Prompt:
    .db "Enter Name:", 0                ; To be displayed on LCD 1 when kiosk in entery mode

Entry_Mode_Complete_Message:
    .db "Your Number Is:", 0            ; To be dispalyed when asking patient to confirm their name and number

Display_Mode_Message:
    .db "Next Patient:", 0              ; To be dispalyed on LCD 2 all the time. and on LCD 1 when kiok in display mode

; Letters characters for Keypad function to index
key_offsets:   
    .dw key2_letters
    .dw key3_letters
    .dw key4_letters
    .dw key5_letters
    .dw key6_letters
    .dw key7_letters
    .dw key8_letters
    .dw key9_letters

; Each label resemble a struct
; Example:
/*
    struct key_letters {
        char number_of_letter_can_be_index_by_this_key;
        char letter_literals_of_this_key[number_of_letter_can_be_index_by_this_key];
    };
*/
; 0 for padding to 2 byte (program memory is word addressed)
key2_letters:
    .db 3, 0
    .db 'A', 'B', 'C', 0
key3_letters:
    .db 3, 0
    .db 'D', 'E', 'F', 0
key4_letters:
    .db 3, 0
    .db 'G', 'H', 'I', 0
key5_letters:
    .db 3, 0
    .db 'J', 'K', 'L', 0
key6_letters:
    .db 3, 0
    .db 'M', 'N', 'O' , 0
key7_letters:
    .db 4, 0
    .db 'P', 'Q', 'R', 'S'  
key8_letters:
    .db 3, 0
    .db 'T', 'U', 'V', 0
key9_letters:
    .db 4, 0
    .db 'W', 'X', 'Y', 'Z'


; ------------------------------------------------------------------------------------------------------------------------------- 
; -----------------------------------------------  Interrupt Service Routines ---------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------

; Interrupt service routine on board start up, or reset button push
RESET:
    CLEAR_TWO_BYTE_IN_DATA_MEMORY Temp_Counter                                  ; Initialize counters and flags to 0
	CLEAR_TWO_BYTE_IN_DATA_MEMORY Seconds_Counter
    CLEAR_ONE_BYTE_IN_DATA_MEMORY Entry_Mode_Flag
    CLEAR_ONE_BYTE_IN_DATA_MEMORY Entry_Confirm_Flag

    rcall   interupt_setup                                                      ; set up interrupts
    rcall   setup_keypad                                                        ; set up peripherals
    rcall   setup_LCD
    rcall   initialise_queue                                                    ; initialise queue data structure

	ser     r16                                                                 ; set Port C & G as output for LED bar
	out     DDRC, r16
    out     DDRG, r16
	clr     r16                                                                 ; turn off all LEDs
	out     PORTC, r16
    out     PORTG, r16

    clr     r16                                                                 ; set Port D as input (from push buttons)
    out     DDRD, r16
    ser     r16                                                                 ; set up pull up for port D
    out     PORTD, r16
    
    rjmp    main                                                                ; set up complete, start main program 

; Interrupt service routine when fallling edge detected on PIND bit 0 (button press at PB0)
EXT_INT0:
    rcall   sleep_125ms                                                         ; debouncing        
    push    r16
    in      r16,    SREG
    push    r16
    push    r17
    DATA_MEMORY_PROLOGUE

    in      r16, EIMSK                                                          ; mask INT0 to preventing nested interrupt
	andi    r16, ~(1<<INT0)                                                     ; (INT0 trigger during handling of INT0)
	out     EIMSK, r16                                                          ; as we will re-enable global interrupt flag
    sei                                                                         ; Set Global Interrupt Enable 
                                                                                ; to allow for timer interrupt (updating time counters)
    check_if_there_is_next_patient:
        ldi     YL, low(Next_Patient_Number) 
        ldi     YH, high(Next_Patient_Number)
        ld      r16, Y                                                          ; r16 = Next_Patient_Number
        ldi     YL, low(Last_Patient_Number) 
        ldi     YH, high(Last_Patient_Number)
        ld      r17, Y                                                          ; r17 = Last_Patient_Number
        
        cp      r17, r16                                                        ; if Last_Patient_Number < Next_Patient_Number,
                                                                                ; then no patient in queue
        brmi    exit_INT0                                                       ; if no patient in queue, exit interupt
        rjmp    calling_next_patient                                            ; else, call next patient

        exit_INT0:
            rjmp    end_of_INT0

    calling_next_patient:
        rcall   sleep_125ms                                                     ; debouncing
        rcall   display_next_patient

        CLEAR_ONE_BYTE_IN_DATA_MEMORY Blink_Timer                               ; initilise blink_timer
        rjmp    pattern_a                                                       ; show pattern a after calling next patient

    cancle_appointment:
        rcall   dequeue
        rcall   display_next_patient
        rcall   sleep_1000ms                                                    ; added for user experience
        rjmp    pattern_c                                                       ; show pattern c after cancellation

    patient_arrives:
        rcall   led_bell_low                                                    ; slience the bell and stop flashing LED bar
        rcall   dequeue
        rcall   display_next_patient
        rcall   sleep_1000ms
        CLEAR_TWO_BYTE_IN_DATA_MEMORY Seconds_Counter                           ; reset counter for time elapsed since patient arrives
        rjmp    end_of_INT0

    ; separate canclation/next patient handling for during pattern a and pattern b
    ; A subroutine call is not used here, as it will branche to another instrunction during subtoutine, without returning from subroutine
    start_check_cancle_a:
        rcall   sleep_1000ms                                                    ; check for button push again after 1 second
        ser     r16
        sbis    PIND, 1
        clr     r16
        cpi     r16, 0
        breq    cancle_appointment                                              ; if still pushed, cancel appointment
        rjmp    finish_check_cancle_a                                           ; else, return from checking cancelation

    start_check_cancle_b:
        rcall   sleep_1000ms                                                    ; check for button push again after 1 second
        ser     r16
        sbis    PIND, 1
        clr     r16
        cpi     r16, 0
        breq    cancle_appointment                                              ; if still pushed, cancel appointment
        rjmp    finish_check_cancle_b                                           ; else, return from checking cancelation

    start_check_next_patient_a:
        rcall   sleep_1000ms                                                    ; check for button push again after 1 second
        ser     r16
        sbis    PIND, 0
        clr     r16
        cpi     r16, 0
        breq    patient_arrives                                                 ; if still pushed, the patient has arrived
        rjmp    finish_check_next_patient_a                                     ; else, return from checking if patient arrives

    start_check_next_patient_b:
        rcall   sleep_1000ms                                                    ; check for button push again after 1 second
        ser     r16
        sbis    PIND, 0
        clr     r16
        cpi     r16, 0
        breq    patient_arrives                                                 ; if still pushed, the patient has arrived
        rjmp    finish_check_next_patient_b                                     ; else, return from checking if patient arrives
                                                                                
    pattern_a:
        sbis    PIND, 1
        rjmp    start_check_cancle_a                                            ; check if PB1 is pushed for 1 second
        finish_check_cancle_a:

        sbis    PIND, 0
        rjmp    start_check_next_patient_a                                      ; check if PB0 button is pushed for 1 second
        finish_check_next_patient_a:

        ldi     YL, low(Blink_Timer) 
        ldi     YH, high(Blink_Timer)
        ld      r24, Y                                                          ; r24 has number of 0.5 seconds since calling mode begins
                                                                                ; Updates to bell and LED pattern happen after counter updates
                                                                                ; hence will overwrite remaining time dispalyed on LED bar
        
        cpi     r24, 20                                                         ; check if 10 seconds passed
        breq    pattern_b                                                       ; if so, show pattern b

        mov     r16, r24
        andi    r16, 0b00000011                                                 ; mask out all bits except the last two
        breq    multiples_of_4                                                  ; if r16 becomes 0, then r24 is multiples of 4
        
        mov     r16, r24
        subi    r16, -2
        andi    r16, 0b00000011                                                 ; mask out all bits except the last two       
        breq    multiples_of_4_plus_two                                         ; if r16 becomes 0, then r24 is (multiples of 4) - 2 
        
        rjmp    pattern_a                                                       ; continue show pattern a

        multiples_of_4:
            rcall   led_bell_low                                                ; turn off bell and LED bar every even seconds
            rjmp    pattern_a
        multiples_of_4_plus_two:  
            rcall   led_bell_high                                               ; turn on bell and LED bar every odd seconds
            rjmp    pattern_a

    pattern_b:
        sbis    PIND, 1                                                         ; check if PB1 is pushed for 1 second
        rjmp    start_check_cancle_b
        finish_check_cancle_b:
        
        sbis    PIND, 0                                                         ; check if PB0 is pushed for 1 second
        rjmp    start_check_next_patient_b
        finish_check_next_patient_b:

        ldi     YL, low(Blink_Timer) 
        ldi     YH, high(Blink_Timer)
        ld      r24, Y                                                          ; r24 has number of 0.5 seconds since calling mode begins
                                                                                ; Updates to bell and LED pattern happen after counter updates
                                                                                ; hence will overwrite remaining time dispalyed on LED bar

        sbrc    r24, 0                                                          ; if bit 0 in r24 is cleared, then r24 is even
        rjmp    timer_odd                                                       ; else, r24 is odd

        timer_even:
            rcall   led_bell_low                                                ; turn off bell and LED bar every even number of half seconds
            rjmp    pattern_b
        timer_odd:  
            rcall   led_bell_high                                               ; turn off bell and LED bar every odd number of half seconds
            rjmp    pattern_b
    
    pattern_c:
        rcall   led_bell_high   
        cli                                                                     ; disable global interrupt (this also stops timer interrupt)
                                                                                ; But Blink_Timer is going to be reset after this anyway
        rcall   sleep_3000ms                                                    ; to prevent pattern C disrupted by remaining time display
        sei                                                                     ; re-enable global interrupt
        rjmp    calling_next_patient                                            ; current appointment canceled, calling next patient


    end_of_INT0:

        ENTRY_MODE_PROLOGUE

        ldi     YL, low(Entry_Mode_Flag)                                        ; Check Entry_Mode_Flag to determine how to exit interrupt
        ldi     YH, high(Entry_Mode_Flag)
        ld      r24, Y
        cpi     r24, 1
        breq    return_to_entry_mode

        ldi     YL, low(Entry_Confirm_Flag)                                     ; Check Entry_Confirm_Flag to determine how to exit interrupt
        ldi     YH, high(Entry_Confirm_Flag)
        ld      r24, Y
        cpi     r24, 1
        breq    return_to_entry_confirm_mode

        rjmp    INT0_epilogue                                                   ; kiosk was not in entry mode, exit interrupt normally

        return_to_entry_mode:
            rcall   sleep_5000ms                                                ; As project speced, entry mode will be restored after 5 seconds
            rcall   strobe_off                                                  ; Turn off strobe LED for entry mode (no data sent to LCD 2)
            REFRESH_LCD
            LCD_DISPLAY_STRING_FROM_PROGRAM_SPACE Entry_Mode_Prompt             ; Restore Entry_Mode_Prompt back to LCD  
            DO_LCD_COMMAND 0xC0

            ldi     YL, low(temp_name)
            ldi     YH, high(temp_name)

            print_entered_chars_to_LCD:                                         ; Restore entered letters back to LCD
                ld      r16 , Y+
                cpi     r16, ' '
                breq    end_of_return_to_entry_mode
                DO_LCD_DATA_REGISTER r16
                rjmp    print_entered_chars_to_LCD

            end_of_return_to_entry_mode:
                rjmp    INT0_epilogue                                           ; interrupt can exit normally now

        return_to_entry_confirm_mode:
            rcall   sleep_5000ms                                                ; As project speced, entry mode will be restored after 5 seconds
            rcall   strobe_off                                                  ; Turn off strobe LED for entry mode (no data sent to LCD 2)
            REFRESH_LCD
            LCD_DISPLAY_STRING_FROM_PROGRAM_SPACE Entry_Mode_Complete_Message   ; Restore Entry_Mode_Complete_Message back to LCD
            DO_LCD_COMMAND 0xC0  

            rcall   display_last_patient                                        ; Restore patient name and patient number back to LCD

            rjmp    INT0_epilogue                                               ; interrupt can exit normally now

    INT0_epilogue:
        ENTRY_MODE_EPILOGUE

        in      r16, EIFR                                                       ; Clear the interrupt flag for INT0
                                                                                ; (Interrupt Flags are cleared by writing 1 to the flag bit)
        ori     r16, (1 << INTF0)                                               ; The flag will be set duing handling of INT0 (hold PB0)
        out     EIFR, r16                                                       ; If not cleared, INT0 will be triggered again after unmask

        in      r16, EIMSK                                                      ; Re-enable (unmask) INT0 interrupt
        ori     r16, (1 << INT0)                                                ; It was masked at the start of INT0 to
                                                                                ; prevent it from nesting itself
        out     EIMSK, r16

        DATA_MEMORY_EPILOGUE
        pop     r17
        pop     r16
        out     SREG, r16
        pop     r16
        reti

Timer0OVF:                                                                      ; interrupt service routine for Timer0 overflow
	push    r16 
	in      r16, SREG
	push    r16 

	INCREMENT_TWO_BYTE_IN_DATA_MEMORY Temp_Counter                              ; 1 millisecond has passed

    DATA_MEMORY_PROLOGUE
    ldi     YL, low(Temp_Counter) 
	ldi     YH, high(Temp_Counter)
	ld      r24, Y+                                                             ; r25:r24 has number of ms passed since last cleared
	ld      r25, Y

    update_blink_timer:
        cpi     r24, low(500) 
        brne    update_seconds_counter
        cpi     r25, high(500) 
        brne    update_seconds_counter
        INCREMENT_ONE_BYTE_IN_DATA_MEMORY Blink_Timer                           ; 500 ms (0.5 second) passed since last cleared

    update_seconds_counter:
        cpi     r24, low(1000) 
        brne    continue_counting
        cpi     r25, high(1000) 
        brne    continue_counting
        rcall   update_timers                                                   ; 1000 ms (1 second) passed since last cleared

	CLEAR_TWO_BYTE_IN_DATA_MEMORY Temp_Counter                                  ; reset Temp_Counter every 1000 ms
	
	continue_counting:
		DATA_MEMORY_EPILOGUE
		pop     r16
		out     SREG, r16
		pop     r16
		reti                                                                    ; Return from timer 0 overflow interrupt

    update_timers:
        DATA_MEMORY_PROLOGUE
        push    r18
        push    r17
        push    r0
        push    r1

        rcall   display_remaining_time                                          ; update the estimated remaining time on LED bar
                                                                                ; Over written by pattern a and b
                                                                                ; but for pattern C to function as intended,
                                                                                ; global interrupt should be disabled to stop timer interrupts

        INCREMENT_TWO_BYTE_IN_DATA_MEMORY Seconds_Counter                       ; Seconds_counter is incremented every 1 second
        INCREMENT_ONE_BYTE_IN_DATA_MEMORY Blink_Timer                           ; Blink_Timer is incremented at 0.5 second and 1 second

        update_timers_end:
            pop     r1
            pop     r0
            pop     r17
            pop     r18
            DATA_MEMORY_EPILOGUE
            ret

; ------------------------------------------------------------------------------------------------------------------------------- 
; -----------------------------------------------  Main Program -----------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------

main:
    rcall   display_next_patient                                                ; start with dispaly mode 
    rcall   take_keypad_input                                                   ; input from keypad stored in r21
    cpi     r21, 'A'                                                            ; if 'A' is pressed on keypad
    brne    main
    rcall   start_entry_mode                                                    ; switch to entry mode
    rjmp    main

 ; halt:   
    ; rjmp halt

; ------------------------------------------------------------------------------------------------------------------------------- 
; ----------------------------------------------- Subroutines -------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------------

interupt_setup:
    ldi     r16, 0b00000000                                                     ; Normal mode: counting up, TOP=0xFF, BOTTOM=0x00
	out     TCCR0A, r16                                                         ; 0xFF ~ 0x00, can count 256 clock cycles

	ldi     r16, 0b00000011                                                     ; Prescaler=64, (clk_I/O)/64, counting 1024 us (1 ms)
	out     TCCR0B, r16                                                         ; 256 x 64 /(16 MHz) = 1024 us
	
	ldi     r16, 1<<TOIE0                                                       ; enable the Overflow Interrupt for timer 0
	sts     TIMSK0, r16 

	
	ldi     r16, (2<<ISC00)                                                     ; set INT0 as falling edge triggered interrupt
	sts     EICRA, r16                                                          
	
    in      r16, EIMSK                                                          ; read EIMSK and ori, keep other bits untouched
	ori     r16, (1<<INT0)                                                      ; enable INT0
	out     EIMSK, r16
	
	sei                                                                         ; Enable global interrupt

    ret

; every time seconds_timer is updated, update remaining time to LED
display_remaining_time:
        ldi     YL, low(Seconds_Counter) 
        ldi     YH, high(Seconds_Counter)
        ld      r24, Y                                                          ; r24 has number of seconds since start of consultation
        
        cpi     r24, 20                                                         ; if time elapsed >= 20 
        brsh    time_is_up                                                      ; turn off all LEDs 

        ldi     r16, 20
        sub     r16, r24                                                        ; r16 = remaining time 
        subi    r16, -1                                                         ; add 1 to account for first update to led happens at t = 1, not 0
        ldi     r17, 10
        mul     r16, r17                                                        ; r1:r0 = r16 * 10
        mov     r16, r0                                                         ; r16 = remaining time * 10 (we only need lower byte)
        
        ; implementation of r16 / 20
        clr     r17                                                             ; ready to tore quotient
        keep_minus_20:
            cpi     r16, 20                                                     ; if dividend smaller than divisor
            brlo divided_by_20_finish                                           ; division finish
            
            continue_minus_20:
                subi    r16, 20                                                 ; minus one divisor from dividend
                inc     r17                                                     ; increment quotient
                rjmp    keep_minus_20

        divided_by_20_finish:

        mov     r16, r17                                                        ; r16 is now the quotient, which is the number of leds to turn on

        clr     r17                                                             ; ready display pattern for leds 0-7
        clr     r18                                                             ; ready display pattern for leds 8-9

        make_bit_loop_start:
            dec     r16                                                         ; Decrement r16, adding one 1 bit to the pattern
            brmi    make_bit_loop_end                                           ; If r16 < 0, all LEDs bits added, exit the loop
            lsl     r17                                                         ; Shift r17 left by 1 bit (make space for another bit)
            rol     r18                                                         ; Rotate left through carry into r18 (MSB of r17 -> LSB of r18)
            ori     r17, 1                                                      ; Set the least significant bit of r17 (adding a bit)
            rjmp    make_bit_loop_start 
        make_bit_loop_end:

        out PORTC, r17
        ; lsl r18                                                               ; algin bits (if pins connectted differently)
        out PORTG, r18

        rjmp display_remaining_time_end

        time_is_up:
            rcall led_bell_low                                                  ; turn off all LEDs when exceeds 20 seconds
        
        display_remaining_time_end:
            ret

