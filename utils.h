; utils.h
; Version 0.1

; Useful defines for other projects. Possible additions to ves.h
; Note: This file is not referenced in dodge_it.asm. Anything useful from this
;  file is copied directly into there, so that the project can be compiled with
;  just the standard ves.h

;-------------------------------------------------------------------------------
; Background Attribute Colors

; TODO: Verify
;  Is it this
BG_COLOR_GREEN      = %00000000
BG_COLOR_BLUE       = %00110000
BG_COLOR_GRAY       = %11000000
BG_COLOR_BLACK      = %11110000
; or is it this?
;BG_COLOR_BLACK      = %00000000 
;BG_COLOR_GREY       = %01000000 
;BG_COLOR_BLUE       = %10000000
;BG_COLOR_GREEN      = %11000000

;-------------------------------------------------------------------------------
; Hand Controller 

CONTROL_RIGHT    = %00000001  ;right
CONTROL_LEFT     = %00000010  ;left
; TODO: Should I change these to UP and DOWN to match the schematics?
CONTROL_BACKWARD = %00000100  ;backward
CONTROL_FORWARD  = %00001000  ;forward
CONTROL_CCW      = %00010000  ;counterclockwise
CONTROL_CW       = %00100000  ;clockwise
; TODO: Should I change these to G_UP and G_DOWN to match the schematics?
CONTROL_PULL     = %01000000  ;pull up
CONTROL_PUSH     = %10000000  ;push down

;-------------------------------------------------------------------------------
; Console Buttons

CONSOLE_1 = %00000001 ;button 1 (Time)
CONSOLE_2 = %00000010 ;button 2 (Mode)
CONSOLE_3 = %00000100 ;button 3 (Hold)
CONSOLE_4 = %00001000 ;button 4 (Start)

;-------------------------------------------------------------------------------
; Alternate Register Names

r0 = 0
r1 = 1
r2 = 2
r3 = 3
r4 = 4
r5 = 5
r6 = 6
r7 = 7
r8 = 8
r9 = 9
r10 = 10
r11 = 11

;-------------------------------------------------------------------------------
; Mnemonics for the BT Instruction
;  "If any of these flags are true, then branch"
never = 0 ; 3-cycle NOP
ifS   = 1 ; same as BP
ifC   = 2 ; same as BC
ifCS  = 3 
ifZ   = 4 ; same as BZ
ifZS  = 5 ; same as t=1 (BP)
ifZC  = 6
ifZCS = 7 ; same as t=3

;-------------------------------------------------------------------------------
; Mnemonics for the BF Instruction
;  "If all of these flags are false, then branch"
always    = $0 ; same as BR
ifNotS    = $1 ; same as BM
ifNotC    = $2 ; same as BNC
ifNotCS   = $3
ifNotZ    = $4 ; same as BNZ
ifNotZS   = $5 ; same as t=1 (BM)
ifNotZC   = $6 
ifNotZCS  = $7 ; same as t=3
ifNotO    = $8 ; same as BNO
ifNotOS   = $9
ifNotOC   = $A
ifNotOCS  = $B
ifNotOZ   = $C
ifNotOZS  = $D ; same as t=9
ifNotOZC  = $E
ifNotOZCS = $F ; same as t=B

;===================================================================
; M A C R O S
;===================================================================

;-------------------------
; SETISARU
;  Works like LISU, except you can use named registers with it. For example:
;
; testReg = 042
; LISU testReg <--- This does not work
; SETISARU testReg <--- This does work

	MAC SETISARU
	lisu	[[[{1}] >> 3] & %111]
	ENDM

;-------------------------
; SETISARL
;  Like the previous macro, except for LISL instead.
	
	MAC SETISARL
	lisl	[[{1}] & %111]
	ENDM

;--------------------------
; neg
; Takes the 2's complement of the accumulator

	MAC neg
	com
	inc
	ENDM
	
;-------------------------------------------------------------------------------
; The following required for back-compatibility with code which does not use
; segments.

	SEG

; EOF
