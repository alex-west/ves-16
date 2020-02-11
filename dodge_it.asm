;-------------------------------------------------------------------------------
; Dodge It - Videocart 16
;  for the Fairchild Video Entertainment System
; Original Code Copyright © 1978, Fairchild Semiconductor
;
; Disassembly Generated using Peter Trauner's f8tool
; 
; Comments, Labels, Etc. added by
;  Alex West
;
; Thanks to http://channelf.se/veswiki/ for making this possible
;
; A text file of the instruction manual can be found here:
; http://channelf.se/gallery/txt/videocart16.txt
;
; Build Instructions
;  dasm dodge_it.asm -f3 -ododge_it.bin

; Terms 
; - mid-function - A function called from the main thread that saves and restores
;    the return address using LR K,P, LR P,K, or PK, that calls other functions.
; - leaf-function - A function that is called from main or a mid function that 
;    does not save context and does not call other functions.

	processor f8

	include "ves.h"
	
Reset: equ $0000

; Global Variables / Registers

; Main-Level Registers
main.gameSettings = $A
playerSizeMask  = %11000000
enemySizeMask   = %00110000
playerSpeedMask = %00001100
enemySpeedMask  = %00000011

main.curBall = $B

; Balls
balls.xpos = $10 ; Array
balls.ypos = $1B ; Array
balls.arraySize = $0B ; Constant
balls.velocity = 046 ; Bitpacked array
balls.count = 056

; Arena Bounds
bounds.rightEnemy = 060
bounds.rightPlayer = 061
bounds.left = 062
bounds.bottomEnemy = 063
bounds.bottomPlayer = 064
bounds.top = 065

; Timer
timer.hiByte = 066
timer.loByte = 067

explosionFlag = 072

hiScore.hiByte = 054
hiScore.loByte = 055

; Game mode
gameMode = 075
mode.speedMask = $02
mode.2playerMask = $01

;errata
delayIndex = 057

;--------------------
; Constants
MAX_PLAYERS = 2
MAX_ENEMIES = 9
MAX_BALLS = 11

BCD_ADJUST = $66 ; This should probably be in ves.h

; Graphics
gfx.attributeCol = $7d
gfx.attributeWidth = 2
gfx.screenWidth = $80
gfx.screenHeight = $40

gfx.G = $A
gfx.Qmark = $B

gfx.charWidth = $4
gfx.charHeight = $5

;--

	org $0800

CartridgeHeader: db $55, $2b
CartridgeEntry:  JMP initRoutine

; Graphics data
graphicsData:
	;0,1
	db %01110010
	db %01010110
	db %01010010
	db %01010010
	db %01110111
	; 2, 3
	db %01110111
	db %00010001
	db %01110011
	db %01000001
	db %01110111
	; 4, 5
	db %01010111
	db %01010100
	db %01110111
	db %00010001
	db %00010111
	; 6, 7
	db %01000111
	db %01000001
	db %01110001
	db %01010001
	db %01110001
	; 8, 9
	db %01110111
	db %01010101
	db %01110111
	db %01010001
	db %01110001
	; G ?
	db %11111111
	db %10000001
	db %10110010
	db %10010000
	db %11110010
	; F A
	db %01110111
	db %01000101
	db %01110111
	db %01000101
	db %01000101
	; S T
	db %01110111
	db %01000010
	db %01110010
	db %00010010
	db %01110010

; Delay table A (easy)
delayTableA:
	db $19, $16, $13, $11, $0e, $0c, $0a, $08, $06, $03, $01

; Delay table B (pro)
delayTableB:
	db $0b, $0a, $09, $08, $07, $06, $05, $04, $03, $02, $01

; Bitmasks used while randomizing the game mode
gameModeMasks:
	db $C0, $30, $0C, $03, $FC ; 0843 c0 30 0c 03 fc
				
; Referenced but never read, it seems
A0848:
	db $00, $00, $12, $0B, $0B, $06, $02, $01 ; 0848 00 00 12 0b 0b 06 02 01

ballColors: ; blue, green, red ?
	db $40, $C0, $80 ; 0850 40 c0 80
	
menuChoices:
	db $00, $01, $02, $03, $03  ; 0853 00 01
	
; --?

;----------------------------
; leaf-function : draw
;  This function has 2 entry points
;  If the second entry point is used, then draw.glyph should be either $80 or $C0
;  Given the control codes in draw.glyph, this routine should support up to 64 different
;  characters.
; 
; Bitmasks for draw.glyph
draw.drawRect      = $80
draw.drawAttribute = $C0
; Local constants
draw.colorMask     = $C0
draw.soundMask     = $C0
draw.noSoundMask   = $3F
; Args:
draw.glyph  = 0 ; r0 - Glyph
draw.xpos   = 1 ; r1 - X pos
draw.ypos   = 2 ; r2 - Y pos & color (upper 2 bits)
draw.width  = 4 ; r4 - Width
draw.height = 5 ; r5 - Height
; Locals
draw.data   = 3 ; r3 as data
draw.xcount = 6 ; r6 as h_count
draw.ycount = 7 ; r7 as v_count
draw.temp   = 8 ; For color and data counter

; Entry point for drawing a glyph
drawGlyph:          
	; Get the starting address of the desired glyph
	; dc = graphicsData + glyph/2 + (glyph/2)*4
	DCI  graphicsData        ; 0858 2a 08 05
	LR   A, draw.glyph       ; 085b 40
	SR   1                   ; 085c 12
	LR   draw.temp, A        ; 085d 58
	SL   1                   ; 085e 13
	SL   1                   ; 085f 13
	AS   draw.temp           ; 0860 c8
	ADC                      ; 0861 8e

; Entry point for drawing a box
drawBox:        
	; xcount = width
	; ycount = height
	LR   A, draw.width       ; 0862 44
	LR   draw.xcount, A      ; 0863 56
    LR   A, draw.height      ; 0864 45
    LR   draw.ycount, A      ; 0865 57

; Do one row
draw.doRow:          
	; Mask out row, put color in r8
	LR   A, draw.ypos        ; 0866 42
	NI   draw.colorMask      ; 0867 21 c0
	LR   draw.temp, A        ; 0869 58
	; Mask out sound, put row in r3
	LR   A, draw.ypos        ; 086a 42
	COM                      ; 086b 18
	NI   draw.noSoundMask    ; 086c 21 3f
	LR   draw.data, A        ; 086e 53
	; Preserve sound, write row to port 5
	INS  5                   ; 086f a5
	NI   draw.soundMask      ; 0870 21 c0
	AS   draw.data           ; 0872 c3
	OUTS 5                   ; 0873 b5
	
	; If glyph (r0) is negative, jump ahead
	CLR                  ; 0874 70
	AS   draw.glyph          ; 0875 c0
	LI   $ff                 ; 0876 20 ff
	BM    draw.label_1    ; 0878 91 09
	; Load data into r3
	LM                       ; 087a 16
	LR   draw.data, A        ; 087b 53
	; If glyph number is even, jump ahead
	LIS  $1                  ; 087c 71
	NS   draw.glyph          ; 087d f0
	BZ   draw.doPixel        ; 087e 84 04
	; else, r3 = r3 << 4
	LR   A, draw.data        ; 0880 43
	SL   4                   ; 0881 15	
draw.label_1:
	LR   draw.data, A        ; 0882 53

draw.doPixel:
	; port 4 = xpos
	LR   A, draw.xpos        ; 0883 41
	COM                      ; 0884 18
	OUTS 4                   ; 0885 b4

	; // Set the output color
	; if(draw.data(MSB) == 1)
	;  port 1 = draw.temp & draw.colorMask
	; else
	;  port 1 = BG_COLOR & draw.colorMask
	CLR                  ; 0886 70
	AS   draw.data           ; 0887 c3
	LR   A, draw.temp        ; 0888 48
	BM   draw.label_2    ; 0889 91 02
	CLR                  ; 088b 70
draw.label_2:          
	COM                      ; 088c 18
	NI   draw.colorMask      ; 088d 21 c0
	OUTS 1                   ; 088f b1
	
	; // Left-shift data, while 1-padding it
	; data = (data << 1) + 1
	LR   A, draw.data        ; 0890 43
	SL   1                   ; 0891 13
	INC                      ; 0892 1f
	LR   draw.data, A        ; 0893 53
	
	; If bit 6 of glyph is (not?) set, skip ahead
	LR   A, draw.glyph       ; 0894 40
	SL   1                   ; 0895 13
	BP   draw.label_3      ; 0896 81 04
	; Else, shift color left
	LR   A, draw.temp        ; 0898 48
	SL   1                   ; 0899 13
	LR   draw.temp, A        ; 089a 58

draw.label_3:          
	; Activate VRAM write
	LI   $60                 ; 089b 20 60
	OUTS 0                   ; 089d b0
	LI   $50                 ; 089e 20 50
	OUTS 0                   ; 08a0 b0

	; xpos++
	LR   A, draw.xpos        ; 08a1 41
	INC                      ; 08a2 1f
	LR   draw.xpos, A        ; 08a3 51
	
	; Delay loop
	LIS  $4                  ; 08a4 74
draw.delay:
	AI   $ff                 ; 08a5 24 ff
	BNZ   draw.delay       ; 08a7 94 fd
	
	; xcount--
	DS   draw.xcount         ; 08a9 36
	; if(xcount != 0) goto doPixel
	BNZ   draw.doPixel     ; 08aa 94 d8
	
	; ypos++
	LR   A, draw.ypos        ; 08ac 42
	INC                      ; 08ad 1f
	LR   draw.ypos, A        ; 08ae 52
	
	; // Reset x counters
	; xcount = width
	; xpos = xpos - width
	LR   A, draw.width       ; 08af 44
	LR   draw.xcount,A       ; 08b0 56
	; Reset x_pos
	COM                      ; 08b1 18
	INC                      ; 08b2 1f
	AS   draw.xpos           ; 08b3 c1
	LR   draw.xpos, A        ; 08b4 51

	; ycount--
	DS   draw.ycount         ; 08b5 37
	; // if(ycount != 0) goto doRow
	BNZ    draw.doRow      ; 08b6 94 af
	
	; // Reset ypos
	; ypos = ypos - height
	LR   A, draw.height      ; 08b8 45
	COM                      ; 08b9 18
	INC                      ; 08ba 1f
	AS   draw.ypos           ; 08bb c2
	LR   draw.ypos, A        ; 08bc 52
	
	; Clear ports
	CLR                  ; 08bd 70
	OUTS 1                   ; 08be b1
	OUTS 0                   ; 08bf b0
	POP                      ; 08c0 1c
;
; end leaf-function draw
;----------------------------

;----------------------------
; RNG (probably)
; Modifies the contents of o76 and o77
; No input arguments
RNG.seedHi = 076
RNG.seedLo = 077
; Returns in registers
RNG.regHi = $6
RNG.regLo = $7

; Locals
RNG.tempISAR = 8 ; r8 is used as temp ISAR

RNG.roll:
	; Save the ISAR in r8
	LR   A,IS                ; 08c1 0a
	LR   RNG.tempISAR, A; 08c2 58
	
	; r6 = o77*2 + o76
	SETISAR RNG.seedLo      ; 08c3 67 6f
	LR   A,(IS)-             ; 08c5 4e
	SL   1                   ; 08c6 13
	AS   (IS)+               ; 08c7 cd
	LR   RNG.regHi, A        ; 08c8 56
	
	; r6,7 = (r6,77)*2
	;  do the lo byte
	LR   A,(IS)              ; 08c9 4c
	AS   (IS)                ; 08ca cc
	LR   RNG.regLo, A        ; 08cb 57
	;  do the hi byte
	LR   J,W                 ; 08cc 1e ; save status reg
	LR   A, RNG.regHi        ; 08cd 46
	SL   1                   ; 08ce 13
	LR   W,J                 ; 08cf 1d ; reload status reg
	LNK                      ; 08d0 19
	LR   RNG.regHi, A        ; 08d1 56
	
	; r6,7 = (r6,7)*2
	;  do the lo byte
	LR   A, RNG.regLo        ; 08d2 47
	AS   RNG.regLo           ; 08d3 c7
	LR   RNG.regLo, A        ; 08d4 57
	;  do the hi byte
	LR   J,W                 ; 08d5 1e
	LR   A, RNG.regHi        ; 08d6 46
	SL   1                   ; 08d7 13
	LR   W,J                 ; 08d8 1d
	LNK                      ; 08d9 19
	LR   RNG.regHi, A        ; 08da 56
	
	; r6,7 += r66,67
	;  do the lo byte
	LR   A, RNG.regLo        ; 08db 47
	AS   (IS)-               ; 08dc ce
	LR   RNG.regLo, A        ; 08dd 57
	;  do the hi byte
	LR   A, RNG.regHi        ; 08de 46
	LNK                      ; 08df 19
	AS   (IS)+               ; 08e0 cd
	LR   RNG.regHi, A        ; 08e1 56
	
	; r6,r7 += 0x3619
	; o76,77 = r6,r7
	;  do the lo byte
	LR   A, RNG.regLo        ; 08e2 47
	AI   $19                 ; 08e3 24 19
	LR   RNG.regLo, A        ; 08e5 57
	LR   (IS)-,A             ; 08e6 5e
	;  do the hi byte
	LR   A, RNG.regHi        ; 08e7 46
	LNK                      ; 08e8 19
	AI   $36                 ; 08e9 24 36
	LR   RNG.regHi, A        ; 08eb 56
	LR   (IS)+,A             ; 08ec 5d
	
	; Restore ISAR
	LR   A, RNG.tempISAR; 08ed 48
	LR   IS,A                ; 08ee 0b
	; Return
	POP                      ; 08ef 1c
; end of RNG function
;----------------------------

;----------------------------
; Menu

; Locals
menu.waitTime = $af00
menu.buttons = 0
menu.waitHi = 2
menu.waitLo = 1

menu:          
	LR   K,P                 ; 08f0 08
	; set lower byte of waitloop counter
	LIS  [<menu.waitTime]    ; 08f1 70
	LR   menu.waitLo,A       ; 08f2 51
	; clear console buttons, load default state
	OUTS 0                   ; 08f3 b0
	INS  0                   ; 08f4 a0
	LR   menu.buttons, A     ; 08f5 50
	; set upper byte of waitloop counter
	LI   [>menu.waitTime]    ; 08f6 20 af
	LR   menu.waitHi, A      ; 08f8 52
	
menu.pollInput:
	PI   RNG.roll            ; 08f9 28 08 c1
	DCI  menuChoices               ; 08fc 2a 08 53
	; Read console buttons
	CLR                  ; 08ff 70
	OUTS 0                   ; 0900 b0
	INS  0                   ; 0901 a0
	; Check if different
	XS   menu.buttons        ; 0902 e0
	; if not, decrement waitloop
	BZ   menu.wait           ; 0903 84 03
	
menu.exit:
	LR   $0,A                ; 0905 50
	PK                       ; 0906 0c

menu.wait:
	DS   menu.waitLo         ; 0907 31
	BNZ   menu.pollInput     ; 0908 94 f0
	DS   menu.waitHi         ; 090a 32
	BNZ   menu.pollInput     ; 090b 94 ed
	; Default to game mode 1 (1 player, easy)
	LIS  $1                  ; 090d 71
	; return
	BR   menu.exit               ; 090e 90 f6
;
; end mid-function menu
;---------------------------- 

;----------------------------
; Read controllers
; Args 
; Locals
; r0
; Return
controller1 = 070 ; Controller 1
controller2 = 071 ; Controller 2

readControllers:          
	SETISAR controller1      ; 0910 67 68
	
	; Clear controllers
	CLR                  ; 0912 70
	OUTS 1                   ; 0913 b1
	OUTS 4                   ; 0914 b4
	
	; Save controller 1 in o70
	INS  1                   ; 0915 a1
	LR   (IS)+,A             ; 0916 5d
	
	; Save controller 2 in 071
	INS  4                   ; 0917 a4
	LR   (IS)-,A             ; 0918 5e
	
	; Add controller 1 & 2
	AS   (IS)                ; 0919 cc
	; Take the two's complement
	INC                      ; 091a 1f
	COM                      ; 091b 18
	; If the result is zero, return
	BZ   readControllers.exit               ; 091c 84 06
	
	; else, shuffle RNG
	; switch to o77
	SETISARL RNG.seedLo     ; 091e 6f
	LIS  $1                  ; 091f 71
	; o77 = o77 + 1
	AS   (IS)                ; 0920 cc
	LR   (IS)-,A             ; 0921 5e
	; o76--
	DS   (IS)                ; 0922 3c
	
readControllers.exit:
	POP                      ; 0923 1c
;
;----------------------------
	
;----------------------------	
; HandlePlayerMovement
;
; Args
tempVelocity = $0
tempXpos = $1
tempYpos = $2
; locals
tempLoopCount = $8

playerHandler:
	LR   K,P                 ; 0924 08
	PI   readControllers               ; 0925 28 09 10
	
	; Randomize which player is processed first
	; if LSB of RNG is set
	;  process player 1 first
	; else
	;  process player 2 first
	SETISAR RNG.seedLo      ; 0928 67 6f
	LIS  %00000001           ; 092a 71
	NS   (IS)                ; 092b fc
	CLR                  ; 092c 70
	BNZ   playerHandler.setPlayer            ; 092d 94 02
	LIS  1                  ; 092f 71
playerHandler.setPlayer:
	LR   main.curBall,A      ; 0930 5b

	; r8 = 2 ; loop count
	LIS  MAX_PLAYERS         ; 0931 72
	LR   tempLoopCount,A     ; 0932 58

	; start loop
playerHandler.mainLoop:
	; clear speed (so we don't move if nothing is pressed)
	CLR                      ; 0933 70
	LR   tempVelocity,A      ; 0934 50

	; tempXpos = xpos[curBall]
	LR   A,main.curBall      ; 0935 4b
	AI   balls.xpos          ; 0936 24 10
	LR   IS,A                ; 0938 0b
	LR   A,(IS)              ; 0939 4c
	LR   tempXpos,A          ; 093a 51

	; tempypos = ypos[curBall]
	LR   A,IS                ; 093b 0a
	AI   balls.arraySize     ; 093c 24 0b
	LR   IS,A                ; 093e 0b
	LR   A,(IS)              ; 093f 4c
	LR   $2,A                ; 0940 52

	; set ISAR to match the current player's controller
	SETISARU controller1     ; 0941 67
	LIS  %00000001           ; 0942 71
	NS   main.curBall        ; 0943 fb
	SETISARL controller2     ; 0944 69
	BNZ   playerHandler.checkRight ; 0945 94 02
	SETISARL controller1     ; 0947 68

	; Check if right is pressed
playerHandler.checkRight:
	LIS  CONTROL_RIGHT       ; 0948 71
	NS   (IS)                ; 0949 fc
	BNZ  playerHandler.checkLeft ; 094a 94 06
	; If so, set x direction to right
	LR   A,tempXpos          ; 094c 41
	NI   %01111111           ; 094d 21 7f
	BR   playerHandler.setXspeed; 094f 90 08

	; Check if left is pressed
playerHandler.checkLeft:
	LIS  CONTROL_LEFT        ; 0951 72
	NS   (IS)                ; 0952 fc
	BNZ  playerHandler.checkDown ; 0953 94 08
	; If so, set x direction to left
	LR   A,tempXpos          ; 0955 41
	OI   %10000000           ; 0956 22 80
	
playerHandler.setXspeed:
	LR   tempXpos,A          ; 0958 51
	; set x speed
	LIS  playerSpeedMask     ; 0959 7c
	NS   main.gameSettings   ; 095a fa
	LR   tempVelocity,A      ; 095b 50

	; Check if down is pressed
playerHandler.checkDown:
	LIS  CONTROL_BACKWARD    ; 095c 74
	NS   (IS)                ; 095d fc
	BNZ   playerHandler.checkUp ; 095e 94 06
	; If so, set y direction to down
	LR   A,tempYpos          ; 0960 42
	NI   %00111111           ; 0961 21 3f
	BR   playerHandler.setYspeed ; 0963 90 08
	
	; Check if up is pressed
playerHandler.checkUp:
	LIS  CONTROL_FORWARD     ; 0965 78
	NS   (IS)                ; 0966 fc
	BNZ   playerHandler.prepSaveBall ; 0967 94 0b
	; If so, set y direction to up
	LR   A,tempYpos          ; 0969 42
	OI   %10000000           ; 096a 22 80

playerHandler.setYspeed:
	LR   tempYpos,A          ; 096c 52
	; set y speed
	LIS  playerSpeedMask     ; 096d 7c
	NS   main.gameSettings   ; 096e fa
	SR   1                   ; 096f 12
	SR   1                   ; 0970 12
	AS   tempVelocity        ; 0971 c0
	LR   tempVelocity,A      ; 0972 50

playerHandler.prepSaveBall:
	; copy the velocity to the other nybble
	; (saveBall will figure out which one it needs)
	LR   A,tempVelocity      ; 0973 40
	SL   4                   ; 0974 15
	AS   tempVelocity        ; 0975 c0
	LR   tempVelocity,A      ; 0976 50
	PI   saveBall            ; 0977 28 09 a2
	
	; set curBall to the other player's ball
	; (why not xor the register with a constant 1?)
	LIS  $1                  ; 097a 71
	NS   main.curBall        ; 097b fb
	CLR                      ; 097c 70
	BNZ   playerHandler.setNextPlayer ; 097d 94 02
	LIS  $1                  ; 097f 71
playerHandler.setNextPlayer:
	LR   main.curBall,A      ; 0980 5b
	
	; decrement the loop counter
	DS   tempLoopCount       ; 0981 38
	BNZ   playerHandler.mainLoop ; 0982 94 b0

	LR   P,K                 ; 0984 09
	POP                      ; 0985 1c
; end player handler function
;----------------------------

;----------------------------
; Variable delay function
; Args
; Use this if entering via delay.viaLookup
delay.index    = 0
; Use this if entering via delay.variable
delay.count    = 0
; Locals
delay.tempISAR = 3

delay.viaLookup:
	; // Get the appropriate delay count from an array in ROM.
	; // Also, save the ISAR during this so it doesn't get clobbered
	; if(gameMode & speedMask == 0)
	;  count = delayTableA[index]
	; else
	;  count = delayTableB[index]
	DCI  delayTableA         ; 0986 2a 08 2d
	
	; Save the ISAR
	LR   A,IS               ; 0989 0a
	LR   delay.tempISAR, A  ; 098a 53
	
	SETISAR gameMode         ; 098b 67 6d
	LIS  mode.speedMask      ; 098d 72
	NS   (IS)                ; 098e fc
	
	; Restore the ISAR
	LR   A, delay.tempISAR  ; 098f 43
	LR   IS, A              ; 0990 0b
	
	BZ   delay.loadData     ; 0991 84 04
	DCI  delayTableB        ; 0993 2a 08 38

delay.loadData:          
	LR   A, delay.index      ; 0996 40
	ADC                      ; 0997 8e
	LM                       ; 0998 16
	LR   delay.count, A      ; 0999 50

delay.variable:
	CLR                  ; 099a 70
delay.inner:
	INC                      ; 099b 1f
	BNZ  delay.inner         ; 099c 94 fe
	DS   delay.count         ; 099e 30
	BNZ  delay.variable      ; 099f 94 fa

	POP                      ; 09a1 1c
; end of delay function
;----------------------------
	
;----------------------------
; save ball function
;  saves the temp xpos, ypos, and velocity of a ball to their arrays
; Args
saveBall.velocity = $0
saveBall.xpos = $1
saveBall.ypos = $2
; Local
saveBall.mask = $3

saveBall:          
	; xpos[b] = r1
	LI   balls.xpos          ; 09a2 20 10
	AS   main.curBall        ; 09a4 cb
	LR   IS,A                ; 09a5 0b
	LR   A,saveBall.xpos     ; 09a6 41
	LR   (IS),A              ; 09a7 5c
	
	; ypos[b] = r2
	LR   A,IS                ; 09a8 0a
	AI   balls.arraySize     ; 09a9 24 0b
	LR   IS,A                ; 09ab 0b
	LR   A,saveBall.ypos     ; 09ac 42
	LR   (IS),A              ; 09ad 5c
	
	; calculate index and bitmask for the bitpacked velocity array
	; isar = velocity array + curBall/2
	LR   A, main.curBall     ; 09ae 4b
	SR   1                   ; 09af 12
	AI   balls.velocity      ; 09b0 24 26
	LR   IS,A                ; 09b2 0b
	
	; if curBall is even
	;  bitmask = %00001111
	; else 
	;  bitmask = %11110000
	LIS  $1                  ; 09b3 71
	NS   main.curBall        ; 09b4 fb
	LIS  %00001111           ; 09b5 7f
	BNZ   A09b9              ; 09b6 94 02
	COM                      ; 09b8 18
A09b9:          
	LR   saveBall.mask,A     ; 09b9 53

	; clear curBall's bitfield from the velocity byte
	COM                      ; 09ba 18
	NS   (IS)                ; 09bb fc
	LR   (IS),A              ; 09bc 5c
	; extract the velocity bitfield from the input argument
	LR   A,saveBall.velocity ; 09bd 40
	NS   saveBall.mask       ; 09be f3
	; merge the bitfields
	AS   (IS)                ; 09bf cc
	LR   (IS),A              ; 09c0 5c

	; exit
	POP                      ; 09c1 1c
; end save ball function
;----------------------------

;----------------------------
; Spawn ball
; mid-level function
; Args

; Locals
spawn.velocity = $0
spawn.xpos = $1
spawn.ypos = $2

; Constants
spawn.xmin = $10
spawn.xmax = $57
spawn.ymin = $10
spawn.ymax = $37

spawn.playerY = $23
spawn.playerX1 = $33
spawn.playerX2 = $3A
; Returns
; None (TODO: verify)

spawn:
	LR   K,P                 ; 09c2 08
spawn.reroll:          
	; keep rerolling RNG until it gets an inbounds x and y position
	; xpos = rng.hi
	PI   RNG.roll            ; 09c3 28 08 c1
	LR   A, RNG.regHi        ; 09c6 46
	CI   spawn.xmin          ; 09c7 25 10
	BC   spawn.reroll   ; 09c9 82 f9
	CI   spawn.xmax          ; 09cb 25 57
	BNC  spawn.reroll   ; 09cd 92 f5
	LR   spawn.xpos,A                ; 09cf 51
	; ypos = rng.lo
	LR   A, RNG.regLo        ; 09d0 47
	CI   spawn.ymin                 ; 09d1 25 10
	BC   spawn.reroll   ; 09d3 82 ef
	CI   spawn.ymax                 ; 09d5 25 37
	BNC  spawn.reroll  ; 09d7 92 eb
	LR   spawn.ypos,A                ; 09d9 52
				; set velocity (TODO: verify)
				; r0 = 0x55
                LI   $55                 ; 09da 20 55
                LR   $0,A                ; 09dc 50
	; use lower 2 bits of rng.hi as index to jump table
	LIS  %00000011           ; 09dd 73
	NS   RNG.regHi           ; 09de f6
	; jump to (jump_table + 2*A)
	DCI  spawn.jumpTable; 09df 2a 09 e6
	ADC                      ; 09e2 8e
	ADC                      ; 09e3 8e
	LR   Q,DC                ; 09e4 0e
	LR   P0,Q                ; 09e5 0d
; Jump table !
spawn.jumpTable:          
	BR   spawn.north  ; 09e6 90 07
	BR   spawn.east  ; 09e8 90 0a
	BR   spawn.south  ; 09ea 90 13
	BR   spawn.west  ; 09ec 90 1c

spawn.north:
	; ypos = 0x11
	LI   $11                 ; 09ee 20 11
	LR   spawn.ypos,A        ; 09f0 52
	BR   spawn.handlePlayers ; 09f1 90 1a
	
spawn.east:          
	; xpos = $58 - enemy ball size
	; xvel = west
	LI   %00110000           ; 09f3 20 30
	NS   $a                  ; 09f5 fa
	SR   4                   ; 09f6 14
	COM                      ; 09f7 18
	INC                      ; 09f8 1f
	AI   $80 | (spawn.xmax + 1) ;$d8                 ; 09f9 24 d8
	LR   spawn.xpos,A                ; 09fb 51
	BR   spawn.handlePlayers ; 09fc 90 0f

spawn.south:
	; ypos = $38 - enemy ball size
	; yvel = north
	LI   %00110000           ; 09fe 20 30
	NS   $a                  ; 0a00 fa
	SR   4                   ; 0a01 14
	COM                      ; 0a02 18
	INC                      ; 0a03 1f
	AI   $80 | (spawn.ymax + 1) ;$b8                 ; 0a04 24 b8
	LR   spawn.ypos,A                ; 0a06 52
	BR   spawn.handlePlayers ; 0a07 90 04

spawn.west:
	; xpos = 0x11
	LI   $11                 ; 0a09 20 11
	LR   spawn.xpos,A                ; 0a0b 51

spawn.handlePlayers:          
	; if (reg_b > 1) skip ahead
	LR   A, main.curBall     ; 0a0c 4b
	CI   [MAX_PLAYERS-1]     ; 0a0d 25 01
	BNC   spawn.exit         ; 0a0f 92 0b

	; ypos = 0x23
	LI   spawn.playerY               ; 0a11 20 23
	LR   spawn.ypos,A                ; 0a13 52
	; if (curBall != 0)
	;  xpos = 0x33
	; else xpos = 0x33 + 0x07
	LI   spawn.playerX1                  ; 0a14 20 33
	BNZ   spawn.setXPos                  ; 0a16 94 03
	AI   spawn.playerX2 - spawn.playerX1 ; 0a18 24 07
spawn.setXPos:
	LR   spawn.xpos,A                ; 0a1a 51

spawn.exit:
	; Save xpos and ypos
	PI   saveBall               ; 0a1b 28 09 a2
	; Exit
	LR   P,K                 ; 0a1e 09
	POP                      ; 0a1f 1c
; end spawn function
;----------------------------

;----------------------------
; draw timer
; mid-level function
; Args
drawTimer.xpos = 0
drawTimer.ypos = 2 ; and color
; ISAR should point to the lower byte of the score
; Local Constants
drawTimer.yOffset = $0A
drawTimer.xDelta  = <[-5]
drawTimer.digitMask = $0F

drawTimer:          
	LR   K,P                 ; 0a20 08
	; Update score display (ones)
	; Load x pos from r0 to r1
	LR   A, drawTimer.xpos   ; 0a21 40
	LR   draw.xpos, A        ; 0a22 51
	; y pos
	LI   drawTimer.yOffset   ; 0a23 20 0a
	AS   drawTimer.ypos      ; 0a25 c2
	LR   draw.ypos, A        ; 0a26 52
	; Set glyph
	LI   drawTimer.digitMask ; 0a27 20 0f
	NS   (IS)                ; 0a29 fc
	LR   draw.glyph, A       ; 0a2a 50
	; Width
	LIS  gfx.charWidth       ; 0a2b 74
	LR   draw.width, A       ; 0a2c 54
	; Height
	LIS  gfx.charHeight      ; 0a2d 75
	LR   draw.height, A      ; 0a2e 55
	PI   drawGlyph           ; 0a2f 28 08 58
	
	; Update score display (tens)
	; Set glyph
	LR   A,(IS)-             ; 0a32 4e
	SR   4                   ; 0a33 14
	LR   draw.glyph, A       ; 0a34 50
	; Subtract 5 from x pos
	LI   drawTimer.xDelta    ; 0a35 20 fb
	AS   draw.xpos           ; 0a37 c1
	LR   draw.xpos, A        ; 0a38 51
	PI   drawGlyph           ; 0a39 28 08 58
	
	; Update score display (hundreds)
	; Set glyph
	LR   A,(IS)              ; 0a3c 4c
	NI   drawTimer.digitMask ; 0a3d 21 0f
	LR   draw.glyph, A       ; 0a3f 50
	; Subtract 5 from x pos
	LI   drawTimer.xDelta    ; 0a40 20 fb
	AS   draw.xpos           ; 0a42 c1
	LR   draw.xpos, A        ; 0a43 51
	PI   drawGlyph           ; 0a44 28 08 58
	
	; Update score display (thousands)
	; Load glyph
	LR   A,(IS)              ; 0a47 4c
	SR   4                   ; 0a48 14
	LR   draw.glyph, A       ; 0a49 50
	; Subtract 5 from x pos
	LI   drawTimer.xDelta    ; 0a4a 20 fb
	AS   draw.xpos           ; 0a4c c1
	LR   draw.xpos, A        ; 0a4d 51
	PI   drawGlyph           ; 0a4e 28 08 58
	; Exit
	LR   P,K                 ; 0a51 09
	POP                      ; 0a52 1c
; end of draw timer function
;----------------------------

;----------------------------
; Ball handler
;  handles ball movement and ball/wall collisions
; Args
; 070 = ball sizes
; 071 = ball speed
; velocity = r3 ?
tempBallSize = 070
tempBallSpeed = 071

handleBall:
	LR   K,P                 ; 0a53 08

	; load ball xpos
	LI   balls.xpos          ; 0a54 20 10
	AS   main.curBall        ; 0a56 cb
	LR   IS,A                ; 0a57 0b
	LR   A,(IS)              ; 0a58 4c
	LR   draw.xpos, A        ; 0a59 51

	; load ball ypos
	LR   A,IS                ; 0a5a 0a
	AI   balls.arraySize     ; 0a5b 24 0b
	LR   IS,A                ; 0a5d 0b
	LR   A,(IS)              ; 0a5e 4c

	; store temp y velocity in r9
	LR   $9,A                ; 0a5f 59

	; Mask out the color bits
	NI   %00111111           ; 0a60 21 3f
	LR   draw.ypos, A        ; 0a62 52

	; Load ball size
	SETISAR tempBallSize     ; 0a63 67 68
	LR   A,(IS)              ; 0a65 4c
	LR   draw.width, A       ; 0a66 54
	LR   draw.height, A      ; 0a67 55

	; Set parameter
	LI   draw.drawRect       ; 0a68 20 80
	LR   draw.glyph, A       ; 0a6a 50

	; Undraw ball
	PI   drawBox               ; 0a6b 28 08 62

	; reload ypos from temp
	LR   A,$9                ; 0a6e 49
	LR   draw.ypos, A        ; 0a6f 52

	; get bitpacked velocity
	; ISAR = o46 + index/2
	LR   A, main.curBall     ; 0a70 4b
	SR   1                   ; 0a71 12
	AI   balls.velocity      ; 0a72 24 26
	LR   IS,A                ; 0a74 0b
				
	; if (index is odd)
	;  tempMask = $0F
	; else
	;  tempMask = $F0
	LIS  $1                  ; 0a75 71
	NS   main.curBall        ; 0a76 fb
	LIS  %00001111           ; 0a77 7f
	BNZ   A0a7b              ; 0a78 94 02
	COM                      ; 0a7a 18
A0a7b:          
	LR   $6,A                ; 0a7b 56
	
	; store the other nybble of the velocity byte in r0
	; I don't think this is ever used
	COM                      ; 0a7c 18
	NS   (IS)                ; 0a7d fc
	LR   $0,A                ; 0a7e 50
	
	; store the nybble we're interested in in r6
	LR   A,$6                ; 0a7f 46
	NS   (IS)                ; 0a80 fc
	LR   $3,A                ; 0a81 53
	; shift right by 4 bits in case it's the upper nybble
	SR   4                   ; 0a82 14
	BZ   A0a86               ; 0a83 84 02
	LR   $3,A                ; 0a85 53

A0a86:
	; if(the highest bit of xpos is 0)
	;  xpos += xvel
	; else
	;  xpos -= xvel
	CLR                      ; 0a86 70
	AS   draw.xpos           ; 0a87 c1
	LR   J,W                 ; 0a88 1e
	
	; get the xspeed from r3
	LR   A,$3                ; 0a89 43
	SR   1                   ; 0a8a 12
	SR   1                   ; 0a8b 12
	
	; if xpos was positive, branch ahead
	LR   W,J                 ; 0a8c 1d
	BP   A0a91               ; 0a8d 81 03
	
	; else, negate the accumulator
	COM                      ; 0a8f 18
	INC                      ; 0a90 1f
A0a91:
	; xpos += velocity (fron the accumulator)
	AS   draw.xpos           ; 0a91 c1
	LR   draw.xpos,A         ; 0a92 51

	; if(the highest bit of ypos is 0)
	;  ypos += yvel
	; else
	;  ypos -= yvel
	CLR                  ; 0a93 70
	AS   draw.ypos           ; 0a94 c2
	LR   J,W                 ; 0a95 1e
	
	; get the yspeed from r3
	LIS  %00000011           ; 0a96 73
	NS   $3                  ; 0a97 f3
	
	; if ypos was positive, branch ahead
	LR   W,J                 ; 0a98 1d
	BP   A0a9d               ; 0a99 81 03
	
	; else, negate the accumulator
	COM                      ; 0a9b 18
	INC                      ; 0a9c 1f
A0a9d:
	; ypos += velocity (from the accumulator)
	AS   draw.ypos           ; 0a9d c2
	LR   draw.ypos,A         ; 0a9e 52

; Ball/Wall collision detection
tempRightBound = $4
tempLowerBound = $5
; tempVelocity = $0

	; if (curBall <= [MAX_PLAYERS-1])
	;  tempRightBound = bounds.rightEnemy
	; else
	;  tempRightBound = bounds.rightPlayer
	SETISAR bounds.rightEnemy; 0a9f 66 68
	LR   A, main.curBall     ; 0aa1 4b
	CI   [MAX_PLAYERS-1]     ; 0aa2 25 01
	BNC   A0aa7              ; 0aa4 92 02
	SETISARL bounds.rightPlayer; 0aa6 69
A0aa7:          
	LR   A,(IS)              ; 0aa7 4c
	LR   tempRightBound,A    ; 0aa8 54
	
	; tempLowerBound = (previous isar reg + 3)
	LR   A,IS                ; 0aa9 0a
	AI   3                   ; 0aaa 24 03
	LR   IS,A                ; 0aac 0b
	LR   A,(IS)              ; 0aad 4c
	LR   tempLowerBound,A    ; 0aae 55

	; Clear r0
	CLR                      ; 0aaf 70
	LR   $0,A                ; 0ab0 50
	
	; if bit 7 of velocity is set (meaning the ball is going left), branch ahead
	AS   draw.xpos           ; 0ab1 c1
	BM   A0acb               ; 0ab2 91 18
	; if the two add and don't carry, then branch ahead
	AS   tempRightBound      ; 0ab4 c4
	BNC   A0adf              ; 0ab5 92 29
	
; We have collided with the right wall
	; clamp position to right wall and set direction to left
	LR   A,tempRightBound    ; 0ab7 44
	COM                      ; 0ab8 18
	INC                      ; 0ab9 1f
	AI   $80                 ; 0aba 24 80
	LR   draw.xpos,A         ; 0abc 51
	
	; Play sound for hitting wall
	LI   $40                 ; 0abd 20 40
	LR   playSound.sound,A   ; 0abf 53
	PI   playSound           ; 0ac0 28 0c c8

A0ac3:
	; r0 = speed << 2
	; setting x speed?
	SETISAR tempBallSpeed    ; 0ac3 67 69
	LR   A,(IS)              ; 0ac5 4c
	SL   1                   ; 0ac6 13
	SL   1                   ; 0ac7 13
	LR   $0,A                ; 0ac8 50
	BR   A0adf               ; 0ac9 90 15

A0acb:
	; mask out the directional bit
	LR   A,draw.xpos         ; 0acb 41
	NI   %01111111           ; 0acc 21 7f
	
	; branch ahead if(leftBound < xpos)
	COM                      ; 0ace 18
	INC                      ; 0acf 1f
	SETISAR bounds.left      ; 0ad0 66 6a
	AS   (IS)                ; 0ad2 cc
	BNC   A0adf              ; 0ad3 92 0b
	
	; clamp position to left wall and set direction to the right
	LR   A,(IS)              ; 0ad5 4c
	LR   draw.xpos,A         ; 0ad6 51
	
	; Play sound for hitting wall
	LI   $40                 ; 0ad7 20 40
	LR   playSound.sound,A   ; 0ad9 53
	PI   playSound           ; 0ada 28 0c c8
	
	BR   A0ac3               ; 0add 90 e5
;-----
	
; 
A0adf:
	CLR                      ; 0adf 70
	; if bit 7 of the velocity is set (meaning it's going up) branch ahead
	AS   draw.ypos           ; 0ae0 c2
	BM   A0afb               ; 0ae1 91 19
	; apply bitmask
	NI   %00111111           ; 0ae3 21 3f
	; branch if ypos + lowerBound < 256 or 0 or whatever
	AS   tempLowerBound      ; 0ae5 c5
	BNC   A0b0e              ; 0ae6 92 27
	
; We have collided with the lower wall
	; Clamp position to the lower wall and set the direction to up
	LR   A,tempLowerBound    ; 0ae8 45
	COM                      ; 0ae9 18
	INC                      ; 0aea 1f
	AI   $80                 ; 0aeb 24 80
	LR   draw.ypos,A         ; 0aed 52
	
	; Play sound for hitting wall
	LI   $40                 ; 0aee 20 40
	LR   playSound.sound,A   ; 0af0 53
	PI   playSound           ; 0af1 28 0c c8
				
A0af4:
	; r0 += speed
	; setting the y speed?
	SETISAR 071              ; 0af4 67 69
	LR   A,(IS)              ; 0af6 4c
	AS   $0                  ; 0af7 c0
	LR   $0,A                ; 0af8 50
	BR   A0b0e            ; 0af9 90 14

A0afb:
	SETISARU bounds.top      ; 0afb 66 ; Whyyyyy? Why is this split like this?
	; Apply bitmask to velocity
	NI   %00111111           ; 0afc 21 3f
	; branch ahead if(topBound < ypos)
	COM                      ; 0afe 18
	INC                      ; 0aff 1f
	SETISARL bounds.top      ; 0b00 6d
	AS   (IS)                ; 0b01 cc
	BNC   A0b0e            ; 0b02 92 0b
	
; We have collided with the top wall
	; Clamp position to top wall and set direction downwards
	LR   A,(IS)              ; 0b04 4c
	LR   draw.ypos,A         ; 0b05 52

	; Play sound for hitting wall	
	LI   $40                 ; 0b06 20 40
	LR   playSound.sound,A   ; 0b08 53
	PI   playSound           ; 0b09 28 0c c8
	
	BR   A0af4               ; 0b0c 90 e7
;-----

; Applying velocity changes?
tempBitmask = $7
tempOtherBitmask = $6
tempOtherVelocity = $4
tempThisVelocity = $5

A0b0e:          
	; copy lower nybble to upper nybble
	LR   A,saveBall.velocity ; 0b0e 40
	SL   4                   ; 0b0f 15
	AS   saveBall.velocity   ; 0b10 c0
	LR   saveBall.velocity,A ; 0b11 50

	; ISAR = index of the velocity byte
	LR   A,main.curBall      ; 0b12 4b
	SR   1                   ; 0b13 12
	AI   balls.velocity      ; 0b14 24 26
	LR   IS,A                ; 0b16 0b

	; Set the bitmask for the appropriate nybble
	LIS  $1                  ; 0b17 71
	NS   main.curBall        ; 0b18 fb
	LIS  %00001111           ; 0b19 7f
	BNZ   A0b1d              ; 0b1a 94 02
	COM                      ; 0b1c 18
A0b1d:
	LR   tempBitmask, A      ; 0b1d 57

	; Set the bitmask for the opposite nybble 
	COM                      ; 0b1e 18
	LR   tempOtherBitmask,A  ; 0b1f 56
	; save opposite nybble
	NS   (IS)                ; 0b20 fc
	LR   tempOtherVelocity,A ; 0b21 54

	; apply the bitmask to get our velocity
	LR   A,tempBitmask       ; 0b22 47
	NS   (IS)                ; 0b23 fc
	LR   tempThisVelocity,A  ; 0b24 55

	; branch ahead if y speed is zero
	LI   %00110011       ; 0b25 20 33
	NS   saveBall.velocity   ; 0b27 f0
	BZ   A0b35               ; 0b28 84 0c

	; mask out everything but the x speed
	LI   %11001100           ; 0b2a 20 cc
	NS   tempBitmask         ; 0b2c f7
	NS   tempThisVelocity    ; 0b2d f5
	LR   tempThisVelocity,A  ; 0b2e 55
	
	; retain the old y speed
	; set the new x speed to the xspeed in gameSettings
	LI   %00110011           ; 0b2f 20 33
	NS   saveBall.velocity   ; 0b31 f0
	AS   tempThisVelocity    ; 0b32 c5
	NS   tempBitmask         ; 0b33 f7
	LR   tempThisVelocity,A  ; 0b34 55
				
A0b35:
	; branch ahead x speed is zero
	LI   %11001100           ; 0b35 20 cc
	NS   saveBall.velocity   ; 0b37 f0
	BZ   A0b45               ; 0b38 84 0c
				
	; mask out everything but the x speed
	LI   %00110011           ; 0b3a 20 33
	NS   tempBitmask         ; 0b3c f7
	NS   tempThisVelocity    ; 0b3d f5
	LR   tempThisVelocity,A  ; 0b3e 55

	; retain the old x speed
	; set the new y speed to the xspeed in gameSettings
	LI   %11001100           ; 0b3f 20 cc
	NS   saveBall.velocity   ; 0b41 f0
	AS   tempThisVelocity    ; 0b42 c5
	NS   tempBitmask         ; 0b43 f7
	LR   tempThisVelocity,A  ; 0b44 55

A0b45:
	; Merge the nybbles back together
	LR   A,tempThisVelocity  ; 0b45 45
	AS   tempOtherVelocity   ; 0b46 c4

	; Set velocity for saveBall
	; (saveBall will determine which nybble is this ball's)
	LR   saveBall.velocity,A ; 0b47 50

	; It is finished... we can save the results
	PI   saveBall            ; 0b48 28 09 a2
	
	; Redraw ball
	DCI  ballColors          ; 0b4b 2a 08 50
	LR   A,main.curBall      ; 0b4e 4b
	CI   [MAX_PLAYERS-1]     ; 0b4f 25 01
	LIS  $2                  ; 0b51 72
	BNC   A0b55              ; 0b52 92 02
	LR   A,main.curBall      ; 0b54 4b
A0b55:
	ADC                      ; 0b55 8e
	LR   A, draw.ypos        ; 0b56 42

	; Mask out the direction
	NI   %01111111           ; 0b57 21 7f

	; OR in the color
	OM                       ; 0b59 8b
	LR   draw.ypos, A        ; 0b5a 52

	; Set drawing parameters
	LI   draw.drawRect       ; 0b5b 20 80
	LR   draw.glyph, A       ; 0b5d 50

	; set ball width/height
	SETISAR 070              ; 0b5e 67 68
	LR   A,(IS)              ; 0b60 4c
	LR   draw.width, A       ; 0b61 54
	LR   draw.height, A      ; 0b62 55

	; Do not redraw if explosion flag is set (TODO: Verify)
	SETISAR explosionFlag    ; 0b63 67 6a
	CLR                      ; 0b65 70
	AS   (IS)                ; 0b66 cc
	BM   handleBall.return   ; 0b67 91 04
	
	; Redraw ball
	PI   drawBox               ; 0b69 28 08 62

ballCollision.return: ; The next function uses this to return as well
handleBall.return:
	LR   P,K                 ; 0b6c 09
	POP                      ; 0b6d 1c
;
;----------------------------

;----------------------------
; Ball-ball collision detection
; Args
;  main.curBall = $0B
;
; Locals
;  071 - ball being tested against
testBall = 071

mainBall.xpos = $1
mainBall.ypos = $2

ballCollision:
	LR   K,P                 ; 0b6e 08
	; setting up the collision loop counter
	; testBall = (delayIndex & 0x0F) + 1
	SETISAR delayIndex       ; 0b6f 65 6f
	LI   %00001111           ; 0b71 20 0f
	NS   (IS)                ; 0b73 fc
	SETISAR testBall         ; 0b74 67 69
	INC                      ; 0b76 1f
	LR   (IS),A              ; 0b77 5c

ballCollision.loopA:
	; loop_counter--
	SETISAR testBall         ; 0b78 67 69
	DS   (IS)                ; 0b7a 3c

	; if(loop_counter < 0), return
	BM   ballCollision.return; 0b7b 91 f0

	; if(loop_counter == current_ball), skip and go to next ball
	LR   A,(IS)              ; 0b7d 4c
	XS   main.curBall        ; 0b7e eb
	BZ   ballCollision.loopA ; 0b7f 84 f8

	; Check if we're in 2-player mode
	SETISARL gameMode                   ; 0b81 6d
	LIS  $1                  ; 0b82 71
	NS   (IS)                ; 0b83 fc
	; If so, skip ahead
	BNZ   A0b8c            ; 0b84 94 07
	
	; If not, check if the loop counter is a player's ball
	SETISARL testBall        ; 0b86 69
	LR   A,(IS)              ; 0b87 4c
	CI   [MAX_PLAYERS-1]     ; 0b88 25 01
	; If so, skip the current ball
	BZ   ballCollision.loopA ; 0b8a 84 ed

A0b8c:
	; r1 = xpos[current_ball]
	LI   balls.xpos          ; 0b8c 20 10
	AS   main.curBall        ; 0b8e cb
	LR   IS,A                ; 0b8f 0b
	LR   A,(IS)              ; 0b90 4c
	; mask out the upper bit (direction of xvel)
	NI   %01111111           ; 0b91 21 7f
	LR   mainBall.xpos,A     ; 0b93 51
	
	; r2 = ypos[current_ball]
	LR   A,IS                ; 0b94 0a
	AI   balls.arraySize     ; 0b95 24 0b
	LR   IS,A                ; 0b97 0b
	LR   A,(IS)              ; 0b98 4c
	; mask out the upper bits (direction of yvel?)
	NI   %00111111           ; 0b99 21 3f
	LR   mainBall.ypos,A     ; 0b9b 52
	
; Test collision along x axis
	; mainBall.xpos-testBall.xpos
	SETISAR testBall         ; 0b9c 67 69
	LI   balls.xpos          ; 0b9e 20 10
	AS   (IS)                ; 0ba0 cc
	LR   IS,A                ; 0ba1 0b
	LR   A,(IS)              ; 0ba2 4c
	NI   %01111111           ; 0ba3 21 7f
	COM                      ; 0ba5 18
	INC                      ; 0ba6 1f
	AS   mainBall.xpos       ; 0ba7 c1
	
	; save test results
	LR   J,W                 ; 0ba8 1e
	; keep results if (mainBall.xpos >= testBall.xpos)
	BP   A0bad             ; 0ba9 81 03	
	; otherwise negate the results
	COM                      ; 0bab 18
	INC                      ; 0bac 1f
	
A0bad:
	; save result from test in r1
	LR   $1,A                ; 0bad 51
	
	; branch ahead if testBall is not a player ball
	LR   A,IS                ; 0bae 0a
	CI   [balls.xpos+MAX_PLAYERS-1] ; 0baf 25 11
	BNC   A0bbd              ; 0bb1 92 0b
	
	; reuse test results from earlier
	; branch ahead if mainBall.xpos < testBall.xpos
	LR   W,J                 ; 0bb3 1d
	BM   A0bbd            ; 0bb4 91 08
				
	; Get player ball width
	LI   playerSizeMask      ; 0bb6 20 c0
	NS   main.gameSettings   ; 0bb8 fa
	SR   1                   ; 0bb9 12
	SR   1                   ; 0bba 12
	BR   A0bc0               ; 0bbb 90 04

	; or get enemy ball width
A0bbd:
	LI   enemySizeMask       ; 0bbd 20 30
	NS   main.gameSettings   ; 0bbf fa

A0bc0:
	SR   4                   ; 0bc0 14

	; r1 = +/-(mainBall.xpos - testBall.xpos) - testBall.width
	COM                      ; 0bc1 18
	INC                      ; 0bc2 1f
	AS   $1                  ; 0bc3 c1

	; if r1 is positive, no collision occured (return to beginning of loop)
	BP   ballCollision.loopA             ; 0bc4 81 b3

; Test collision on the y axis
	; do check with ypos[loop_counter] ??
	; mainBall.ypos-testBall.ypos
	LR   A,IS                ; 0bc6 0a
	AI   balls.arraySize     ; 0bc7 24 0b
	LR   IS,A                ; 0bc9 0b
	LR   A,(IS)              ; 0bca 4c
	NI   %00111111           ; 0bcb 21 3f
	COM                      ; 0bcd 18
	INC                      ; 0bce 1f
	AS   mainBall.ypos       ; 0bcf c2
	
	; save test results
	LR   J,W                 ; 0bd0 1e
	; keep results if (mainBall.ypos >= testBall.ypos)
	BP   A0bd5             ; 0bd1 81 03
	; otherwise negate the results
	COM                      ; 0bd3 18
	INC                      ; 0bd4 1f
A0bd5:
	; save result from test in r2
	LR   $2,A                ; 0bd5 52

	; branch ahead if testBall is not a player ball
	LR   A,IS                ; 0bd6 0a
	CI   [balls.ypos+MAX_PLAYERS-1]; 0bd7 25 1c
	BNC   A0be5              ; 0bd9 92 0b

	; Reuse test result from earlier (player or enemy ball?)
	LR   W,J                 ; 0bdb 1d
	BM   A0be5            ; 0bdc 91 08
	
	; Get player ball width
	LI   playerSizeMask      ; 0bde 20 c0
	NS   main.gameSettings   ; 0be0 fa
	SR   1                   ; 0be1 12
	SR   1                   ; 0be2 12
	BR   A0be8            ; 0be3 90 04
	; or get enemy ball width
A0be5:
	LI   enemySizeMask       ; 0be5 20 30
	NS   main.gameSettings   ; 0be7 fa
A0be8:
	SR   4                   ; 0be8 14
	
	; r1 = +/-(mainBall.xpos - testBall.xpos) - testBall.width
	COM                      ; 0be9 18
	INC                      ; 0bea 1f
	AS   $2                  ; 0beb c2

	; if r2 is positive, no collision occured (return to beginning of loop)
	BP   ballCollision.loopA             ; 0bec 81 8b

; -- If we got to this point, a collision has happened --
	
	; Check if the collision was with a player
	;  If so, game over
	;  Else, skip ahead
	SETISAR 071              ; 0bee 67 69
	LR   A,(IS)              ; 0bf0 4c
	CI   [MAX_PLAYERS-1]     ; 0bf1 25 01
	BNC   A0bf8              ; 0bf3 92 04
	; Game over
	JMP  gameOver               ; 0bf5 29 0e 44

A0bf8:
	; Play sound
	LI   $80                 ; 0bf8 20 80
	LR   playSound.sound,A   ; 0bfa 53
	PI   playSound           ; 0bfb 28 0c c8
	
	; RNG for random bounce trajectory
	PI   RNG.roll            ; 0bfe 28 08 c1

	; branch ahead if the ydelta from earlier is small (?)
	LR   A,$2                ; 0c01 42
	CI   $01                 ; 0c02 25 01
	BC   A0c41               ; 0c04 82 3c

; Fiddle with the x direction
	; randomize x direction of mainBall
	LI   balls.xpos          ; 0c06 20 10
	AS   main.curBall        ; 0c08 cb
	LR   IS,A                ; 0c09 0b
	LI   %10000000           ; 0c0a 20 80
	NS   RNG.regHi           ; 0c0c f6
	XS   (IS)                ; 0c0d ec
	LR   (IS),A              ; 0c0e 5c

	; save flags from the XOR operation (I don't think they're ever used)
	LR   J,W                 ; 0c0f 1e

	; randomize x direction of testBall
	SETISAR testBall         ; 0c10 67 69
	LI   balls.xpos          ; 0c12 20 10
	AS   (IS)                ; 0c14 cc
	LR   IS,A                ; 0c15 0b
	LI   %10000000           ; 0c16 20 80
	NS   RNG.regLo           ; 0c18 f7
	AS   (IS)                ; 0c19 cc
	LR   (IS),A              ; 0c1a 5c
				
	; We'll be using this later to adjust the velocity
	LI   $44                 ; 0c1b 20 44
	LR   $8,A                ; 0c1d 58

	; r0 = mainBall
	LR   A, main.curBall     ; 0c1e 4b
	LR   $0,A                ; 0c1f 50

A0c20:
	; If bit 7 of gameMode is set, we mess with the velocity
	; TODO: Figure out if it is set elsewhere
	SETISAR gameMode         ; 0c20 67 6d
	CLR                      ; 0c22 70
	AS   (IS)                ; 0c23 cc
	BP   A0c29               ; 0c24 81 04
	; If so, restart loop
	JMP  ballCollision.loopA               ; 0c26 29 0b 78

; Fiddle with the velocity	
A0c29:	
	; get index to mainBall's velocity
	LR   A,$0                ; 0c29 40
	SR   1                   ; 0c2a 12
	AI   balls.velocity      ; 0c2b 24 26
	LR   IS,A                ; 0c2d 0b

	; conjure up the bitmask to extract it
	LIS  $1                  ; 0c2e 71
	NS   $0                  ; 0c2f f0
	LIS  $f                  ; 0c30 7f
	BNZ   A0c34            ; 0c31 94 02
	COM                      ; 0c33 18
A0c34:
	; save it in r3
	LR   $3,A                ; 0c34 53
	; save the other velocity bitfield in r4
	COM                      ; 0c35 18
	NS   (IS)                ; 0c36 fc
	LR   $4,A                ; 0c37 54
	; get the velocity bitfield for mainBall
	LR   A,$3                ; 0c38 43
	NS   (IS)                ; 0c39 fc
	; add r8 to it, and clean up with the bitmask
	AS   $8                  ; 0c3a c8
	NS   $3                  ; 0c3b f3
	; merge the two bitfields and save the result
	AS   $4                  ; 0c3c c4
	LR   (IS),A              ; 0c3d 5c
	; Since we had a collision, we can just return early
	JMP  ballCollision.return            ; 0c3e 29 0b 6c

; Fiddle with y direction	
A0c41:
	; r0 = testBall
	; isar = balls.ypos[testBall]
	SETISAR testBall         ; 0c41 67 69
	LR   A,(IS)              ; 0c43 4c
	LR   $0,A                ; 0c44 50
	AI   balls.ypos          ; 0c45 24 1b
	LR   IS,A                ; 0c47 0b

	; Flip the y velocity of testBall
	LI   %10000000           ; 0c48 20 80
	XS   (IS)                ; 0c4a ec
	LR   (IS),A              ; 0c4b 5c
	LR   J,W                 ; 0c4c 1e ; save flags

	; isar = mainBall
	LI   balls.ypos          ; 0c4d 20 1b
	AS   main.curBall        ; 0c4f cb
	LR   IS,A                ; 0c50 0b

	; balls.ypos[mainBall]
	LR   A,(IS)              ; 0c51 4c
	OI   %10000000           ; 0c52 22 80

	; if testBall's y direction became 1, let mainBall's y direction become 1
	; if testBall's y direction became 0, let mainBall's y direction become 0
	;  This almost feels like a bug, but it would explain some weirdness with 
	;   how the balls bounce
	LR   W,J                 ; 0c54 1d ; restore flags
	BP   A0c59               ; 0c55 81 03
	NI   %00111111           ; 0c57 21 3f
A0c59:
	LR   (IS),A              ; 0c59 5c
	
	; We'll be using this later to adjust the velocity
	LI   $44                 ; 0c5a 20 44
	LR   $8,A                ; 0c5c 58
	; Branch always
	BR   A0c20            ; 0c5d 90 c2
; End ball-ball collision routine
;----------------------------

;----------------------------
; Set playfield bounds (for one axis)
; Args
;  r1 - ??
;  r2 - 
;  r4 -
;  r10 - ??
; Clobbers
;  r6 - via RNG call
;  r7 - via RNG call
;  ISAR[x] to ISAR[x+2]
setBounds:
	LR   K,P                 ; 0c5f 08
A0c60: ; Reroll RNG until r6 is non-zero
	PI   RNG.roll               ; 0c60 28 08 c1
	CLR                  ; 0c63 70
	AS   RNG.regHi           ; 0c64 c6
	BZ   A0c60             ; 0c65 84 fa
	
	; if(r1 == 0x58)
	;  if(RNG > 0x0B)
	;   go back and reroll
	; else if(RNG > 0x12)
	;   go back and reroll
	LR   A,$1                ; 0c67 41
	CI   $58                 ; 0c68 25 58
	LR   A, RNG.regHi                ; 0c6a 46
	BNZ   A0c71            ; 0c6b 94 05
	CI   $12                 ; 0c6d 25 12
	BR   A0c73            ; 0c6f 90 03
A0c71:
	CI   $0b                 ; 0c71 25 0b
A0c73:
	BNC   A0c60            ; 0c73 92 ec

	; do the math for the right or bottom boundary
	;  Note: the greater this number is, the more to the left or top this boundary
	;   is. (Unintuitive. Works opposite of how the top and left bounds work)
	; r4 = -(r1-(rng-1))  ??
	COM                      ; 0c75 18
	INC                      ; 0c76 1f
	INC                      ; 0c77 1f
	AS   $1                  ; 0c78 c1
	COM                      ; 0c79 18
	INC                      ; 0c7a 1f
	LR   $4,A                ; 0c7b 54
	
	; Set enemy's right or bottom boundary
	; ISAR++ = ((reg_a & 0x30) >> 4) + r4
	; Get enemy ball size
	LI   $30                 ; 0c7c 20 30
	NS   $a                  ; 0c7e fa
	SR   4                   ; 0c7f 14
	; Add it to r4
	AS   $4                  ; 0c80 c4
	LR   (IS)+,A             ; 0c81 5d
	
	; Set players's right or bottom boundary
	; ISAR++ = ((reg_a & 0xC0) >> 6) + r4
	; Get the player's ball size
	LI   $c0                 ; 0c82 20 c0
	NS   $a                  ; 0c84 fa
	SR   4                   ; 0c85 14
	SR   1                   ; 0c86 12
	SR   1                   ; 0c87 12
	; Add it to r4
	AS   $4                  ; 0c88 c4
	LR   (IS)+,A             ; 0c89 5d
	
	; Set the left or top boundary
	; ISAR++ = r6 + r2
	LR   A,$6                ; 0c8a 46
	AS   $2                  ; 0c8b c2
	LR   (IS)+,A             ; 0c8c 5d
	LR   P,K                 ; 0c8d 09
	POP                      ; 0c8e 1c
; end of set bounds function
;----------------------------
	
;----------------------------
; Screen Flash
;  Unused function - possibly an old death animation
; Args

; Locals / Clobbers
flash.timer = 9

; Constants
flash.length = $25
; Returns
;  N/A

flash: 
	LR   K,P                 ; 0c8f 08
	LI   flash.length        ; 0c90 20 25
	LR   flash.timer, A      ; 0c92 59

	; Set flash color value depending on value of o71 (who died?)
	SETISAR 071              ; 0c93 67 69
	LIS  $1                  ; 0c95 71
	NS   (IS)-               ; 0c96 fe
	LI   $80                 ; 0c97 20 80
	BZ   A0c9d             ; 0c99 84 03
	LI   $c0                 ; 0c9b 20 c0
A0c9d:          
	LR   (IS), A             ; 0c9d 5c
	LR   draw.ypos, A        ; 0c9e 52

A0c9f:          
	LR   A,(IS)              ; 0c9f 4c
A0ca0:          
	; Set ypos/color
	LR   draw.ypos, A        ; 0ca0 52
	; Make sound
	LR   A,(IS)              ; 0ca1 4c
	LR   playSound.sound,A   ; 0ca2 53
	PI   playSound           ; 0ca3 28 0c c8
	
	LISL 0                   ; 0ca6 68 ; ???
	; Set xpos to attribute column
	LI   gfx.attributeCol    ; 0ca7 20 7d
	LR   draw.xpos, A        ; 0ca9 51
	; Set width
	LIS  gfx.attributeWidth  ; 0caa 72
	LR   draw.width, A       ; 0cab 54
	; Set height
	LI   gfx.screenHeight    ; 0cac 20 40
	LR   draw.height, A      ; 0cae 55
	; Set rendering properties
	LI   draw.drawAttribute  ; 0caf 20 c0
	LR   draw.glyph, A       ; 0cb1 50
	PI   drawBox             ; 0cb2 28 08 62
	
	; Clear sound
	CLR                  ; 0cb5 70
	OUTS 5                   ; 0cb6 b5
	
	; Delay
	LIS  $b                  ; 0cb7 7b
	LR   delay.count, A      ; 0cb8 50
	PI   delay.variable      ; 0cb9 28 09 9a

	DS   flash.timer         ; 0cbc 39
	BM   flash.exit          ; 0cbd 91 08
	
	; if (timer is even)
	;  ypos/color = (ISAR)
	; else
	;  ypos/color = 0
	LIS  $1                  ; 0cbf 71
	NS   flash.timer         ; 0cc0 f9
	CLR                  ; 0cc1 70
	BZ   A0c9f             ; 0cc2 84 dc
	; Else set r2 to 0
	BR   A0ca0            ; 0cc4 90 db

flash.exit:     
	LR   P,K                 ; 0cc6 09
	POP                      ; 0cc7 1c
; end screen flash function
;----------------------------

;----------------------------
; Play ticking sound when bumping into a wall
; rb - Index of the ball (don't let players make noise?)
; r3 - Sound to be played
playSound.sound = 3

playSound:      
	; if(curBall >= MAX_PLAYERS)
	;  play the sound
	; return
	LR   A, main.curBall     ; 0cc8 4b
	CI   [MAX_PLAYERS-1]     ; 0cc9 25 01
	BC   playSound.exit      ; 0ccb 82 03
	LR   A, playSound.sound  ; 0ccd 43
	OUTS 5                   ; 0cce b5
playSound.exit:          
	POP                      ; 0ccf 1c
;----------------------------

;----------------------------	
; Init Game
initRoutine:
	SETISAR RNG.seedLo       ; 0cd0 67 6f
	; Enable data from controllers ?
	LI   $40                 ; 0cd2 20 40
	OUTS 0                   ; 0cd4 b0
	; Seed RNG from uninitialized ports
	INS  4                   ; 0cd5 a4
	LR   (IS)-,A             ; 0cd6 5e
	INS  5                   ; 0cd7 a5
	LR   (IS)-,A             ; 0cd8 5e
	; clear o73
	LISL 3                   ; 0cd9 6b
	CLR                  ; 0cda 70
	LR   (IS),A              ; 0cdb 5c
	; Clear port
	OUTS 0                   ; 0cdc b0

; Clear screen
	; Set properties
	LI   draw.drawRect        ; 0cdd 20 80
	LR   draw.glyph, A       ; 0cdf 50
	; Set x and y pos
	CLR                  ; 0ce0 70
	LR   draw.xpos, A        ; 0ce1 51
	LR   draw.ypos, A        ; 0ce2 52
	; width = screen width
	LI   gfx.screenWidth     ; 0ce3 20 80
	LR   draw.width, A       ; 0ce5 54
	; height = screen height
	LI   gfx.screenHeight    ; 0ce6 20 40
	LR   draw.height, A      ; 0ce8 55
	PI   drawBox             ; 0ce9 28 08 62

; Set row attributes
	; Set rendering properties, ypos, and color
	LI   draw.drawAttribute  ; 0cec 20 c0
	LR   draw.glyph, A       ; 0cee 50
	LR   draw.ypos, A        ; 0cef 52
	; Set width
	LIS  gfx.attributeWidth  ; 0cf0 72
	LR   draw.width, A       ; 0cf1 54
	; xpos = attribute column
	LI   gfx.attributeCol    ; 0cf2 20 7d
	LR   draw.xpos, A        ; 0cf4 51
	; Height and ypos are retained from previous write
	PI   drawBox             ; 0cf5 28 08 62

; Draw the "G?" screen
	; glyph = 'G'
	LIS  gfx.G               ; 0cf8 7a
	LR   draw.glyph, A       ; 0cf9 50
	; xpos
	LI   $30                 ; 0cfa 20 30
	LR   draw.xpos, A        ; 0cfc 51
	; ypos and color
	LI   $9b                 ; 0cfd 20 9b
	LR   draw.ypos, A        ; 0cff 52
	; width
	LIS  gfx.charWidth       ; 0d00 74
	LR   draw.width, A       ; 0d01 54
	; height
	LIS  gfx.charHeight      ; 0d02 75
	LR   draw.height, A      ; 0d03 55
	PI   drawGlyph           ; 0d04 28 08 58
	
	; glyph = '?'
	LIS  gfx.Qmark                  ; 0d07 7b
	LR   draw.glyph, A       ; 0d08 50
	; x pos
	LI   $35                 ; 0d09 20 35
	LR   draw.xpos, A        ; 0d0b 51
	PI   drawGlyph           ; 0d0c 28 08 58
	
	; returns button pressed in the accumulator
	PI   menu                ; 0d0f 28 08 f0

	; Use a table to put the number of the button pressed into the lower two
	;  bits of gameMode
	SETISAR gameMode         ; 0d12 67 6d
	SR   1                   ; 0d14 12
	; DC was set in the menu
	ADC                      ; 0d15 8e
	LM                       ; 0d16 16
	LR   (IS),A              ; 0d17 5c

; Shuffle gametype
shuffleGameType:          
	SETISAR gameMode                     ; 0d18 67 6d
	; preserve the player and game speed bits of gameMode
	LR   A,(IS)              ; 0d1a 4c
	NI   %00000011           ; 0d1b 21 03
	LR   (IS),A              ; 0d1d 5c

shuffleGameTypeReroll:
	DCI  gameModeMasks               ; 0d1e 2a 08 43
	PI   RNG.roll            ; 0d21 28 08 c1
	
	; put bits 6 and 7 of RNG into r8
	; set player ball size
	LM                       ; 0d24 16
	NS   RNG.regHi           ; 0d25 f6
	LR   $8,A                ; 0d26 58
	
	; add bits 4 and 5 of RNG to bits 6 and 7 r8
	; set enemy ball size
	; redo it no carry
	LM                       ; 0d27 16
	NS   RNG.regHi           ; 0d28 f6
	SL   1                   ; 0d29 13
	SL   1                   ; 0d2a 13
	AS   $8                  ; 0d2b c8
	BNC   shuffleGameTypeReroll              ; 0d2c 92 f1
	; this is to make sure player and ball widths do not sum to less than 4
	
	; make sure at least one of bits 2 and 3 of RNG are set
	; make sure player speed > 0
	LM                       ; 0d2e 16
	NS   RNG.regHi           ; 0d2f f6
	BZ   shuffleGameTypeReroll               ; 0d30 84 ed

	; make sure at least one of bits 0 and 1 of RNG are set
	; make sure enemy speed > 0
	LM                       ; 0d32 16
	NS   RNG.regHi           ; 0d33 f6
	BZ   shuffleGameTypeReroll               ; 0d34 84 e9

	; store the results in r10
	LR   A, RNG.regHi        ; 0d36 46
	LR   $a,A                ; 0d37 5a

	; put the upper six bits of the RNG into gameMode
	LM                       ; 0d38 16
	NS   RNG.regLo           ; 0d39 f7
	AS   (IS)                ; 0d3a cc
	LR   (IS)-,A             ; 0d3b 5e

	; DC = (lower 2 bits of r10)*2
	; I don't think this array ever gets read
	; Each array element would have been 2 bytes
	DCI  A0848               ; 0d3c 2a 08 48
	LIS  $3                  ; 0d3f 73
	NS   main.gameSettings   ; 0d40 fa
	SL   1                   ; 0d41 13
	ADC                      ; 0d42 8e
	
	; set playfield bounds for x axis
	LI   $58                 ; 0d43 20 58
	LR   $1,A                ; 0d45 51
	LI   $10                 ; 0d46 20 10
	LR   $2,A                ; 0d48 52
	SETISAR bounds.rightEnemy ; 0d49 66 68
	PI   setBounds               ; 0d4b 28 0c 5f
	
	; set playfied bounds for y axis
	LI   $38                 ; 0d4e 20 38
	LR   $1,A                ; 0d50 51
	PI   setBounds               ; 0d51 28 0c 5f

restartGame:          
	; Draw playfield
	; Set rendering properties
	LI   draw.drawRect        ; 0d54 20 80
	LR   draw.glyph, A       ; 0d56 50
	; Set x pos
	LI   $10                 ; 0d57 20 10
	LR   draw.xpos, A        ; 0d59 51
	; Set ypos and color
	AI   $80                 ; 0d5a 24 80
	LR   draw.ypos, A        ; 0d5c 52
	; Set width
	LI   $49                 ; 0d5d 20 49
	LR   draw.width, A       ; 0d5f 54
	; Set height
	LI   $29                 ; 0d60 20 29
	LR   draw.height, A      ; 0d62 55
	; Draw box
	PI   drawBox               ; 0d63 28 08 62

	; Draw inner box
	; xpos = o62
	SETISAR bounds.left      ; 0d66 66 6a
	LR   A,(IS)              ; 0d68 4c
	LR   draw.xpos, A        ; 0d69 51
	; width = -(o62 + o60)
	SETISARL bounds.rightEnemy ; 0d6a 68
	AS   (IS)                ; 0d6b cc
	COM                      ; 0d6c 18
	INC                      ; 0d6d 1f
	LR   draw.width, A       ; 0d6e 54
	
	; Add the enemy size to the width
	; r3 = (reg_a & $30) >> 4
	; width += r3
	LI   enemySizeMask       ; 0d6f 20 30
	NS   main.gameSettings   ; 0d71 fa
	SR   4                   ; 0d72 14
	LR   $3,A                ; 0d73 53
	AS   draw.width          ; 0d74 c4
	LR   draw.width, A       ; 0d75 54
	
	; set ypos (color is blank)
	SETISARL bounds.top                  ; 0d76 6d
	LR   A,(IS)              ; 0d77 4c
	LR   draw.ypos, A        ; 0d78 52
	; height = -(top - bottom) + temp // temp is enemy size
	SETISARL bounds.bottomEnemy; 0d79 6b
	AS   (IS)                ; 0d7a cc
	COM                      ; 0d7b 18
	INC                      ; 0d7c 1f
	AS   $3                  ; 0d7d c3
	LR   draw.height, A      ; 0d7e 55
	; Set rendering properties
	LI   draw.drawRect        ; 0d7f 20 80
	LR   draw.glyph, A       ; 0d81 50
	; Draw inner box
	PI   drawBox             ; 0d82 28 08 62
	
	; timer = 0
	SETISAR timer.hiByte     ; 0d85 66 6e
	CLR                  ; 0d87 70
	LR   (IS)+,A             ; 0d88 5d
	LR   (IS)+,A             ; 0d89 5d

	; spawn the player balls
	CLR                  ; 0d8a 70
startGame.spawnBalls:          
	LR   main.curBall, A     ; 0d8b 5b
	PI   spawn               ; 0d8c 28 09 c2
	LR   A, main.curBall     ; 0d8f 4b
	INC                      ; 0d90 1f
	CI   [MAX_PLAYERS-1]     ; 0d91 25 01
	BC   startGame.spawnBalls; 0d93 82 f7

	; spawn the first enemy ball
	SETISAR balls.count      ; 0d95 65 6e
	LR   (IS),A              ; 0d97 5c
	LR   main.curBall, A     ; 0d98 5b
	PI   spawn               ; 0d99 28 09 c2

	; bit 7 of o72 is the explosion flag
	SETISAR explosionFlag    ; 0d9c 67 6a
	CLR                      ; 0d9e 70
	LR   (IS),A              ; 0d9f 5c

;----------------------------
; Beginning of MAIN LOOP 
mainLoop:
	; Clear sound
	CLR                      ; 0da0 70
	OUTS 5                   ; 0da1 b5
				
	; Change delay index according to the timer
	; if (timer.hi > 10)
	;   delay index = 10
	; else
	;	delay index = timer.hi + 1
	SETISAR timer.hiByte     ; 0da2 66 6e
	LR   A,(IS)+             ; 0da4 4d
	INC                      ; 0da5 1f
	CI   [MAX_BALLS-1]       ; 0da6 25 0a
	BC   main.setDelay       ; 0da8 82 02
	LIS  [MAX_BALLS-1]       ; 0daa 7a
main.setDelay:
	SETISARU delayIndex      ; 0dab 65
	LR   (IS),A              ; 0dac 5c
	SETISARU timer.loByte    ; 0dad 66

	; Increment 16-bit BCD timer
	; timer.lo++
	LI   $01 + BCD_ADJUST    ; 0dae 20 67
	ASD  (IS)                ; 0db0 dc
	LR   (IS)-,A             ; 0db1 5e
	BNC   main.setTimerPos   ; 0db2 92 12
	; if carry, timer.hi++
	LI   $01 + BCD_ADJUST    ; 0db4 20 67
	ASD  (IS)                ; 0db6 dc
	LR   (IS)+,A             ; 0db7 5d
	; check if hundreds digit is zero
	NI   %00001111           ; 0db8 21 0f
	BNZ   main.setTimerPos   ; 0dba 94 0a
	; if so, check if tens and ones digits are zero				
	CLR                      ; 0dbc 70
	AS   (IS)                ; 0dbd cc
	BNZ   main.setTimerPos   ; 0dbe 94 06
	; if so, set the explosion flag
	SETISAR explosionFlag    ; 0dc0 67 6a
	LI   $80                 ; 0dc2 20 80
	LR   (IS),A              ; 0dc4 5c

main.setTimerPos:          
	; Display timer
	; Check if 1 or 2 player
	SETISAR gameMode         ; 0dc5 67 6d
	LIS  mode.2playerMask    ; 0dc7 71
	NS   (IS)                ; 0dc8 fc
	; Display in middle if 2 player mode
	LI   $39                 ; 0dc9 20 39
	BNZ   main.drawTimer     ; 0dcb 94 03
	; Display to left if 1 player mode
	LI   $1f                 ; 0dcd 20 1f
main.drawTimer:          
	LR   drawTimer.xpos, A   ; 0dcf 50
	; Set y pos (or color ?)
	LI   $80                 ; 0dd0 20 80
	LR   drawTimer.ypos, A   ; 0dd2 52
	; Set ISAR to LSB of score
	SETISAR timer.loByte     ; 0dd3 66 6f
	PI   drawTimer           ; 0dd5 28 0a 20

	; delay(delayIndex)
	SETISAR delayIndex       ; 0dd8 65 6f
	LR   A,(IS)              ; 0dda 4c
	LR   delay.index, A      ; 0ddb 50
	PI   delay.viaLookup     ; 0ddc 28 09 86

	; set current ball to balls.count
	SETISAR balls.count      ; 0ddf 65 6e
	LI   %00001111           ; 0de1 20 0f
	NS   (IS)+               ; 0de3 fd
	LR   main.curBall, A     ; 0de4 5b
	
	; ISAR is delayIndex
	; check if curBall >= delayIndex
	LR   A,(IS)              ; 0de5 4c
	COM                      ; 0de6 18
	INC                      ; 0de7 1f
	AS   main.curBall        ; 0de8 cb
	; branch ahead if so
	BP   main.ballLoopInit   ; 0de9 81 0d

	; curBall = delayIndex
	LR   A,(IS)              ; 0deb 4c
	LR   main.curBall, A     ; 0dec 5b
	
	PI   spawn               ; 0ded 28 09 c2
	
	; ball count = delayIndex (preserve upper nybble of ball count)
	SETISAR balls.count      ; 0df0 65 6e
	LI   %11110000           ; 0df2 20 f0
	NS   (IS)+               ; 0df4 fd
	AS   (IS)-               ; 0df5 ce
	LR   (IS),A              ; 0df6 5c
				
main.ballLoopInit:          
	SETISAR balls.count      ; 0df7 65 6e
	LI   %00001111           ; 0df9 20 0f
	NS   (IS)                ; 0dfb fc
	LR   main.curBall, A     ; 0dfc 5b
				
main.ballLoop:          
	; o70 = enemy ball size
	SETISAR 070              ; 0dfd 67 68
	LI   enemySizeMask       ; 0dff 20 30
	NS   main.gameSettings   ; 0e01 fa
	SR   4                   ; 0e02 14
	LR   (IS)+,A             ; 0e03 5d
	
	; o71 = enemy speed (TODO: verify)
	LI   enemySpeedMask      ; 0e04 20 03
	NS   main.gameSettings   ; 0e06 fa
	LR   (IS),A              ; 0e07 5c

	PI   handleBall          ; 0e08 28 0a 53
	PI   ballCollision       ; 0e0b 28 0b 6e

	DS   main.curBall        ; 0e0e 3b
	LR   A,main.curBall      ; 0e0f 4b
	CI   [MAX_PLAYERS-1]     ; 0e10 25 01
	BNC   main.ballLoop      ; 0e12 92 ea

	PI   playerHandler       ; 0e14 28 09 24

	; o70 = player ball size
	SETISAR 070              ; 0e17 67 68
	LI   playerSizeMask      ; 0e19 20 c0
	NS   main.gameSettings   ; 0e1b fa
	SR   4                   ; 0e1c 14
	SR   1                   ; 0e1d 12
	SR   1                   ; 0e1e 12
	LR   (IS)+,A             ; 0e1f 5d
	
	; o71 = player speed
	LI   playerSpeedMask     ; 0e20 20 0c
	NS   main.gameSettings   ; 0e22 fa
	SR   1                   ; 0e23 12
	SR   1                   ; 0e24 12
	LR   (IS),A              ; 0e25 5c
	
	; Handle player 1
	LI   0                   ; 0e26 20 00
	LR   main.curBall,A      ; 0e28 5b
	PI   handleBall          ; 0e29 28 0a 53
	
	; Check if were doing 2 player mode
	SETISAR gameMode         ; 0e2c 67 6d
	LIS  1                   ; 0e2e 71
	NS   (IS)                ; 0e2f fc
	BZ   main.checkExplosion ; 0e30 84 05	
	; If so handle player 2
	LR   main.curBall,A      ; 0e32 5b
	PI   handleBall          ; 0e33 28 0a 53

main.checkExplosion:
	; Loop back to beginning if explosion flag isn't set
	SETISAR explosionFlag    ; 0e36 67 6a
	CLR                      ; 0e38 70
	AS   (IS)                ; 0e39 cc
	BP   main.end            ; 0e3a 81 06
	
	; Clear explosion flag, and then explode
	CLR                      ; 0e3c 70
	LR   (IS),A              ; 0e3d 5c
	JMP  explode             ; 0e3e 29 0f 6b

main.end:          
	JMP  mainLoop               ; 0e41 29 0d a0
; end of main loop
;----------------------------

;----------------------------
; Game Over / Death Animation
; top level procedure
gameOver.spiralRadius = 046

gameOver:
	; ypos = $24, color = $80
	LI   $80 | $24 ;$a4                 ; 0e44 20 a4
	LR   draw.ypos, A        ; 0e46 52
	; spiralRadius = $14
	SETISAR gameOver.spiralRadius ; 0e47 64 6e
	LI   $14                 ; 0e49 20 14
	LR   (IS),A              ; 0e4b 5c
gameOver.spiralLoop:
	PI   drawSpiral          ; 0e4c 28 0f 0a
	; spiralRadius--
	SETISAR gameOver.spiralRadius ; 0e4f 64 6e
	DS   (IS)                ; 0e51 3c
	; save flags
	LR   J,W                 ; 0e52 1e
	; color++
	; if(color == 0)
	;  color++
	; ypos = $24
	LR   A, draw.ypos        ; 0e53 42
	AI   $40                 ; 0e54 24 40
	BNC   gameOver.label1            ; 0e56 92 03
	AI   $40                 ; 0e58 24 40
gameOver.label1:
	NI   $c0                 ; 0e5a 21 c0
	AI   $24                 ; 0e5c 24 24
	LR   draw.ypos,A         ; 0e5e 52
	; restore flags
	; loop back if o46 != 0
	LR   W,J                 ; 0e5f 1d
	BNZ   gameOver.spiralLoop            ; 0e60 94 eb

	; delay.variable($0)
	CLR                  ; 0e62 70
	LR   delay.count, A      ; 0e63 50
	PI   delay.variable      ; 0e64 28 09 9a

	; Set color depending on who died
	; 1P - Red
	; 2P, player 1 - Green
	; 2P, player 2 - Blue
	SETISAR gameMode         ; 0e67 67 6d
	LIS  mode.2playerMask    ; 0e69 71
	NS   (IS)                ; 0e6a fc
	LI   $80                 ; 0e6b 20 80
	BZ   gameOver.clearSpiral; 0e6d 84 0a

	LISL 1                   ; 0e6f 69
	LIS  $1                  ; 0e70 71
	NS   (IS)                ; 0e71 fc
	LI   $C0                 ; 0e72 20 c0
	BZ   gameOver.clearSpiral; 0e74 84 03

	LI   $40                 ; 0e76 20 40

gameOver.clearSpiral:
	; Set ypos
	AI   $24                 ; 0e78 24 24
	LR   $2,A                ; 0e7a 52

	; draw spiral
	SETISAR gameOver.spiralRadius ; 0e7b 64 6e
	LI   $14                 ; 0e7d 20 14
	LR   (IS),A              ; 0e7f 5c
	PI   drawSpiral               ; 0e80 28 0f 0a

	; Delay
	LI   $28                 ; 0e83 20 28
	LR   delay.count,A       ; 0e85 50
	PI   delay.variable      ; 0e86 28 09 9a
	
	; Check if two players
	SETISAR gameMode         ; 0e89 67 6d
	LIS  mode.2playerMask    ; 0e8b 71
	NS   (IS)                ; 0e8c fc
	; If so, jump ahead
	BNZ   gameOver.2players  ; 0e8d 94 38

;----------------------------
; Game over cleanup - 1 player case
	; One player case
	; r6/r7 = timer
	SETISAR timer.hiByte     ; 0e8f 66 6e
	LR   A,(IS)+             ; 0e91 4d
	LR   $6,A                ; 0e92 56
	LR   A,(IS)              ; 0e93 4c
	LR   $7,A                ; 0e94 57
	
	; check if tempTimer.hi < hiScore.hi
	SETISAR hiScore.hiByte   ; 0e95 65 6c
	LR   A,(IS)+             ; 0e97 4d
	COM                      ; 0e98 18
	INC                      ; 0e99 1f
	AS   $6                  ; 0e9a c6
	; if so, jump ahead
	BM   gameOver.1pEnd      ; 0e9b 91 16
	; else, check if tempTimer.hi != hiScore.hi
	;  if so, replace the old high score
	BNZ   gameOver.1pHiScore ; 0e9d 94 07
	; else, check if tempTimer.lo < hiScore.lo
	LR   A,(IS)              ; 0e9f 4c
	COM                      ; 0ea0 18
	INC                      ; 0ea1 1f
	AS   $7                  ; 0ea2 c7
	; if so, jump ahead
	BM   gameOver.1pEnd      ; 0ea3 91 0e
	; else, replace the old high score

	; Draw score
gameOver.1pHiScore:
	; hiScore = tempTimer
	LR   A,$7                ; 0ea5 47
	LR   (IS)-,A             ; 0ea6 5e
	LR   A,$6                ; 0ea7 46
	LR   (IS)+,A             ; 0ea8 5d
	; Set color
	LI   $40                 ; 0ea9 20 40
	LR   drawTimer.ypos, A   ; 0eab 52
	; Set xpos
	LI   $54                 ; 0eac 20 54
	LR   drawTimer.xpos, A   ; 0eae 50
	PI   drawTimer           ; 0eaf 28 0a 20

gameOver.1pEnd:
	; Delay
	LI   $40                 ; 0eb2 20 40
	LR   delay.count, A      ; 0eb4 50
	PI   delay.variable      ; 0eb5 28 09 9a
	
	; Read controllers
	PI   readControllers     ; 0eb8 28 09 10
	
	; If controller is pushed, keep gametype
	LISL 0                   ; 0ebb 68
	CLR                      ; 0ebc 70
	AS   (IS)                ; 0ebd cc
	BM   gameOver.gotoShuffle; 0ebe 91 04
				
	JMP  restartGame               ; 0ec0 29 0d 54
; end of 1 player case
;----------------------------

gameOver.gotoShuffle:
	JMP  shuffleGameType               ; 0ec3 29 0d 18

;----------------------------
; Game over cleanup - 2 player case
gameOver.2players:
	; r6/r7 = timer
	SETISAR timer.hiByte     ; 0ec6 66 6e
	LR   A,(IS)+             ; 0ec8 4d
	LR   $6,A                ; 0ec9 56
	LR   A,(IS)              ; 0eca 4c
	LR   $7,A                ; 0ecb 57
	
	; Check who died
	SETISAR 071              ; 0ecc 67 69
	LIS  $1                  ; 0ece 71
	NS   (IS)                ; 0ecf fc
	BNZ   gameOver.2pSetParams; 0ed0 94 0b

	; Set parameters for player 2
	; set ypos (and color)
	LI   $c0                 ; 0ed2 20 c0
	LR   drawTimer.ypos,A    ; 0ed4 52
	; set xpos
	LI   $54                 ; 0ed5 20 54
	LR   drawTimer.xpos,A    ; 0ed7 50
	; player 2 hi score? (TODO: verify)
	SETISAR 074              ; 0ed8 67 6c
	BR   gameOver.2pHiScore  ; 0eda 90 09

gameOver.2pSetParams:
	; Set drawing parameters for player 1
	SETISAR hiScore.loByte         ; 0edc 65 6d
	; set ypos (or maybe color?)
	LI   $40                 ; 0ede 20 40
	LR   drawTimer.ypos,A    ; 0ee0 52
	; set xpos
	LI   $1f                 ; 0ee1 20 1f
	LR   drawTimer.xpos,A    ; 0ee3 50

gameOver.2pHiScore:
	; add the current timer to the winning player's high score
	; hiScore.lo += tempTimer.lo
	LR   A,$7                ; 0ee4 47
	AS   (IS)                ; 0ee5 cc
	LR   (IS),A              ; 0ee6 5c
	; Add zero in BCD to adjust score and check carry flag (what the heck?)
	LI   0 + BCD_ADJUST      ; 0ee7 20 66
	ASD  (IS)                ; 0ee9 dc
	LR   (IS)-,A             ; 0eea 5e
	BNC   gameOver.2pHiScoreHiByte ; 0eeb 92 05
	; Carry
	LI   1 + BCD_ADJUST      ; 0eed 20 67
	ASD  (IS)                ; 0eef dc
	LR   (IS),A              ; 0ef0 5c

gameOver.2pHiScoreHiByte:
	; hiScore.hi += tempTimer.hi
	LR   A,(IS)              ; 0ef1 4c
	AS   $6                  ; 0ef2 c6
	LR   (IS),A              ; 0ef3 5c
	; Add zero in BCD to adjust score (seriously, what the heck?)
	LI   0 + BCD_ADJUST      ; 0ef4 20 66
	ASD  (IS)                ; 0ef6 dc
	LR   (IS)+,A             ; 0ef7 5d

	PI   drawTimer           ; 0ef8 28 0a 20

	; Read controllers
	PI   readControllers               ; 0efb 28 09 10

	; If neither player is touching anything, shuffle gametype
	; Player 1
	SETISARL controller1     ; 0efe 68
	CLR                      ; 0eff 70
	AS   (IS)+               ; 0f00 cd
	BM   gameOver.gotoShuffle; 0f01 91 c1

	; Player 2
	CLR                      ; 0f03 70
	AS   (IS)                ; 0f04 cc
	BM   gameOver.gotoShuffle; 0f05 91 bd

	; Else, just restart the current game
	JMP  restartGame               ; 0f07 29 0d 54
; end of 2 player case
; end of game over procedure
;----------------------------
				
;-----------------------------
; Draw Spiral (for death animation)
; mid-level function
; 
; r1 - X pos
; r2 - Y pos
; r4 - Width
; r5 - Height

; Locals
; Note: These take the place of variables used while the game is being played!
spiral.hdiameter = 024 ; o24 - horizontal diameter
spiral.hcount = 025    ; o25 - horizontal counter
spiral.vcount = 026    ; o26 - vertical counter
spiral.vdiameter = 027 ; o27 - vertical diameter
spiral.lapcount = 036  ; o36 - spiral lap counter

drawSpiral:
	LR   K,P                 ; 0f0a 08
	; Set properties to draw a rect
	LI   draw.drawRect       ; 0f0b 20 80
	LR   draw.glyph, A       ; 0f0d 50
	
	; xpos = $34
	; Note: ypos is set before entering this function
	LI   $34                 ; 0f0e 20 34
	LR   draw.xpos, A        ; 0f10 51
	
	SETISAR spiral.hdiameter              ; 0f11 62 6c
	
	; Set width/height to 1
	LIS  $1                  ; 0f13 71
	LR   draw.width, A       ; 0f14 54
	LR   draw.height, A      ; 0f15 55
	
	; Set all spiral counters to 1 (o24, o25, o26, o27)
	LR   (IS)+,A             ; 0f16 5d ;is = o24
	LR   (IS)+,A             ; 0f17 5d ;is = o25
	LR   (IS)+,A             ; 0f18 5d ;is = o26
	LR   (IS)-,A             ; 0f19 5e ;is = o27
	
	; spiral lap counter = spiral radius
	SETISARU gameOver.spiralRadius ; 0f1a 64
	LR   A,(IS)              ; 0f1b 4c ; is = o46
	SETISARU spiral.lapcount ; 0f1c 63
	LR   (IS),A              ; 0f1d 5c ; is = o36
	
	; set ISAR
	SETISARU spiral.vcount   ; 0f1e 62
	
	; dummy arithmetic operation
	LIS  $1                  ; 0f1f 71
	SL   1                   ; 0f20 13
	; save the flags from that operation to prevent the "LR W,J" a few lines
	; down from causing the function to erroneously return early
	LR   J,W                 ; 0f21 1e ; save flags

	PI   drawBox             ; 0f22 28 08 62
drawSpiral.plotUp: ; plot up
	; ypos--
	DS   draw.ypos           ; 0f25 32
	PI   drawBox             ; 0f26 28 08 62
	; vcount-- (o26)
	DS   (IS)                ; 0f29 3c ; is = 0x16
	; loop until vcount reaches 0
	BNZ   drawSpiral.plotUp  ; 0f2a 94 fa
	
	; goto exit if o36 (spiral lap counter) is zero
	LR   W,J                 ; 0f2c 1d ; restore flags
	BZ   drawSpiral.exit     ; 0f2d 84 3b

	; vdiameter++ (o27)
	LR   A,(IS)+             ; 0f2f 4d
	LR   A,(IS)              ; 0f30 4c ; is=o27
	INC                      ; 0f31 1f
	LR   (IS)-,A             ; 0f32 5e
	; vcount = vdiameter
	LR   (IS)-,A             ; 0f33 5e ;is=o26
									   ;is=o25
drawSpiral.plotRight: ; plot right         
	; xpos++
	LR   A, draw.xpos        ; 0f34 41
	INC                      ; 0f35 1f
	LR   draw.xpos, A        ; 0f36 51
	PI   drawBox             ; 0f37 28 08 62
	; hcount-- (o25)
	DS   (IS)                ; 0f3a 3c
	; loop until hcount reaches 0
	BNZ   drawSpiral.plotRight ; 0f3b 94 f8
	
	; Clear sound
	CLR                      ; 0f3d 70
	OUTS 5                   ; 0f3e b5

	; hdiameter++ (o24)
	LR   A,(IS)-             ; 0f3f 4e ;is=o25
	LR   A,(IS)              ; 0f40 4c ;is=o24
	INC                      ; 0f41 1f
	LR   (IS)+,A             ; 0f42 5d ;is=o24
	; hcount = hdiameter
	LR   (IS)+,A             ; 0f43 5d ;is=o25
									   ;is=o26
drawSpiral.plotDown: ; plot down
	; ypos++
	LR   A, draw.ypos        ; 0f44 42
	INC                      ; 0f45 1f
	LR   draw.ypos, A        ; 0f46 52
	PI   drawBox             ; 0f47 28 08 62
	; vcount-- (o26)
	DS   (IS)                 ; 0f4a 3c
	BNZ   drawSpiral.plotDown ; 0f4b 94 f8

	; vdiameter++ (o27)
	LR   A,(IS)+             ; 0f4d 4d ;is=o26
	LR   A,(IS)              ; 0f4e 4c ;is=o27
	INC                      ; 0f4f 1f
	LR   (IS)-,A             ; 0f50 5e ;is=o27
	; vcount = vdiameter
	; o26 = o27
	LR   (IS)-,A             ; 0f51 5e ;is=o26
									   ;is=o25
drawSpiral.plotLeft: ; plot left
	; xpos--
	DS   draw.xpos           ; 0f52 31
	PI   drawBox             ; 0f53 28 08 62
	; hcount-- (o25)
	DS   (IS)                 ; 0f56 3c
	BNZ   drawSpiral.plotLeft ; 0f57 94 fa

	; hdiameter++ (o24) 
	LR   A,(IS)-             ; 0f59 4e ;is=o25
	LR   A,(IS)              ; 0f5a 4c ;is=o24
	INC                      ; 0f5b 1f
	LR   (IS)+,A             ; 0f5c 5d ;is=o24
	; hcount = hdiameter
	LR   (IS)+,A             ; 0f5d 5d ;is=o25
									   ;is=o26
	; spiral count-- (o36)
	SETISARU spiral.lapcount ; 0f5e 63
	DS   (IS)                ; 0f5f 3c 
	SETISARU spiral.vcount   ; 0f60 62
	; save flags (to be used above shortly after drawSpiral.plotUp)
	LR   J,W                 ; 0f61 1e
				
	; Play sound
	LR   A,$2                ; 0f62 42
	OUTS 5                   ; 0f63 b5
	
	BNZ  drawSpiral.plotUp   ; 0f64 94 c0
	
	; vcount--
	DS   (IS)                ; 0f66 3c ;is=o26
	BR   drawSpiral.plotUp   ; 0f67 90 bd
	
drawSpiral.exit: ; Return
	LR   P,K                 ; 0f69 09
	POP                      ; 0f6a 1c
; end drawSpiral function
;-----------------------------

;-----------------------------
; Explode every time the timer reaches 1000
; Top level procedure
; r0 = loop counter
explode.loopCounter = $0

; Constants
explode.xpos = $30
explode.ypos = $22

explode:          
	; Set xpos of all balls
	; ISAR = 0x12
	LIS  MAX_PLAYERS         ; 0f6b 72
	AI   balls.xpos          ; 0f6c 24 10
	LR   IS,A                ; 0f6e 0b

	; r0 = 9
	LIS  $9                  ; 0f6f 79
	LR   $0,A                ; 0f70 50
explode.xloop:
	; set xpos while preserving the direction of xvel
	LI   %10000000           ; 0f71 20 80
	NS   (IS)                ; 0f73 fc
	AI   explode.xpos                 ; 0f74 24 30
	LR   (IS),A              ; 0f76 5c
	; increment ISAR (did the programmer forget about the ISAR post-increment?)
	LR   A,IS                ; 0f77 0a
	INC                      ; 0f78 1f
	LR   IS,A                ; 0f79 0b
	; loop back if not zero
	DS   $0                  ; 0f7a 30
	BNZ   explode.xloop            ; 0f7b 94 f5

	; Set ypos of all balls
	; increment ISAR by 2 to skip the player balls
	LR   A,IS                ; 0f7d 0a
	AI   MAX_PLAYERS         ; 0f7e 24 02
	LR   IS,A                ; 0f80 0b
	; r0 = 9
	LIS  $9                  ; 0f81 79
	LR   $0,A                ; 0f82 50
explode.yloop:
	; set ypos while preserving the direction of yvel
	LI   %10000000           ; 0f83 20 80
	NS   (IS)                ; 0f85 fc
	AI   explode.ypos        ; 0f86 24 22
	LR   (IS),A              ; 0f88 5c
	; increment ISAR, decrement loop counter
	LR   A,IS                ; 0f89 0a
	INC                      ; 0f8a 1f
	LR   IS,A                ; 0f8b 0b
	DS   $0                  ; 0f8c 30
	; loop back if not zero
	BNZ   explode.yloop            ; 0f8d 94 f5

	; (ISAR) = reg_a, ISAR++, (ISAR) = reg_a
	; TODO: Why are we overwriting the speeds of the player balls and the first two enemies?
	LR   A,$a                ; 0f8f 4a ; is=046
	LR   (IS)+,A             ; 0f90 5d ; is=046
	LR   (IS)+,A             ; 0f91 5d ; is=047

	; Clear top bit of game mode (TODO: Find out why)
	SETISAR gameMode         ; 0f92 67 6d
	LR   A,(IS)              ; 0f94 4c
	SL   1                   ; 0f95 13
	SR   1                   ; 0f96 12
	LR   (IS),A              ; 0f97 5c

	; Exit
	JMP  mainLoop               ; 0f98 29 0d a0
; end explosion procedure
;-----------------------------
	
    db $b2 ; Unused?

	; Free space - 94 bytes!
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff

; EoF