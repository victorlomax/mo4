; ---------------------------------------------------------------------------------------
; This program simulates the parallel output of the Atari ST driven by the driver MO44.DRV.
; Timer 1 is used to "bleep" new data.
;
; On output, we use:
; - the port B (8 bits) to read simulate the parallel port
; - PD6 (pin 11) simulate /STROBE
; - PD5 (pin 9): the activity LED which blinks briefly when BUSY is high. It uses timer 0.
;
; On Input, we use:
; - PD3/INT1 (pin 7) to simulate BUSY
; ---------------------------------------------------------------------------------------

.include "tn4313def.h"

; Timer 0 settings
.equ	T0_START,	(1<<CS02)|(1<<CS00)

; Calculate the delay value for Timer 1
.equ	CLOCK_FREQ,	8000000		; 8 MHz
.equ	PRESCALER,	1024		; / 1024
; Timer 1 settings
;.equ	T1_DELAY,	((CLOCK_FREQ / (2 * PRESCALER)) / 16)
.equ	T1_DELAY,	6000
.equ	T1_START,	(1<<WGM12)|(1<<CS10)|(1<<CS12)
.equ	T1_STOP,	(1<<WGM12)

.equ    NOTE_ON, 0x99
.equ    NOTE_OFF, 0x89

.equ	LED, PIND5		; activity LED
.equ	STROBE, PIND4		; Output
.equ	BUSY, PIND3		; Input

.text
; =========================================================
; Interrupt vectors
; =========================================================
Reset:		rjmp	Init
INT0addr:	rjmp	Reset
INT1addr:	rjmp	busy		; INT1 = pulse on BUSY
ICP1addr:	rjmp	Reset
OC1Aaddr:	rjmp	bleep		; timer 1 overflow
OVF1addr:	rjmp	Reset
OVF0addr:	rjmp	blink_off	; Timer 0 overflow
URXCaddr:	rjmp	Reset
UDREaddr:	rjmp	Reset
UTXCaddr:	rjmp	Reset
ACIaddr:	rjmp	Reset
PCIBaddr:	rjmp	Reset
OC1Baddr:	rjmp	Reset
OC0Aaddr:	rjmp	Reset
OC0Baddr:	rjmp	Reset
USI_STARTaddr:	rjmp	Reset
USI_OVFaddr:	rjmp	Reset
ERDYaddr:	rjmp	Reset
WDTaddr:	rjmp	Reset
PCIAaddr:	rjmp	Reset
PCIDaddr:	rjmp	Reset

; =========================================================
; Configurations
; =========================================================
Init:	cli				; disable interrupts for now
; ---------------------------------
; Configuration of Stack pointer
; ---------------------------------
	ldi	r16,	lo8(RAMEND)	; Set stack pointer to end of ram
	STORE	SPL,	r16
	;ldi	r16,	hi8(RAMEND)
	;STORE	SPH,	r16
; ---------------------------------
; Configuration of ports
; ---------------------------------
	; port D outputs
	ldi	r16, (1<<LED)|(1<<STROBE)
	STORE	DDRD,	r16		; ... and set the data direction of port D to "out"
	; port B is all output
	ser	r16
	STORE	DDRB,	r16
; ---------------------------------
; Configuration of Timer 0
; ---------------------------------
	clr     r16
	STORE   TCCR0A, r16 	; Normal mode (=0)
	STORE   TCCR0B, r16 	; Timer 0 is stopped
; ---------------------------------
; Configuration of Timer 1
; ---------------------------------
	; Configure Timer/Counter 1 to mode 4 (CTC) and prescaler / 1024
	;	TOP value = OCR1A
	;TOV1 Flag Set on = MAX
	;          |   7  |   6  |   5  |   4  |   3  |   2  |   1  |   0  |
	;          +------+------+------+------+------+------+------+------+
        ; TCCR1A = |COM1A1|COM1A0|COM1B1|COM1B0|   -  |   -  | WGM11| WGM10|
	;          |   0  |   0  |   0  |   0  |   0  |   0  |   0  |   0  | = 0x00: mode 4
        ; TCCR1B = |ICNC1 |ICES1 |   -  | WGM13| WGM12| CS12 | CS11 | CS10 |
	;          |   0  |   0  |   0  |   0  |   1  |   1  |   0  |   1  | = 0x0d: mode 4, prescaler 1024
        ; TCCR1C = |FOC1A |FOC1B |   -  |  -   |   -  |   -  |   -  |   -  |
	;          |   0  |   0  |   0  |   0  |   0  |   0  |   0  |   0  |

; Load the T1_DELAY into OCR1A
	ldi	r16,	hi8(T1_DELAY)
	ldi	r17,	lo8(T1_DELAY)
	STORE	OCR1AH,	r16			; High byte must be written first ...
	STORE	OCR1AL,	r17			; .. when setting a 16 bits register.
; Select Timer 1 mode: mode 4, prescaler 1024
	clr	r16
	STORE	TCCR1A, r16
	STORE	TCCR1C, r16
	ldi	r16,	T1_START
	STORE	TCCR1B, r16
; Clear (set bit to 1) the OCF1A interrupt flag
	LOAD	r16,	TIFR
	ldi	r16,	(1<<OCF1A)
	STORE	TIFR, 	r16
; Enable OCIE0A and OCIE1A interrupt
	ldi	r16,	(1<<TOIE0)|(1<<OCIE1A)
	STORE	TIMSK,	r16
; ---------------------------------
; Configuration of external interrupts
; ---------------------------------
	; - All pull-up resistors are disabled
	; - INT1 triggers on rising edge (ISC11=1, ISC10=1)
	ldi     r16,	(1<<PUD)|(1<<ISC11)|(1<<ISC10)
	STORE   MCUCR,	r16			; Update the MCU Control Register
	sbr     r16,    INT1			; Enable INT1
	STORE   GIMSK,	r16			; Update interrupt mask
	; Clear the General Interrupt Flag Register
	ldi     r16,	(1<<INTF1)
	STORE	GIFR,	r16

; ==========================================
; Starting the show
; ==========================================
	LOAD    r16,    PORTD
	sbr	r16, 	(1<<STROBE)|(1<<LED)	; STROBE is high, light up the LED
	STORE   PORTD,  r16 

	ldi	r22,	NOTE_ON
	sei				; Allow interrupts
; ---------------------------------
; Main loop: check if there some data
; ready to be sent in the RAM buffer
; ---------------------------------
Main:	nop					; do nothing
	rjmp	Main				; Loop

; ---------------------------------
; Set 0x00 on port D and pulse /STROBE 4 times
; ---------------------------------
reset_hardware:
	clr	r21
	STORE	PORTB,	r21
	rcall	pulse_strobe
	rcall	pulse_strobe
	rcall	pulse_strobe
	rcall	pulse_strobe
	ret

send_data:
	cpi	r22,	NOTE_OFF	; r22 = NOTE_OFF ?
	ldi	r22,	NOTE_ON		; Yes -> r22 = NOTE_ON
; ------ OUTPUT 1 ------
	ldi	r21,	0x03
	STORE	PORTB,	r21		; Number of bytes coming next
	rcall	pulse_strobe

	STORE	PORTB,	r22		; NOTE_ON or NOTE_OFF
	rcall	pulse_strobe

	ldi	r21,	0x24
	STORE	PORTB,	r21		; note number
	rcall	pulse_strobe

	ldi	r21,	0x40
	STORE	PORTB,	r21		; velocity
	rcall	pulse_strobe
; ------ OUTPUT 2 ------
	ldi	r21,	0x03
	STORE	PORTB,	r21		; Number of bytes coming next
	rcall	pulse_strobe

	STORE	PORTB,	r22		; NOTE_ON or NOTE_OFF
	rcall	pulse_strobe

	ldi	r21,	0x25
	STORE	PORTB,	r21		; note number
	rcall	pulse_strobe

	ldi	r21,	0x40
	STORE	PORTB,	r21		; velocity
	rcall	pulse_strobe
; ------ OUTPUT 3 ------
	ldi	r21,	0x03
	STORE	PORTB,	r21		; Number of bytes coming next
	rcall	pulse_strobe

	STORE	PORTB,	r22		; NOTE_ON or NOTE_OFF
	rcall	pulse_strobe

	ldi	r21,	0x26
	STORE	PORTB,	r21		; note number
	rcall	pulse_strobe

	ldi	r21,	0x40
	STORE	PORTB,	r21		; velocity
	rcall	pulse_strobe
; ------ OUTPUT 4 ------
	ldi	r21,	0x03
	STORE	PORTB,	r21		; Number of bytes coming next
	rcall	pulse_strobe

	STORE	PORTB,	r22		; NOTE_ON or NOTE_OFF
	rcall	pulse_strobe

	ldi	r21,	0x27
	STORE	PORTB,	r21		; note number
	rcall	pulse_strobe

	ldi	r21,	0x40
	STORE	PORTB,	r21		; velocity
	rcall	pulse_strobe

	clr	r21
	STORE	PORTB,	r21		; port b cleanup
	ret

pulse_strobe:
	LOAD    r16,    PORTD
	cbr     r16,    (1<<STROBE)
	STORE   PORTD,  r16 		; pulse low
	sbr     r16,    (1<<STROBE)
	STORE   PORTD,  r16 		; pulse low
	ret
; =========================================================
; Interrupt Service Routine (ISR)
; =========================================================

; ---------------------------------
; Stop timer 0 and switch off the activity LED
; ---------------------------------
blink_off:
	clr     r16				; Set prescaler = 0 to ...
	STORE   TCCR0B, r16 			; ... stop timer 0
	LOAD	r16,	PORTD
	cbr     r16,    (1<<LED)
	STORE	PORTD, 	r16			; Switch off the LED
	reti					; Return from ISR

; ---------------------------------
; We received a BUSY pulse
; ---------------------------------
busy:
	ldi	r21,	0x00
	STORE	PORTB,	r21
	LOAD    r16,    PORTD
	sbr     r16,    (1<<LED)	; light up LED
	STORE   PORTD,  r16 		; pulse low

	ldi	r16,	T0_START
	STORE	TCCR0B,	r16		; Start timer 0
	reti				; Return from ISR
; ---------------------------------
; Send new data
; ---------------------------------
bleep:
	rcall	reset_hardware		; Reset hardware
	rcall	send_data		; Send midi data

	ldi	r22,	NOTE_OFF
	
	LOAD    r16,    PORTD
	sbr     r16,    (1<<LED)	; light up LED
	STORE   PORTD,  r16 		; pulse low

	ldi	r16,	T0_START
	STORE	TCCR0B,	r16		; Start timer 0

	clr	r16
	STORE	TCNT1H,	r16
	STORE	TCNT1L,	r16		; Reset Timer 1 counter

	reti
