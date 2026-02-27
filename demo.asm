; Sega Master System bouncing ball demo
; Compatible with WLA-DX 10.6 (wla-z80 + wlalink)

.memorymap
  defaultslot 0
  slotsize $4000
  slot 0 $0000
  slot 1 $4000
  slot 2 $8000
.endme

.rombankmap
  bankstotal 1
  banksize $4000
  banks 1
.endro

.define VDP_DATA    $BE
.define VDP_CTRL    $BF

.define VRAM_WRITE  $4000
.define CRAM_WRITE  $C000

.define BALL_MAX_X  248
.define BALL_MAX_Y  183

.ramsection "WRAM" slot 2
  ball_x      db
  ball_y      db
  ball_vx     db
  ball_vy     db
  vblank_flag db
.ends

.bank 0 slot 0
.org $0000
  di
  jp Start

.org $0038
  jp VBlankIRQ

.org $0066
  retn

.org $0100
Start:
  di
  im 1
  ld sp, $DFF0

  xor a
  ld (vblank_flag), a

  call InitVDP
  call LoadPalette
  call LoadBallTile
  call ClearNameTable

  ld a, 120
  ld (ball_x), a
  ld a, 80
  ld (ball_y), a
  ld a, 1
  ld (ball_vx), a
  ld (ball_vy), a

  call UpdateSprite

  ei
MainLoop:
  call WaitVBlank
  call UpdateBall
  call UpdateSprite
  jr MainLoop

; ------------------------------------------------------------
; VBlank interrupt handler
; ------------------------------------------------------------
VBlankIRQ:
  push af
  in a, (VDP_CTRL)        ; acknowledge VDP interrupt
  ld a, 1
  ld (vblank_flag), a
  pop af
  ei
  reti

; ------------------------------------------------------------
WaitVBlank:
  halt
.wait:
  ld a, (vblank_flag)
  or a
  jr z, .wait
  xor a
  ld (vblank_flag), a
  ret

; ------------------------------------------------------------
; VDP init + display enable
; ------------------------------------------------------------
InitVDP:
  ; R0-R10
  ld hl, VDPRegs
  ld b, 11
  ld c, 0
.loop:
  ld a, (hl)
  out (VDP_CTRL), a
  ld a, c
  or $80
  out (VDP_CTRL), a
  inc hl
  inc c
  djnz .loop
  ret

LoadPalette:
  ld a, <CRAM_WRITE
  out (VDP_CTRL), a
  ld a, >CRAM_WRITE
  out (VDP_CTRL), a

  ; Color 0: black, Color 1: white, rest black
  ld a, $00
  out (VDP_DATA), a
  ld a, $3F
  out (VDP_DATA), a

  ld b, 30
  xor a
.clear:
  out (VDP_DATA), a
  djnz .clear
  ret

LoadBallTile:
  ld a, <VRAM_WRITE
  out (VDP_CTRL), a
  ld a, >VRAM_WRITE
  out (VDP_CTRL), a

  ld hl, BallTile
  ld b, 32
.loop:
  ld a, (hl)
  out (VDP_DATA), a
  inc hl
  djnz .loop
  ret

ClearNameTable:
  ld a, <$7800|$4000
  out (VDP_CTRL), a
  ld a, >$7800|$4000
  out (VDP_CTRL), a

  xor a
  ld bc, 32*28*2
.loop:
  out (VDP_DATA), a
  dec bc
  ld a, b
  or c
  jr nz, .loop
  ret

; ------------------------------------------------------------
UpdateBall:
  ; X += VX
  ld a, (ball_x)
  ld e, a
  ld a, (ball_vx)
  add a, e
  ld (ball_x), a

  cp BALL_MAX_X+1
  jr c, .checkLeftX
  ld a, BALL_MAX_X
  ld (ball_x), a
  ld a, -1
  ld (ball_vx), a
  jr .updateY

.checkLeftX:
  ld a, (ball_x)
  cp 0
  jr nz, .updateY
  ld a, 1
  ld (ball_vx), a

.updateY:
  ld a, (ball_y)
  ld e, a
  ld a, (ball_vy)
  add a, e
  ld (ball_y), a

  cp BALL_MAX_Y+1
  jr c, .checkTopY
  ld a, BALL_MAX_Y
  ld (ball_y), a
  ld a, -1
  ld (ball_vy), a
  ret

.checkTopY:
  ld a, (ball_y)
  cp 0
  ret nz
  ld a, 1
  ld (ball_vy), a
  ret

; ------------------------------------------------------------
; SMS sprite table format:
; base + 0..63   = Y list
; base + 128..   = X/tile pairs
; ------------------------------------------------------------
UpdateSprite:
  ; Y for sprite 0
  ld a, <$3F00|$4000
  out (VDP_CTRL), a
  ld a, >$3F00|$4000
  out (VDP_CTRL), a

  ld a, (ball_y)
  out (VDP_DATA), a
  ld a, 208              ; end marker
  out (VDP_DATA), a

  ; X + tile index for sprite 0
  ld a, <$3F80|$4000
  out (VDP_CTRL), a
  ld a, >$3F80|$4000
  out (VDP_CTRL), a

  ld a, (ball_x)
  out (VDP_DATA), a
  xor a                  ; tile index 0
  out (VDP_DATA), a
  ret

VDPRegs:
  .db $04                ; R0: Mode control 1
  .db $E0                ; R1: display on, VBlank IRQ on
  .db $0E                ; R2: name table at $3800
  .db $FF                ; R3: color table (unused in mode 4)
  .db $FF                ; R4: pattern table (unused in mode 4)
  .db $7E                ; R5: sprite attribute table at $3F00
  .db $00                ; R6: sprite pattern select
  .db $00                ; R7: backdrop color
  .db $00                ; R8: horizontal scroll
  .db $00                ; R9: vertical scroll
  .db $FF                ; R10: line counter

; 8x8 circle in color index 1.
BallTile:
  .db %00111100,0,0,0
  .db %01111110,0,0,0
  .db %11111111,0,0,0
  .db %11111111,0,0,0
  .db %11111111,0,0,0
  .db %11111111,0,0,0
  .db %01111110,0,0,0
  .db %00111100,0,0,0

; Pad to SMS header location ($7FF0)
.ds $7FF0-*

.org $7FF0
  .db "TMR SEGA"
  .db 0,0
  .db 0,0
  .db $4C, $00, $00, $00, $00, $00
