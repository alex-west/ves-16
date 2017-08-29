; VES.H
; Fairchild Channel F Header
; Version x

VERSION_CHANNELF	= 101
VERSION_VES		= 101

; Ignore these paragraphs below for the moment. - alex

; THIS IS A PRELIMINARY RELEASE OF *THE* "STANDARD" VES.H
; THIS FILE IS EXPLICITLY SUPPORTED AS A DASM-PREFERRED COMPANION FILE
; PLEASE DO *NOT* REDISTRIBUTE THIS FILE!
;
; This file defines hardware registers and memory mapping for the
; Fairchild Channel-F. It is distributed as a companion machine-specific support package
; for the DASM compiler. Updates to this file, DASM, and associated tools are
; available at at http://www.atari2600.org/dasm
;
; Many thanks to the original author(s) of this file, and to everyone who has
; contributed to understanding the Channel-F.  If you take issue with the
; contents, or naming of registers, please write to me (atari2600@taswegian.com)
; with your views.  Please contribute, if you think you can improve this
; file!
;
; Latest Revisions...
; 1.01   2/NOV/2004	Kevin Lipe's version (combined macro/header)
;			renamed to VES.H
;			alternates provided for deprecated equates
;			ALL hardware/BIOS equates now in uppercase and prefixed
; 1.00  31/OCT/2004	- initial release


; Please contribute Channel-F header code to atari2600@taswegian.com


;-------------------------------------------------------------------------------
; BIOS Calls
;------------------------

BIOS_CLEAR_SCREEN   = $00d0        ; uses r31
BIOS_DELAY          = $008f
BIOS_PUSH_K         = $0107        ; used to allow more subroutine stack space
BIOS_POP_K          = $011e
BIOS_DRAW_CHARACTER = $0679

;-------------------------------------------------------------------------------
; Colors

COLOR_RED           = $40
COLOR_BLUE          = $80
COLOR_GREEN         = $00
COLOR_BACKGROUND    = $C0

; TODO: Verify
BG_COLOR_GREEN      = %00000000
BG_COLOR_BLUE       = %00110000
BG_COLOR_GRAY       = %11000000
BG_COLOR_BLACK      = %11110000
;BG_COLOR_BLACK      = %00 
;BG_COLOR_GREY       = %01 
;BG_COLOR_BLUE       = %10 
;BG_COLOR_GREEN      = %11

; Alternate (European) spellings...
COLOUR_RED          = COLOR_RED
COLOUR_BLUE         = COLOR_BLUE
COLOUR_GREEN        = COLOR_GREEN
COLOUR_BACKGROUND   = COLOR_BACKGROUND

;-------------------------------------------------------------------------------
; Hand Controller 

CONTROL_RIGHT    = %00000001  ;right
CONTROL_LEFT     = %00000010  ;left
CONTROL_BACKWARD = %00000100  ;backward
CONTROL_FORWARD  = %00001000  ;forward
CONTROL_CCW      = %00010000  ;counterclockwise
CONTROL_CW       = %00100000  ;clockwise
CONTROL_PULL     = %01000000  ;pull up
CONTROL_PUSH     = %10000000  ;push down

;-------------------------------------------------------------------------------
; Console Buttons

CONSOLE_1 = %00000001 ;button 1
CONSOLE_2 = %00000010 ;button 2
CONSOLE_3 = %00000100 ;button 3
CONSOLE_4 = %00001000 ;button 4

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
never = 0
ifS   = 1
ifC   = 2
ifCS  = 3
ifZ   = 4
ifZS  = 5
ifZC  = 6
ifZCS = 7

;-------------------------------------------------------------------------------
; Mnemonics for the BF Instruction
;  "If all of these flags are false, then branch"
always    = $0
ifNotS    = $1
ifNotC    = $2
ifNotCS   = $3
ifNotZ    = $4
ifNotZS   = $5
ifNotZC   = $6
ifNotZCS  = $7
ifNotO    = $8
ifNotOS   = $9
ifNotOC   = $A
ifNotOCS  = $B
ifNotOZ   = $C
ifNotOZS  = $D
ifNotOZC  = $E
ifNotOZCS = $F

;------------------------
; Schach RAM
;------------------------
ram		=	$2800					;location of RAM available in Schach cartridge

;===================================================================
; M A C R O S
;===================================================================

;-------------------------
; CARTRIDGE_START
; Original Author: Sean Riddle
; Inserts the $55 that signals a valid Channel F cartridge and an
; unused byte, which places the VES at the cartridge entry point, $802.

	MAC CARTRIDGE_START
	.byte	$55, $00					; valid cart indicator, unused byte
	ENDM

;-------------------------
; CARTRIDGE_INIT
; Original Author: Sean Riddle
; Initalizes the hardware and clears the complement flag.

	MAC CARTRIDGE_INIT
	; initalize the hardware
	lis	0
	outs	1
	outs	4
	outs	5
	outs	0

	; clear the complement flag (r32)
	lisu	4
	lisl	0
	lr	S, A
	ENDM

;-------------------------
; PROMPTS_NO_T
; Original Author: Sean Riddle
; This code functions the same as the "prompts" section of the BIOS,
; but this code doesn't have a "T?" prompt, so it's useful in games that
; don't have time limits or settings.

                MAC PROMPTS_NOT
prompts         SUBROUTINE
                LR   K,P                 ; 
                PI   BIOS_PUSH_K         ; 
.prompts2:      LI   $85                 ; red 5 (S)
                LR   $0,A                ; 
                PI   prompt              ; 
                LR   A,$4                ; 
                CI   $08                 ; is it button 4, Start?
                BF   $4,.notbut4         ; no, check others
.notbut2:
                PI   popk                ; yes, return
                PK                       ; 
                
.notbut4:       CI   $02                 ; is it button 2, Mode?
                BF   $4,.notbut2         ; 
                LI   $8e                 ; red M
                LR   $0,A                ; 
                PI   prompt              ; 
                LISU 3                   ; 
                LISL 6                   ; 
                LR   A,(IS)              ; 
                as   4                   ;add the mode to the game #
                LR   (IS),A              ; 
                BF   $0,.prompts2        ; 
                ENDM
	
;-------------------------
; SETISAR
; Original Author: Blackbird
; Sets the ISAR to a register number, using lisu and lisl

	MAC SETISAR
	lisu	[[{1}] >> 3]
	lisl	[[{1}] & %111]
	ENDM

;-------------------------
; SETISARU / SETISARL
; Sets the corresponding ISAR octal nybble to the corresponding octal nybble
; of the input argument

	MAC SETISARU
	lisu	[[[{1}] >> 3] & %111]
	ENDM
	
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
