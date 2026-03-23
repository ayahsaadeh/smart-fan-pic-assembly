#INCLUDE<P16F877a.INC> 

;****************************************************************************************
	ORG		0X0000
	GOTO	MAIN
	ORG		0X0004
	GOTO	ISR
;****************************************************************************************

; Define registers
COUNT       EQU 0x20     ; Current number of objects in the room
RESULT      EQU 0x21     ; Maximum number of objects
DUTY_CYCLE  EQU 0x22     ; Calculated duty cycle
TEMP1		EQU 0x23
TEMP2		EQU 0x24
D1			EQU 0x25
D2			EQU 0x26
COUNTER		EQU 0x27
Delay_reg	EQU 0x28
TEMP_MAX    EQU 0X29
N_MAX 		EQU 0X30

; Port definitions
;IR_SENSOR   PORTB, 0 ; IR sensor input
;TOGGLE_SW   PORTB, 1 ; Toggle switch input
;BUTTON_UP   PORTB, 2 ; Button to increase count/N_MAX
;BUTTON_DOWN PORTB, 3 ; Button to decrease count/N_MAX
;PWM_OUTPUT  PORTC, 2 ; PWM output to motor
;DISPLAY     PORTD    ; Seven-segment display

;****************************************************************************************	
; Initialize the system
INIT
    ; Initialize ports
	CLRF PORTC
	CLRF PORTD
    BSF STATUS, RP0        ; Select bank 1
    MOVLW 0x0F
    MOVWF TRISB            ; Set RB0-RB3 as inputs, RB4-RB7 as outputs
    MOVLW 0x00
    MOVWF TRISC            ; Set PORTC as outputs
    MOVLW 0x00
    MOVWF TRISD            ; Set PORTD as outputs
    BCF STATUS, RP0        ; Select bank 0

    ; Initialize counters and registers
    CLRF COUNT             ; Clear COUNT register
    ; Initialize PWM
    CALL INIT_PWM

	MOVLW .15
    MOVWF N_MAX            ; Set N_MAX to MAX_COUNT
    CLRF DUTY_CYCLE        ; Clear DUTY_CYCLE register
    ; Enable interrupts
    BSF INTCON, GIE        ; Global Interrupt Enable
    BSF INTCON, PEIE       ; Peripheral Interrupt Enable
    BSF	INTCON, INTE
	RETURN
;*****************************************************

MAIN
	CALL	INIT
    ; Main loop
MAIN_LOOP
    CALL UPDATE_DISPLAY    ; Update the display
    CALL CHECK_BUTTONS     ; Check button presses
    GOTO MAIN_LOOP         ; Repeat the loop

; Initialize PWM settings
INIT_PWM
    ; Set up Timer2 for PWM (Cycle Frequeny - Cycle Time)
    MOVLW 0x3F             ; Prescaler= 16
    MOVWF T2CON
    MOVLW 0xFF
    MOVWF PR2              ; Load PR2 register
    MOVLW 0x00
    MOVWF CCPR1L           ; Initialize CCPR1L to 0 (Holds The Value Of D)
    BSF CCP1CON, CCP1M3
    BSF CCP1CON, CCP1M2    ; Set CCP1 module to PWM mode
    BSF T2CON, TMR2ON      ; Turn on Timer2
    RETURN

; ISR to handle IR sensor input 
ISR:
	BTFSC PORTB, RB0	   ; Check IR sensor input
    CALL IR_SENSOR_CHECK	; Reset Flag & Incerment COUNT & Check whether COUNT == MAX_COUNT
    CALL UPDATE_PWM        ; Update PWM duty cycle
	RETFIE                 ; Return from interrupt

IR_SENSOR_CHECK:
	BCF	INTCON, INTF
    ; IR sensor detected an entry
    INCF COUNT, F          ; Increment COUNT
	MOVF N_MAX ,W
    SUBWF COUNT, W 		   ; COUNT - N_MAX = W
    BTFSS STATUS, C        ; Check if COUNT >= N_MAX --> C = 0
    RETURN
	MOVF N_MAX ,W
    MOVWF COUNT            ; Limit COUNT to MAX_COUNT
    RETFIE                 ; Return from interrupt

; Update PWM duty cycle based on COUNT and N_MAX
UPDATE_PWM
    ; Duty Cycle = (COUNT / N_MAX) * 100%
    CALL DIVIDE      
    MOVWF CCPR1L           ; Update PWM duty cycle (This register is used to set the duty cycle of the PWM signal on the CCP1 (Capture/Compare/PWM) module.)
	RETURN

; Multiply By 4
DIVIDE	
	MOVF N_MAX,W
	MOVWF TEMP_MAX	
	CLRF RESULT
	MOVF COUNT, W
	MOVWF TEMP1			   ; TEMP1 = COUNT
	BCF STATUS,C
	BCF STATUS,Z
	RLF	TEMP1, F
	BCF STATUS,C
	RLF	TEMP1, F
	BCF STATUS,C
	RLF	TEMP1, F
	MOVF N_MAX, W
	MOVWF TEMP2				; TEMP2 = N_MAX
	;Subtract TEMP1 by N_MAX
SUB
	MOVF TEMP2,W
	SUBWF TEMP1,F			;TEMP1 = TEMP1 - TEMP2
	BTFSS STATUS, C
	GOTO MUL_BY_25
	INCF RESULT, F
	GOTO SUB

MUL_BY_25
	BCF STATUS,Z
	MOVLW .0
	SUBWF RESULT, W
	BTFSC STATUS, Z
	RETURN
	MOVLW .24
	MOVWF COUNTER
	MOVF RESULT,W
MUL_BY_25_LOOP
	ADDWF RESULT,F
	DECFSZ COUNTER, F
	GOTO MUL_BY_25_LOOP
	MOVF TEMP_MAX,W
	MOVWF N_MAX
	MOVF RESULT, W
	RETURN


; Update the seven-segment display
UPDATE_DISPLAY
    ; Check toggle switch to decide what to display
    BTFSS PORTB, RB1
    CALL DISPLAY_COUNT     ; Display COUNT if toggle switch is 0
    BTFSC PORTB, RB1
	CALL DISPLAY_N_MAX     ; Display N_MAX if toggle switch is 1
    RETURN

; Display COUNT on the seven-segment display
DISPLAY_COUNT
    MOVF COUNT, W
	CALL SELECT_DIGIT
	MOVF D1, W
    CALL SEGMENT_CONVERT
	MOVWF PORTD
	BCF PORTC, RC5
	CALL DELAY
	BSF PORTC, RC4
	MOVF D2, W
    CALL SEGMENT_CONVERT
	MOVWF PORTD
	BCF PORTC, RC4
	CALL DELAY
	BSF PORTC, RC5
    RETURN

; Display N_MAX on the seven-segment display
DISPLAY_N_MAX
    MOVF N_MAX, W
	CALL SELECT_DIGIT
	MOVF D1, W
    CALL SEGMENT_CONVERT
	MOVWF PORTD
	BCF PORTC, RC5
	CALL DELAY
	BSF PORTC, RC4
	MOVF D2, W
    CALL SEGMENT_CONVERT
	MOVWF PORTD
	BCF PORTC, RC4
	CALL DELAY
	BSF PORTC, RC5
    RETURN

; Check button presses to adjust COUNT or N_MAX
CHECK_BUTTONS
    BTFSC PORTB, RB2 ;BUTTON_UP
    CALL BUTTON_UP_PRESSED
    BTFSC PORTB, RB3 ;BUTTON_DOWN
    CALL BUTTON_DOWN_PRESSED
    RETURN

BUTTON_UP_PRESSED
    BTFSS PORTB, RB1		;TOGGLE_SW LOGIC 0
    INCF COUNT, F          ; Increment COUNT
    BTFSC PORTB, RB1		;TOGGLE_SW
    INCF N_MAX, F          ; Increment N_MAX
    GOTO ISR
	RETURN

BUTTON_DOWN_PRESSED
    BTFSS PORTB, RB1		;TOGGLE_SW
    DECF COUNT, F          ; Decrement COUNT
    BTFSC PORTB, RB1		;TOGGLE_SW
    DECF N_MAX, F          ; Decrement N_MAX
    GOTO ISR 
	RETURN

; Convert binary to seven-segment display format
SEGMENT_CONVERT
    ; Add code to convert binary to seven-segment display format
    ; Example for common anode seven-segment display
    ADDWF PCL, F
    RETLW 0x3F ; 0 (0011 1111)
    RETLW 0x06 ; 1
    RETLW 0x5B ; 2
    RETLW 0x4F ; 3
    RETLW 0x66 ; 4
    RETLW 0x6D ; 5
    RETLW 0x7D ; 6
    RETLW 0x07 ; 7
    RETLW 0x7F ; 8
    RETLW 0x67 ; 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;SELECT_DIGIT;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SELECT_DIGIT
	MOVWF D1
	CLRF D2
	MOVWF D1
LOOP
	MOVLW .10	
	SUBWF D1, W
	BTFSS STATUS, C
	RETURN
	MOVWF D1			;D1 = ONES DIGIT
	INCF D2, F			;D2 = TENS DIGIT
	GOTO LOOP
    
DELAY
 	MOVLW   0x30
 	MOVWF   Delay_reg
L1 	DECFSZ  Delay_reg,F
 	GOTO    L1
 	RETURN


	END