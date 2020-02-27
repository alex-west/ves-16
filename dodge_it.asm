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

	processor f8

	include "ves.h"
	
Reset: equ $0000

;-------------------------------------------------------------------------------
; Scratchpad Registers

main.gameSettings = $A
MASK_PLAYER_SIZE  = %11000000
MASK_ENEMY_SIZE   = %00110000
MASK_PLAYER_SPEED = %00001100
MASK_ENEMY_SPEED  = %00000011

main.curBall = $B
PLAYER_1 = 0
PLAYER_2 = 1

; Indirect Registers (020-077)
;  Scratchpad registers solely accessible via indirection (using the ISAR)

; Ball Properties
;  The x and y positions are fairly straightforward. The xpos is 7 bits, and 
;   the ypos is 6 bits. Velocity is a bit more complicated.
;
;  The balls' velocity is stored in a sign-magnitude format. The sign, or
;   direction, of the balls' x and y velocities is stored in the upper bits of 
;   the x and y positions, for those respective directions. The magnitudes are
;   stored in a bitpacked array, with the information for two balls being stored
;   in one byte like so:
;
;   /-- Ball 0's x speed
;   |  /-- Ball 0's y speed
;   XX YY xx yy
;         |  \-- Ball 1's y speed
;         \-- Ball 1's x speed
;
;  ...and so on and so forth for balls 2 and 3, 4 and 5, etc.
;
; Astute observers will note that bit 6 the in y position remains unused, and 
;  the last byte of the velocity array has an unused nybble. Such waste...
balls.xpos = 020 ; Array
balls.ypos = 033 ; Array
balls.speed = 046 ; Bitpacked array

MASK_DIRECTION = %10000000
MASK_POSITION  = %01111111
MASK_YPOSITION = %00111111

MASK_SPEED  = %00001111
MASK_XSPEED = %11001100
MASK_YSPEED = %00110011

balls.arraySize = $0B ; Constant

; Player one's high score
hiScore.p1.hi = 054
hiScore.p1.lo = 055

balls.count = 056
delayIndex  = 057 ; Basically the same as balls.count

; Arena Walls
; The left and top walls work how you'd expect. However, the right and bottom
;  walls are weird. Not only do they have different values for player and enemy
;  (to account for their different sizes), but they are also negative. In other
;  words, they give distances for how far the walls are from some point 256
;  pixels away from the origin. It's weird and inexplicable
wall.rightEnemy = 060
wall.rightPlayer = 061
wall.left = 062
wall.lowerEnemy = 063
wall.lowerPlayer = 064
wall.upper = 065

; Timer
timer.hi = 066
timer.lo = 067
DIGIT_MASK = $0F

; These two registers are also used for a couple other things (TODO: Note those)
input.p1 = 070 ; Left controller
input.p2 = 071 ; Right controller

explosionFlag = 072
MASK_EXPLODE = %10000000

hiScore.p2.hi = 073
hiScore.p2.lo = 074

; Game mode
gameMode = 075
MODE_CHOICE_MASK = %00000011
MODE_SPEED_MASK = $02
MODE_2P_MASK = $01

RNG.seedHi = 076
RNG.seedLo = 077

;--------------------
; Constants
MAX_PLAYERS = 2
MAX_ENEMIES = 9
MAX_BALLS = 11

BCD_ADJUST = $66 ; This should probably be in ves.h

; Sounds
SOUND_NONE  = %00000000 ; Silence
SOUND_1kHz  = %01000000 ; 1kHz tone
SOUND_500Hz = %10000000 ; 500Hz tone
SOUND_120Hz = %11000000 ; 120Hz tone

; Graphics
; blue, green, red: for P1, P2, and enemies
BLUE  = $40
RED   = $80
GREEN = $C0

DRAW_ATTR_X = $7d
DRAW_ATTR_W = 2
DRAW_SCREEN_W = $80
DRAW_SCREEN_H = $40

CHAR_G = $A
CHAR_QMARK = $B

CHAR_WIDTH = $4
CHAR_HEIGHT = $5

;-------------------------------------------------------------------------------

	org $0800

CartridgeHeader: db $55, $2b
CartridgeEntry:  JMP init

;-------------------------------------------------------------------------------
; Graphics data
; 
; Each character takes 5 nybbles of data, split across 5 bytes. Even numbered
;  characters take the left nybble while odd numbered characters take the right.

graphicsData: ; 0805
	; 0 1
	db %01110010 ;  ███  █ 
	db %01010110 ;  █ █ ██ 
	db %01010010 ;  █ █  █ 
	db %01010010 ;  █ █  █ 
	db %01110111 ;  ███ ███
	; 2 3
	db %01110111 ;  ███ ███
	db %00010001 ;    █   █
	db %01110011 ;  ███  ██
	db %01000001 ;  █     █
	db %01110111 ;  ███ ███
	; 4 5
	db %01010111 ;  █ █ ███
	db %01010100 ;  █ █ █  
	db %01110111 ;  ███ ███
	db %00010001 ;    █   █
	db %00010111 ;    █ ███
	; 6 7
	db %01000111 ;  █   ███
	db %01000001 ;  █     █
	db %01110001 ;  ███   █
	db %01010001 ;  █ █   █
	db %01110001 ;  ███   █
	; 8 9
	db %01110111 ;  ███ ███
	db %01010101 ;  █ █ █ █
	db %01110111 ;  ███ ███
	db %01010001 ;  █ █   █
	db %01110001 ;  ███   █
	; G ?
	db %11111111 ; ████████
	db %10000001 ; █      █
	db %10110010 ; █ ██  █ 
	db %10010000 ; █  █    
	db %11110010 ; ████  █ 
	; F A
	db %01110111 ;  ███ ███
	db %01000101 ;  █   █ █
	db %01110111 ;  ███ ███
	db %01000101 ;  █   █ █
	db %01000101 ;  █   █ █
	; S T
	db %01110111 ;  ███ ███
	db %01000010 ;  █    █ 
	db %01110010 ;  ███  █ 
	db %00010010 ;    █  █ 
	db %01110010 ;  ███  █ 

;-------------------------------------------------------------------------------
; Data Tables

; Delay table A (easy)
delayTableEasy:
	db $19, $16, $13, $11, $0e, $0c, $0a, $08, $06, $03, $01

; Delay table B (pro)
delayTableHard:
	db $0b, $0a, $09, $08, $07, $06, $05, $04, $03, $02, $01

; Bitmasks used while randomizing the game mode
gameModeMasks:
	db $C0, $30, $0C, $03, $FC ; 0843 c0 30 0c 03 fc
				
; This table is referenced but never read. Based on the code that references
;  this table, it likely pertained to the enemy speeds. (Also, there is a chance
;  that the endian-ness is wrong on these.)
unusedSpeedTable:
	dw $0000, $120B, $0B06, $0201 ; 0848 00 00 12 0b 0b 06 02 01

ballColors: ; blue, green, red: for P1, P2, and enemies
	db $40, $C0, $80 ; 0850 40 c0 80
	
menuChoices:
	db $00, $01, $02, $03, $03  ; 0853 00 01 02 03 03

;-------------------------------------------------------------------------------
; draw(param, xpos, ypos, width, height)
;  Leaf function
;
; This function plots pixels to screen. It has two different entry points, which
;  make it act like two different functions.
;
; When entering via drawChar, draw.param should be set to the index of the
;  character to be drawn. Although the charset only contains 16 characters, it
;  could be expanded up to 64 without changing this function.
;
; When entering via drawBox, draw.param should be set to either DRAW_RECT or
;  DRAW_ATTRIBUTE depending on whether you're drawing a box or the attribute
;  column.
;
; The x and y coordinates are relative to the top-left corner of the screen.
;
; Despite the y position and color being mapped to different I/O ports, this
;  function expects those values to be bitpacked together. The y position takes
;  up the lower 6 bits, and the color takes up the upper 2 bits.
;
; Although this function modifies draw.xpos and draw.ypos, those variables are
;  set back to their original values upon returning from the function.
;
; == Arguments ==
draw.param  = 0 ; Drawing Parameter or Character Index
draw.xpos   = 1 ; X Position
draw.ypos   = 2 ; Y Position and Color
draw.width  = 4 ; Width
draw.height = 5 ; Width

; == Entry Point A == (for drawing a character)
drawChar: subroutine

; == Local Variables ==
.data   = 3 ; pixel data
.xcount = 6 ; horizontal counter
.ycount = 7 ; vertical counter
.temp   = 8 ; helps calculate the data counter
.color  = 8 ; color, as extracted from ypos

; == Local constants ==
DRAW_RECT      = %10000000 ; Draw a rectangle
DRAW_ATTRIBUTE = %11000000 ; Draw the attribute column

MASK_COLOR     = %11000000
MASK_SOUND     = %11000000
MASK_NO_SOUND  = %00111111

; Get the starting address of the desired character
	; DC = graphicsData + param/2 + (param/2)*4
	DCI  graphicsData        ; 0858 2a 08 05
	LR   A, draw.param       ; 085b 40
	SR   1                   ; 085c 12
	LR   .temp, A            ; 085d 58
	SL   1                   ; 085e 13
	SL   1                   ; 085f 13
	AS   .temp               ; 0860 c8
	ADC                      ; 0861 8e

; == Entry point B == (for drawing a box)
drawBox:
	; (xcount,ycount) = (width,height)
	LR   A, draw.width       ; 0862 44
	LR   .xcount, A      ; 0863 56
    LR   A, draw.height      ; 0864 45
    LR   .ycount, A      ; 0865 57

.doRowLoop:
; I/O write the ypos
	; Extract color bits from ypos
	LR   A, draw.ypos        ; 0866 42
	NI   MASK_COLOR          ; 0867 21 c0
	LR   .color, A           ; 0869 58
	
	; Mask out sound, put the ypos in .data
	LR   A, draw.ypos        ; 086a 42
	COM                      ; 086b 18
	NI   MASK_NO_SOUND       ; 086c 21 3f
	LR   .data, A            ; 086e 53
	
	; Write row to port 5, making sure to preserve the sound
	INS  5                   ; 086f a5
	NI   MASK_SOUND          ; 0870 21 c0
	AS   .data               ; 0872 c3
	OUTS 5                   ; 0873 b5

; Load the pixel data into .data
	; If either DRAW_RECT or DRAW_ATTRIBUTE is
	;  then set all of the pixels and jump ahead
	CLR                      ; 0874 70
	AS   draw.param          ; 0875 c0
	LI   %11111111           ; 0876 20 ff
	BM   .setPixelData       ; 0878 91 09
	
	; Load .data from memory
	LM                       ; 087a 16
	LR   .data, A            ; 087b 53

	; If character number is even, just use the left 4 bits
	LIS  $1                  ; 087c 71
	NS   draw.param          ; 087d f0
	BZ   .doPixelLoop        ; 087e 84 04

	; If char is odd, use the right 4 bits by shifting them into place
	LR   A, .data            ; 0880 43
	SL   4                   ; 0881 15	
.setPixelData:
	LR   .data, A            ; 0882 53

; I/O write the xpos
.doPixelLoop:
	LR   A, draw.xpos        ; 0883 41
	COM                      ; 0884 18
	OUTS 4                   ; 0885 b4

; I/O write the color
	; if MSB of .data is 1, draw that color
	; if MSB of .data is 0, draw the BG color
	CLR                      ; 0886 70
	AS   .data               ; 0887 c3
	LR   A, .color           ; 0888 48
	BM   .setColor           ; 0889 91 02
	LIS 0                    ; 088b 70
.setColor:
	COM                      ; 088c 18
	NI   MASK_COLOR          ; 088d 21 c0
	OUTS 1                   ; 088f b1
	
; Iterate on to the next data bit, making sure to pad with 1
	; .data = (.data << 1) + 1
	LR   A, .data            ; 0890 43
	SL   1                   ; 0891 13
	INC                      ; 0892 1f
	LR   .data, A            ; 0893 53
	
; If DRAW_ATTRIBUTE is set, iterate to the color of the next column
	; Check if DRAW_ATTRIBUTE is set
	LR   A, draw.param       ; 0894 40
	SL   1                   ; 0895 13
	BP   .activateWrite      ; 0896 81 04
	; If so, .color = .color << 1
	LR   A, .color           ; 0898 48
	SL   1                   ; 0899 13
	LR   .color, A           ; 089a 58

; I/O write to push our color through
.activateWrite:
	LI   $60                 ; 089b 20 60
	OUTS 0                   ; 089d b0
	LI   $50                 ; 089e 20 50
	OUTS 0                   ; 08a0 b0

	; xpos++
	LR   A, draw.xpos        ; 08a1 41
	INC                      ; 08a2 1f
	LR   draw.xpos, A        ; 08a3 51
	
; Spin in place to make sure the write goes through
	LIS  4                   ; 08a4 74
.delay:
	AI   $ff                 ; 08a5 24 ff
	BNZ  .delay              ; 08a7 94 fd
	
	; xcount--, loop on to next pixel if not zero
	DS   .xcount             ; 08a9 36
	BNZ  .doPixelLoop        ; 08aa 94 d8
	
	; ypos++
	LR   A, draw.ypos        ; 08ac 42
	INC                      ; 08ad 1f
	LR   draw.ypos, A        ; 08ae 52
	
; Reset xcount and xpos
	; xcount = width
	LR   A, draw.width       ; 08af 44
	LR   .xcount,A       ; 08b0 56
	; xpos = xpos - width
	COM                      ; 08b1 18
	INC                      ; 08b2 1f
	AS   draw.xpos           ; 08b3 c1
	LR   draw.xpos, A        ; 08b4 51

	; ycount--, loop on to next row if not zero
	DS   .ycount             ; 08b5 37
	BNZ  .doRowLoop          ; 08b6 94 af
	
; Reset ypos
	; ypos = ypos - height
	LR   A, draw.height      ; 08b8 45
	COM                      ; 08b9 18
	INC                      ; 08ba 1f
	AS   draw.ypos           ; 08bb c2
	LR   draw.ypos, A        ; 08bc 52
	
; Clear I/O ports
	CLR                      ; 08bd 70
	OUTS 1                   ; 08be b1
	OUTS 0                   ; 08bf b0
	
	POP                      ; 08c0 1c

; end draw()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; rand()
;  Leaf Function
;
; Random number generator. I am uncertain how random this is, or what the
;  mathematical basis is behind it.

; == Arguments ==
; None

; == Returns ==
RNG.regHi = $6
RNG.regLo = $7

; == Entry Point ==
rand: subroutine

; == Local Variable ==
.tempISAR = 8

; save ISAR to a temp register
	LR   A,IS                ; 08c1 0a
	LR   .tempISAR, A; 08c2 58
	
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
	LR   A, .tempISAR        ; 08ed 48
	LR   IS,A                ; 08ee 0b

	; Return
	POP                      ; 08ef 1c
; end of rand()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; menu()
;  Mid-Level Function
;
; Returns the menu button you pressed.
;
; Note that drawing "G?" is handled by main()

; == Return ==
menu.buttons = 0

; == Entry Point ==
menu: subroutine

; == Locals ==
.waitTimerHi = 2
.waitTimerLo = 1
; Wait time is 10 seconds, according to the manual.
.WAIT_TIME = $af00
.DEFAULT_MODE = $1

	LR   K,P                 ; 08f0 08

	; set lower byte of .waitTimer
	LIS  [<.WAIT_TIME]       ; 08f1 70
	LR   .waitTimerLo,A      ; 08f2 51

	; clear console buttons, load default state
	OUTS 0                   ; 08f3 b0
	INS  0                   ; 08f4 a0
	LR   menu.buttons, A     ; 08f5 50

	; set upper byte of .waitTimer
	LI   [>.WAIT_TIME]       ; 08f6 20 af
	LR   .waitTimerHi, A     ; 08f8 52
	
.pollInputLoop:
	PI   rand                ; 08f9 28 08 c1
	
	; Set DC (to be used after this function in main)
	DCI  menuChoices         ; 08fc 2a 08 53

	; Read console buttons
	CLR                      ; 08ff 70
	OUTS 0                   ; 0900 b0
	INS  0                   ; 0901 a0

	; Check if different from last time they were read
	XS   menu.buttons        ; 0902 e0
	; if not, decrement .waitTimer
	BZ   .wait               ; 0903 84 03

	; Return after 10 seconds or a choice is made
.exit:
	LR   menu.buttons,A      ; 0905 50
	PK                       ; 0906 0c

	; Wait for a choice for 10 seconds
.wait:
	DS   .waitTimerLo        ; 0907 31
	BNZ  .pollInputLoop      ; 0908 94 f0
	DS   .waitTimerHi        ; 090a 32
	BNZ  .pollInputLoop      ; 090b 94 ed

	; Default to game mode 1 (1 player, easy)
	LIS  .DEFAULT_MODE       ; 090d 71

	; Return
	BR   .exit               ; 090e 90 f6
; end menu()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; readInput()
;  Leaf Function
;
; Reads input from the hand controllers, and twiddles the RNG a bit (if no
;  inputs are detected (?)).
;
; Note: To enable data reads from the controllers, bit 6 of I/O port 0 needs to
;  be set to 1. This is done in draw(), meaning that it doesn't need to be done
;  here (although it might have been better practice to do so).
;
; == Arguments ==
;  None
; == Returns ==
;  input.p1 = 070
;  input.p2 = 071
; == Locals ==
;  None

; == Entry Point ==
readInput: subroutine
	SETISAR input.p1         ; 0910 67 68
	
	; Clear I/O ports
	CLR                      ; 0912 70
	OUTS 1                   ; 0913 b1
	OUTS 4                   ; 0914 b4
		
	; Read left controller from I/O port 1
	INS  1                   ; 0915 a1
	LR   (IS)+,A             ; 0916 5d
	
	; Read right controller from I/O port 2
	INS  4                   ; 0917 a4
	LR   (IS)-,A             ; 0918 5e
	
	; if(-(input.p1 + input.p2) == 0) then exit
	AS   (IS)                ; 0919 cc
	INC                      ; 091a 1f
	COM                      ; 091b 18
	BZ   .exit               ; 091c 84 06
	
	; else, twiddle with the RNG
	SETISARL RNG.seedLo     ; 091e 6f
	; RNG.lo = RNG.lo + 1
	LIS  $1                  ; 091f 71
	AS   (IS)                ; 0920 cc
	LR   (IS)-,A             ; 0921 5e
	; RNG.hi--
	DS   (IS)                ; 0922 3c

.exit:
	POP                      ; 0923 1c
; end of readInput()
;-------------------------------------------------------------------------------
	
;-------------------------------------------------------------------------------
; doPlayers()
;  Mid-Level Function
;
; This function takes the controller inputs sets the speed and direction of each
;  player's ball accordingly. Player speed is taken from main.gameSettings. The 
;  results are then save to the xpos, ypos, and speed arrays in the scratchpad.
;
; The order in which the players are processed is done randomly.
;
; In the case of L/R or U/D conflicts, right takes precedence over left and down
;  over up.
;
; This function does not handle drawing the players.

; == Entry Point ==
doPlayers: subroutine

; == Locals ==
.speed = $0
.xpos = $1
.ypos = $2
.loopCount = $8

	LR   K,P                 ; 0924 08
	
	; Read input from hand controllers
	PI   readInput           ; 0925 28 09 10
	
; Randomize which player is processed first
	; if LSB of RNG is set
	;  curBall = player 1
	; else
	;  curBall = player 2
	SETISAR RNG.seedLo       ; 0928 67 6f
	LIS  PLAYER_2            ; 092a 71
	NS   (IS)                ; 092b fc
	LIS  PLAYER_1            ; 092c 70
	BNZ  .setPlayer          ; 092d 94 02
	LIS  PLAYER_2            ; 092f 71
.setPlayer:
	LR   main.curBall,A      ; 0930 5b

	; .loopCount = 2
	LIS  MAX_PLAYERS         ; 0931 72
	LR   .loopCount,A        ; 0932 58

; start loop
.playerLoop:
	; speed = 0 (so we don't move if nothing is pressed)
	CLR                      ; 0933 70
	LR   .speed,A            ; 0934 50

	; .xpos = xpos[curBall]
	LR   A,main.curBall      ; 0935 4b
	AI   balls.xpos          ; 0936 24 10
	LR   IS,A                ; 0938 0b
	LR   A,(IS)              ; 0939 4c
	LR   .xpos,A             ; 093a 51

	; .ypos = ypos[curBall]
	LR   A,IS                ; 093b 0a
	AI   balls.arraySize     ; 093c 24 0b
	LR   IS,A                ; 093e 0b
	LR   A,(IS)              ; 093f 4c
	LR   $2,A                ; 0940 52

	; set ISAR to match the current player's controller
	SETISARU RNG.seedLo      ; 0941 67
	LIS  PLAYER_2            ; 0942 71
	NS   main.curBall        ; 0943 fb
	SETISARL input.p2        ; 0944 69
	BNZ  .checkRight         ; 0945 94 02
	SETISARL input.p1        ; 0947 68

; Check if right is pressed
.checkRight:
	LIS  CONTROL_RIGHT       ; 0948 71
	NS   (IS)                ; 0949 fc
	BNZ  .checkLeft          ; 094a 94 06

	; If so, set x direction to right
	LR   A,.xpos             ; 094c 41
	NI   MASK_POSITION      ; 094d 21 7f
	BR   .setXspeed          ; 094f 90 08

; Check if left is pressed
.checkLeft:
	LIS  CONTROL_LEFT        ; 0951 72
	NS   (IS)                ; 0952 fc
	BNZ  .checkDown          ; 0953 94 08

	; If so, set x direction to left
	LR   A,.xpos             ; 0955 41
	OI   MASK_DIRECTION      ; 0956 22 80

.setXspeed:
	; Apply the direction to .xpos
	LR   .xpos,A             ; 0958 51
	; xspeed = gameSettings.playerSpeed
	LIS  MASK_PLAYER_SPEED   ; 0959 7c
	NS   main.gameSettings   ; 095a fa
	LR   .speed,A            ; 095b 50

; Check if down is pressed
.checkDown:
	LIS  CONTROL_BACKWARD    ; 095c 74
	NS   (IS)                ; 095d fc
	BNZ  .checkUp            ; 095e 94 06

	; If so, set y direction to down
	LR   A,.ypos             ; 0960 42
	NI   MASK_YPOSITION      ; 0961 21 3f
	BR   .setYspeed          ; 0963 90 08
	
; Check if up is pressed
.checkUp:
	LIS  CONTROL_FORWARD     ; 0965 78
	NS   (IS)                ; 0966 fc
	BNZ  .prepSaveBall       ; 0967 94 0b

	; If so, set y direction to up
	LR   A,.ypos             ; 0969 42
	OI   MASK_DIRECTION      ; 096a 22 80

.setYspeed:
	; Apply the direction to .ypos
	LR   .ypos,A             ; 096c 52
	; yspeed = gameSettings.playerSpeed
	LIS  MASK_PLAYER_SPEED   ; 096d 7c
	NS   main.gameSettings   ; 096e fa
	SR   1                   ; 096f 12
	SR   1                   ; 0970 12
	AS   .speed              ; 0971 c0
	LR   .speed,A            ; 0972 50

; Copy the speed to the other nybble
.prepSaveBall:
	LR   A,.speed            ; 0973 40
	SL   4                   ; 0974 15
	AS   .speed              ; 0975 c0
	LR   .speed,A            ; 0976 50
	; saveBall will figure out which nybble to save
	
	; Save the ball to the scratchpad arrays
	PI   saveBall            ; 0977 28 09 a2
	
; Set curBall to the other player's ball
	; (why not xor the register with a constant 1?)
	LIS  PLAYER_2            ; 097a 71
	NS   main.curBall        ; 097b fb
	LIS  PLAYER_1            ; 097c 70
	BNZ  .setNextPlayer      ; 097d 94 02
	LIS  PLAYER_2            ; 097f 71
.setNextPlayer:
	LR   main.curBall,A      ; 0980 5b
	
	; .loopCount--
	DS   .loopCount          ; 0981 38
	BNZ  .playerLoop         ; 0982 94 b0
	
	; Return
	LR   P,K                 ; 0984 09
	POP                      ; 0985 1c
; end doPlayers()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; delayByTable(index)
; delayVariable(count)
;  Leaf Functions
;
; This procedure has two different entry points, so we can consider it two
;  different functions. Alternatively, we can think of the first function as
;  calling the second function by having just continuing on to its code.
;  (Alternatively, this is just some spaghetti code.)
;
; The first sets the delay according to the game mode and the current number of
;  balls. This function is necessary to make sure that the game runs at a
;  consistent speed, since the Channel F does not have any means of
;  synchronizing itself to vblank or anything like that.
;
; The second function sets a delay according to an a count provided by the
;  callee. This is useful for providing short pauses, like during a game over.
;
; TODO: Find a rough conversion between delay.count and the amount of time this
;  function actually delays.

; == Arguments ==
; Same register, yes, but this is good syntactic sugar.
delay.index = 0 ; when entering through delayByTable 
delay.count = 0 ; when entering through delayVariable

; == Entry Point A ==
delayByTable: subroutine

; == Locals ==
.tempISAR = 3

	; if(gameMode & speedMask == 0)
	;  count = delayTableEasy[index]
	; else
	;  count = delayTableHard[index]
	; Set 
	DCI  delayTableEasy      ; 0986 2a 08 2d
	
; Save the ISAR
	LR   A,IS                ; 0989 0a
	LR   .tempISAR,A         ; 098a 53
	
; Test to check the game speed
	SETISAR gameMode         ; 098b 67 6d
	LIS  MODE_SPEED_MASK     ; 098d 72
	NS   (IS)                ; 098e fc
	
; Restore the ISAR
	LR   A,.tempISAR         ; 098f 43
	LR   IS,A                ; 0990 0b
	
	; Branch ahead if playing easy
	BZ   .loadData           ; 0991 84 04
	
	; Else, set the table to hard
	DCI  delayTableHard      ; 0993 2a 08 38

; delay.count = delayTable[index]
.loadData:
	LR   A, delay.index      ; 0996 40
	ADC                      ; 0997 8e
	LM                       ; 0998 16
	LR   delay.count, A      ; 0999 50

; == Entry Point B ==
delayVariable:

; A = 0
.outerLoop:
	LIS  0                   ; 099a 70	
; A++
.innerLoop:
	INC                      ; 099b 1f
	BNZ  .innerLoop          ; 099c 94 fe
; count--
	DS   delay.count         ; 099e 30
	BNZ  .outerLoop          ; 099f 94 fa

	; Return
	POP                      ; 09a1 1c
; end of delayByTable() and delayVariable()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; saveBall(ball, speed, xpos, ypos)
;  Leaf Function
;
; Given the ball number, speed, x position, and y position in the input
;  arguements, this function saves those ball parameters into the appropriate
;  arrays in the scratchpad. This function is useful because the speed array is
;  bitpacked.

; == Arguments ==
saveBall.speed = $0
saveBall.xpos = $1
saveBall.ypos = $2
; main.curBall = $B

saveBall: subroutine

; == Local ==
.speedMask = $3

; xpos[curBall] = saveBall.xpos
	LI   balls.xpos          ; 09a2 20 10
	AS   main.curBall        ; 09a4 cb
	LR   IS,A                ; 09a5 0b
	LR   A,saveBall.xpos     ; 09a6 41
	LR   (IS),A              ; 09a7 5c
	
; ypos[curBall] = saveBall.xpos
	LR   A,IS                ; 09a8 0a
	AI   balls.arraySize     ; 09a9 24 0b
	LR   IS,A                ; 09ab 0b
	LR   A,saveBall.ypos     ; 09ac 42
	LR   (IS),A              ; 09ad 5c
	
; Calculate index and bitmask for the bitpacked velocity array
	; ISAR = balls.speed + curBall/2
	LR   A, main.curBall     ; 09ae 4b
	SR   1                   ; 09af 12
	AI   balls.speed         ; 09b0 24 26
	LR   IS,A                ; 09b2 0b
	
	; if curBall is even
	;  bitmask = %00001111
	; else 
	;  bitmask = %11110000
	LIS  $1                  ; 09b3 71
	NS   main.curBall        ; 09b4 fb
	LIS  MASK_SPEED          ; 09b5 7f
	BNZ  .setSpeedMask       ; 09b6 94 02
	COM                      ; 09b8 18
.setSpeedMask:          
	LR   .speedMask,A        ; 09b9 53

; Set curBall speed bitfield
	; Clear curBall's bitfield from the velocity[curBall/2]
	COM                      ; 09ba 18
	NS   (IS)                ; 09bb fc
	LR   (IS),A              ; 09bc 5c

	; Extract the appropriate speed bitfield from the input argument
	LR   A,saveBall.speed    ; 09bd 40
	NS   .speedMask          ; 09be f3

	; Merge the bitfields and save the result
	AS   (IS)                ; 09bf cc
	LR   (IS),A              ; 09c0 5c

	; Return
	POP                      ; 09c1 1c
; end saveBall()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; spawnBall(curBall)
;  Mid-Level Function
;
; This function spawns a single enemy or player ball.
;
; Enemy balls are given a random position in the playfield and a random 
;  direction, and then clamped to one of the four walls, with their direction
;  being set away from the wall. They are also given a non-random starting speed
;  of 1 and 1 on each axis.
; 
; Player balls are spawned in hardcoded positions in the middle of the court.

; == Arguments ==
; main.curBall = $b

; == Returns ==
; None

; == Entry Point ==
spawnBall: subroutine
	LR   K,P                 ; 09c2 08

; == Local Variables ==
.speed = $0
.xpos = $1
.ypos = $2

; == Local Constants ==
.XMIN = $10
.XMAX = $57
.YMIN = $10
.YMAX = $37
.SPEED = %01010101
.PLAYER_Y = $23
.PLAYER1_X = $33
.PLAYER2_X = $3A
	
; keep rerolling RNG until it gets an inbounds x and y position
.reroll:
	PI   rand                ; 09c3 28 08 c1

; xpos = rng.hi
	LR   A, RNG.regHi        ; 09c6 46
	CI   .XMIN               ; 09c7 25 10
	BC   .reroll             ; 09c9 82 f9
	CI   .XMAX               ; 09cb 25 57
	BNC  .reroll             ; 09cd 92 f5

	LR   .xpos,A             ; 09cf 51

; ypos = rng.lo
	LR   A, RNG.regLo        ; 09d0 47
	CI   .YMIN               ; 09d1 25 10
	BC   .reroll             ; 09d3 82 ef
	CI   .YMAX               ; 09d5 25 37
	BNC  .reroll             ; 09d7 92 eb

	LR   .ypos,A             ; 09d9 52
	
; speed = 0x55
	LI   .SPEED              ; 09da 20 55
	LR   .speed,A            ; 09dc 50
	
; Spawn the ball against one of the walls
	; use lower 2 bits of rng.hi as index to jump table
	; This is essentially a case statement
	LIS  %00000011           ; 09dd 73
	NS   RNG.regHi           ; 09de f6
	
	; jump to (jump_table + 2*A)
	DCI  .jumpTable          ; 09df 2a 09 e6
	ADC                      ; 09e2 8e
	ADC                      ; 09e3 8e
	LR   Q,DC                ; 09e4 0e
	; Jump!
	LR   P0,Q                ; 09e5 0d

.jumpTable:
	BR   .north              ; 09e6 90 07
	BR   .east               ; 09e8 90 0a
	BR   .south              ; 09ea 90 13
	BR   .west               ; 09ec 90 1c

.north:
	; ypos = 0x11
	; ydir = sount
	LI   .YMIN+1             ; 09ee 20 11
	LR   .ypos,A             ; 09f0 52
	BR   .spawnPlayers       ; 09f1 90 1a
	
.east:
	; xpos = $58 - enemy ball size
	; xdir = west
	LI   MASK_ENEMY_SIZE     ; 09f3 20 30
	NS   main.gameSettings   ; 09f5 fa
	SR   4                   ; 09f6 14
	COM                      ; 09f7 18
	INC                      ; 09f8 1f
	AI   MASK_DIRECTION|(.XMAX+1) ; 09f9 24 d8
	LR   .xpos,A             ; 09fb 51
	BR   .spawnPlayers       ; 09fc 90 0f

.south:
	; ypos = $38 - enemy ball size
	; ydir = north
	LI   MASK_ENEMY_SIZE     ; 09fe 20 30
	NS   main.gameSettings   ; 0a00 fa
	SR   4                   ; 0a01 14
	COM                      ; 0a02 18
	INC                      ; 0a03 1f
	AI   MASK_DIRECTION|(.YMAX+1) ; 0a04 24 b8
	LR   .ypos,A             ; 0a06 52
	BR   .spawnPlayers       ; 0a07 90 04

.west:
	; xpos = 0x11
	; xdir = east
	LI   .XMIN+1             ; 0a09 20 11
	LR   .xpos,A             ; 0a0b 51

.spawnPlayers:
	; exit if current ball is not a player
	LR   A, main.curBall     ; 0a0c 4b
	CI   [MAX_PLAYERS-1]     ; 0a0d 25 01
	BNC   .exit              ; 0a0f 92 0b
	
; Ignore all the above calculations and spawn the players
	; ypos = 0x23
	LI   .PLAYER_Y           ; 0a11 20 23
	LR   .ypos,A             ; 0a13 52
	; if (curBall == Player 1)
	;  xpos = 0x33
	; else xpos = 0x33 + 0x07
	LI   .PLAYER1_X          ; 0a14 20 33
	BNZ  .setPlayerXPos      ; 0a16 94 03
	AI   .PLAYER2_X-.PLAYER1_X ; 0a18 24 07
.setPlayerXPos:
	LR   .xpos,A             ; 0a1a 51

; Save xpos, ypos, and speed
.exit:
	PI   saveBall            ; 0a1b 28 09 a2

	LR   P,K                 ; 0a1e 09
	POP                      ; 0a1f 1c
; end spawnBall()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; drawTimer(int* timer, xpos, ypos)
;  Mid-Level Function
;
; Draws a 4-digit number pointed to by the ISAR. The ISAR should point to the
;  least significant byte of a big-endian word. The x and y positions specify
;  the upper-left corner of the ones digit (not the thousands digit).

; == Arguments ==
; timer = ISAR
drawTimer.xpos = 0
drawTimer.ypos = 2 ; and color

drawTimer:          
	LR   K,P                 ; 0a20 08
	
; == Local Constants ==
.Y_OFFSET = $0A
.X_DELTA  = <[-5]
	
; Draw ones digit
	; Load xpos
	LR   A, drawTimer.xpos   ; 0a21 40
	LR   draw.xpos, A        ; 0a22 51
	; Adjust ypos
	LI   .Y_OFFSET           ; 0a23 20 0a
	AS   drawTimer.ypos      ; 0a25 c2
	LR   draw.ypos, A        ; 0a26 52
	; Set character
	LI   DIGIT_MASK          ; 0a27 20 0f
	NS   (IS)                ; 0a29 fc
	LR   draw.param, A       ; 0a2a 50
	; Width
	LIS  CHAR_WIDTH          ; 0a2b 74
	LR   draw.width, A       ; 0a2c 54
	; Height
	LIS  CHAR_HEIGHT         ; 0a2d 75
	LR   draw.height, A      ; 0a2e 55

	PI   drawChar            ; 0a2f 28 08 58
	
; Draw tens digit
	; Set character
	LR   A,(IS)-             ; 0a32 4e
	SR   4                   ; 0a33 14
	LR   draw.param, A       ; 0a34 50
	; xpos -= xdelta
	LI   .X_DELTA            ; 0a35 20 fb
	AS   draw.xpos           ; 0a37 c1
	LR   draw.xpos, A        ; 0a38 51
	
	PI   drawChar            ; 0a39 28 08 58
	
; Draw hundreds digit
	; Set character
	LR   A,(IS)              ; 0a3c 4c
	NI   DIGIT_MASK          ; 0a3d 21 0f
	LR   draw.param, A       ; 0a3f 50
	; xpos -= xdelta
	LI   .X_DELTA           ; 0a40 20 fb
	AS   draw.xpos           ; 0a42 c1
	LR   draw.xpos, A        ; 0a43 51

	PI   drawChar            ; 0a44 28 08 58
	
; Draw thousands digit
	; Set character
	LR   A,(IS)              ; 0a47 4c
	SR   4                   ; 0a48 14
	LR   draw.param, A       ; 0a49 50
	; xpos -= xdelta
	LI   .X_DELTA            ; 0a4a 20 fb
	AS   draw.xpos           ; 0a4c c1
	LR   draw.xpos, A        ; 0a4d 51

	PI   drawChar            ; 0a4e 28 08 58

	; Exit
	LR   P,K                 ; 0a51 09
	POP                      ; 0a52 1c
; end of drawTimer()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; doBall()
;  Mid-Level Function
;
; This function:
; - Undraws the ball
; - Moves the ball according its velocity
; - Checks if the ball has collided with a wall
; - Saves the changes the ball's velocity
; - Redraws the ball (if the explosion flag is not set)
;
; Since this is such a long function (relative to the rest of the functions in 
;  this game), these parts of the function will be given nice, labeled dividers.
;  Also, the local variables for each part of the function will be declared at
;  the start of each part of the function.

; == Arguments ==
doBall.size = 070
doBall.speed = 071
; main.curBall = $b

doBall: subroutine
	LR   K,P                 ; 0a53 08

; -- Undraw the ball -----------------------------------------------------------
.tempYpos = $9

	; Load xpos
	LI   balls.xpos          ; 0a54 20 10
	AS   main.curBall        ; 0a56 cb
	LR   IS,A                ; 0a57 0b
	LR   A,(IS)              ; 0a58 4c
	LR   draw.xpos, A        ; 0a59 51

	; Load ypos
	LR   A,IS                ; 0a5a 0a
	AI   balls.arraySize     ; 0a5b 24 0b
	LR   IS,A                ; 0a5d 0b
	LR   A,(IS)              ; 0a5e 4c

	; Store temp ypos
	LR   .tempYpos,A         ; 0a5f 59

	; Mask out the color bits from ypos
	NI   MASK_YPOSITION      ; 0a60 21 3f
	LR   draw.ypos, A        ; 0a62 52

	; Load ball size
	SETISAR doBall.size      ; 0a63 67 68
	LR   A,(IS)              ; 0a65 4c
	LR   draw.width, A       ; 0a66 54
	LR   draw.height, A      ; 0a67 55

	; Set parameter
	LI   DRAW_RECT           ; 0a68 20 80
	LR   draw.param, A       ; 0a6a 50

	; Undraw ball
	PI   drawBox             ; 0a6b 28 08 62

	; Reload ypos from temp
	LR   A,.tempYpos         ; 0a6e 49
	LR   draw.ypos, A        ; 0a6f 52

; -- Apply x and y velocities to the ball --------------------------------------
.xpos = $1
.ypos = $2

.tempSpeed = $3
.speedMask = $6

; Get bitpacked velocity
	; ISAR = balls.speed[curBall/2]
	LR   A, main.curBall     ; 0a70 4b
	SR   1                   ; 0a71 12
	AI   balls.speed         ; 0a72 24 26
	LR   IS,A                ; 0a74 0b
				
	; if (index is odd)
	;  speedMask = $0F
	; else
	;  speedMask = $F0
	LIS  $1                  ; 0a75 71
	NS   main.curBall        ; 0a76 fb
	LIS  MASK_SPEED          ; 0a77 7f
	BNZ  .setSpeedMask       ; 0a78 94 02
	COM                      ; 0a7a 18
.setSpeedMask:          
	LR   .speedMask,A        ; 0a7b 56
	
	; Load the other ball's speed nybble
	; Note: This is never read.
	COM                      ; 0a7c 18
	NS   (IS)                ; 0a7d fc
	LR   $0,A                ; 0a7e 50
	
	; Load this ball's speed nybble
	LR   A,.speedMask        ; 0a7f 46
	NS   (IS)                ; 0a80 fc
	LR   .tempSpeed,A        ; 0a81 53
	; Shift right by 4 and save the result if non-zero
	SR   4                   ; 0a82 14
	BZ   .applyVelocity      ; 0a83 84 02
	LR   .tempSpeed,A        ; 0a85 53

; Apply x velocity
.applyVelocity:
	; Test if bit 7 of xpos is set
	CLR                      ; 0a86 70
	AS   .xpos               ; 0a87 c1
	; Save result of test
	LR   J,W                 ; 0a88 1e
	
	; Load xspeed to A
	LR   A,.tempSpeed        ; 0a89 43
	SR   1                   ; 0a8a 12
	SR   1                   ; 0a8b 12
	
	; If bit 7 of xpos wasn't set, branch ahead
	LR   W,J                 ; 0a8c 1d
	BP   .addXVelocity       ; 0a8d 81 03
	
	; Else, negate the xspeed
	COM                      ; 0a8f 18
	INC                      ; 0a90 1f
.addXVelocity:
	; xpos = xpos +/- xspeed
	AS   .xpos               ; 0a91 c1
	LR   .xpos,A             ; 0a92 51

; Apply y velocity
	; Test if bit 7 of ypos is set
	CLR                      ; 0a93 70
	AS   .ypos               ; 0a94 c2
	; Save result of test
	LR   J,W                 ; 0a95 1e
	
	; Load yspeed to A
	LIS  %00000011           ; 0a96 73
	NS   .tempSpeed          ; 0a97 f3
	
	; If bit 7 of ypos wasn't set, branch ahead
	LR   W,J                 ; 0a98 1d
	BP   .addYVelocity       ; 0a99 81 03
	
	; Else, negate yspeed
	COM                      ; 0a9b 18
	INC                      ; 0a9c 1f
.addYVelocity:
	; ypos = ypos +/- yspeed
	AS   .ypos               ; 0a9d c2
	LR   .ypos,A             ; 0a9e 52

; -- Ball/Wall collision detection ---------------------------------------------
.bounceSpeed = $0 ; Speed imparted by bouncing off the walls
.rightBound  = $4
.lowerBound  = $5

; Get player or enemy right bound, depending on curBall
	SETISAR wall.rightEnemy  ; 0a9f 66 68
	LR   A, main.curBall     ; 0aa1 4b
	CI   [MAX_PLAYERS-1]     ; 0aa2 25 01
	BNC   .setRightBound     ; 0aa4 92 02
	SETISARL wall.rightPlayer; 0aa6 69
.setRightBound:          
	LR   A,(IS)              ; 0aa7 4c
	LR   .rightBound,A       ; 0aa8 54

; Likewise, get lower bound
	; .lowerBound = (ISAR+3)
	LR   A,IS                ; 0aa9 0a
	AI   3                   ; 0aaa 24 03
	LR   IS,A                ; 0aac 0b
	LR   A,(IS)              ; 0aad 4c
	LR   .lowerBound,A       ; 0aae 55

; -- Check collision with left and right walls --
	; Clear .bounceSpeed
	CLR                      ; 0aaf 70
	LR   .bounceSpeed,A      ; 0ab0 50

; Check collision with right wall
	; If ball is going leftward, branch ahead
	AS   .xpos               ; 0ab1 c1
	BM   .checkLeftWall      ; 0ab2 91 18
	; Branch if (xpos + rightBound < 256)
	AS   .rightBound         ; 0ab4 c4
	BNC   .checkBottomWall   ; 0ab5 92 29
	
; We have collided with the right wall
	; Clamp position to right wall and set direction to left
	LR   A,.rightBound       ; 0ab7 44
	COM                      ; 0ab8 18
	INC                      ; 0ab9 1f
	AI   MASK_DIRECTION      ; 0aba 24 80
	LR   .xpos,A             ; 0abc 51
	
	; Play sound for hitting wall
	LI   SOUND_1kHz          ; 0abd 20 40
	LR   playSound.sound,A   ; 0abf 53
	PI   playSound           ; 0ac0 28 0c c8

.setXSpeed:
	; .bounceSpeed.x = doBall.speed
	SETISAR doBall.speed     ; 0ac3 67 69
	LR   A,(IS)              ; 0ac5 4c
	SL   1                   ; 0ac6 13
	SL   1                   ; 0ac7 13
	LR   .bounceSpeed,A      ; 0ac8 50
	BR   .checkBottomWall    ; 0ac9 90 15

; Check if colliding with left wall
.checkLeftWall:
	; Mask out the directional bit
	LR   A,.xpos             ; 0acb 41
	NI   MASK_POSITION      ; 0acc 21 7f
	
	; branch ahead if(leftBound < xpos)
	COM                      ; 0ace 18
	INC                      ; 0acf 1f
	SETISAR wall.left        ; 0ad0 66 6a
	AS   (IS)                ; 0ad2 cc
	BNC  .checkBottomWall    ; 0ad3 92 0b
	
	; Clamp position to left wall and set direction to the right
	LR   A,(IS)              ; 0ad5 4c
	LR   .xpos,A             ; 0ad6 51
	
	; Play sound for hitting wall
	LI   SOUND_1kHz          ; 0ad7 20 40
	LR   playSound.sound,A   ; 0ad9 53
	PI   playSound           ; 0ada 28 0c c8
	
	BR   .setXSpeed          ; 0add 90 e5

; -- Check collision with top and bottom walls --
.checkBottomWall:
	CLR                      ; 0adf 70
	; If ball is moving upwards, branch ahead
	AS   .ypos               ; 0ae0 c2
	BM   .checkTopWall       ; 0ae1 91 19
	; Apply bitmask
	NI   MASK_YPOSITION      ; 0ae3 21 3f
	; Branch if ypos + lowerBound < 256
	AS   .lowerBound         ; 0ae5 c5
	BNC  .applySpeedChanges  ; 0ae6 92 27
	
; We have collided with the lower wall
	; Clamp position to the lower wall and set the direction to up
	LR   A,.lowerBound       ; 0ae8 45
	COM                      ; 0ae9 18
	INC                      ; 0aea 1f
	AI   MASK_DIRECTION      ; 0aeb 24 80
	LR   draw.ypos,A         ; 0aed 52
	
	; Play sound for hitting wall
	LI   SOUND_1kHz          ; 0aee 20 40
	LR   playSound.sound,A   ; 0af0 53
	PI   playSound           ; 0af1 28 0c c8

; Set y speed
.setYSpeed:
	; yspeed = doBall.speed
	SETISAR doBall.speed     ; 0af4 67 69
	LR   A,(IS)              ; 0af6 4c
	AS   .bounceSpeed        ; 0af7 c0
	LR   .bounceSpeed,A      ; 0af8 50
	BR   .applySpeedChanges  ; 0af9 90 14

; Check if colliding with top wall
.checkTopWall:
	SETISARU wall.upper      ; 0afb 66
	NI   MASK_YPOSITION      ; 0afc 21 3f
	; branch ahead if(topBound < ypos)
	COM                      ; 0afe 18
	INC                      ; 0aff 1f
	SETISARL wall.upper      ; 0b00 6d
	AS   (IS)                ; 0b01 cc
	BNC   .applySpeedChanges ; 0b02 92 0b
	
; We have collided with the top wall
	; Clamp position to top wall and set direction downwards
	LR   A,(IS)              ; 0b04 4c
	LR   draw.ypos,A         ; 0b05 52

	; Play sound for hitting wall	
	LI   SOUND_1kHz          ; 0b06 20 40
	LR   playSound.sound,A   ; 0b08 53
	PI   playSound           ; 0b09 28 0c c8
	
	BR   .setYSpeed          ; 0b0c 90 e7

; -- Apply velocity changes from wall bounces ----------------------------------
; Variables pertaining to curBall
.thisSpeed    = $5
.thisBitmask  = $7
; Variables pertaining to the ball that shares curBall's speed byte
.otherSpeed   = $4
.otherBitmask = $6

.applySpeedChanges:
	; Copy lower nybble to upper nybble
	LR   A,.bounceSpeed      ; 0b0e 40
	SL   4                   ; 0b0f 15
	AS   .bounceSpeed        ; 0b10 c0
	LR   .bounceSpeed,A      ; 0b11 50

	; ISAR = index of the speed byte
	LR   A,main.curBall      ; 0b12 4b
	SR   1                   ; 0b13 12
	AI   balls.speed         ; 0b14 24 26
	LR   IS,A                ; 0b16 0b

	; Set the bitmask for the appropriate nybble
	LIS  $1                  ; 0b17 71
	NS   main.curBall        ; 0b18 fb
	LIS  MASK_SPEED          ; 0b19 7f
	BNZ  .setSpeedMaskAgain  ; 0b1a 94 02
	COM                      ; 0b1c 18
.setSpeedMaskAgain:
	LR   .thisBitmask, A     ; 0b1d 57

	; Set the bitmask for the other ball's speed nybble 
	COM                      ; 0b1e 18
	LR   .otherBitmask,A     ; 0b1f 56
	; Save other ball's speed nybble
	NS   (IS)                ; 0b20 fc
	LR   .otherSpeed,A       ; 0b21 54

	; Apply the bitmask to get our speed from memory
	LR   A,.thisBitmask      ; 0b22 47
	NS   (IS)                ; 0b23 fc
	LR   .thisSpeed,A        ; 0b24 55

; Apply y axis bounce
	; Branch ahead if .bounceSpeed.y == 0
	LI   MASK_YSPEED         ; 0b25 20 33
	NS   .bounceSpeed        ; 0b27 f0
	BZ   .saveXAxisBounce    ; 0b28 84 0c

	; Mask out yspeed from thisSpeed
	LI   MASK_XSPEED         ; 0b2a 20 cc
	NS   .thisBitmask        ; 0b2c f7
	NS   .thisSpeed          ; 0b2d f5
	LR   .thisSpeed,A        ; 0b2e 55
	
	; .thisSpeed.y = .bounceSpeed.y
	LI   MASK_YSPEED         ; 0b2f 20 33
	NS   .bounceSpeed        ; 0b31 f0
	AS   .thisSpeed          ; 0b32 c5
	NS   .thisBitmask        ; 0b33 f7
	LR   .thisSpeed,A        ; 0b34 55

; Apply x axis bounce
.saveXAxisBounce:
	; Branch ahead if .bounceSpeed.x == 0
	LI   MASK_XSPEED         ; 0b35 20 cc
	NS   .bounceSpeed        ; 0b37 f0
	BZ   .prepSaveBall       ; 0b38 84 0c
				
	; Mask out xspeed from thisSpeed
 	LI   MASK_YSPEED         ; 0b3a 20 33
	NS   .thisBitmask        ; 0b3c f7
	NS   .thisSpeed          ; 0b3d f5
	LR   .thisSpeed,A        ; 0b3e 55

	; .thisSpeed.x = .bounceSpeed.x
	LI   MASK_XSPEED         ; 0b3f 20 cc
	NS   .bounceSpeed        ; 0b41 f0
	AS   .thisSpeed          ; 0b42 c5
	NS   .thisBitmask        ; 0b43 f7
	LR   .thisSpeed,A        ; 0b44 55

; Prepare to save ball to array
.prepSaveBall:
	; Merge the nybbles back together
	LR   A,.thisSpeed        ; 0b45 45
	AS   .otherSpeed         ; 0b46 c4

	; Set speed for saveBall
	LR   saveBall.speed,A    ; 0b47 50

	; It is finished... we can save the results
	PI   saveBall            ; 0b48 28 09 a2
	
; -- Redraw the ball -----------------------------------------------------------
	; if(curball <=1)
	;  color = ballColors[curBall]
	; else
	;  color = ballColors[2]
	DCI  ballColors          ; 0b4b 2a 08 50
	LR   A,main.curBall      ; 0b4e 4b
	CI   [MAX_PLAYERS-1]     ; 0b4f 25 01
	LIS  2                   ; 0b51 72
	BNC   .setColor          ; 0b52 92 02
	LR   A,main.curBall      ; 0b54 4b
.setColor:
	ADC                      ; 0b55 8e
	LR   A, draw.ypos        ; 0b56 42

	; Mask out the direction
	NI   MASK_POSITION      ; 0b57 21 7f

	; OR in the color
	OM                       ; 0b59 8b
	LR   draw.ypos, A        ; 0b5a 52

	; Set drawing parameters
	LI   DRAW_RECT           ; 0b5b 20 80
	LR   draw.param, A       ; 0b5d 50

	; Set ball width/height
	SETISAR doBall.size      ; 0b5e 67 68
	LR   A,(IS)              ; 0b60 4c
	LR   draw.width, A       ; 0b61 54
	LR   draw.height, A      ; 0b62 55

	; Do not redraw if explosion flag is set
	SETISAR explosionFlag    ; 0b63 67 6a
	CLR                      ; 0b65 70
	AS   (IS)                ; 0b66 cc
	BM   .return             ; 0b67 91 04

	; Redraw ball
	PI   drawBox             ; 0b69 28 08 62

collision.return: ; The next function uses this to return as well
.return:
	LR   P,K                 ; 0b6c 09
	POP                      ; 0b6d 1c
; end doBall()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; collision()
;
; Performs ball-ball collision detection.
;
; This function:
; - Sets up the loop
; - Tests collision along the x axis
; - Tests collision along the y axis
; - Jumps to game over
; - Plays bumping sound
; - Fiddles with x direction
; - Fiddles with velocity
; - Fiddles with y direction
;
; That's a lot of stuff.
;
; TODO: Write a better description here.

; == Arguments ==
; main.curBall = $b

; == Locals ==
testBall = 071
mainBall.xpos = $1
mainBall.ypos = $2

; == Entry Point ==
collision: subroutine
	LR   K,P                 ; 0b6e 08

	; setting up the collision loop counter
	; testBall = (delayIndex & 0x0F) + 1
	SETISAR delayIndex       ; 0b6f 65 6f
	LI   %00001111           ; 0b71 20 0f
	NS   (IS)                ; 0b73 fc
	SETISAR testBall         ; 0b74 67 69
	INC                      ; 0b76 1f
	LR   (IS),A              ; 0b77 5c

.testBallLoop:
	; loopCount--
	SETISAR testBall         ; 0b78 67 69
	DS   (IS)                ; 0b7a 3c

	; if(testBall < 0), return
	BM   collision.return; 0b7b 91 f0

	; if(testBall == curBall), skip and go to next ball
	LR   A,(IS)              ; 0b7d 4c
	XS   main.curBall        ; 0b7e eb
	BZ   .testBallLoop       ; 0b7f 84 f8

	; Check if we're in 2-player mode
	SETISARL gameMode        ; 0b81 6d
	LIS  $1                  ; 0b82 71
	NS   (IS)                ; 0b83 fc
	; If so, skip ahead
	BNZ  .getBallPosition    ; 0b84 94 07
	
	; If not, check if the loop counter is a player's ball
	SETISARL testBall        ; 0b86 69
	LR   A,(IS)              ; 0b87 4c
	CI   [MAX_PLAYERS-1]     ; 0b88 25 01
	; If so, skip the current ball
	BZ   .testBallLoop ; 0b8a 84 ed

.getBallPosition:
	; r1 = xpos[curBall]
	LI   balls.xpos          ; 0b8c 20 10
	AS   main.curBall        ; 0b8e cb
	LR   IS,A                ; 0b8f 0b
	LR   A,(IS)              ; 0b90 4c
	; Mask out the direction
	NI   MASK_POSITION       ; 0b91 21 7f
	LR   mainBall.xpos,A     ; 0b93 51
	
	; r2 = ypos[curBall]
	LR   A,IS                ; 0b94 0a
	AI   balls.arraySize     ; 0b95 24 0b
	LR   IS,A                ; 0b97 0b
	LR   A,(IS)              ; 0b98 4c
	; Mask out the direction
	NI   MASK_YPOSITION      ; 0b99 21 3f
	LR   mainBall.ypos,A     ; 0b9b 52
	
; -- Test collision along x axis -----------------------------------------------
.xDelta = $1

	; mainBall.xpos-testBall.xpos
	SETISAR testBall         ; 0b9c 67 69
	LI   balls.xpos          ; 0b9e 20 10
	AS   (IS)                ; 0ba0 cc
	LR   IS,A                ; 0ba1 0b
	LR   A,(IS)              ; 0ba2 4c
	NI   MASK_POSITION       ; 0ba3 21 7f
	COM                      ; 0ba5 18
	INC                      ; 0ba6 1f
	AS   mainBall.xpos       ; 0ba7 c1
	
	; Save flags
	LR   J,W                 ; 0ba8 1e
	; Keep results if (mainBall.xpos >= testBall.xpos)
	BP   .saveXdelta         ; 0ba9 81 03	
	; Otherwise negate the results
	COM                      ; 0bab 18
	INC                      ; 0bac 1f
	
.saveXdelta:
	; abs(mainBall.x - testBall.x)
	LR   .xDelta,A           ; 0bad 51
	
	; branch ahead if testBall is not a player ball
	LR   A,IS                ; 0bae 0a
	CI   [balls.xpos+MAX_PLAYERS-1] ; 0baf 25 11
	BNC  .useEnemySize       ; 0bb1 92 0b

	; branch ahead if mainBall.xpos < testBall.xpos
	;  or: if mainBall is left of testBall
	LR   W,J                 ; 0bb3 1d    ; Reuse flags from earlier
	BM   .useEnemySize       ; 0bb4 91 08
				
	; Get player ball width
	LI   MASK_PLAYER_SIZE    ; 0bb6 20 c0
	NS   main.gameSettings   ; 0bb8 fa
	SR   1                   ; 0bb9 12
	SR   1                   ; 0bba 12
	BR   .testXaxis          ; 0bbb 90 04

	; or get enemy ball width
.useEnemySize:
	LI   MASK_ENEMY_SIZE     ; 0bbd 20 30
	NS   main.gameSettings   ; 0bbf fa

.testXaxis:
	SR   4                   ; 0bc0 14

	; xDelta - testBall.width
	COM                      ; 0bc1 18
	INC                      ; 0bc2 1f
	AS   .xDelta             ; 0bc3 c1

	; if (xDelta >= testBall.width)
	;  continue on to next ball
	BP   .testBallLoop             ; 0bc4 81 b3
	; else
	;  test the y axis collision

; -- Test collision on the y axis ----------------------------------------------
.yDelta = $2

	; mainBall.ypos-testBall.ypos
	LR   A,IS                ; 0bc6 0a
	AI   balls.arraySize     ; 0bc7 24 0b
	LR   IS,A                ; 0bc9 0b
	LR   A,(IS)              ; 0bca 4c
	NI   MASK_YPOSITION      ; 0bcb 21 3f
	COM                      ; 0bcd 18
	INC                      ; 0bce 1f
	AS   mainBall.ypos       ; 0bcf c2
	
	; Save flags
	LR   J,W                 ; 0bd0 1e
	; Keep results if (mainBall.ypos >= testBall.ypos)
	BP   .saveYdelta         ; 0bd1 81 03
	; Otherwise negate the results
	COM                      ; 0bd3 18
	INC                      ; 0bd4 1f
.saveYdelta:
	; abs(mainBall.ypos-testBall.ypos)
	LR   .yDelta,A           ; 0bd5 52

	; branch ahead if testBall is not a player ball
	LR   A,IS                ; 0bd6 0a
	CI   [balls.ypos+MAX_PLAYERS-1]; 0bd7 25 1c
	BNC   .useEnemySize2     ; 0bd9 92 0b

	; branch ahead if mainBall.ypos < testBall.ypos
	;  or: if mainBall is north of testBall
	LR   W,J                 ; 0bdb 1d    ; Reuse flags from earlier
	BM   .useEnemySize2      ; 0bdc 91 08
	
	; Get player ball width
	LI   MASK_PLAYER_SIZE    ; 0bde 20 c0
	NS   main.gameSettings   ; 0be0 fa
	SR   1                   ; 0be1 12
	SR   1                   ; 0be2 12
	BR   .testYaxis          ; 0be3 90 04
	; or get enemy ball width
.useEnemySize2:
	LI   MASK_ENEMY_SIZE     ; 0be5 20 30
	NS   main.gameSettings   ; 0be7 fa
.testYaxis:
	SR   4                   ; 0be8 14
	
	; yDelta - tempWidth
	COM                      ; 0be9 18
	INC                      ; 0bea 1f
	AS   .yDelta             ; 0beb c2

	; if (yDelta >= tempWidth)
	;  continue on to next ball
	BP   .testBallLoop       ; 0bec 81 8b
	; else
	;  handle the collision that just happened

; -- If we got to this point, a collision has happened -------------------------
	
	; Check if the collision was with a player
	;  If so, game over
	;  Else, skip ahead
	SETISAR testBall         ; 0bee 67 69
	LR   A,(IS)              ; 0bf0 4c
	CI   [MAX_PLAYERS-1]     ; 0bf1 25 01
	BNC   .makeNoise         ; 0bf3 92 04
	; Game over
	JMP  gameOver            ; 0bf5 29 0e 44

.makeNoise:
	; Play sound
	LI   SOUND_500Hz         ; 0bf8 20 80
	LR   playSound.sound,A   ; 0bfa 53
	PI   playSound           ; 0bfb 28 0c c8
	
	; RNG for random bounce trajectory
	PI   rand                ; 0bfe 28 08 c1

	; branch ahead if(yDelta < 1)
	LR   A,.yDelta           ; 0c01 42
	CI   1                   ; 0c02 25 01
	BC   .randYdirection     ; 0c04 82 3c

; -- Fiddle with the x direction -----------------------------------------------
.speedThing = $8
.SPEED_ADJUST = $44
.randBall = $0 ; TODO: Give this variable a better name (it's not random)
	
; Randomize x direction of mainBall
	; Set ISAR to xpos[curBall]
	LI   balls.xpos          ; 0c06 20 10
	AS   main.curBall        ; 0c08 cb
	LR   IS,A                ; 0c09 0b
	; XOR the direction with the RNG
	LI   MASK_DIRECTION      ; 0c0a 20 80
	NS   RNG.regHi           ; 0c0c f6
	XS   (IS)                ; 0c0d ec
	LR   (IS),A              ; 0c0e 5c
	; Save flags from (MASK_DIRECTION xor RNG)
	; Note: These flags do not appear to be used
	LR   J,W                 ; 0c0f 1e

; Randomize x direction of testBall
	; ISAR = balls.xpos + testBall
	SETISAR testBall         ; 0c10 67 69
	LI   balls.xpos          ; 0c12 20 10
	AS   (IS)                ; 0c14 cc
	LR   IS,A                ; 0c15 0b
	; Add RNG.lo to the direction
	LI   MASK_DIRECTION      ; 0c16 20 80
	NS   RNG.regLo           ; 0c18 f7
	AS   (IS)                ; 0c19 cc
	LR   (IS),A              ; 0c1a 5c
				
	; We'll be using this later to adjust the speed
	LI   .SPEED_ADJUST       ; 0c1b 20 44
	LR   .speedThing,A       ; 0c1d 58

	; randBall = mainBall
	;  The branch that fiddles the y direction sets this to testBall
	LR   A, main.curBall     ; 0c1e 4b
	LR   .randBall,A         ; 0c1f 50

; -- Fiddle with the speed -----------------------------------------------------
.thisBitmask = $3
.otherSpeed = $4

.checkMode:
	; If bit 7 of gameMode is set, we mess with the speed
	; TODO: Figure out where this bit is set (explode() clears this bit)
	SETISAR gameMode         ; 0c20 67 6d
	CLR                      ; 0c22 70
	AS   (IS)                ; 0c23 cc
	BP   .changeSpeed        ; 0c24 81 04
	; Else, test the next ball
	JMP  .testBallLoop       ; 0c26 29 0b 78

.changeSpeed:
	; ISAR = balls.speed + randBall/2
	LR   A,.randBall         ; 0c29 40
	SR   1                   ; 0c2a 12
	AI   balls.speed         ; 0c2b 24 26
	LR   IS,A                ; 0c2d 0b

	; Conjure up the bitmask to extract randBall's speed
	LIS  $1                  ; 0c2e 71
	NS   .randBall           ; 0c2f f0
	LIS  MASK_SPEED          ; 0c30 7f
	BNZ  .getThisBitmask     ; 0c31 94 02
	COM                      ; 0c33 18
.getThisBitmask:
	; Save randBall's speed bitmask
	LR   .thisBitmask,A      ; 0c34 53
	; Temp storage for the other speed bitfield
	COM                      ; 0c35 18
	NS   (IS)                ; 0c36 fc
	LR   .otherSpeed,A       ; 0c37 54
	
	; Get the speed bitfield for randBall
	LR   A,.thisBitmask      ; 0c38 43
	NS   (IS)                ; 0c39 fc
	; Add .speedThing to it, and clean up with the bitmask
	AS   .speedThing         ; 0c3a c8
	NS   .thisBitmask        ; 0c3b f3
	; Merge the two speed bitfields and save the result
	AS   .otherSpeed         ; 0c3c c4
	LR   (IS),A              ; 0c3d 5c
	
	; Return (don't process any more collisions for mainBall)
	JMP  collision.return            ; 0c3e 29 0b 6c

; -- Fiddle with y direction ---------------------------------------------------
.randYdirection:
	; randBall = testBall
	; ISAR = balls.ypos + randBall
	SETISAR testBall         ; 0c41 67 69
	LR   A,(IS)              ; 0c43 4c
	LR   .randBall,A         ; 0c44 50
	AI   balls.ypos          ; 0c45 24 1b
	LR   IS,A                ; 0c47 0b

	; Flip the y direction of testBall
	LI   MASK_DIRECTION      ; 0c48 20 80
	XS   (IS)                ; 0c4a ec
	LR   (IS),A              ; 0c4b 5c
	; Save flags for later
	LR   J,W                 ; 0c4c 1e

	; ISAR = balls.ypos + mainBall
	LI   balls.ypos          ; 0c4d 20 1b
	AS   main.curBall        ; 0c4f cb
	LR   IS,A                ; 0c50 0b

	; Set mainBall's direction to down
	LR   A,(IS)              ; 0c51 4c
	OI   MASK_DIRECTION      ; 0c52 22 80
	
	; Load flags from earlier
	;  if testBall went down, mainBall goes up
	;  if testBall went up, mainBall goes down
	LR   W,J                 ; 0c54 1d
	BP   .setYdirection      ; 0c55 81 03
	NI   MASK_YPOSITION      ; 0c57 21 3f
.setYdirection:
	LR   (IS),A              ; 0c59 5c
	
	; We'll be using this later to adjust the velocity
	LI   .SPEED_ADJUST       ; 0c5a 20 44
	LR   .speedThing,A       ; 0c5c 58
	
	; Go to the "fiddle with speed" section of this function
	BR   .checkMode          ; 0c5d 90 c2
; end of collision()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; setWalls()
;
; Sets the positions of the walls along one axis given an input range.
  
; == Arguments ==
; *walls = ISAR
walls.max = $1
walls.min = $2

; == Constants ==
WALL_XMAX = $58
WALL_YMAX = $38
WALL_MIN  = $10

setWalls: subroutine 
	LR   K,P                 ; 0c5f 08

; == Locals ==
.tempWall = $4
.X_OFFSET_MAX = $12
.Y_OFFSET_MAX = $0B

.reroll:
	; Reroll RNG until r6 is non-zero
	PI   rand                ; 0c60 28 08 c1
	CLR                      ; 0c63 70
	AS   RNG.regHi           ; 0c64 c6
	BZ   .reroll             ; 0c65 84 fa
	
; Make sure the RNG is in range, depending on the axis being set
	; if(r1 == 0x58) ; x axis case
	;  if(RNG > 0x12)
	;   go back and reroll
	; else if(RNG > 0x0B) ; y axis case
	;   go back and reroll
	LR   A,walls.max         ; 0c67 41
	CI   WALL_XMAX           ; 0c68 25 58

	LR   A, RNG.regHi        ; 0c6a 46
	BNZ  .clampY             ; 0c6b 94 05

	CI   .X_OFFSET_MAX       ; 0c6d 25 12
	BR   .clampX             ; 0c6f 90 03

.clampY:
	CI   .Y_OFFSET_MAX       ; 0c71 25 0b
.clampX:
	BNC  .reroll             ; 0c73 92 ec

; Get the base value for the right/lower wall
	;  Note: the greater this number is, the more to the left (or top) this wall
	;   is. (Unintuitive. Works opposite of how the upper and left walls work.)
	; .tempWall = -(max-rng+1)
	COM                      ; 0c75 18
	INC                      ; 0c76 1f
	INC                      ; 0c77 1f
	AS   walls.max           ; 0c78 c1
	COM                      ; 0c79 18
	INC                      ; 0c7a 1f
	LR   .tempWall,A         ; 0c7b 54
	
; Adjust the right/lower wall according to the enemy's size
	; wall.right(or lower)Enemy = playerSize + .tempWall
	LI   MASK_ENEMY_SIZE     ; 0c7c 20 30
	NS   main.gameSettings   ; 0c7e fa
	SR   4                   ; 0c7f 14
	AS   .tempWall           ; 0c80 c4
	LR   (IS)+,A             ; 0c81 5d
	
; Adjust the right/lower wall according to the player's size
	; wall.right(or lower)Player = playerSize + .tempWall
	LI   MASK_PLAYER_SIZE    ; 0c82 20 c0
	NS   main.gameSettings   ; 0c84 fa
	SR   4                   ; 0c85 14
	SR   1                   ; 0c86 12
	SR   1                   ; 0c87 12
	AS   .tempWall           ; 0c88 c4
	LR   (IS)+,A             ; 0c89 5d
	
; Set the left or top boundary
	; ISAR++ = walls.min + RNG
	LR   A,RNG.regHi         ; 0c8a 46
	AS   walls.min           ; 0c8b c2
	LR   (IS)+,A             ; 0c8c 5d

	; Exit
	LR   P,K                 ; 0c8d 09
	POP                      ; 0c8e 1c
; end of setWalls()
;-------------------------------------------------------------------------------
	
;-------------------------------------------------------------------------------
; flash()
;  Mid-Level Function
;
; UNUSED
;
; Makes the screen flash -- possibly an old form of the death animation. Working
;  off of that assumption, we will assume that this function would have been
;  called after a player collision in the ball-ball collision function.

; == Arguments ==
; testBall = 071

; No Returns

flash: subroutine
	LR   K,P                 ; 0c8f 08

; == Locals ==
.loopCount = $9
.NUM_LOOPS = $25
	
	LI   .NUM_LOOPS          ; 0c90 20 25
	LR   .loopCount, A       ; 0c92 59

	; Set flash color/sound value depending on value of o71 (who died?)
	SETISAR testBall         ; 0c93 67 69
	LIS  $1                  ; 0c95 71
	NS   (IS)-               ; 0c96 fe
	LI   SOUND_500Hz         ; 0c97 20 80
	BZ   .setSound           ; 0c99 84 03
	LI   SOUND_120Hz         ; 0c9b 20 c0
.setSound:          
	LR   (IS), A             ; 0c9d 5c
	LR   draw.ypos, A        ; 0c9e 52

; Loop back here to reset the sound and row attribute color to the above value
.loopResetColor:          
	LR   A,(IS)              ; 0c9f 4c

; Loop back here to keep the sound and row attribute color cleared
.loopClearColor:          
	; Set ypos/color
	LR   draw.ypos, A        ; 0ca0 52

	; Make sound
	; NOTE: sound is not played if curBall is one of the player balls
	LR   A,(IS)              ; 0ca1 4c
	LR   playSound.sound,A   ; 0ca2 53
	PI   playSound           ; 0ca3 28 0c c8
	
	LISL 0                   ; 0ca6 68 ; ISAR = 070 ; Temp?
	; Set xpos to attribute column
	LI   DRAW_ATTR_X         ; 0ca7 20 7d
	LR   draw.xpos, A        ; 0ca9 51
	; Set width
	LIS  DRAW_ATTR_W         ; 0caa 72
	LR   draw.width, A       ; 0cab 54
	; Set height
	LI   DRAW_SCREEN_H       ; 0cac 20 40
	LR   draw.height, A      ; 0cae 55
	; Set rendering parameter
	LI   DRAW_ATTRIBUTE      ; 0caf 20 c0
	LR   draw.param, A       ; 0cb1 50
	PI   drawBox             ; 0cb2 28 08 62
	
	; Clear sound
	CLR                      ; 0cb5 70
	OUTS 5                   ; 0cb6 b5
	
	; Delay
	LIS  $b                  ; 0cb7 7b
	LR   delay.count, A      ; 0cb8 50
	PI   delayVariable       ; 0cb9 28 09 9a

	; loopCount--
	;  exit it less than zero
	DS   .loopCount          ; 0cbc 39
	BM   .exit               ; 0cbd 91 08
	
	; if (timer is even)
	;  ypos/color = (ISAR)
	LIS  $1                  ; 0cbf 71
	NS   .loopCount          ; 0cc0 f9
	CLR                      ; 0cc1 70
	BZ   .loopResetColor     ; 0cc2 84 dc
	; else
	;  ypos/color = 0
	BR   .loopClearColor     ; 0cc4 90 db

.exit:     
	LR   P,K                 ; 0cc6 09
	POP                      ; 0cc7 1c
; end flash()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; playSound(ball, sound)
;  Leaf Function
;
; Make a ticking noise when the balls collide with something.

; == Arguments ==
playSound.sound = 3
; main.curBall = $b

; == Entry Point ==
playSound: subroutine
	; if(curBall >= MAX_PLAYERS)
	LR   A, main.curBall     ; 0cc8 4b
	CI   [MAX_PLAYERS-1]     ; 0cc9 25 01
	BC   playSound.exit      ; 0ccb 82 03
	; then play the sound
	LR   A, playSound.sound  ; 0ccd 43
	OUTS 5                   ; 0cce b5
	
playSound.exit:          
	POP                      ; 0ccf 1c
; end playSound()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; init()
;  Top-Level Procedure
;
; For simplicity's sake, this disassembly will divide the top-level thread into
;  separate "functions", even though they are not callable and the code just
;  flows and jumps from one block to another.
;
; To initialize the game, this procedure does some initial bookkeeping with the
;  scratchpad, I/O, and display, and then asks the player to select the game
;  mode with the question "G?" The four selectable game types are:
;
; 1 - Slow, 1 player
; 2 - Slow, 2 players
; 3 - Fast, 1 player
; 4 - Fast, 2 players

init: subroutine
	SETISAR RNG.seedLo       ; 0cd0 67 6f

	; Enable data from controllers
	LI   $40                 ; 0cd2 20 40
	OUTS 0                   ; 0cd4 b0
	
	; Seed RNG from uninitialized ports
	INS  4                   ; 0cd5 a4
	LR   (IS)-,A             ; 0cd6 5e
	INS  5                   ; 0cd7 a5
	LR   (IS)-,A             ; 0cd8 5e
	
	; Clear BIOS stack pointer at 073
	;  This game does not use the BIOS's stack functions
	LISL 3                   ; 0cd9 6b
	CLR                      ; 0cda 70
	LR   (IS),A              ; 0cdb 5c
	; The BIOS already intialized the rest of the scratchpad to zero
	
	; Clear port
	OUTS 0                   ; 0cdc b0

; Clear screen
	; Set properties
	LI   DRAW_RECT           ; 0cdd 20 80
	LR   draw.param, A       ; 0cdf 50
	; Set x and y pos
	CLR                      ; 0ce0 70
	LR   draw.xpos, A        ; 0ce1 51
	LR   draw.ypos, A        ; 0ce2 52
	; Set width
	LI   DRAW_SCREEN_W       ; 0ce3 20 80
	LR   draw.width, A       ; 0ce5 54
	; Set height
	LI   DRAW_SCREEN_H       ; 0ce6 20 40
	LR   draw.height, A      ; 0ce8 55

	PI   drawBox             ; 0ce9 28 08 62

; Set row attributes
	; Set rendering properties, ypos, and color
	LI   DRAW_ATTRIBUTE      ; 0cec 20 c0
	LR   draw.param, A       ; 0cee 50
	LR   draw.ypos, A        ; 0cef 52
	; Set width
	LIS  DRAW_ATTR_W         ; 0cf0 72
	LR   draw.width, A       ; 0cf1 54
	; xpos = attribute column
	LI   DRAW_ATTR_X         ; 0cf2 20 7d
	LR   draw.xpos, A        ; 0cf4 51
	; Height and ypos are retained from previous write
	PI   drawBox             ; 0cf5 28 08 62

; Draw the "G?" screen
.G_X = $30
.G_Y = $1B
.Q_X = $35

	; Set char
	LIS  CHAR_G              ; 0cf8 7a
	LR   draw.param, A       ; 0cf9 50
	; Set xpos
	LI   .G_X                ; 0cfa 20 30
	LR   draw.xpos, A        ; 0cfc 51
	; Set ypos and color
	LI   RED | .G_Y          ; 0cfd 20 9b
	LR   draw.ypos, A        ; 0cff 52
	; Set width
	LIS  CHAR_WIDTH          ; 0d00 74
	LR   draw.width, A       ; 0d01 54
	; Set height
	LIS  CHAR_HEIGHT         ; 0d02 75
	LR   draw.height, A      ; 0d03 55

	PI   drawChar            ; 0d04 28 08 58
	
	; Set char
	LIS  CHAR_QMARK          ; 0d07 7b
	LR   draw.param, A       ; 0d08 50
	; Set xpos
	LI   .Q_X                ; 0d09 20 35
	LR   draw.xpos, A        ; 0d0b 51

	PI   drawChar            ; 0d0c 28 08 58
	
; Wait 10 seconds for input
	PI   menu                ; 0d0f 28 08 f0
	; The button press is returned in A (default is 1)

; Use a table to put the number of the button pressed into gameMode
	SETISAR gameMode         ; 0d12 67 6d
	SR   1                   ; 0d14 12
	; DC was set in the menu
	ADC                      ; 0d15 8e
	LM                       ; 0d16 16
	LR   (IS),A              ; 0d17 5c

	; Continue on to next procedure
	
;-------------------------------------------------------------------------------
; shuffleGame()
;  Top-Level Procedure
;
; This function randomizes the game parameters such as player size, enemy size,
;  player speed, enemy speed, the upper six bits of gameMode, and the walls.
;
; TODO: Figure out if the upper six bits of gameMode are used for anything
;  interesting or not.

shuffleGame: subroutine
	; Preserve the player and game speed bits of gameMode
	SETISAR gameMode         ; 0d18 67 6d
	LR   A,(IS)              ; 0d1a 4c
	NI   MODE_CHOICE_MASK    ; 0d1b 21 03
	LR   (IS),A              ; 0d1d 5c

.reroll:
	; Array of bitmaks to be used in the following series of tests
	DCI  gameModeMasks       ; 0d1e 2a 08 43
	
	; Get a random number
	PI   rand                ; 0d21 28 08 c1
	
; Test to see if the number is a valid game setting
.temp = $8

	; Put bits 6 and 7 of RNG into .temp (for player ball size)
	LM                       ; 0d24 16
	NS   RNG.regHi           ; 0d25 f6
	LR   .temp,A             ; 0d26 58
	
	; Add bits 4 and 5 of RNG to the previous result (for enemy ball size)
	LM                       ; 0d27 16
	NS   RNG.regHi           ; 0d28 f6
	SL   1                   ; 0d29 13
	SL   1                   ; 0d2a 13
	AS   .temp               ; 0d2b c8
	; if(playerSize + enemySize < 4), then reroll
	BNC  .reroll             ; 0d2c 92 f1
	
	; Test if at least one of bits 2 and 3 of RNG are set
	LM                       ; 0d2e 16
	NS   RNG.regHi           ; 0d2f f6
	; if(playerSpeed == 0), then reroll
	BZ   .reroll             ; 0d30 84 ed

	; Test if at least one of bits 0 and 1 of RNG are set
	LM                       ; 0d32 16
	NS   RNG.regHi           ; 0d33 f6
	; if(enemySpeed == 0), then reroll
	BZ   .reroll             ; 0d34 84 e9

	; RNG.regHi contains a valid value, so we can use it
	LR   A, RNG.regHi        ; 0d36 46
	LR   main.gameSettings,A ; 0d37 5a

; Put the upper six bits of the RNG into gameMode
	LM                       ; 0d38 16
	NS   RNG.regLo           ; 0d39 f7
	AS   (IS)                ; 0d3a cc
	LR   (IS)-,A             ; 0d3b 5e
	; Note: This ISAR post-decrement puts the ISAR on player 2's high score.
	;  This is not utilized.

	; DC = (enemySpeed)*2
	; Note: This array is never read from.
	DCI  unusedSpeedTable    ; 0d3c 2a 08 48
	LIS  MASK_ENEMY_SPEED    ; 0d3f 73
	NS   main.gameSettings   ; 0d40 fa
	SL   1                   ; 0d41 13
	ADC                      ; 0d42 8e
	; Note: Perhaps the 2 bytes from this table was meant to be loaded into the
	;  space that is now reserved for player 2's high score.

; Set playfield walls
	; Set playfield walls for x axis
	LI   WALL_XMAX           ; 0d43 20 58
	LR   walls.max,A         ; 0d45 51
	LI   WALL_MIN            ; 0d46 20 10
	LR   walls.min,A         ; 0d48 52
	SETISAR wall.rightEnemy  ; 0d49 66 68
	PI   setWalls            ; 0d4b 28 0c 5f
	
	; Set playfield walls for y axis
	LI   WALL_YMAX           ; 0d4e 20 38
	LR   walls.max,A         ; 0d50 51
	PI   setWalls            ; 0d51 28 0c 5f
	
	; Continue on to next procedure

;-------------------------------------------------------------------------------
; restartGame()
;  Top-Level Procedure
;
; Does prep work necessary to restart (or start the game), such as drawing the
;  playfield, clearing the timer, spawning the players and the first ball, and
;  making sure the explosion flag is clear.

restartGame: subroutine

; Draw playfield walls
.FIELD_X = $10
.FIELD_W = $49
.FIELD_H = $29

	; Set rendering properties
	LI   DRAW_RECT           ; 0d54 20 80
	LR   draw.param, A       ; 0d56 50
	; Set x pos
	LI   .FIELD_X            ; 0d57 20 10
	LR   draw.xpos, A        ; 0d59 51
	; Set color (and ypos)
	AI   RED                 ; 0d5a 24 80
	LR   draw.ypos, A        ; 0d5c 52
	; Set width
	LI   .FIELD_W            ; 0d5d 20 49
	LR   draw.width, A       ; 0d5f 54
	; Set height
	LI   .FIELD_H            ; 0d60 20 29
	LR   draw.height, A      ; 0d62 55
	; Draw box
	PI   drawBox             ; 0d63 28 08 62

; Draw inner box of playfield
.tempSize = $3

	; xpos = wall.left
	SETISAR wall.left        ; 0d66 66 6a
	LR   A,(IS)              ; 0d68 4c
	LR   draw.xpos, A        ; 0d69 51

	; width = -(wall.left + wall.rightEnemy) + enemySize
	SETISARL wall.rightEnemy ; 0d6a 68
	AS   (IS)                ; 0d6b cc
	COM                      ; 0d6c 18
	INC                      ; 0d6d 1f
	LR   draw.width, A       ; 0d6e 54

	LI   MASK_ENEMY_SIZE     ; 0d6f 20 30
	NS   main.gameSettings   ; 0d71 fa
	SR   4                   ; 0d72 14
	LR   .tempSize,A         ; 0d73 53

	AS   draw.width          ; 0d74 c4
	LR   draw.width, A       ; 0d75 54
	
	; Set ypos (color is blank)
	SETISARL wall.upper      ; 0d76 6d
	LR   A,(IS)              ; 0d77 4c
	LR   draw.ypos, A        ; 0d78 52
	
	; height = -(wall.top - wall.lowerEnemy) + enemySize
	SETISARL wall.lowerEnemy ; 0d79 6b
	AS   (IS)                ; 0d7a cc
	COM                      ; 0d7b 18
	INC                      ; 0d7c 1f
	AS   .tempSize           ; 0d7d c3
	LR   draw.height, A      ; 0d7e 55
	
	; Set rendering properties
	LI   DRAW_RECT           ; 0d7f 20 80
	LR   draw.param, A       ; 0d81 50

	; Draw
	PI   drawBox             ; 0d82 28 08 62
	
; Clear timer
	SETISAR timer.hi         ; 0d85 66 6e
	CLR                      ; 0d87 70
	LR   (IS)+,A             ; 0d88 5d
	LR   (IS)+,A             ; 0d89 5d

; Spawn the balls
	; Spawn the players
	CLR                      ; 0d8a 70
.spawnLoop:          
	LR   main.curBall, A     ; 0d8b 5b
	PI   spawnBall           ; 0d8c 28 09 c2
	
	LR   A, main.curBall     ; 0d8f 4b
	INC                      ; 0d90 1f
	CI   [MAX_PLAYERS-1]     ; 0d91 25 01
	BC   .spawnLoop          ; 0d93 82 f7

	; Spawn the first enemy ball
	SETISAR balls.count      ; 0d95 65 6e
	LR   (IS),A              ; 0d97 5c
	LR   main.curBall, A     ; 0d98 5b
	PI   spawnBall           ; 0d99 28 09 c2

; Clear the the explosion flag
	SETISAR explosionFlag    ; 0d9c 67 6a
	CLR                      ; 0d9e 70
	LR   (IS),A              ; 0d9f 5c

	; Continue on to next procedure

;-------------------------------------------------------------------------------
; mainLoop()
;  Top-Level Procedure
;
; Clears the sound, draws the timer, runs a delay function, processes the enemy
;  balls, processes the player balls, and repeats until somebody loses.
;
; Note that since the Channel F lacks vsync or any sort of interval timer, that
;  the game needs to use a delay function to keep the game running at a
;  consistent and reasonable speed.

mainLoop: subroutine
	; Clear sound
	CLR                      ; 0da0 70
	OUTS 5                   ; 0da1 b5
				
; Change delay index according to the timer
	; if (timer.hi > 10)
	;   delay index = 10
	; else
	;	delay index = timer.hi + 1
	SETISAR timer.hi         ; 0da2 66 6e
	LR   A,(IS)+             ; 0da4 4d
	INC                      ; 0da5 1f
	CI   [MAX_BALLS-1]       ; 0da6 25 0a
	BC   .setDelay           ; 0da8 82 02
	LIS  [MAX_BALLS-1]       ; 0daa 7a
.setDelay:
	SETISARU delayIndex      ; 0dab 65
	LR   (IS),A              ; 0dac 5c
	SETISARU timer.lo        ; 0dad 66

; Increment 16-bit BCD timer
	; timer.lo++
	LI   $01 + BCD_ADJUST    ; 0dae 20 67
	ASD  (IS)                ; 0db0 dc
	LR   (IS)-,A             ; 0db1 5e
	BNC   .setTimerPos       ; 0db2 92 12
	; if carry, timer.hi++
	LI   $01 + BCD_ADJUST    ; 0db4 20 67
	ASD  (IS)                ; 0db6 dc
	LR   (IS)+,A             ; 0db7 5d
	
; Check if the explosion flag should be set
	; Check if hundreds digit is zero
	NI   DIGIT_MASK          ; 0db8 21 0f
	BNZ  .setTimerPos        ; 0dba 94 0a
	; If so, check if tens and ones digits are zero
	CLR                      ; 0dbc 70
	AS   (IS)                ; 0dbd cc
	BNZ  .setTimerPos        ; 0dbe 94 06
	; If so, set the explosion flag
	SETISAR explosionFlag    ; 0dc0 67 6a
	LI   MASK_EXPLODE        ; 0dc2 20 80
	LR   (IS),A              ; 0dc4 5c

; Handle Drawing of the timer
.setTimerPos:
.TIMER_X_1P = $1F
.TIMER_X_2P = $39
	; Check if 1 or 2 player
	SETISAR gameMode         ; 0dc5 67 6d
	LIS  MODE_2P_MASK        ; 0dc7 71
	NS   (IS)                ; 0dc8 fc
	; Display in middle if 2 player mode
	LI   .TIMER_X_2P         ; 0dc9 20 39
	BNZ  .drawTimer          ; 0dcb 94 03
	; Display to left if 1 player mode
	LI   .TIMER_X_1P         ; 0dcd 20 1f
.drawTimer:          
	LR   drawTimer.xpos, A   ; 0dcf 50
	; Set color (drawTimer adds the ypos)
	LI   RED                 ; 0dd0 20 80
	LR   drawTimer.ypos, A   ; 0dd2 52
	; Set ISAR to LSB of score
	SETISAR timer.lo         ; 0dd3 66 6f
	PI   drawTimer           ; 0dd5 28 0a 20

; Perform the delay (to keep the game speed consistent)
	; delayByTable(delayIndex)
	SETISAR delayIndex       ; 0dd8 65 6f
	LR   A,(IS)              ; 0dda 4c
	LR   delay.index, A      ; 0ddb 50
	PI   delayByTable        ; 0ddc 28 09 86

; Check if a new ball needs to be spawned
	; curBall = balls.count
	SETISAR balls.count      ; 0ddf 65 6e
	LI   %00001111           ; 0de1 20 0f
	NS   (IS)+               ; 0de3 fd
	LR   main.curBall, A     ; 0de4 5b
	
	; ISAR is delayIndex here
	; Check if curBall >= delayIndex
	LR   A,(IS)              ; 0de5 4c
	COM                      ; 0de6 18
	INC                      ; 0de7 1f
	AS   main.curBall        ; 0de8 cb
	; if so, branch ahead
	BP   .ballLoopInit       ; 0de9 81 0d
	; if not, spawn a new ball

	; curBall = delayIndex
	LR   A,(IS)              ; 0deb 4c
	LR   main.curBall, A     ; 0dec 5b

	; Spawn new ball
	PI   spawnBall           ; 0ded 28 09 c2
	
	; balls.count = delayIndex (preserve upper nybble of ball count)
	SETISAR balls.count      ; 0df0 65 6e
	LI   %11110000           ; 0df2 20 f0
	NS   (IS)+               ; 0df4 fd
	AS   (IS)-               ; 0df5 ce
	LR   (IS),A              ; 0df6 5c

; Handle enemy balls
.ballLoopInit:
	SETISAR balls.count      ; 0df7 65 6e
	LI   %00001111           ; 0df9 20 0f
	NS   (IS)                ; 0dfb fc
	LR   main.curBall, A     ; 0dfc 5b
				
.ballLoop:          
	; doBall.size = enemy ball size
	SETISAR doBall.size      ; 0dfd 67 68
	LI   MASK_ENEMY_SIZE     ; 0dff 20 30
	NS   main.gameSettings   ; 0e01 fa
	SR   4                   ; 0e02 14
	LR   (IS)+,A             ; 0e03 5d
	
	; doBall.speed = enemy speed 
	LI   MASK_ENEMY_SPEED    ; 0e04 20 03
	NS   main.gameSettings   ; 0e06 fa
	LR   (IS),A              ; 0e07 5c

	PI   doBall              ; 0e08 28 0a 53
	PI   collision           ; 0e0b 28 0b 6e
	
	; if we're not dealing with a player ball, then move on to the next ball
	DS   main.curBall        ; 0e0e 3b
	LR   A,main.curBall      ; 0e0f 4b
	CI   [MAX_PLAYERS-1]     ; 0e10 25 01
	BNC   .ballLoop          ; 0e12 92 ea

; Handle player balls
	PI   doPlayers           ; 0e14 28 09 24

	; doBall.size = player ball size
	SETISAR doBall.size      ; 0e17 67 68
	LI   MASK_PLAYER_SIZE    ; 0e19 20 c0
	NS   main.gameSettings   ; 0e1b fa
	SR   4                   ; 0e1c 14
	SR   1                   ; 0e1d 12
	SR   1                   ; 0e1e 12
	LR   (IS)+,A             ; 0e1f 5d
	
	; doBall.size = player speed
	LI   MASK_PLAYER_SPEED   ; 0e20 20 0c
	NS   main.gameSettings   ; 0e22 fa
	SR   1                   ; 0e23 12
	SR   1                   ; 0e24 12
	LR   (IS),A              ; 0e25 5c
	
	; Handle player 1
	LI   0                   ; 0e26 20 00
	LR   main.curBall,A      ; 0e28 5b
	PI   doBall              ; 0e29 28 0a 53
	
	; Check if were doing 2 player mode
	SETISAR gameMode         ; 0e2c 67 6d
	LIS  1                   ; 0e2e 71
	NS   (IS)                ; 0e2f fc
	BZ   .checkExplosion     ; 0e30 84 05	
	; If so handle player 2
	LR   main.curBall,A      ; 0e32 5b
	PI   doBall              ; 0e33 28 0a 53

; Deal with the explosion
.checkExplosion:
	; Loop back to beginning if explosion flag isn't set
	SETISAR explosionFlag    ; 0e36 67 6a
	CLR                      ; 0e38 70
	AS   (IS)                ; 0e39 cc
	BP   .endMain            ; 0e3a 81 06
	
	; Clear explosion flag, and then explode
	CLR                      ; 0e3c 70
	LR   (IS),A              ; 0e3d 5c
	JMP  explode             ; 0e3e 29 0f 6b

.endMain:
	JMP  mainLoop            ; 0e41 29 0d a0
; end of mainLoop()
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; gameOver()
;  Top-Level Procedure
;
; collision() jumps to here if the player comes in contact with an enemy ball
;
; This procedure jumps back to either shuffleGame() or restartGame() depending
;  on whether the controller is pushed in.

gameOver: subroutine

; Make the multicolored spiral death effect
	; ypos = $24, color = $80
	LI   RED | $24           ; 0e44 20 a4
	LR   draw.ypos, A        ; 0e46 52
	; spiralRadius = $14
	SETISAR spiral.radius    ; 0e47 64 6e
	LI   $14                 ; 0e49 20 14
	LR   (IS),A              ; 0e4b 5c

.spiralLoop:
	PI   drawSpiral          ; 0e4c 28 0f 0a
	; spiralRadius--
	SETISAR spiral.radius ; 0e4f 64 6e
	DS   (IS)                ; 0e51 3c
	; save flags
	LR   J,W                 ; 0e52 1e
	; color++
	; if(color == 0)
	;  color++
	; ypos = $24
	LR   A, draw.ypos        ; 0e53 42
	AI   $40                 ; 0e54 24 40
	BNC  .setColor           ; 0e56 92 03
	AI   $40                 ; 0e58 24 40
.setColor:
	NI   MASK_COLOR          ; 0e5a 21 c0
	AI   $24                 ; 0e5c 24 24
	LR   draw.ypos,A         ; 0e5e 52
	; restore flags
	; loop back if o46 != 0
	LR   W,J                 ; 0e5f 1d
	BNZ  .spiralLoop         ; 0e60 94 eb

; Wait a bit before clearing the spiral effect
	; delayVariable($0)
	CLR                      ; 0e62 70
	LR   delay.count, A      ; 0e63 50
	PI   delayVariable       ; 0e64 28 09 9a

; Clear the spiral
	; Set color depending on who died
	; 1P mode - Red
	SETISAR gameMode         ; 0e67 67 6d
	LIS  MODE_2P_MASK        ; 0e69 71
	NS   (IS)                ; 0e6a fc
	LI   RED                 ; 0e6b 20 80
	BZ   .clearSpiral        ; 0e6d 84 0a
	; 2P mode, P1 - Green
	SETISARL testBall        ; 0e6f 69
	LIS  $1                  ; 0e70 71
	NS   (IS)                ; 0e71 fc
	LI   GREEN               ; 0e72 20 c0
	BZ   .clearSpiral        ; 0e74 84 03
	; 2P mode, P2 - Blue
	LI   BLUE                ; 0e76 20 40
.clearSpiral:
	; Set ypos
	AI   $24                 ; 0e78 24 24
	LR   draw.ypos,A         ; 0e7a 52

	; Draw spiral
	SETISAR spiral.radius    ; 0e7b 64 6e
	LI   $14                 ; 0e7d 20 14
	LR   (IS),A              ; 0e7f 5c
	PI   drawSpiral          ; 0e80 28 0f 0a

; Delay a bit to allow the players time before input is polled later
	; Delay
	LI   $28                 ; 0e83 20 28
	LR   delay.count,A       ; 0e85 50
	PI   delayVariable       ; 0e86 28 09 9a

; Determine which case we should handle
	; Check if two players
	SETISAR gameMode         ; 0e89 67 6d
	LIS  MODE_2P_MASK        ; 0e8b 71
	NS   (IS)                ; 0e8c fc
	; If so, jump ahead
	BNZ  .2Pcleanup          ; 0e8d 94 38

; -- Game over cleanup - 1 player mode -----------------------------------------
.tempTimerHi = $6
.tempTimerLo = $7

	; r6/r7 = timer
	SETISAR timer.hi         ; 0e8f 66 6e
	LR   A,(IS)+             ; 0e91 4d
	LR   .tempTimerHi,A      ; 0e92 56
	LR   A,(IS)              ; 0e93 4c
	LR   .tempTimerLo,A      ; 0e94 57

	; check if tempTimer.hi < hiScore.hi
	SETISAR hiScore.p1.hi    ; 0e95 65 6c
	LR   A,(IS)+             ; 0e97 4d
	COM                      ; 0e98 18
	INC                      ; 0e99 1f
	AS   .tempTimerHi        ; 0e9a c6
	; if so, jump ahead
	BM   .delayP1            ; 0e9b 91 16
	; else, check if tempTimer.hi != hiScore.hi
	;  if so, replace the old high score
	BNZ  .newHighScore       ; 0e9d 94 07
	; else, check if tempTimer.lo < hiScore.lo
	LR   A,(IS)              ; 0e9f 4c
	COM                      ; 0ea0 18
	INC                      ; 0ea1 1f
	AS   .tempTimerLo        ; 0ea2 c7
	; if so, jump ahead
	BM   .delayP1            ; 0ea3 91 0e
	; else, replace the old high score

; Draw score
.newHighScore:
	; hiScore = tempTimer
	LR   A,.tempTimerLo      ; 0ea5 47
	LR   (IS)-,A             ; 0ea6 5e
	LR   A,.tempTimerHi      ; 0ea7 46
	LR   (IS)+,A             ; 0ea8 5d
	; Set color
	LI   BLUE                ; 0ea9 20 40
	LR   drawTimer.ypos, A   ; 0eab 52
	; Set xpos
	LI   $54                 ; 0eac 20 54
	LR   drawTimer.xpos, A   ; 0eae 50
	PI   drawTimer           ; 0eaf 28 0a 20

.delayP1:
	; Delay
	LI   $40                 ; 0eb2 20 40
	LR   delay.count, A      ; 0eb4 50
	PI   delayVariable       ; 0eb5 28 09 9a

	; Read controllers
	PI   readInput           ; 0eb8 28 09 10

	; If controller is pushed, keep gametype
	SETISARL input.p1        ; 0ebb 68
	CLR                      ; 0ebc 70
	AS   (IS)                ; 0ebd cc
	BM   .gotoShuffle        ; 0ebe 91 04

	JMP  restartGame         ; 0ec0 29 0d 54
; -- End of 1 player case ------------------------------------------------------

.gotoShuffle:
	JMP  shuffleGame         ; 0ec3 29 0d 18

; -- Game over cleanup - 2 player mode -----------------------------------------
.2Pcleanup:
	; r6/r7 = timer
	SETISAR timer.hi         ; 0ec6 66 6e
	LR   A,(IS)+             ; 0ec8 4d
	LR   .tempTimerHi,A      ; 0ec9 56
	LR   A,(IS)              ; 0eca 4c
	LR   .tempTimerLo,A      ; 0ecb 57
	
	; Check who died
	SETISAR testBall         ; 0ecc 67 69
	LIS  $1                  ; 0ece 71
	NS   (IS)                ; 0ecf fc
	BNZ  .P1survived         ; 0ed0 94 0b

	; Set parameters for player 2
	; set ypos (and color)
	LI   GREEN               ; 0ed2 20 c0
	LR   drawTimer.ypos,A    ; 0ed4 52
	; set xpos
	LI   $54                 ; 0ed5 20 54
	LR   drawTimer.xpos,A    ; 0ed7 50
	; player 2 hi score? (TODO: verify)
	SETISAR hiScore.p2.lo    ; 0ed8 67 6c
	BR   .addHiScore         ; 0eda 90 09

.P1survived:
	; Set drawing parameters for player 1
	SETISAR hiScore.p1.lo    ; 0edc 65 6d
	; Set color
	LI   BLUE                ; 0ede 20 40
	LR   drawTimer.ypos,A    ; 0ee0 52
	; set xpos
	LI   $1f                 ; 0ee1 20 1f
	LR   drawTimer.xpos,A    ; 0ee3 50

.addHiScore:
	; add the current timer to the winning player's high score
	; hiScore.lo += tempTimer.lo
	LR   A,.tempTimerLo      ; 0ee4 47
	AS   (IS)                ; 0ee5 cc
	LR   (IS),A              ; 0ee6 5c
	; Add zero in BCD to adjust score and check carry flag (what the heck?)
	LI   0 + BCD_ADJUST      ; 0ee7 20 66
	ASD  (IS)                ; 0ee9 dc
	LR   (IS)-,A             ; 0eea 5e
	BNC   .addHiScoreHiByte  ; 0eeb 92 05
	; Carry
	LI   1 + BCD_ADJUST      ; 0eed 20 67
	ASD  (IS)                ; 0eef dc
	LR   (IS),A              ; 0ef0 5c

.addHiScoreHiByte:
	; hiScore.hi += tempTimer.hi
	LR   A,(IS)              ; 0ef1 4c
	AS   .tempTimerHi        ; 0ef2 c6
	LR   (IS),A              ; 0ef3 5c
	; Add zero in BCD to adjust score (seriously, what the heck?)
	LI   0 + BCD_ADJUST      ; 0ef4 20 66
	ASD  (IS)                ; 0ef6 dc
	LR   (IS)+,A             ; 0ef7 5d

	PI   drawTimer           ; 0ef8 28 0a 20

; There is no delay here, unlike in 1 player mode!

	; Read controllers
	PI   readInput           ; 0efb 28 09 10

	; If neither player is pushing the controller, shuffle gametype
	; Player 1
	SETISARL input.p1        ; 0efe 68
	CLR                      ; 0eff 70
	AS   (IS)+               ; 0f00 cd
	BM   .gotoShuffle        ; 0f01 91 c1

	; Player 2
	CLR                      ; 0f03 70
	AS   (IS)                ; 0f04 cc
	BM   .gotoShuffle        ; 0f05 91 bd

	; Else, just restart the current game
	JMP  restartGame         ; 0f07 29 0d 54
; -- End of 2 player case ------------------------------------------------------

; end of gameOver()
;-------------------------------------------------------------------------------

;-----------------------------
; Draw Spiral (for death animation)
; mid-level function
; 

; == Arguments ==
spiral.radius = 046    ; o46 - spiral radius
; r1 - X pos
; NOT r2 - Y pos (this is set in this function)
; r4 - Width
; r5 - Height

drawSpiral: subroutine

; == Locals ==
; Note: These take the place of variables used while the game is being played!
spiral.hdiameter = 024 ; o24 - horizontal diameter
spiral.hcount = 025    ; o25 - horizontal counter
spiral.vcount = 026    ; o26 - vertical counter
spiral.vdiameter = 027 ; o27 - vertical diameter
spiral.lapCount = 036  ; o36 - spiral lap counter

	LR   K,P                 ; 0f0a 08
	; Set properties to draw a rect
	LI   DRAW_RECT           ; 0f0b 20 80
	LR   draw.param, A       ; 0f0d 50

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
	SETISARU spiral.radius   ; 0f1a 64
	LR   A,(IS)              ; 0f1b 4c ; is = o46
	SETISARU spiral.lapCount ; 0f1c 63
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

.plotUp:
	; ypos--
	DS   draw.ypos           ; 0f25 32
	PI   drawBox             ; 0f26 28 08 62
	; vcount-- (o26)
	DS   (IS)                ; 0f29 3c ; is = 0x16
	; loop until vcount reaches 0
	BNZ  .plotUp             ; 0f2a 94 fa

	; goto exit if o36 (spiral lap counter) is zero
	LR   W,J                 ; 0f2c 1d ; restore flags
	BZ   .exit     ; 0f2d 84 3b

	; vdiameter++ (o27)
	LR   A,(IS)+             ; 0f2f 4d
	LR   A,(IS)              ; 0f30 4c ; is=o27
	INC                      ; 0f31 1f
	LR   (IS)-,A             ; 0f32 5e
	; vcount = vdiameter
	LR   (IS)-,A             ; 0f33 5e ;is=o26
									   ;is=o25
.plotRight:
	; xpos++
	LR   A, draw.xpos        ; 0f34 41
	INC                      ; 0f35 1f
	LR   draw.xpos, A        ; 0f36 51
	PI   drawBox             ; 0f37 28 08 62
	; hcount-- (o25)
	DS   (IS)                ; 0f3a 3c
	; loop until hcount reaches 0
	BNZ  .plotRight          ; 0f3b 94 f8
	
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
.plotDown:
	; ypos++
	LR   A, draw.ypos        ; 0f44 42
	INC                      ; 0f45 1f
	LR   draw.ypos, A        ; 0f46 52
	PI   drawBox             ; 0f47 28 08 62
	; vcount-- (o26)
	DS   (IS)                ; 0f4a 3c
	BNZ  .plotDown           ; 0f4b 94 f8

	; vdiameter++ (o27)
	LR   A,(IS)+             ; 0f4d 4d ;is=o26
	LR   A,(IS)              ; 0f4e 4c ;is=o27
	INC                      ; 0f4f 1f
	LR   (IS)-,A             ; 0f50 5e ;is=o27
	; vcount = vdiameter
	; o26 = o27
	LR   (IS)-,A             ; 0f51 5e ;is=o26
									   ;is=o25
.plotLeft:
	; xpos--
	DS   draw.xpos           ; 0f52 31
	PI   drawBox             ; 0f53 28 08 62
	; hcount-- (o25)
	DS   (IS)                ; 0f56 3c
	BNZ  .plotLeft           ; 0f57 94 fa

	; hdiameter++ (o24) 
	LR   A,(IS)-             ; 0f59 4e ;is=o25
	LR   A,(IS)              ; 0f5a 4c ;is=o24
	INC                      ; 0f5b 1f
	LR   (IS)+,A             ; 0f5c 5d ;is=o24
	; hcount = hdiameter
	LR   (IS)+,A             ; 0f5d 5d ;is=o25
									   ;is=o26
	; spiral count-- (o36)
	SETISARU spiral.lapCount ; 0f5e 63
	DS   (IS)                ; 0f5f 3c 
	SETISARU spiral.vcount   ; 0f60 62
	; save flags (to be used above shortly after .plotUp)
	LR   J,W                 ; 0f61 1e
				
	; Play sound
	LR   A,$2                ; 0f62 42
	OUTS 5                   ; 0f63 b5
	
	BNZ  .plotUp             ; 0f64 94 c0
	
	; vcount--
	DS   (IS)                ; 0f66 3c ;is=o26
	BR   .plotUp             ; 0f67 90 bd
	
.exit:
	LR   P,K                 ; 0f69 09
	POP                      ; 0f6a 1c
; end drawSpiral()
;-----------------------------

;-------------------------------------------------------------------------------
; explode()
;  Top-level procedure
;
; Move the balls to the center to "explode". This procedure is executed
;  every 1000 points.
;
; Accessed from the end of the main loop, and returns to the beginning of the
;  main loop.
;
; No input arguments

; == Entry Point ==
explode: subroutine

; == Local Regs ==
.loopCount = $0

; == Local Constants ==
.NUM_LOOPS = MAX_ENEMIES
.X_CENTER = $30
.Y_CENTER = $22

; == Start ==
; Prepare for loop to set x positions
	; ISAR = balls.xpos + MAX_PLAYERS
	LIS  MAX_PLAYERS         ; 0f6b 72
	AI   balls.xpos          ; 0f6c 24 10
	LR   IS,A                ; 0f6e 0b
	; .loopCount = .NUM_LOOPS
	LIS  .NUM_LOOPS          ; 0f6f 79
	LR   .loopCount,A        ; 0f70 50
; Set xpos of all enemy balls
.xLoop:
	; Set xpos while preserving the x direction
	LI   MASK_DIRECTION      ; 0f71 20 80
	NS   (IS)                ; 0f73 fc
	AI   .X_CENTER           ; 0f74 24 30
	LR   (IS),A              ; 0f76 5c
	; ISAR++ (NOTE: ISAR post-increment would only affect the lower octal digit)
	LR   A,IS                ; 0f77 0a
	INC                      ; 0f78 1f
	LR   IS,A                ; 0f79 0b
	; .loopCount--, loop back if not zero
	DS   .loopCount          ; 0f7a 30
	BNZ  .xLoop              ; 0f7b 94 f5

; Prepare for loop to set y positions
	; ISAR = balls.ypos + MAX_PLAYERS
	LR   A,IS                ; 0f7d 0a
	AI   MAX_PLAYERS         ; 0f7e 24 02
	LR   IS,A                ; 0f80 0b
	; .loopCount = .NUM_LOOPS
	LIS  .NUM_LOOPS          ; 0f81 79
	LR   .loopCount,A        ; 0f82 50
; Set ypos of all enemy balls
.yLoop:
	; Set ypos while preserving the y direction
	LI   MASK_DIRECTION      ; 0f83 20 80
	NS   (IS)                ; 0f85 fc
	AI   .Y_CENTER           ; 0f86 24 22
	LR   (IS),A              ; 0f88 5c
	; ISAR++
	LR   A,IS                ; 0f89 0a
	INC                      ; 0f8a 1f
	LR   IS,A                ; 0f8b 0b
	; .loopCount, loop back if not
	DS   .loopCount          ; 0f8c 30
	BNZ  .yLoop              ; 0f8d 94 f5

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
; end explode()
;-------------------------------------------------------------------------------
	
    db $b2 ; Unused!

	; Free space - 94 bytes!
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff

; EoF