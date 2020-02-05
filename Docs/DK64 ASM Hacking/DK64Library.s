;************************************
; DK64 Library
;************************************

;************************************
; ENUMS
;************************************
;Buttons [0x80014DC4]
[L_Button]: 0x0020
[D_Up]: 0x0800		;check this
[D_Down]: 0x0400
[D_Left]: 0x0200
[D_Right]: 0x0100

;************************************
; ADDRESSES
;************************************
[DestinationMap]: 0x807444E4
[DestinationEntrance]: 0x807444E8

[SecurityText]: 0x8075E5DC
[SecurityByte]: 0x807552E0
[ControllerInput]: 0x80014DC4

[ZipperBitfield]: 0x807FBB62

[NewlyPressed]: 0x807ECD48
[ButtonHeld]: 0x807ECD58

[TinyHelmTSB]: 0x807FCAA0		;Tiny Helm T&S Bananas
[TinyIslesTSB]: 0x807FCA9E		;Tiny Isles T&S Bananas

;************************************
; CUSTOM CODE
;************************************
LA		at, EndOfFile
JR		at
;************************************
; SetSecurityByte
; ra -> (int*) return_address
; return -> void
;************************************
SetSecurityByte:
LI      t0, 1
SB      t0, @SecurityByte
JR		ra

;************************************
; ForceZipper
; t0 -> (byte) destination_map
; t1 -> (byte) destination_entrance
; ra -> (int*) return_address
; return -> void
;************************************
ForceZipper:
LA		at, @DestinationMap
SW      t0, 0x00(at)

LA		at, @DestinationEntrance
SW		t1, 0x00(at)

LA      t3, @ZipperBitfield
LB      at, 0x00(t3)
ORI     t2, at, 0x01
SB      t2, 0x00(t3)
JR		ra
NOP

;************************************
; CheckInput
; t0 -> (short) desired_input
; ra -> (int*) return_address
; return -> (boolean) t1 -> input_matched
;************************************
CheckInput:
LH      t1, @ControllerInput
BEQ		t1, t0, ReturnFromCheckInput
NOP
LI		t1, 0x0
ReturnFromCheckInput:
JR		ra

;************************************
; LCheck
; ra -> (int*) return_address
; return -> (boolean) t1 -> L_pressed
;************************************
LCheck:
LI      t0, @L_Button
ADDI	t2, ra, 0x0					;t2 = ra (temp)
LA		ra, ReturnFromLCheck
B		CheckInput
NOP
ReturnFromLCheck:
ADDI	ra, t2, 0x0					;ra = t2 (original ra)
JR		ra

;************************************
; DLeftCheck
; ra -> (int*) return_address
; return -> (boolean) t1 -> L_pressed
;************************************
DLeftCheck:
LI      t0, @D_Left
ADDI	t2, ra, 0x0					;t2 = ra (temp)
LA		ra, ReturnFromDLeftCheck
B		CheckInput
NOP
ReturnFromDLeftCheck:
ADDI	ra, t2, 0x0					;ra = t2 (original ra)
JR		ra

;************************************
; DRightCheck
; ra -> (int*) return_address
; return -> (boolean) t1 -> L_pressed
;************************************
DRightCheck:
LI      t0, @D_Right
ADDI	t2, ra, 0x0					;t2 = ra (temp)
LA		ra, ReturnFromDLeftCheck
B		CheckInput
NOP
ReturnFromDRightCheck:
ADDI	ra, t2, 0x0					;ra = t2 (original ra)
JR		ra

;************************************
; CheckNewlyPressed
; ra -> (int*) return_address
; return -> (boolean) t1 -> newly_pressed
;************************************
CheckNewlyPressed:
LI		t1, @NewlyPressed
LH		t1, 0x0(t1)
JR		ra

;************************************
; PrintToSecurityByte
; 
; ra -> (int*) return_address
; return ->
;************************************
;TODO

EndOfFile:
NOP