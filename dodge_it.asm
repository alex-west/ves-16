	processor f8

Reset: equ $0000

	org $0800

CartridgeStart: db $55, $2b
CartridgeEntry: JMP  initRoutine               ; 0802 29 0c d0

; Graphics data
A0805:
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
A0814: ; Spuriously generated label ?
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
A082d:
	db $19, $16, $13, $11, $0e, $0c, $0a, $08, $06, $03, $01

; Delay table B (pro)
A0838:
	db $0b, $0a, $09, $08, $07, $06, $05, $04, $03, $02, $01

; ? --
				; Game mode table ?
A0843:          AS   $0                  ; 0843 c0
                DS   $0                  ; 0844 30
                PK                       ; 0845 0c
                LR   A,QL                ; 0846 03
                NS   (IS)                ; 0847 fc
				
				; Data here?
A0848:          LR   A,KU                ; 0848 00
                LR   A,KU                ; 0849 00
                SR   1                   ; 084a 12
                LR   IS,A                ; 084b 0b
                LR   IS,A                ; 084c 0b
				
                LR   QU,A                ; 084d 06
                LR   A,QU                ; 084e 02
                LR   A,KL                ; 084f 01
A0850:          LR   A,$0                ; 0850 40
                AS   $0                  ; 0851 c0
				
                db $80, $00 ;BT   0,0                 ; 0852 80 00 ; Data at 0853
                LR   A,KL                ; 0854 01
                LR   A,QU                ; 0855 02
                LR   A,QL                ; 0856 03
                LR   A,QL                ; 0857 03
; --?

; Draw numbers
; r0 - Glyph
drawGlyph:          
				DCI  A0805               ; 0858 2a 08 05
				; r8 = r0/2
				; dc = 0x0805 + r0/2 + (r0/2)*4
                LR   A,$0                ; 085b 40
                SR   1                   ; 085c 12
                LR   $8,A                ; 085d 58
                SL   1                   ; 085e 13
                SL   1                   ; 085f 13
                AS   $8                  ; 0860 c8
                ADC                      ; 0861 8e

; Draw Box
; Args:
; r0 - Glyph (should be 0x80 or (0xC0?))
; r1 - X pos
; r2 - Y pos & color (upper 2 bits)
; r4 - Width
; r5 - Height
; Uses
; r3 as data
; r6 as h_count
; r7 as v_count
; r8 - Color temp (upper 2 bits)
drawBox:        
				; h_count = width
				LR   A, $4                ; 0862 44
                LR   $6,A                ; 0863 56
				; v_count = height
                LR   A,$5                ; 0864 45
                LR   $7,A                ; 0865 57
; Do one row
A0866:          
				; Mask out row, put color in r8
				LR   A,$2                ; 0866 42
                NI   $c0                 ; 0867 21 c0
                LR   $8,A                ; 0869 58
				; Mask out sound, put row in r3
                LR   A,$2                ; 086a 42
                COM                      ; 086b 18
                NI   $3f                 ; 086c 21 3f
                LR   $3,A                ; 086e 53
				; Preserve sound, write row to port 5
                INS  5                   ; 086f a5
                NI   $c0                 ; 0870 21 c0
                AS   $3                  ; 0872 c3
                OUTS 5                   ; 0873 b5
				; If glyph (r0) is negative, jump ahead
                LIS  $0                  ; 0874 70
                AS   $0                  ; 0875 c0
                LI   $ff                 ; 0876 20 ff
                BF   $1,A0882            ; 0878 91 09
				; Load data into r3
                LM                       ; 087a 16
                LR   $3,A                ; 087b 53
				; If glyph number is even, jump ahead
                LIS  $1                  ; 087c 71
                NS   $0                  ; 087d f0
                BT   4,A0883             ; 087e 84 04
				; else, r3 = r3 << 4
                LR   A,$3                ; 0880 43
                SL   4                   ; 0881 15
A0882:          LR   $3,A                ; 0882 53

				; Write column to port 4 from r1 ?
A0883:          LR   A,$1                ; 0883 41
                COM                      ; 0884 18
                OUTS 4                   ; 0885 b4
				
				; Write color to be plotted from r8[7:6] to port 1
                LIS  $0                  ; 0886 70
                AS   $3                  ; 0887 c3
				; Set color to input
                LR   A,$8                ; 0888 48
				; If upper bit of r3 is 1, skip ahead
                BF   $1,A088c            ; 0889 91 02
				; Set color to bg
                LIS  $0                  ; 088b 70
A088c:          COM                      ; 088c 18
				; Write color bits to port 1
                NI   $c0                 ; 088d 21 c0
                OUTS 1                   ; 088f b1
				
				; Shift r3 left, while 1-padding it
                LR   A,$3                ; 0890 43
                SL   1                   ; 0891 13
                INC                      ; 0892 1f
                LR   $3,A                ; 0893 53
				
				; If bit 6 of glyph is set, skip ahead
                LR   A,$0                ; 0894 40
                SL   1                   ; 0895 13
                BT   1,A089b             ; 0896 81 04
				; Else, shift color left
                LR   A,$8                ; 0898 48
                SL   1                   ; 0899 13
                LR   $8,A                ; 089a 58
				; Activate VRAM write
A089b:          LI   $60                 ; 089b 20 60
                OUTS 0                   ; 089d b0
                LI   $50                 ; 089e 20 50
                OUTS 0                   ; 08a0 b0
				; xpos++
                LR   A,$1                ; 08a1 41
                INC                      ; 08a2 1f
                LR   $1,A                ; 08a3 51
				; Delay loop
                LIS  $4                  ; 08a4 74
A08a5:          AI   $ff                 ; 08a5 24 ff
                BF   $4,A08a5            ; 08a7 94 fd
				
				; Decrease r6 h_count
                DS   $6                  ; 08a9 36
                BF   $4,A0883            ; 08aa 94 d8
				; Inc ypos
                LR   A,$2                ; 08ac 42
                INC                      ; 08ad 1f
                LR   $2,A                ; 08ae 52
				; Reset h_count
                LR   A,$4                ; 08af 44
                LR   $6,A                ; 08b0 56
				; Reset x_pos
                COM                      ; 08b1 18
                INC                      ; 08b2 1f
                AS   $1                  ; 08b3 c1
                LR   $1,A                ; 08b4 51
				; Decrease v_count
                DS   $7                  ; 08b5 37
                BF   $4,A0866            ; 08b6 94 af
				; Reset ypos
                LR   A,$5                ; 08b8 45
                COM                      ; 08b9 18
                INC                      ; 08ba 1f
                AS   $2                  ; 08bb c2
                LR   $2,A                ; 08bc 52
                ; Clear ports
				LIS  $0                  ; 08bd 70
                OUTS 1                   ; 08be b1
                OUTS 0                   ; 08bf b0
                POP                      ; 08c0 1c

; Modifies the contents of o76 and o77
; No input arguments
; RNG (probably)
; clobbers r6 and r7
; r8 is used as temp ISAR
roll_RNG:          
				; Save the ISAR in r8
				LR   A,IS                ; 08c1 0a
                LR   $8,A                ; 08c2 58
				; r6 = o77*2 + o76
                LISU 7                   ; 08c3 67
                LISL 7                   ; 08c4 6f
                LR   A,(IS)-             ; 08c5 4e
                SL   1                   ; 08c6 13
                AS   (IS)+               ; 08c7 cd
                LR   $6,A                ; 08c8 56
				; r7 = o77*2 ??
                LR   A,(IS)              ; 08c9 4c
                AS   (IS)                ; 08ca cc
                LR   $7,A                ; 08cb 57
				; r6 = r6*2 (+1 if o77*2 carried over) ?
                LR   J,W                 ; 08cc 1e ; save status reg
                LR   A,$6                ; 08cd 46
                SL   1                   ; 08ce 13
                LR   W,J                 ; 08cf 1d ; reload status reg
                LNK                      ; 08d0 19
                LR   $6,A                ; 08d1 56
				; r7 = r7*2
                LR   A,$7                ; 08d2 47
                AS   $7                  ; 08d3 c7
                LR   $7,A                ; 08d4 57
				; r6 = r6*2 (+1 if r7*2 carried over) ?
                LR   J,W                 ; 08d5 1e
                LR   A,$6                ; 08d6 46
                SL   1                   ; 08d7 13
                LR   W,J                 ; 08d8 1d
                LNK                      ; 08d9 19
                LR   $6,A                ; 08da 56
				; r7 = r7 + o77
                LR   A,$7                ; 08db 47
                AS   (IS)-               ; 08dc ce
                LR   $7,A                ; 08dd 57
				; r6 = r6 (+1 if r7+077 carried) + o76
                LR   A,$6                ; 08de 46
                LNK                      ; 08df 19
                AS   (IS)+               ; 08e0 cd
                LR   $6,A                ; 08e1 56
				; r7 = r7 + 0x19
				; o77 = the same
                LR   A,$7                ; 08e2 47
                AI   $19                 ; 08e3 24 19
                LR   $7,A                ; 08e5 57
                LR   (IS)-,A             ; 08e6 5e
				; r6 = r6 (+1 if r7+0x19 carried) + 0x36
				; o76 = the same
                LR   A,$6                ; 08e7 46
                LNK                      ; 08e8 19
                AI   $36                 ; 08e9 24 36
                LR   $6,A                ; 08eb 56
                LR   (IS)+,A             ; 08ec 5d
				; Reload ISAR
                LR   A,$8                ; 08ed 48
                LR   IS,A                ; 08ee 0b
				; Return
                POP                      ; 08ef 1c

; Menu
menu:          
				LR   K,P                 ; 08f0 08
				; set lower byte of waitloop counter
                LIS  $0                  ; 08f1 70
                LR   $1,A                ; 08f2 51
				; clear console buttons, load default state
                OUTS 0                   ; 08f3 b0
                INS  0                   ; 08f4 a0
                LR   $0,A                ; 08f5 50
				; set upper byte of waitloop counter
                LI   $af                 ; 08f6 20 af
                LR   $2,A                ; 08f8 52
				; roll rng
A08f9:          PI   roll_RNG               ; 08f9 28 08 c1
                DCI  $0853               ; 08fc 2a 08 53
				; Read console buttons
                LIS  $0                  ; 08ff 70
                OUTS 0                   ; 0900 b0
                INS  0                   ; 0901 a0
				; Check if different
                XS   $0                  ; 0902 e0
				; if not, decrement waitloop
                BT   4,A0907             ; 0903 84 03
				; return
A0905:          LR   $0,A                ; 0905 50
                PK                       ; 0906 0c
				; 16-bit waitloop
A0907:          DS   $1                  ; 0907 31
                BF   $4,A08f9            ; 0908 94 f0
                DS   $2                  ; 090a 32
                BF   $4,A08f9            ; 090b 94 ed
				; Default to game mode 1 (1 player, easy)
                LIS  $1                  ; 090d 71
				; return
                BF   $0,A0905            ; 090e 90 f6
				
; Read controllers
; Args 
; Locals
; r0
; Return
; 070 - Controller 1
; 071 - Controller 2
readControllers:          
				LISU 7                   ; 0910 67
                LISL 0                   ; 0911 68
                ; Clear controllers
				LIS  $0                  ; 0912 70
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
                BT   4,A0923             ; 091c 84 06
				; else, shuffle RNG ?
				; switch to o77
                LISL 7                   ; 091e 6f
                LIS  $1                  ; 091f 71
				; o77 = o77 + 1
                AS   (IS)                ; 0920 cc
                LR   (IS)-,A             ; 0921 5e
				; o76--
                DS   (IS)                ; 0922 3c
				; Return
A0923:          POP                      ; 0923 1c

; HandlePlayerMovement
playerHandler:          LR   K,P                 ; 0924 08
				; Read controllers
                PI   readControllers               ; 0925 28 09 10
				; Check if LSB of RNG is set
                LISU 7                   ; 0928 67
                LISL 7                   ; 0929 6f
                LIS  $1                  ; 092a 71
                NS   (IS)                ; 092b fc
                LIS  $0                  ; 092c 70
				; skip ahead if it is not set
                BF   $4,A0930            ; 092d 94 02
				
                LIS  $1                  ; 092f 71
A0930:          LR   $b,A                ; 0930 5b
				; r8 = 2
                LIS  $2                  ; 0931 72
                LR   $8,A                ; 0932 58
				; r0 = 0
A0933:          LIS  $0                  ; 0933 70
                LR   $0,A                ; 0934 50
				; r1 = xpos[r11]
                LR   A,$b                ; 0935 4b
                AI   $10                 ; 0936 24 10
                LR   IS,A                ; 0938 0b
                LR   A,(IS)              ; 0939 4c
                LR   $1,A                ; 093a 51
				; r2 = ypos[r11]
                LR   A,IS                ; 093b 0a
                AI   $0b                 ; 093c 24 0b
                LR   IS,A                ; 093e 0b
                LR   A,(IS)              ; 093f 4c
                LR   $2,A                ; 0940 52
				; if((r11 & 0x01) == 0)
				;  ISAR = 70 (controller 1 ?)
				; else
				;  ISAR = 71 (controller 2 ?)
                LISU 7                   ; 0941 67
                LIS  $1                  ; 0942 71
                NS   $b                  ; 0943 fb
                LISL 1                   ; 0944 69
                BF   $4,A0948            ; 0945 94 02
                LISL 0                   ; 0947 68
				; Check if a direction is pressed
A0948:          LIS  $1                  ; 0948 71
                NS   (IS)                ; 0949 fc
                BF   $4,A0951            ; 094a 94 06
                ;
				LR   A,$1                ; 094c 41
                NI   $7f                 ; 094d 21 7f
                BF   $0,A0958            ; 094f 90 08
				; Check if a different direction is pressed
A0951:          LIS  $2                  ; 0951 72
                NS   (IS)                ; 0952 fc
                BF   $4,A095c            ; 0953 94 08
                LR   A,$1                ; 0955 41
                OI   $80                 ; 0956 22 80				
A0958:          LR   $1,A                ; 0958 51
				LIS  $c                  ; 0959 7c
                NS   $a                  ; 095a fa
                LR   $0,A                ; 095b 50
				; Check if a direction is pressed
A095c:          LIS  $4                  ; 095c 74
                NS   (IS)                ; 095d fc
                BF   $4,A0965            ; 095e 94 06
                LR   A,$2                ; 0960 42
                NI   $3f                 ; 0961 21 3f
                BF   $0,A096c            ; 0963 90 08
				; Check if a direction is pressed
A0965:          LIS  $8                  ; 0965 78
                NS   (IS)                ; 0966 fc
                BF   $4,A0973            ; 0967 94 0b
                LR   A,$2                ; 0969 42
                OI   $80                 ; 096a 22 80
A096c:          LR   $2,A                ; 096c 52
				; ??
                LIS  $c                  ; 096d 7c
                NS   $a                  ; 096e fa
                SR   1                   ; 096f 12
                SR   1                   ; 0970 12
                AS   $0                  ; 0971 c0
                LR   $0,A                ; 0972 50
A0973:          LR   A,$0                ; 0973 40
                SL   4                   ; 0974 15
                AS   $0                  ; 0975 c0
                LR   $0,A                ; 0976 50
				; What ?
                PI   A09a2               ; 0977 28 09 a2
                LIS  $1                  ; 097a 71
                NS   $b                  ; 097b fb
                LIS  $0                  ; 097c 70
                BF   $4,A0980            ; 097d 94 02
                LIS  $1                  ; 097f 71
A0980:          LR   $b,A                ; 0980 5b
                DS   $8                  ; 0981 38
                BF   $4,A0933            ; 0982 94 b0
                LR   P,K                 ; 0984 09
                POP                      ; 0985 1c
; --?
				
; Variable delay function
				; Load the DC
variableDelay:          DCI  A082d               ; 0986 2a 08 2d
				; Temp store the ISAR in r3
                LR   A,IS                ; 0989 0a
                LR   $3,A                ; 098a 53
				; Check if bit 1 of o75 is set
                LISU 7                   ; 098b 67
                LISL 5                   ; 098c 6d
                LIS  $2                  ; 098d 72
                NS   (IS)                ; 098e fc
				; Reload the ISAR from its temp register
                LR   A,$3                ; 098f 43
                LR   IS,A                ; 0990 0b
				; Branch ahead if it was not set
                BT   4,A0996             ; 0991 84 04
				; Else, load a different DC
                DCI  A0838               ; 0993 2a 08 38
				; Add the offset in r0 to the data counter
A0996:          LR   A,$0                ; 0996 40
                ADC                      ; 0997 8e
				; Save the contents of the array to r0
                LM                       ; 0998 16
                LR   $0,A                ; 0999 50
				; Two byte waitloop
delay:          LIS  $0                  ; 099a 70
A099b:          INC                      ; 099b 1f
                BF   $4,A099b            ; 099c 94 fe
                DS   $0                  ; 099e 30
                BF   $4,delay            ; 099f 94 fa
				; Return
                POP                      ; 09a1 1c

; Args
; r0 = ??
; r1 = xpos
; r2 = ypos
; rb = index
; Clobber
; r3 ?
A09a2:          
				; xpos[b] = r1
				LI   $10                 ; 09a2 20 10
                AS   $b                  ; 09a4 cb
                LR   IS,A                ; 09a5 0b
                LR   A,$1                ; 09a6 41
                LR   (IS),A              ; 09a7 5c
                ; ypos[b] = r2
				LR   A,IS                ; 09a8 0a
                AI   $0b                 ; 09a9 24 0b
                LR   IS,A                ; 09ab 0b
                LR   A,$2                ; 09ac 42
                LR   (IS),A              ; 09ad 5c
				; set velocity according to some formula
                LR   A,$b                ; 09ae 4b
                SR   1                   ; 09af 12
                AI   $26                 ; 09b0 24 26
                LR   IS,A                ; 09b2 0b
                LIS  $1                  ; 09b3 71
                NS   $b                  ; 09b4 fb
                LIS  $f                  ; 09b5 7f
                BF   $4,A09b9            ; 09b6 94 02
                COM                      ; 09b8 18
A09b9:          LR   $3,A                ; 09b9 53
                COM                      ; 09ba 18
                NS   (IS)                ; 09bb fc
                LR   (IS),A              ; 09bc 5c
                LR   A,$0                ; 09bd 40
                NS   $3                  ; 09be f3
                AS   (IS)                ; 09bf cc
                LR   (IS),A              ; 09c0 5c
				; exit
                POP                      ; 09c1 1c

; Spawn ball?
A09c2:          LR   K,P                 ; 09c2 08
A09c3:          ; keep rerolling RNG until r6 and r7 are in some range
				; r1 = r6, r2 = r7
				PI   roll_RNG               ; 09c3 28 08 c1
                LR   A,$6                ; 09c6 46
                CI   $10                 ; 09c7 25 10
                BT   2,A09c3             ; 09c9 82 f9
                CI   $57                 ; 09cb 25 57
                BF   $2,A09c3            ; 09cd 92 f5
                LR   $1,A                ; 09cf 51
                LR   A,$7                ; 09d0 47
                CI   $10                 ; 09d1 25 10
                BT   2,A09c3             ; 09d3 82 ef
                CI   $37                 ; 09d5 25 37
                BF   $2,A09c3            ; 09d7 92 eb
                LR   $2,A                ; 09d9 52
				; r0 = 0x55
                LI   $55                 ; 09da 20 55
                LR   $0,A                ; 09dc 50
				; use lower 2 bits of r6 as index to jump table
                LIS  $3                  ; 09dd 73
                NS   $6                  ; 09de f6
				; jump to (jump_table + 2*A)
                DCI  A09e6               ; 09df 2a 09 e6
                ADC                      ; 09e2 8e
                ADC                      ; 09e3 8e
                LR   Q,DC                ; 09e4 0e
                LR   P0,Q                ; 09e5 0d
; Jump table !
A09e6:          BF   $0,A09ee            ; 09e6 90 07
                BF   $0,A09f3            ; 09e8 90 0a
                BF   $0,A09fe            ; 09ea 90 13
                BF   $0,A0a09            ; 09ec 90 1c
				
				; r2 = 0x11
A09ee:          LI   $11                 ; 09ee 20 11
                LR   $2,A                ; 09f0 52
                BF   $0,A0a0c            ; 09f1 90 1a
				
				; r1 = -((0x30 & reg_a) >> 4) + 0xD8
A09f3:          LI   $30                 ; 09f3 20 30
                NS   $a                  ; 09f5 fa
                SR   4                   ; 09f6 14
                COM                      ; 09f7 18
                INC                      ; 09f8 1f
                AI   $d8                 ; 09f9 24 d8
                LR   $1,A                ; 09fb 51
                BF   $0,A0a0c            ; 09fc 90 0f
				
				; r2 = -((0x30 & reg_a) >> 4) + 0xB8
A09fe:          LI   $30                 ; 09fe 20 30
                NS   $a                  ; 0a00 fa
                SR   4                   ; 0a01 14
                COM                      ; 0a02 18
                INC                      ; 0a03 1f
                AI   $b8                 ; 0a04 24 b8
                LR   $2,A                ; 0a06 52
                BF   $0,A0a0c            ; 0a07 90 04
				
				; r1 = 0x11
A0a09:          LI   $11                 ; 0a09 20 11
                LR   $1,A                ; 0a0b 51

				; if (reg_b <= 1) skip ahead
A0a0c:          LR   A,$b                ; 0a0c 4b
                CI   $01                 ; 0a0d 25 01
                BF   $2,A0a1b            ; 0a0f 92 0b
				; r2 = 0x23
                LI   $23                 ; 0a11 20 23
                LR   $2,A                ; 0a13 52
				; if (reg_b != 0)
				;  r1 = 0x33
				; else r1 = 0x33 + 0x07
                LI   $33                 ; 0a14 20 33
                BF   $4,A0a1a            ; 0a16 94 03
                AI   $07                 ; 0a18 24 07
A0a1a:          LR   $1,A                ; 0a1a 51
				; Save xpos and ypos
A0a1b:          PI   A09a2               ; 0a1b 28 09 a2
				; Exit
                LR   P,K                 ; 0a1e 09
                POP                      ; 0a1f 1c

				
; Update score
drawTimer:          
				LR   K,P                 ; 0a20 08
                ; Update score display (ones)
				 ; Load x pos from r0 to r1
				LR   A,$0                ; 0a21 40
                LR   $1,A                ; 0a22 51
                 ; y pos
				LI   $0a                 ; 0a23 20 0a
                AS   $2                  ; 0a25 c2
                LR   $2,A                ; 0a26 52
				 ; Set glyph
                LI   $0f                 ; 0a27 20 0f
                NS   (IS)                ; 0a29 fc
                LR   $0,A                ; 0a2a 50
				 ; Width
                LIS  $4                  ; 0a2b 74
                LR   $4,A                ; 0a2c 54
				 ; Height
                LIS  $5                  ; 0a2d 75
                LR   $5,A                ; 0a2e 55
                PI   drawGlyph               ; 0a2f 28 08 58
				
                ; Update score display (tens)
				 ; Set glyph
				LR   A,(IS)-             ; 0a32 4e
                SR   4                   ; 0a33 14
                LR   $0,A                ; 0a34 50
				 ; Subtract 5 from x pos
                LI   $fb                 ; 0a35 20 fb
                AS   $1                  ; 0a37 c1
                LR   $1,A                ; 0a38 51
                PI   drawGlyph               ; 0a39 28 08 58
				
				; Update score display (hundreds)
				 ; Set glyph
                LR   A,(IS)              ; 0a3c 4c
                NI   $0f                 ; 0a3d 21 0f
                LR   $0,A                ; 0a3f 50
				 ; Subtract 5 from x pos
                LI   $fb                 ; 0a40 20 fb
                AS   $1                  ; 0a42 c1
                LR   $1,A                ; 0a43 51
                PI   drawGlyph               ; 0a44 28 08 58
				
				; Update score display (thousands)
				 ; Load glyph
                LR   A,(IS)              ; 0a47 4c
                SR   4                   ; 0a48 14
                LR   $0,A                ; 0a49 50
				 ; Subtract 5 from x pos
                LI   $fb                 ; 0a4a 20 fb
                AS   $1                  ; 0a4c c1
                LR   $1,A                ; 0a4d 51
                PI   drawGlyph               ; 0a4e 28 08 58
				; Exit
                LR   P,K                 ; 0a51 09
                POP                      ; 0a52 1c

; Do thing
; reg_b (r11 or o13) - Index of thing to finangle
handleBall:
				LR   K,P                 ; 0a53 08
				; load x pos of thing
                LI   $10                 ; 0a54 20 10
                AS   $b                  ; 0a56 cb
                LR   IS,A                ; 0a57 0b
                LR   A,(IS)              ; 0a58 4c
                LR   $1,A                ; 0a59 51
				; load y pos of thing from $1b + index
                LR   A,IS                ; 0a5a 0a
                AI   $0b                 ; 0a5b 24 0b
                LR   IS,A                ; 0a5d 0b
                LR   A,(IS)              ; 0a5e 4c
                LR   $9,A                ; 0a5f 59
                NI   $3f                 ; 0a60 21 3f
                LR   $2,A                ; 0a62 52
				; Load size of thing from o70
                LISU 7                   ; 0a63 67
                LISL 0                   ; 0a64 68
                LR   A,(IS)              ; 0a65 4c
                LR   $4,A                ; 0a66 54
                LR   $5,A                ; 0a67 55
				; Color?
                LI   $80                 ; 0a68 20 80
                LR   $0,A                ; 0a6a 50
				; Undraw player
                PI   drawBox               ; 0a6b 28 08 62
				
				; reload ypos
                LR   A,$9                ; 0a6e 49
                LR   $2,A                ; 0a6f 52
				
				; get bitpacked velocity ?
				; ISAR = o46 + index/2
                LR   A,$b                ; 0a70 4b
                SR   1                   ; 0a71 12
                AI   $26                 ; 0a72 24 26
                LR   IS,A                ; 0a74 0b
				
				; if (index is odd)
				;  r6 = $0F
				; else
				;  r6 = $F0
                LIS  $1                  ; 0a75 71
                NS   $b                  ; 0a76 fb
                LIS  $f                  ; 0a77 7f
                BF   $4,A0a7b            ; 0a78 94 02
                COM                      ; 0a7a 18
A0a7b:          LR   $6,A                ; 0a7b 56
				; store one nybble in r0
                COM                      ; 0a7c 18
                NS   (IS)                ; 0a7d fc
                LR   $0,A                ; 0a7e 50
				; store the other nybble in r3
                LR   A,$6                ; 0a7f 46
                NS   (IS)                ; 0a80 fc
                LR   $3,A                ; 0a81 53
				; if the desired nybble is the upper nybble
				; shift it right 4 and then store in r3
                SR   4                   ; 0a82 14
                BT   4,A0a86             ; 0a83 84 02
                LR   $3,A                ; 0a85 53
A0a86:          
				; xpos = xpos + xvel ?
				LIS  $0                  ; 0a86 70
                AS   $1                  ; 0a87 c1
                LR   J,W                 ; 0a88 1e
                ; a = r3/4
				LR   A,$3                ; 0a89 43
                SR   1                   ; 0a8a 12
                SR   1                   ; 0a8b 12
                LR   W,J                 ; 0a8c 1d
                ; if r1 was negative, branch ahead
				BT   1,A0a91             ; 0a8d 81 03
				; else, take the 2's complement
                COM                      ; 0a8f 18
                INC                      ; 0a90 1f
A0a91:          ; r1 = r1 + a
				AS   $1                  ; 0a91 c1
                LR   $1,A                ; 0a92 51
				
				; Do the same with ypos ?
                LIS  $0                  ; 0a93 70
                AS   $2                  ; 0a94 c2
                LR   J,W                 ; 0a95 1e
                LIS  $3                  ; 0a96 73
                NS   $3                  ; 0a97 f3
                LR   W,J                 ; 0a98 1d
                BT   1,A0a9d             ; 0a99 81 03
                COM                      ; 0a9b 18
                INC                      ; 0a9c 1f
A0a9d:          
				AS   $2                  ; 0a9d c2
                LR   $2,A                ; 0a9e 52
				
			; Ball/Wall collision detection
				; if (reg_b <= 1)
				;  r4 = o61
				; else
				;  r4 = o60
                LISU 6                   ; 0a9f 66
                LISL 0                   ; 0aa0 68
                LR   A,$b                ; 0aa1 4b
                CI   $01                 ; 0aa2 25 01
                BF   $2,A0aa7            ; 0aa4 92 02
				
                LISL 1                   ; 0aa6 69
A0aa7:          LR   A,(IS)              ; 0aa7 4c
                LR   $4,A                ; 0aa8 54
				; r5 = (previous isar reg + 3)
                LR   A,IS                ; 0aa9 0a
                AI   $03                 ; 0aaa 24 03
                LR   IS,A                ; 0aac 0b
                LR   A,(IS)              ; 0aad 4c
                LR   $5,A                ; 0aae 55
                ; Clear r0
				LIS  $0                  ; 0aaf 70
                LR   $0,A                ; 0ab0 50
				; if r1 is positive, branch ahead
                AS   $1                  ; 0ab1 c1
                BF   $1,A0acb            ; 0ab2 91 18
                AS   $4                  ; 0ab4 c4
                BF   $2,A0adf            ; 0ab5 92 29
				
                LR   A,$4                ; 0ab7 44
                COM                      ; 0ab8 18
                INC                      ; 0ab9 1f
                AI   $80                 ; 0aba 24 80
                LR   $1,A                ; 0abc 51
                LI   $40                 ; 0abd 20 40
                LR   $3,A                ; 0abf 53
                PI   bumpSound               ; 0ac0 28 0c c8
				
A0ac3:          LISU 7                   ; 0ac3 67
                LISL 1                   ; 0ac4 69
                LR   A,(IS)              ; 0ac5 4c
                SL   1                   ; 0ac6 13
                SL   1                   ; 0ac7 13
                LR   $0,A                ; 0ac8 50
                BF   $0,A0adf            ; 0ac9 90 15

A0acb:          LR   A,$1                ; 0acb 41
                NI   $7f                 ; 0acc 21 7f
                COM                      ; 0ace 18
                INC                      ; 0acf 1f
                LISU 6                   ; 0ad0 66
                LISL 2                   ; 0ad1 6a
                AS   (IS)                ; 0ad2 cc
                BF   $2,A0adf            ; 0ad3 92 0b
				
                LR   A,(IS)              ; 0ad5 4c
                LR   $1,A                ; 0ad6 51
                LI   $40                 ; 0ad7 20 40
                LR   $3,A                ; 0ad9 53
                PI   bumpSound               ; 0ada 28 0c c8
                BF   $0,A0ac3            ; 0add 90 e5

A0adf:          LIS  $0                  ; 0adf 70
                AS   $2                  ; 0ae0 c2
                BF   $1,A0afb            ; 0ae1 91 19
                NI   $3f                 ; 0ae3 21 3f
                AS   $5                  ; 0ae5 c5
                BF   $2,A0b0e            ; 0ae6 92 27
				
                LR   A,$5                ; 0ae8 45
                COM                      ; 0ae9 18
                INC                      ; 0aea 1f
                AI   $80                 ; 0aeb 24 80
                LR   $2,A                ; 0aed 52
                LI   $40                 ; 0aee 20 40
                LR   $3,A                ; 0af0 53
                PI   bumpSound               ; 0af1 28 0c c8
				
A0af4:          LISU 7                   ; 0af4 67
                LISL 1                   ; 0af5 69
                LR   A,(IS)              ; 0af6 4c
                AS   $0                  ; 0af7 c0
                LR   $0,A                ; 0af8 50
                BF   $0,A0b0e            ; 0af9 90 14
				
A0afb:          LISU 6                   ; 0afb 66
                NI   $3f                 ; 0afc 21 3f
                COM                      ; 0afe 18
                INC                      ; 0aff 1f
                LISL 5                   ; 0b00 6d
                AS   (IS)                ; 0b01 cc
                BF   $2,A0b0e            ; 0b02 92 0b
				
                LR   A,(IS)              ; 0b04 4c
                LR   $2,A                ; 0b05 52
                LI   $40                 ; 0b06 20 40
                LR   $3,A                ; 0b08 53
                PI   bumpSound               ; 0b09 28 0c c8
                BF   $0,A0af4            ; 0b0c 90 e7
			; ?--
A0b0e:          LR   A,$0                ; 0b0e 40
                SL   4                   ; 0b0f 15
                AS   $0                  ; 0b10 c0
                LR   $0,A                ; 0b11 50
                LR   A,$b                ; 0b12 4b
                SR   1                   ; 0b13 12
                AI   $26                 ; 0b14 24 26
                LR   IS,A                ; 0b16 0b
                LIS  $1                  ; 0b17 71
                NS   $b                  ; 0b18 fb
                LIS  $f                  ; 0b19 7f
                BF   $4,A0b1d            ; 0b1a 94 02
				
                COM                      ; 0b1c 18
A0b1d:          LR   $7,A                ; 0b1d 57
                COM                      ; 0b1e 18
                LR   $6,A                ; 0b1f 56
                NS   (IS)                ; 0b20 fc
                LR   $4,A                ; 0b21 54
                LR   A,$7                ; 0b22 47
                NS   (IS)                ; 0b23 fc
                LR   $5,A                ; 0b24 55
                LI   $33                 ; 0b25 20 33
                NS   $0                  ; 0b27 f0
                BT   4,A0b35             ; 0b28 84 0c
				
                LI   $cc                 ; 0b2a 20 cc
                NS   $7                  ; 0b2c f7
                NS   $5                  ; 0b2d f5
                LR   $5,A                ; 0b2e 55
                LI   $33                 ; 0b2f 20 33
                NS   $0                  ; 0b31 f0
                AS   $5                  ; 0b32 c5
                NS   $7                  ; 0b33 f7
                LR   $5,A                ; 0b34 55
A0b35:          LI   $cc                 ; 0b35 20 cc
                NS   $0                  ; 0b37 f0
                BT   4,A0b45             ; 0b38 84 0c
				
                LI   $33                 ; 0b3a 20 33
                NS   $7                  ; 0b3c f7
                NS   $5                  ; 0b3d f5
                LR   $5,A                ; 0b3e 55
                LI   $cc                 ; 0b3f 20 cc
                NS   $0                  ; 0b41 f0
                AS   $5                  ; 0b42 c5
                NS   $7                  ; 0b43 f7
                LR   $5,A                ; 0b44 55
A0b45:          LR   A,$5                ; 0b45 45
                AS   $4                  ; 0b46 c4
                LR   $0,A                ; 0b47 50
                PI   A09a2               ; 0b48 28 09 a2
				
                DCI  A0850               ; 0b4b 2a 08 50
                LR   A,$b                ; 0b4e 4b
                CI   $01                 ; 0b4f 25 01
                LIS  $2                  ; 0b51 72
                BF   $2,A0b55            ; 0b52 92 02
				
                LR   A,$b                ; 0b54 4b
A0b55:          ADC                      ; 0b55 8e
                LR   A,$2                ; 0b56 42
                NI   $7f                 ; 0b57 21 7f
                OM                       ; 0b59 8b
                LR   $2,A                ; 0b5a 52
                LI   $80                 ; 0b5b 20 80
                LR   $0,A                ; 0b5d 50
                LISU 7                   ; 0b5e 67
                LISL 0                   ; 0b5f 68
                LR   A,(IS)              ; 0b60 4c
                LR   $4,A                ; 0b61 54
                LR   $5,A                ; 0b62 55
                LISU 7                   ; 0b63 67
                LISL 2                   ; 0b64 6a
                LIS  $0                  ; 0b65 70
                AS   (IS)                ; 0b66 cc
                BF   $1,A0b6c            ; 0b67 91 04
				
				; Redraw thing
                PI   drawBox               ; 0b69 28 08 62
				; Return
A0b6c:          LR   P,K                 ; 0b6c 09
                POP                      ; 0b6d 1c

; Collision detection ?
; Args
;  r11 - Current ball ?
;
; Clobbers
; 071 - Used as a loop counter
ballCollision:          LR   K,P                 ; 0b6e 08
				; setting up the collision loop counter
				; 071 = (num_balls(??) & 0x0F) + 1
                LISU 5                   ; 0b6f 65
                LISL 7                   ; 0b70 6f
                LI   $0f                 ; 0b71 20 0f
                NS   (IS)                ; 0b73 fc
                LISU 7                   ; 0b74 67
                LISL 1                   ; 0b75 69
                INC                      ; 0b76 1f
                LR   (IS),A              ; 0b77 5c
				; loop_counter--
A0b78:          LISU 7                   ; 0b78 67
                LISL 1                   ; 0b79 69
                DS   (IS)                ; 0b7a 3c
				; if(loop_counter == 0), return
                BF   $1,A0b6c            ; 0b7b 91 f0
				; if(loop_counter == current_ball), return
                LR   A,(IS)              ; 0b7d 4c
                XS   $b                  ; 0b7e eb
                BT   4,A0b78             ; 0b7f 84 f8
				
				; Check if we're in 2-player mode
                LISL 5                   ; 0b81 6d
                LIS  $1                  ; 0b82 71
                NS   (IS)                ; 0b83 fc
				; If so, skip ahead
                BF   $4,A0b8c            ; 0b84 94 07
				; If not, check if the current ball is player 2
                LISL 1                   ; 0b86 69
                LR   A,(IS)              ; 0b87 4c
                CI   $01                 ; 0b88 25 01
				; If so, skip the current ball
                BT   4,A0b78             ; 0b8a 84 ed
				; r1 = xpos[current_ball]
A0b8c:          LI   $10                 ; 0b8c 20 10
                AS   $b                  ; 0b8e cb
                LR   IS,A                ; 0b8f 0b
                LR   A,(IS)              ; 0b90 4c
                NI   $7f                 ; 0b91 21 7f
                LR   $1,A                ; 0b93 51
				; r2 = ypos[current_ball]
                LR   A,IS                ; 0b94 0a
                AI   $0b                 ; 0b95 24 0b
                LR   IS,A                ; 0b97 0b
                LR   A,(IS)              ; 0b98 4c
                NI   $3f                 ; 0b99 21 3f
                LR   $2,A                ; 0b9b 52
				; do some sort of check with xpos[loop_counter]
                LISU 7                   ; 0b9c 67
                LISL 1                   ; 0b9d 69
                LI   $10                 ; 0b9e 20 10
                AS   (IS)                ; 0ba0 cc
                LR   IS,A                ; 0ba1 0b
                LR   A,(IS)              ; 0ba2 4c
                NI   $7f                 ; 0ba3 21 7f
                COM                      ; 0ba5 18
                INC                      ; 0ba6 1f
                AS   $1                  ; 0ba7 c1
                LR   J,W                 ; 0ba8 1e
                BT   1,A0bad             ; 0ba9 81 03
				
                COM                      ; 0bab 18
                INC                      ; 0bac 1f
A0bad:          LR   $1,A                ; 0bad 51
                LR   A,IS                ; 0bae 0a
				; Check if workin on a player ball ?
                CI   $11                 ; 0baf 25 11
                BF   $2,A0bbd            ; 0bb1 92 0b
				
                LR   W,J                 ; 0bb3 1d
                BF   $1,A0bbd            ; 0bb4 91 08
				
                LI   $c0                 ; 0bb6 20 c0
                NS   $a                  ; 0bb8 fa
                SR   1                   ; 0bb9 12
                SR   1                   ; 0bba 12
                BF   $0,A0bc0            ; 0bbb 90 04
				
A0bbd:          LI   $30                 ; 0bbd 20 30
                NS   $a                  ; 0bbf fa
A0bc0:          SR   4                   ; 0bc0 14
                COM                      ; 0bc1 18
                INC                      ; 0bc2 1f
                AS   $1                  ; 0bc3 c1
				; If so, restart loop
                BT   1,A0b78             ; 0bc4 81 b3
				; do check with ypos[loop_counter] ??
                LR   A,IS                ; 0bc6 0a
                AI   $0b                 ; 0bc7 24 0b
                LR   IS,A                ; 0bc9 0b
                LR   A,(IS)              ; 0bca 4c
                NI   $3f                 ; 0bcb 21 3f
                COM                      ; 0bcd 18
                INC                      ; 0bce 1f
                AS   $2                  ; 0bcf c2
                LR   J,W                 ; 0bd0 1e
                BT   1,A0bd5             ; 0bd1 81 03
				
                COM                      ; 0bd3 18
                INC                      ; 0bd4 1f
A0bd5:          LR   $2,A                ; 0bd5 52
                LR   A,IS                ; 0bd6 0a
                CI   $1c                 ; 0bd7 25 1c
                BF   $2,A0be5            ; 0bd9 92 0b
				
                LR   W,J                 ; 0bdb 1d
                BF   $1,A0be5            ; 0bdc 91 08
                LI   $c0                 ; 0bde 20 c0
                NS   $a                  ; 0be0 fa
                SR   1                   ; 0be1 12
                SR   1                   ; 0be2 12
                BF   $0,A0be8            ; 0be3 90 04
				
A0be5:          LI   $30                 ; 0be5 20 30
                NS   $a                  ; 0be7 fa
A0be8:          SR   4                   ; 0be8 14
                COM                      ; 0be9 18
                INC                      ; 0bea 1f
                AS   $2                  ; 0beb c2
				; If so, restart loop
                BT   1,A0b78             ; 0bec 81 8b
				
				; Check if the collision was with a player
				;  If so, game over
				;  Else, skip ahead
                LISU 7                   ; 0bee 67
                LISL 1                   ; 0bef 69
                LR   A,(IS)              ; 0bf0 4c
                CI   $01                 ; 0bf1 25 01
                BF   $2,A0bf8            ; 0bf3 92 04
				; Game over
                JMP  A0e44               ; 0bf5 29 0e 44
				
A0bf8:          LI   $80                 ; 0bf8 20 80
                LR   $3,A                ; 0bfa 53
                PI   bumpSound               ; 0bfb 28 0c c8
                PI   roll_RNG               ; 0bfe 28 08 c1
				
                LR   A,$2                ; 0c01 42
                CI   $01                 ; 0c02 25 01
                BT   2,A0c41             ; 0c04 82 3c
				
                LI   $10                 ; 0c06 20 10
                AS   $b                  ; 0c08 cb
                LR   IS,A                ; 0c09 0b
                LI   $80                 ; 0c0a 20 80
                NS   $6                  ; 0c0c f6
                XS   (IS)                ; 0c0d ec
                LR   (IS),A              ; 0c0e 5c
                LR   J,W                 ; 0c0f 1e
                LISU 7                   ; 0c10 67
                LISL 1                   ; 0c11 69
                LI   $10                 ; 0c12 20 10
                AS   (IS)                ; 0c14 cc
                LR   IS,A                ; 0c15 0b
                LI   $80                 ; 0c16 20 80
                NS   $7                  ; 0c18 f7
                AS   (IS)                ; 0c19 cc
                LR   (IS),A              ; 0c1a 5c
                LI   $44                 ; 0c1b 20 44
                LR   $8,A                ; 0c1d 58
                LR   A,$b                ; 0c1e 4b
                LR   $0,A                ; 0c1f 50
				
A0c20:          LISU 7                   ; 0c20 67
                LISL 5                   ; 0c21 6d
                LIS  $0                  ; 0c22 70
                AS   (IS)                ; 0c23 cc
                BT   1,A0c29             ; 0c24 81 04
                ; If so, restart loop
				JMP  A0b78               ; 0c26 29 0b 78
				
A0c29:          LR   A,$0                ; 0c29 40
                SR   1                   ; 0c2a 12
                AI   $26                 ; 0c2b 24 26
                LR   IS,A                ; 0c2d 0b
                LIS  $1                  ; 0c2e 71
                NS   $0                  ; 0c2f f0
                LIS  $f                  ; 0c30 7f
                BF   $4,A0c34            ; 0c31 94 02
				
                COM                      ; 0c33 18
A0c34:          LR   $3,A                ; 0c34 53
                COM                      ; 0c35 18
                NS   (IS)                ; 0c36 fc
                LR   $4,A                ; 0c37 54
                LR   A,$3                ; 0c38 43
                NS   (IS)                ; 0c39 fc
                AS   $8                  ; 0c3a c8
                NS   $3                  ; 0c3b f3
                AS   $4                  ; 0c3c c4
                LR   (IS),A              ; 0c3d 5c
				; Exit
                JMP  A0b6c               ; 0c3e 29 0b 6c
				
A0c41:          LISU 7                   ; 0c41 67
                LISL 1                   ; 0c42 69
                LR   A,(IS)              ; 0c43 4c
                LR   $0,A                ; 0c44 50
                AI   $1b                 ; 0c45 24 1b
                LR   IS,A                ; 0c47 0b
                LI   $80                 ; 0c48 20 80
                XS   (IS)                ; 0c4a ec
                LR   (IS),A              ; 0c4b 5c
                LR   J,W                 ; 0c4c 1e
                LI   $1b                 ; 0c4d 20 1b
                AS   $b                  ; 0c4f cb
                LR   IS,A                ; 0c50 0b
                LR   A,(IS)              ; 0c51 4c
                OI   $80                 ; 0c52 22 80
                LR   W,J                 ; 0c54 1d
                BT   1,A0c59             ; 0c55 81 03
                
				NI   $3f                 ; 0c57 21 3f
A0c59:          LR   (IS),A              ; 0c59 5c
                LI   $44                 ; 0c5a 20 44
                LR   $8,A                ; 0c5c 58
                BF   $0,A0c20            ; 0c5d 90 c2
; End collision routine

; Set playfield bounds?
; Args
;  r1 - ??
;  r2 - 
;  r4 -
;  r10 - ??
; Clobbers
;  r6 - via RNG call
;  r7 - via RNG call
;  ISAR[x] to ISAR[x+2]
A0c5f:          LR   K,P                 ; 0c5f 08
				; Reroll RNG until r6 is non-zero
A0c60:          PI   roll_RNG               ; 0c60 28 08 c1
                LIS  $0                  ; 0c63 70
                AS   $6                  ; 0c64 c6
                BT   4,A0c60             ; 0c65 84 fa
				; if(r1 == 0x58)
				;  if(r6 < 0x0B)
				;   go back and reroll
				; else if(r6 < 0x12)
				;   go back and reroll
                LR   A,$1                ; 0c67 41
                CI   $58                 ; 0c68 25 58
                LR   A,$6                ; 0c6a 46
                BF   $4,A0c71            ; 0c6b 94 05
                CI   $12                 ; 0c6d 25 12
                BF   $0,A0c73            ; 0c6f 90 03
A0c71:          CI   $0b                 ; 0c71 25 0b
A0c73:          BF   $2,A0c60            ; 0c73 92 ec
				; r4 = -(-r6+1+r1)
                COM                      ; 0c75 18
                INC                      ; 0c76 1f
                INC                      ; 0c77 1f
                AS   $1                  ; 0c78 c1
                COM                      ; 0c79 18
                INC                      ; 0c7a 1f
                LR   $4,A                ; 0c7b 54
				; ISAR++ = ((reg_a & 0x30) >> 4) + r4
                LI   $30                 ; 0c7c 20 30
                NS   $a                  ; 0c7e fa
                SR   4                   ; 0c7f 14
                AS   $4                  ; 0c80 c4
                LR   (IS)+,A             ; 0c81 5d
				; ISAR++ = ((reg_a & 0xC0) >> 6) + r4
                LI   $c0                 ; 0c82 20 c0
                NS   $a                  ; 0c84 fa
                SR   4                   ; 0c85 14
                SR   1                   ; 0c86 12
                SR   1                   ; 0c87 12
                AS   $4                  ; 0c88 c4
                LR   (IS)+,A             ; 0c89 5d
				; ISAR++ = r6 + r2
                LR   A,$6                ; 0c8a 46
                AS   $2                  ; 0c8b c2
                LR   (IS)+,A             ; 0c8c 5d
                LR   P,K                 ; 0c8d 09
                POP                      ; 0c8e 1c

; Screen Flash!
;  Unused code ?
                LR   K,P                 ; 0c8f 08
				; r9 = 0x25
                LI   $25                 ; 0c90 20 25
                LR   $9,A                ; 0c92 59
				; if((071 & 0x01) == 0)
				;  070 = 0x80
				;  r2 = 0x80
				; else
				;  070 = 0xC0
				;  r2 = 0xC0
                LISU 7                   ; 0c93 67
                LISL 1                   ; 0c94 69
                LIS  $1                  ; 0c95 71
                NS   (IS)-               ; 0c96 fe
                LI   $80                 ; 0c97 20 80
                BT   4,A0c9d             ; 0c99 84 03
				LI   $c0                 ; 0c9b 20 c0
A0c9d:          LR   (IS),A              ; 0c9d 5c
                LR   $2,A                ; 0c9e 52
				; Load ypos for rendering
A0c9f:          LR   A,(IS)              ; 0c9f 4c
A0ca0:          LR   $2,A                ; 0ca0 52
				; Make sound
                LR   A,(IS)              ; 0ca1 4c
                LR   $3,A                ; 0ca2 53
                PI   bumpSound               ; 0ca3 28 0c c8
                LISL 0                   ; 0ca6 68
				; Set xpos to attribute column
                LI   $7d                 ; 0ca7 20 7d
                LR   $1,A                ; 0ca9 51
				; Set width
                LIS  $2                  ; 0caa 72
                LR   $4,A                ; 0cab 54
				; Set height
                LI   $40                 ; 0cac 20 40
                LR   $5,A                ; 0cae 55
				; Set rendering properties
                LI   $c0                 ; 0caf 20 c0
                LR   $0,A                ; 0cb1 50
                PI   drawBox             ; 0cb2 28 08 62
				
				; Clear sound
                LIS  $0                  ; 0cb5 70
                OUTS 5                   ; 0cb6 b5
				; Delay
                LIS  $b                  ; 0cb7 7b
                LR   $0,A                ; 0cb8 50
                PI   delay               ; 0cb9 28 09 9a
				; r9--
                DS   $9                  ; 0cbc 39
				; exit if r9 is negative
                BF   $1,A0cc6            ; 0cbd 91 08
				; If r9 is even, jump back and reload r2 from ISAR
                LIS  $1                  ; 0cbf 71
                NS   $9                  ; 0cc0 f9
                LIS  $0                  ; 0cc1 70
                BT   4,A0c9f             ; 0cc2 84 dc
				; Else set r2 to 0
                BF   $0,A0ca0            ; 0cc4 90 db
				; Return
A0cc6:          LR   P,K                 ; 0cc6 09
                POP                      ; 0cc7 1c

; Play ticking sound when bumping into a wall
; rb - Index of the ball (don't let players make noise?)
; r3 - Sound to be played
bumpSound:          LR   A,$b                ; 0cc8 4b
				; if (rb <= 1)
				;  return
                CI   $01                 ; 0cc9 25 01
                BT   2,A0ccf             ; 0ccb 82 03
				; else
				;  play sound
                LR   A,$3                ; 0ccd 43
                OUTS 5                   ; 0cce b5
				; return
A0ccf:          POP                      ; 0ccf 1c

; Init Game
initRoutine:    LISU 7                   ; 0cd0 67
                LISL 7                   ; 0cd1 6f
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
                LIS  $0                  ; 0cda 70
                LR   (IS),A              ; 0cdb 5c
				; Clear port
                OUTS 0                   ; 0cdc b0
				
				; Clear screen
				; Set properties
                LI   $80                 ; 0cdd 20 80
                LR   $0,A                ; 0cdf 50
				; Set x and y pos
                LIS  $0                  ; 0ce0 70
                LR   $1,A                ; 0ce1 51
                LR   $2,A                ; 0ce2 52
				; Set width
                LI   $80                 ; 0ce3 20 80
                LR   $4,A                ; 0ce5 54
				; Set height
                LI   $40                 ; 0ce6 20 40
                LR   $5,A                ; 0ce8 55
                PI   drawBox               ; 0ce9 28 08 62
				
				; Clear screen attributes
				; Set rendering properties (& color?)
                LI   $c0                 ; 0cec 20 c0
                LR   $0,A                ; 0cee 50
                LR   $2,A                ; 0cef 52
				; Set width
                LIS  $2                  ; 0cf0 72
                LR   $4,A                ; 0cf1 54
				; xpos = attribute column
                LI   $7d                 ; 0cf2 20 7d
                LR   $1,A                ; 0cf4 51
                PI   drawBox               ; 0cf5 28 08 62

	; Prep the G ? screen
				; Draw the G
				 ; Set the glyph
                LIS  $a                  ; 0cf8 7a
                LR   $0,A                ; 0cf9 50
				 ; x pos?
                LI   $30                 ; 0cfa 20 30
                LR   $1,A                ; 0cfc 51
				 ; y pos?
                LI   $9b                 ; 0cfd 20 9b
                LR   $2,A                ; 0cff 52
				 ; width?
                LIS  $4                  ; 0d00 74
                LR   $4,A                ; 0d01 54
				 ; height?
                LIS  $5                  ; 0d02 75
                LR   $5,A                ; 0d03 55
                PI   drawGlyph               ; 0d04 28 08 58

				; Draw the ?
				 ; Set the glyph
                LIS  $b                  ; 0d07 7b
                LR   $0,A                ; 0d08 50
				 ; x pos?
                LI   $35                 ; 0d09 20 35
                LR   $1,A                ; 0d0b 51
                PI   drawGlyph               ; 0d0c 28 08 58
				; Menu
                PI   menu               ; 0d0f 28 08 f0
				; Load game mode into o75
                LISU 7                   ; 0d12 67
                LISL 5                   ; 0d13 6d
                SR   1                   ; 0d14 12
                ADC                      ; 0d15 8e
                LM                       ; 0d16 16
                LR   (IS),A              ; 0d17 5c
				
; Shuffle gametype
A0d18:          LISU 7                   ; 0d18 67
                LISL 5                   ; 0d19 6d
                LR   A,(IS)              ; 0d1a 4c
                NI   $03                 ; 0d1b 21 03
                LR   (IS),A              ; 0d1d 5c

A0d1e:          DCI  A0843               ; 0d1e 2a 08 43
                PI   roll_RNG               ; 0d21 28 08 c1
				
                LM                       ; 0d24 16
                NS   $6                  ; 0d25 f6
                LR   $8,A                ; 0d26 58
                LM                       ; 0d27 16
                NS   $6                  ; 0d28 f6
                SL   1                   ; 0d29 13
                SL   1                   ; 0d2a 13
                AS   $8                  ; 0d2b c8
                BF   $2,A0d1e            ; 0d2c 92 f1
				
                LM                       ; 0d2e 16
                NS   $6                  ; 0d2f f6
                BT   4,A0d1e             ; 0d30 84 ed
				
                LM                       ; 0d32 16
                NS   $6                  ; 0d33 f6
                BT   4,A0d1e             ; 0d34 84 e9
				
                LR   A,$6                ; 0d36 46
                LR   $a,A                ; 0d37 5a
                LM                       ; 0d38 16
                NS   $7                  ; 0d39 f7
                AS   (IS)                ; 0d3a cc
                LR   (IS)-,A             ; 0d3b 5e

                DCI  A0848               ; 0d3c 2a 08 48
                LIS  $3                  ; 0d3f 73
                NS   $a                  ; 0d40 fa
                SL   1                   ; 0d41 13
                ADC                      ; 0d42 8e
                LI   $58                 ; 0d43 20 58
                LR   $1,A                ; 0d45 51
                LI   $10                 ; 0d46 20 10
                LR   $2,A                ; 0d48 52
                LISU 6                   ; 0d49 66
                LISL 0                   ; 0d4a 68
                PI   A0c5f               ; 0d4b 28 0c 5f
				
                LI   $38                 ; 0d4e 20 38
                LR   $1,A                ; 0d50 51
                PI   A0c5f               ; 0d51 28 0c 5f
				
restartGame:          
			; Draw playfield
				; Set rendering properties
				LI   $80                 ; 0d54 20 80
                LR   $0,A                ; 0d56 50
				; Set x pos
                LI   $10                 ; 0d57 20 10
                LR   $1,A                ; 0d59 51
				; Set ypos and color
                AI   $80                 ; 0d5a 24 80
                LR   $2,A                ; 0d5c 52
				; Set width
                LI   $49                 ; 0d5d 20 49
                LR   $4,A                ; 0d5f 54
				; Set height
                LI   $29                 ; 0d60 20 29
                LR   $5,A                ; 0d62 55
				; Draw box
                PI   drawBox               ; 0d63 28 08 62
				
			; Draw inner box
				; xpos = o62
                LISU 6                   ; 0d66 66
                LISL 2                   ; 0d67 6a
                LR   A,(IS)              ; 0d68 4c
                LR   $1,A                ; 0d69 51
				; width = -(o62 + o60)
                LISL 0                   ; 0d6a 68
                AS   (IS)                ; 0d6b cc
                COM                      ; 0d6c 18
                INC                      ; 0d6d 1f
                LR   $4,A                ; 0d6e 54
				; set width
                LI   $30                 ; 0d6f 20 30
                NS   $a                  ; 0d71 fa
                SR   4                   ; 0d72 14
                LR   $3,A                ; 0d73 53
                AS   $4                  ; 0d74 c4
                LR   $4,A                ; 0d75 54
				; set ypos
                LISL 5                   ; 0d76 6d
                LR   A,(IS)              ; 0d77 4c
                LR   $2,A                ; 0d78 52
				; set height
                LISL 3                   ; 0d79 6b
                AS   (IS)                ; 0d7a cc
                COM                      ; 0d7b 18
                INC                      ; 0d7c 1f
                AS   $3                  ; 0d7d c3
                LR   $5,A                ; 0d7e 55
				; Set rendering properties
                LI   $80                 ; 0d7f 20 80
                LR   $0,A                ; 0d81 50
                PI   drawBox               ; 0d82 28 08 62
				
				; Clear timer
                LISU 6                   ; 0d85 66
                LISL 6                   ; 0d86 6e
                LIS  $0                  ; 0d87 70
                LR   (IS)+,A             ; 0d88 5d
                LR   (IS)+,A             ; 0d89 5d

				; Do something for 2 balls?
                LIS  $0                  ; 0d8a 70
A0d8b:          LR   $b,A                ; 0d8b 5b
                PI   A09c2               ; 0d8c 28 09 c2
                LR   A,$b                ; 0d8f 4b
                INC                      ; 0d90 1f
                CI   $01                 ; 0d91 25 01
                BT   2,A0d8b             ; 0d93 82 f7

				; o56 = num_balls?
                LISU 5                   ; 0d95 65
                LISL 6                   ; 0d96 6e
                LR   (IS),A              ; 0d97 5c
                LR   $b,A                ; 0d98 5b
                PI   A09c2               ; 0d99 28 09 c2
				
                LISU 7                   ; 0d9c 67
                LISL 2                   ; 0d9d 6a
                LIS  $0                  ; 0d9e 70
                LR   (IS),A              ; 0d9f 5c
; MAIN LOOP ?
				; Clear sound
mainLoop:          LIS  $0                  ; 0da0 70
                OUTS 5                   ; 0da1 b5
				
				; Change num ball according to timer?
                LISU 6                   ; 0da2 66
                LISL 6                   ; 0da3 6e
                LR   A,(IS)+             ; 0da4 4d
                INC                      ; 0da5 1f
                CI   $0a                 ; 0da6 25 0a
                BT   2,A0dab             ; 0da8 82 02
                LIS  $a                  ; 0daa 7a
A0dab:          LISU 5                   ; 0dab 65
                LR   (IS),A              ; 0dac 5c
                LISU 6                   ; 0dad 66

				; Increment 16-bit BCD timer
				; ISAR is 067 here
				; BCD increment
				LI   $67                 ; 0dae 20 67
                ASD  (IS)                ; 0db0 dc
                LR   (IS)-,A             ; 0db1 5e
                BF   $2,A0dc5            ; 0db2 92 12
				; Continue if tens carry over				
                LI   $67                 ; 0db4 20 67
                ASD  (IS)                ; 0db6 dc
                LR   (IS)+,A             ; 0db7 5d
                NI   $0f                 ; 0db8 21 0f
                BF   $4,A0dc5            ; 0dba 94 0a
				; Continue if hundreds are zero				
                LIS  $0                  ; 0dbc 70
                AS   (IS)                ; 0dbd cc
                BF   $4,A0dc5            ; 0dbe 94 06
				; Continue if tens and ones are both zero
				; o72 = 0x80 ; Set explosion flag
                LISU 7                   ; 0dc0 67
                LISL 2                   ; 0dc1 6a
                LI   $80                 ; 0dc2 20 80
                LR   (IS),A              ; 0dc4 5c

A0dc5:          ; Display timer
				; Check if 1 or 2 player
				LISU 7                   ; 0dc5 67
                LISL 5                   ; 0dc6 6d
                LIS  $1                  ; 0dc7 71
                NS   (IS)                ; 0dc8 fc
				; Display in middle if 2 player mode
                LI   $39                 ; 0dc9 20 39
                BF   $4,A0dcf            ; 0dcb 94 03
				; Display to left if 1 player mode
                LI   $1f                 ; 0dcd 20 1f
A0dcf:          LR   $0,A                ; 0dcf 50
				; Set y pos
                LI   $80                 ; 0dd0 20 80
                LR   $2,A                ; 0dd2 52
				; Set ISAR to LSB of score
                LISU 6                   ; 0dd3 66
                LISL 7                   ; 0dd4 6f
                PI   drawTimer               ; 0dd5 28 0a 20
				
                LISU 5                   ; 0dd8 65
                LISL 7                   ; 0dd9 6f
                LR   A,(IS)              ; 0dda 4c
                LR   $0,A                ; 0ddb 50
				; Wait
                PI   variableDelay               ; 0ddc 28 09 86
                ; rb = o56 (ball count)
				LISU 5                   ; 0ddf 65
                LISL 6                   ; 0de0 6e
                LI   $0f                 ; 0de1 20 0f
                NS   (IS)+               ; 0de3 fd
                LR   $b,A                ; 0de4 5b
                LR   A,(IS)              ; 0de5 4c
                COM                      ; 0de6 18
                INC                      ; 0de7 1f
                AS   $b                  ; 0de8 cb
                BT   1,A0df7             ; 0de9 81 0d
				
                LR   A,(IS)              ; 0deb 4c
                LR   $b,A                ; 0dec 5b
                PI   A09c2               ; 0ded 28 09 c2
				
                LISU 5                   ; 0df0 65
                LISL 6                   ; 0df1 6e
                LI   $f0                 ; 0df2 20 f0
                NS   (IS)+               ; 0df4 fd
                AS   (IS)-               ; 0df5 ce
                LR   (IS),A              ; 0df6 5c
A0df7:          LISU 5                   ; 0df7 65
                LISL 6                   ; 0df8 6e
                LI   $0f                 ; 0df9 20 0f
                NS   (IS)                ; 0dfb fc
                LR   $b,A                ; 0dfc 5b
A0dfd:          LISU 7                   ; 0dfd 67
                LISL 0                   ; 0dfe 68
                LI   $30                 ; 0dff 20 30
                NS   $a                  ; 0e01 fa
                SR   4                   ; 0e02 14
                LR   (IS)+,A             ; 0e03 5d
                LI   $03                 ; 0e04 20 03
                NS   $a                  ; 0e06 fa
                LR   (IS),A              ; 0e07 5c
                PI   handleBall          ; 0e08 28 0a 53
				; Collision ?
                PI   ballCollision               ; 0e0b 28 0b 6e
				
                DS   $b                  ; 0e0e 3b
                LR   A,$b                ; 0e0f 4b
                CI   $01                 ; 0e10 25 01
                BF   $2,A0dfd            ; 0e12 92 ea
				
                PI   playerHandler               ; 0e14 28 09 24
				
                LISU 7                   ; 0e17 67
                LISL 0                   ; 0e18 68
                LI   $c0                 ; 0e19 20 c0
                NS   $a                  ; 0e1b fa
                SR   4                   ; 0e1c 14
                SR   1                   ; 0e1d 12
                SR   1                   ; 0e1e 12
                LR   (IS)+,A             ; 0e1f 5d
                LI   $0c                 ; 0e20 20 0c
                NS   $a                  ; 0e22 fa
                SR   1                   ; 0e23 12
                SR   1                   ; 0e24 12
                LR   (IS),A              ; 0e25 5c
                LI   $00                 ; 0e26 20 00
                LR   $b,A                ; 0e28 5b
                PI   handleBall               ; 0e29 28 0a 53
				
                LISU 7                   ; 0e2c 67
                LISL 5                   ; 0e2d 6d
                LIS  $1                  ; 0e2e 71
                NS   (IS)                ; 0e2f fc
                BT   4,A0e36             ; 0e30 84 05
				
                LR   $b,A                ; 0e32 5b
                PI   handleBall          ; 0e33 28 0a 53
				
				; Loop back to beginning if explosion flag isn't set
A0e36:          LISU 7                   ; 0e36 67
                LISL 2                   ; 0e37 6a
                LIS  $0                  ; 0e38 70
                AS   (IS)                ; 0e39 cc
                BT   1,A0e41             ; 0e3a 81 06
				; Clear explosion flag, and then explode
                LIS  $0                  ; 0e3c 70
                LR   (IS),A              ; 0e3d 5c
                JMP  explode               ; 0e3e 29 0f 6b
				; Loop back
A0e41:          JMP  mainLoop               ; 0e41 29 0d a0

; Game Over / Death Animation
A0e44:          
				; Set ypos ?
				LI   $a4                 ; 0e44 20 a4
                LR   $2,A                ; 0e46 52
                LISU 4                   ; 0e47 64
                LISL 6                   ; 0e48 6e
                LI   $14                 ; 0e49 20 14
                LR   (IS),A              ; 0e4b 5c
A0e4c:          PI   A0f0a               ; 0e4c 28 0f 0a
                LISU 4                   ; 0e4f 64
                LISL 6                   ; 0e50 6e
                DS   (IS)                ; 0e51 3c
                LR   J,W                 ; 0e52 1e
                LR   A,$2                ; 0e53 42
                AI   $40                 ; 0e54 24 40
                BF   $2,A0e5a            ; 0e56 92 03
                AI   $40                 ; 0e58 24 40
A0e5a:          NI   $c0                 ; 0e5a 21 c0
                AI   $24                 ; 0e5c 24 24
                LR   $2,A                ; 0e5e 52
                LR   W,J                 ; 0e5f 1d
                BF   $4,A0e4c            ; 0e60 94 eb
				
				; Delay
                LIS  $0                  ; 0e62 70
                LR   $0,A                ; 0e63 50
                PI   delay               ; 0e64 28 09 9a
				
                LISU 7                   ; 0e67 67
                LISL 5                   ; 0e68 6d
                LIS  $1                  ; 0e69 71
                NS   (IS)                ; 0e6a fc
                LI   $80                 ; 0e6b 20 80
                BT   4,A0e78             ; 0e6d 84 0a
                LISL 1                   ; 0e6f 69
                LIS  $1                  ; 0e70 71
                NS   (IS)                ; 0e71 fc
                LI   $c0                 ; 0e72 20 c0
                BT   4,A0e78             ; 0e74 84 03
                LI   $40                 ; 0e76 20 40
A0e78:          AI   $24                 ; 0e78 24 24
                LR   $2,A                ; 0e7a 52
                LISU 4                   ; 0e7b 64
                LISL 6                   ; 0e7c 6e
                LI   $14                 ; 0e7d 20 14
                LR   (IS),A              ; 0e7f 5c
                PI   A0f0a               ; 0e80 28 0f 0a
				
				; Delay
                LI   $28                 ; 0e83 20 28
                LR   $0,A                ; 0e85 50
                PI   delay               ; 0e86 28 09 9a
				
				; Check if two players
                LISU 7                   ; 0e89 67
                LISL 5                   ; 0e8a 6d
                LIS  $1                  ; 0e8b 71
                NS   (IS)                ; 0e8c fc
				; If so, jump ahead
                BF   $4,A0ec6            ; 0e8d 94 38
		; One player case
				; r6/r7 = timer
                LISU 6                   ; 0e8f 66
                LISL 6                   ; 0e90 6e
                LR   A,(IS)+             ; 0e91 4d
                LR   $6,A                ; 0e92 56
                LR   A,(IS)              ; 0e93 4c
                LR   $7,A                ; 0e94 57
                ; If timer >= hi_score
				;  then replace hi_score
				LISU 5                   ; 0e95 65
                LISL 4                   ; 0e96 6c
                LR   A,(IS)+             ; 0e97 4d
                COM                      ; 0e98 18
                INC                      ; 0e99 1f
                AS   $6                  ; 0e9a c6
                BF   $1,A0eb2            ; 0e9b 91 16
                BF   $4,A0ea5            ; 0e9d 94 07
                LR   A,(IS)              ; 0e9f 4c
                COM                      ; 0ea0 18
                INC                      ; 0ea1 1f
                AS   $7                  ; 0ea2 c7
                BF   $1,A0eb2            ; 0ea3 91 0e

				; Draw score
A0ea5:          LR   A,$7                ; 0ea5 47
                LR   (IS)-,A             ; 0ea6 5e
                LR   A,$6                ; 0ea7 46
                LR   (IS)+,A             ; 0ea8 5d
				; Set y pos
                LI   $40                 ; 0ea9 20 40
                LR   $2,A                ; 0eab 52
				; Set x pos
                LI   $54                 ; 0eac 20 54
                LR   $0,A                ; 0eae 50
                PI   drawTimer               ; 0eaf 28 0a 20
				
				; Delay
A0eb2:          LI   $40                 ; 0eb2 20 40
                LR   $0,A                ; 0eb4 50
                PI   delay               ; 0eb5 28 09 9a
				; Read controllers
                PI   readControllers               ; 0eb8 28 09 10
				; If controller is pushed, keep gametype?
                LISL 0                   ; 0ebb 68
                LIS  $0                  ; 0ebc 70
                AS   (IS)                ; 0ebd cc
                BF   $1,A0ec3            ; 0ebe 91 04
                JMP  restartGame               ; 0ec0 29 0d 54
				; Shuffle gametype
A0ec3:          JMP  A0d18               ; 0ec3 29 0d 18

		; Two player case
A0ec6:          ; r6/r7 = timer
				LISU 6                   ; 0ec6 66
                LISL 6                   ; 0ec7 6e
                LR   A,(IS)+             ; 0ec8 4d
                LR   $6,A                ; 0ec9 56
                LR   A,(IS)              ; 0eca 4c
                LR   $7,A                ; 0ecb 57
				
                LISU 7                   ; 0ecc 67
                LISL 1                   ; 0ecd 69
                LIS  $1                  ; 0ece 71
                NS   (IS)                ; 0ecf fc
                BF   $4,A0edc            ; 0ed0 94 0b
				; set ypos (or maybe color?)
                LI   $c0                 ; 0ed2 20 c0
                LR   $2,A                ; 0ed4 52
                ; set xpos
				LI   $54                 ; 0ed5 20 54
                LR   $0,A                ; 0ed7 50
                LISU 7                   ; 0ed8 67
                LISL 4                   ; 0ed9 6c
                BF   $0,A0ee4            ; 0eda 90 09
				
A0edc:          LISU 5                   ; 0edc 65
                LISL 5                   ; 0edd 6d
				; set ypos (or maybe color?)
                LI   $40                 ; 0ede 20 40
                LR   $2,A                ; 0ee0 52
				; set xpos
                LI   $1f                 ; 0ee1 20 1f
                LR   $0,A                ; 0ee3 50
				
A0ee4:          LR   A,$7                ; 0ee4 47
                AS   (IS)                ; 0ee5 cc
                LR   (IS),A              ; 0ee6 5c
                LI   $66                 ; 0ee7 20 66
                ASD  (IS)                ; 0ee9 dc
                LR   (IS)-,A             ; 0eea 5e
                BF   $2,A0ef1            ; 0eeb 92 05
				
                LI   $67                 ; 0eed 20 67
                ASD  (IS)                ; 0eef dc
                LR   (IS),A              ; 0ef0 5c
A0ef1:          LR   A,(IS)              ; 0ef1 4c
                AS   $6                  ; 0ef2 c6
                LR   (IS),A              ; 0ef3 5c
                LI   $66                 ; 0ef4 20 66
                ASD  (IS)                ; 0ef6 dc
                LR   (IS)+,A             ; 0ef7 5d
                PI   drawTimer           ; 0ef8 28 0a 20 ; Score display
				; Read controllers
                PI   readControllers               ; 0efb 28 09 10
                ; If neither player is touching anything, shuffle gametype
				LISL 0                   ; 0efe 68
                LIS  $0                  ; 0eff 70
                AS   (IS)+               ; 0f00 cd
                BF   $1,A0ec3            ; 0f01 91 c1
                LIS  $0                  ; 0f03 70
                AS   (IS)                ; 0f04 cc
                BF   $1,A0ec3            ; 0f05 91 bd
				; Else, just restart the current game
                JMP  restartGame               ; 0f07 29 0d 54

; Death animation ?
; Draw Box
; r1 - X pos
; r2 - Y pos + something else?
; r4 - Width
; r5 - Height
A0f0a:          
				LR   K,P                 ; 0f0a 08
				; Set something ?
                LI   $80                 ; 0f0b 20 80
                LR   $0,A                ; 0f0d 50
				; Set x pos
				; Where does y pos get set?
                LI   $34                 ; 0f0e 20 34
                LR   $1,A                ; 0f10 51
                LISU 2                   ; 0f11 62
                LISL 4                   ; 0f12 6c
				; Set width/height to 1
                LIS  $1                  ; 0f13 71
                LR   $4,A                ; 0f14 54
                LR   $5,A                ; 0f15 55
				; Set o24, o25, o26, o27 to 1
                LR   (IS)+,A             ; 0f16 5d
                LR   (IS)+,A             ; 0f17 5d
                LR   (IS)+,A             ; 0f18 5d
                LR   (IS)-,A             ; 0f19 5e
				; o36 = o46 ?
                LISU 4                   ; 0f1a 64
                LR   A,(IS)              ; 0f1b 4c
                LISU 3                   ; 0f1c 63
                LR   (IS),A              ; 0f1d 5c
				; isar = o26
                LISU 2                   ; 0f1e 62
				; a = 2
                LIS  $1                  ; 0f1f 71
                SL   1                   ; 0f20 13
                LR   J,W                 ; 0f21 1e ; save flags
                ; Draw
				PI   drawBox               ; 0f22 28 08 62
A0f25: ; plot up         
				; ypos = ypos - 1
				DS   $2                  ; 0f25 32
                PI   drawBox               ; 0f26 28 08 62
				; o26 = o26 - 1
                DS   (IS)                ; 0f29 3c
				; Loop until o26 reaches 0
                BF   $4,A0f25            ; 0f2a 94 fa
				
                LR   W,J                 ; 0f2c 1d ; restore flags
                ; goto exit if zero flag is set
				BT   4,A0f69             ; 0f2d 84 3b
				; o27 = o27 + 1
                LR   A,(IS)+             ; 0f2f 4d
                LR   A,(IS)              ; 0f30 4c
                INC                      ; 0f31 1f
                LR   (IS)-,A             ; 0f32 5e
				; o26 = o27
                LR   (IS)-,A             ; 0f33 5e
A0f34: ; plot right         
				; xpos++
				LR   A,$1                ; 0f34 41
                INC                      ; 0f35 1f
                LR   $1,A                ; 0f36 51
				; plot
                PI   drawBox               ; 0f37 28 08 62
                ; o25--
				DS   (IS)                ; 0f3a 3c
				; loop until o25 reaches 0
                BF   $4,A0f34            ; 0f3b 94 f8
				; Clear sound
                LIS  $0                  ; 0f3d 70
                OUTS 5                   ; 0f3e b5
				; o24 = o24 + 1
                LR   A,(IS)-             ; 0f3f 4e
                LR   A,(IS)              ; 0f40 4c
                INC                      ; 0f41 1f
                LR   (IS)+,A             ; 0f42 5d
				; o25 = o24
                LR   (IS)+,A             ; 0f43 5d
A0f44: ; plot down ?
				; ypos++
				LR   A,$2                ; 0f44 42
                INC                      ; 0f45 1f
                LR   $2,A                ; 0f46 52
				; plot
                PI   drawBox               ; 0f47 28 08 62
				; o26-- ?
                DS   (IS)                ; 0f4a 3c
				
                BF   $4,A0f44            ; 0f4b 94 f8
                LR   A,(IS)+             ; 0f4d 4d
                LR   A,(IS)              ; 0f4e 4c
                INC                      ; 0f4f 1f
                LR   (IS)-,A             ; 0f50 5e
                LR   (IS)-,A             ; 0f51 5e
A0f52: ; plot left ?
				; xpos--
				DS   $1                  ; 0f52 31
				; plot
                PI   drawBox               ; 0f53 28 08 62
                DS   (IS)                ; 0f56 3c
                BF   $4,A0f52            ; 0f57 94 fa
                LR   A,(IS)-             ; 0f59 4e
                LR   A,(IS)              ; 0f5a 4c
                INC                      ; 0f5b 1f
                LR   (IS)+,A             ; 0f5c 5d
                LR   (IS)+,A             ; 0f5d 5d
				
                LISU 3                   ; 0f5e 63
                DS   (IS)                ; 0f5f 3c
                LISU 2                   ; 0f60 62
                LR   J,W                 ; 0f61 1e ; reload flags
				; Play sound ?
                LR   A,$2                ; 0f62 42
                OUTS 5                   ; 0f63 b5

                BF   $4,A0f25            ; 0f64 94 c0

                DS   (IS)                ; 0f66 3c
                BF   $0,A0f25            ; 0f67 90 bd
				; Return
A0f69:          LR   P,K                 ; 0f69 09
                POP                      ; 0f6a 1c

; Explode every time the timer reaches 1000		
explode:          
			; Set xpos of all balls
				; set ISAR to 0x12
				LIS  $2                  ; 0f6b 72
                AI   $10                 ; 0f6c 24 10
                LR   IS,A                ; 0f6e 0b
				; r0 = 9
                LIS  $9                  ; 0f6f 79
                LR   $0,A                ; 0f70 50
				; (ISAR) = (0x80 & (ISAR)) + 0x30
A0f71:          LI   $80                 ; 0f71 20 80
                NS   (IS)                ; 0f73 fc
                AI   $30                 ; 0f74 24 30
                LR   (IS),A              ; 0f76 5c
				;ISAR++
                LR   A,IS                ; 0f77 0a
                INC                      ; 0f78 1f
                LR   IS,A                ; 0f79 0b
				; r0--
                DS   $0                  ; 0f7a 30
				; if r0 != 0, loop back
                BF   $4,A0f71            ; 0f7b 94 f5

				; ISAR += 2
                LR   A,IS                ; 0f7d 0a
                AI   $02                 ; 0f7e 24 02
                LR   IS,A                ; 0f80 0b
				
			; Set ypos of all balls
				; r0 = 9
                LIS  $9                  ; 0f81 79
                LR   $0,A                ; 0f82 50
				; (ISAR) = ((ISAR) & 0x80) + 0x22
A0f83:          LI   $80                 ; 0f83 20 80
                NS   (IS)                ; 0f85 fc
                AI   $22                 ; 0f86 24 22
                LR   (IS),A              ; 0f88 5c
				; ISAR++
                LR   A,IS                ; 0f89 0a
                INC                      ; 0f8a 1f
                LR   IS,A                ; 0f8b 0b
				; r0--
                DS   $0                  ; 0f8c 30
				; if r0 != 0, loop back
                BF   $4,A0f83            ; 0f8d 94 f5
				
				; (ISAR) = reg_a, ISAR++, (ISAR) = reg_a
                LR   A,$a                ; 0f8f 4a
                LR   (IS)+,A             ; 0f90 5d
                LR   (IS)+,A             ; 0f91 5d
				
				; Clear top bit of game mode
                LISU 7                   ; 0f92 67
                LISL 5                   ; 0f93 6d
                LR   A,(IS)              ; 0f94 4c
                SL   1                   ; 0f95 13
                SR   1                   ; 0f96 12
                LR   (IS),A              ; 0f97 5c
				; Exit
                JMP  mainLoop               ; 0f98 29 0d a0
				
    db $b2 ; Unused?
	; Free space
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
; EoF