; 4 cycles per iteration - setup/call-return overhead
.equ F_CPU		= 16000000
.equ DELAY_1MS	= F_CPU / 4 / 1000 - 4

sleep_1ms:
	push		r24
	push		r25
	
	ldi			r25,			high(DELAY_1MS)
	ldi			r24,			low(DELAY_1MS)
    
	delayloop_1ms:
        sbiw		r25:r24,		1
        brne		delayloop_1ms
	
	pop			r25
	pop			r24
	ret

sleep_5ms:
	rcall		sleep_1ms
	rcall		sleep_1ms
	rcall		sleep_1ms
	rcall		sleep_1ms
	rcall		sleep_1ms
	ret

sleep_25ms:
	rcall		sleep_5ms
	rcall		sleep_5ms
	rcall		sleep_5ms
	rcall		sleep_5ms
	rcall		sleep_5ms
	ret

sleep_125ms:
	rcall		sleep_25ms
	rcall		sleep_25ms
	rcall		sleep_25ms
	rcall		sleep_25ms
	rcall		sleep_25ms
	ret

sleep_625ms:
	rcall		sleep_125ms
	rcall		sleep_125ms
	rcall		sleep_125ms
	rcall		sleep_125ms
	rcall		sleep_125ms
	ret

sleep_500ms:
	rcall		sleep_125ms
	rcall		sleep_125ms
	rcall		sleep_125ms
	rcall		sleep_125ms
	ret

sleep_1000ms:
	rcall		sleep_500ms
	rcall		sleep_500ms
	ret

sleep_3000ms:
	rcall		sleep_1000ms
	rcall		sleep_1000ms
	ret

sleep_5000ms:
	rcall		sleep_1000ms
	rcall		sleep_1000ms
	rcall		sleep_1000ms
	rcall		sleep_1000ms
	rcall		sleep_1000ms
	ret