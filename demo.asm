; Sega Master System - Color Snake Demo (WLA-DX 10.6)

.memorymap
  defaultslot 0
  slotsize $8000
  slot 0 $0000
.endme

.rombankmap
  bankstotal 1
  banksize $8000
  banks 1
.endro

.define VDP_DATA      $BE
.define VDP_CTRL      $BF
.define JOY_PORT      $DC

.define DIR_RIGHT     0
.define DIR_LEFT      1
.define DIR_UP        2
.define DIR_DOWN      3

.define TILE_EMPTY    0
.define TILE_HEAD     1
.define TILE_BODY     2
.define TILE_FOOD     3
.define TILE_WALL     4
.define TILE_DIGIT0   16

.define PLAY_MIN_X    1
.define PLAY_MAX_X    30
.define PLAY_MIN_Y    3
.define PLAY_MAX_Y    22

.define NT_BASE_CMD_H $78
.define NT_BASE_CMD_L $00
.define SAT_Y_CMD_H   $7F
.define SAT_Y_CMD_L   $00

.enum $C000
  vblank_flag   dsb 1
  frame_div     dsb 1
  direction     dsb 1
  snake_len     dsb 1
  score         dsb 1
  food_x        dsb 1
  food_y        dsb 1
  rand_seed     dsb 1
  head_old_x    dsb 1
  head_old_y    dsb 1
  tail_old_x    dsb 1
  tail_old_y    dsb 1
  new_head_x    dsb 1
  new_head_y    dsb 1
  snake_x       dsb 64
  snake_y       dsb 64
.ende

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
  ld (frame_div), a
  ld (score), a

  ld a, $5A
  ld (rand_seed), a

  call InitVDP
  call ClearSprites
  call LoadPalette
  call LoadTiles
  call ClearNameTable
  call DrawBorder

  call InitSnake
  call SpawnFood
  call DrawFood
  call DrawScore
  call EnableDisplay

  ei
MainLoop:
  call WaitVBlank
  call ReadInput

  ld a, (frame_div)
  inc a
  ld (frame_div), a
  cp 6
  jr c, MainLoop
  xor a
  ld (frame_div), a

  call SnakeStep
  jr MainLoop

VBlankIRQ:
  push af
  in a, (VDP_CTRL)
  ld a, 1
  ld (vblank_flag), a
  pop af
  ei
  reti

WaitVBlank:
  halt
WaitVBlank_Loop:
  ld a, (vblank_flag)
  or a
  jr z, WaitVBlank_Loop
  xor a
  ld (vblank_flag), a
  ret

InitVDP:
  ld hl, VDPRegs
  ld b, 11
  ld c, 0
InitVDP_Loop:
  ld a, (hl)
  out (VDP_CTRL), a
  ld a, c
  or $80
  out (VDP_CTRL), a
  inc hl
  inc c
  djnz InitVDP_Loop
  ret

EnableDisplay:
  ld a, $E0
  out (VDP_CTRL), a
  ld a, $81
  out (VDP_CTRL), a
  ret

ClearSprites:
  ld a, SAT_Y_CMD_L
  out (VDP_CTRL), a
  ld a, SAT_Y_CMD_H
  out (VDP_CTRL), a
  ld a, 208
  out (VDP_DATA), a
  ret

LoadPalette:
  ; CRAM write address 0
  xor a
  out (VDP_CTRL), a
  ld a, $C0
  out (VDP_CTRL), a

  ; 0 black
  ld a, $00
  out (VDP_DATA), a
  ; 1 green
  ld a, $0C
  out (VDP_DATA), a
  ; 2 yellow
  ld a, $0F
  out (VDP_DATA), a
  ; 3 red
  ld a, $03
  out (VDP_DATA), a
  ; 4 blue
  ld a, $30
  out (VDP_DATA), a
  ; 5 white
  ld a, $3F
  out (VDP_DATA), a

  ; rest black
  ld b, 26
  xor a
LoadPalette_ClearLoop:
  out (VDP_DATA), a
  djnz LoadPalette_ClearLoop
  ret

LoadTiles:
  ; VRAM write address 0
  xor a
  out (VDP_CTRL), a
  ld a, $40
  out (VDP_CTRL), a

  ld hl, TileData
  ld bc, TileDataEnd-TileData
LoadTiles_Loop:
  ld a, (hl)
  out (VDP_DATA), a
  inc hl
  dec bc
  ld a, b
  or c
  jr nz, LoadTiles_Loop
  ret

ClearNameTable:
  ld a, NT_BASE_CMD_L
  out (VDP_CTRL), a
  ld a, NT_BASE_CMD_H
  out (VDP_CTRL), a

  xor a
  ld bc, 1792
ClearNameTable_Loop:
  out (VDP_DATA), a
  dec bc
  ld a, b
  or c
  jr nz, ClearNameTable_Loop
  ret

DrawBorder:
  ; top and bottom
  ld b, 0
DrawBorder_XLoop:
  ld c, 2
  ld a, TILE_WALL
  call PutTile
  ld c, 23
  ld a, TILE_WALL
  call PutTile
  inc b
  ld a, b
  cp 32
  jr c, DrawBorder_XLoop

  ; left and right
  ld c, 3
DrawBorder_YLoop:
  ld b, 0
  ld a, TILE_WALL
  call PutTile
  ld b, 31
  ld a, TILE_WALL
  call PutTile
  inc c
  ld a, c
  cp 23
  jr c, DrawBorder_YLoop
  ret

InitSnake:
  ld a, 3
  ld (snake_len), a
  ld a, DIR_RIGHT
  ld (direction), a

  ld a, 10
  ld (snake_x+0), a
  ld a, 10
  ld (snake_y+0), a

  ld a, 9
  ld (snake_x+1), a
  ld a, 10
  ld (snake_y+1), a

  ld a, 8
  ld (snake_x+2), a
  ld a, 10
  ld (snake_y+2), a

  ; draw head
  ld b, 10
  ld c, 10
  ld a, TILE_HEAD
  call PutTile

  ; draw body
  ld b, 9
  ld c, 10
  ld a, TILE_BODY
  call PutTile
  ld b, 8
  ld c, 10
  ld a, TILE_BODY
  call PutTile
  ret

ReadInput:
  in a, (JOY_PORT)

  bit 3, a
  jr nz, ReadInput_NoRight
  ld a, (direction)
  cp DIR_LEFT
  jr z, ReadInput_NoRight
  ld a, DIR_RIGHT
  ld (direction), a
  ret
ReadInput_NoRight:
  in a, (JOY_PORT)
  bit 2, a
  jr nz, ReadInput_NoLeft
  ld a, (direction)
  cp DIR_RIGHT
  jr z, ReadInput_NoLeft
  ld a, DIR_LEFT
  ld (direction), a
  ret
ReadInput_NoLeft:
  in a, (JOY_PORT)
  bit 0, a
  jr nz, ReadInput_NoUp
  ld a, (direction)
  cp DIR_DOWN
  jr z, ReadInput_NoUp
  ld a, DIR_UP
  ld (direction), a
  ret
ReadInput_NoUp:
  in a, (JOY_PORT)
  bit 1, a
  jr nz, ReadInput_Done
  ld a, (direction)
  cp DIR_UP
  jr z, ReadInput_Done
  ld a, DIR_DOWN
  ld (direction), a
ReadInput_Done:
  ret

SnakeStep:
  ; save old head
  ld a, (snake_x)
  ld (head_old_x), a
  ld a, (snake_y)
  ld (head_old_y), a

  ; save old tail
  ld a, (snake_len)
  dec a
  ld e, a
  ld d, 0
  ld hl, snake_x
  add hl, de
  ld a, (hl)
  ld (tail_old_x), a
  ld hl, snake_y
  add hl, de
  ld a, (hl)
  ld (tail_old_y), a

  ; compute new head in B,C
  ld a, (head_old_x)
  ld b, a
  ld a, (head_old_y)
  ld c, a
  ld a, (direction)
  cp DIR_RIGHT
  jr nz, SnakeStep_CheckLeft
  inc b
  jr SnakeStep_Moved
SnakeStep_CheckLeft:
  cp DIR_LEFT
  jr nz, SnakeStep_CheckUp
  dec b
  jr SnakeStep_Moved
SnakeStep_CheckUp:
  cp DIR_UP
  jr nz, SnakeStep_GoDown
  dec c
  jr SnakeStep_Moved
SnakeStep_GoDown:
  inc c

SnakeStep_Moved:
  ; wall collision
  ld a, b
  cp PLAY_MIN_X
  jp c, ResetGame
  cp PLAY_MAX_X+1
  jp nc, ResetGame
  ld a, c
  cp PLAY_MIN_Y
  jp c, ResetGame
  cp PLAY_MAX_Y+1
  jp nc, ResetGame

  ld a, b
  ld (new_head_x), a
  ld a, c
  ld (new_head_y), a

  ; body collision
  ld a, (snake_len)
  ld b, a
  ld hl, snake_x
  ld de, snake_y
SnakeStep_BodyLoop:
  ld a, b
  or a
  jr z, SnakeStep_Shift
  ld a, (hl)
  ld c, a
  ld a, (new_head_x)
  cp c
  jr nz, SnakeStep_BodyNext
  ld a, (de)
  ld c, a
  ld a, (new_head_y)
  cp c
  jp z, ResetGame
SnakeStep_BodyNext:
  inc hl
  inc de
  dec b
  jr SnakeStep_BodyLoop

  ld a, (new_head_x)
  ld b, a
  ld a, (new_head_y)
  ld c, a
SnakeStep_Shift:
  ; shift tail towards end
  ld a, (snake_len)
  dec a
  ld e, a
SnakeStep_ShiftLoop:
  ld a, e
  or a
  jr z, SnakeStep_StoreHead

  ld d, 0
  ld hl, snake_x
  add hl, de
  dec hl
  ld a, (hl)
  inc hl
  ld (hl), a

  ld hl, snake_y
  add hl, de
  dec hl
  ld a, (hl)
  inc hl
  ld (hl), a

  dec e
  jr SnakeStep_ShiftLoop

SnakeStep_StoreHead:
  ld a, b
  ld (snake_x), a
  ld a, c
  ld (snake_y), a

  ; food check
  ld a, (food_x)
  cp b
  jr nz, SnakeStep_NoFood
  ld a, (food_y)
  cp c
  jr nz, SnakeStep_NoFood

  ld a, (snake_len)
  cp 63
  jr nc, SnakeStep_LenMax
  inc a
  ld (snake_len), a
SnakeStep_LenMax:
  ld a, (score)
  cp 99
  jr z, SnakeStep_ScoreKeep
  inc a
  ld (score), a
SnakeStep_ScoreKeep:
  call DrawScore
  call SpawnFood
  call DrawFood
  jr SnakeStep_DrawNew

SnakeStep_NoFood:
  ; erase old tail
  ld a, (tail_old_x)
  ld b, a
  ld a, (tail_old_y)
  ld c, a
  ld a, TILE_EMPTY
  call PutTile

SnakeStep_DrawNew:
  ; old head becomes body
  ld a, (head_old_x)
  ld b, a
  ld a, (head_old_y)
  ld c, a
  ld a, TILE_BODY
  call PutTile

  ; new head
  ld a, (snake_x)
  ld b, a
  ld a, (snake_y)
  ld c, a
  ld a, TILE_HEAD
  call PutTile
  ret

ResetGame:
  call ClearNameTable
  call DrawBorder
  xor a
  ld (score), a
  call DrawScore
  call InitSnake
  call SpawnFood
  call DrawFood
  ret

SpawnFood:
SpawnFood_Try:
  call NextRandom
  and $1F
  cp PLAY_MIN_X
  jr c, SpawnFood_Try
  cp PLAY_MAX_X+1
  jr nc, SpawnFood_Try
  ld b, a

  call NextRandom
  and $1F
  cp PLAY_MIN_Y
  jr c, SpawnFood_Try
  cp PLAY_MAX_Y+1
  jr nc, SpawnFood_Try
  ld c, a

  ; avoid snake cells
  ld a, b
  ld (new_head_x), a
  ld a, c
  ld (new_head_y), a

  ld a, (snake_len)
  ld b, a
  ld hl, snake_x
  ld de, snake_y
SpawnFood_CheckLoop:
  ld a, b
  or a
  jr z, SpawnFood_Ok
  ld a, (hl)
  ld c, a
  ld a, (new_head_x)
  cp c
  jr nz, SpawnFood_Next
  ld a, (de)
  ld c, a
  ld a, (new_head_y)
  cp c
  jr z, SpawnFood_Try
SpawnFood_Next:
  inc hl
  inc de
  dec b
  jr SpawnFood_CheckLoop

SpawnFood_Ok:
  ld a, (new_head_x)
  ld (food_x), a
  ld a, (new_head_y)
  ld (food_y), a
  ret

DrawFood:
  ld a, (food_x)
  ld b, a
  ld a, (food_y)
  ld c, a
  ld a, TILE_FOOD
  call PutTile
  ret

DrawScore:
  ; row 0, col 0/1 show decimal score (00..99)
  ld a, (score)
  ld e, 0
DrawScore_Sub10Loop:
  cp 10
  jr c, ReadInput_Dones10
  sub 10
  inc e
  jr DrawScore_Sub10Loop
DrawScore_DoneSub10:
  ; A=ones, E=tens
  push af
  ld a, e
  add a, TILE_DIGIT0
  ld b, 0
  ld c, 0
  call PutTile
  pop af
  add a, TILE_DIGIT0
  ld b, 1
  ld c, 0
  call PutTile
  ret

; Put tile A at name table cell (B=x, C=y)
PutTile:
  push af
  push bc
  push de
  push hl

  ld h, NT_BASE_CMD_H
  ld l, NT_BASE_CMD_L

  ; add y*64
  ld a, c
  ld e, a
  ld d, 0
  sla e
  rl d
  sla e
  rl d
  sla e
  rl d
  sla e
  rl d
  sla e
  rl d
  sla e
  rl d
  add hl, de

  ; add x*2
  ld a, b
  add a, a
  ld e, a
  ld d, 0
  add hl, de

  ld a, l
  out (VDP_CTRL), a
  ld a, h
  out (VDP_CTRL), a

  pop hl
  pop de
  pop bc
  pop af

  out (VDP_DATA), a
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  xor a
  out (VDP_DATA), a
  ret

NextRandom:
  ld a, (rand_seed)
  add a, a
  jr nc, NextRandom_NoXor
  xor $1D
NextRandom_NoXor:
  ld (rand_seed), a
  ret

VDPRegs:
  .db $04 ; R0 mode
  .db $A0 ; R1 display off + VBlank IRQ enabled
  .db $0E ; R2 name table at $3800
  .db $FF ; R3 unused in mode 4
  .db $FF ; R4 unused in mode 4
  .db $7E ; R5 sprite table $3F00
  .db $00 ; R6
  .db $00 ; R7 backdrop
  .db $00 ; R8 hscroll
  .db $00 ; R9 vscroll
  .db $FF ; R10 line irq

; -----------------------------------------------------------------------------
; Tile data (32 bytes per tile, mode 4)
; -----------------------------------------------------------------------------
TileData:
; 0 empty (color 0)
  .dsb 32, 0

; 1 snake head (solid color 2: yellow => plane1)
  .db $00,$FF,$00,$00
  .db $00,$FF,$00,$00
  .db $00,$FF,$00,$00
  .db $00,$FF,$00,$00
  .db $00,$FF,$00,$00
  .db $00,$FF,$00,$00
  .db $00,$FF,$00,$00
  .db $00,$FF,$00,$00

; 2 snake body (solid color 1: green => plane0)
  .db $FF,$00,$00,$00
  .db $FF,$00,$00,$00
  .db $FF,$00,$00,$00
  .db $FF,$00,$00,$00
  .db $FF,$00,$00,$00
  .db $FF,$00,$00,$00
  .db $FF,$00,$00,$00
  .db $FF,$00,$00,$00

; 3 food (solid color 3: red => plane0+plane1)
  .db $FF,$FF,$00,$00
  .db $FF,$FF,$00,$00
  .db $FF,$FF,$00,$00
  .db $FF,$FF,$00,$00
  .db $FF,$FF,$00,$00
  .db $FF,$FF,$00,$00
  .db $FF,$FF,$00,$00
  .db $FF,$FF,$00,$00

; 4 wall (checker blue/white: color 4 and 5)
  .db $AA,$00,$AA,$00
  .db $55,$00,$55,$00
  .db $AA,$00,$AA,$00
  .db $55,$00,$55,$00
  .db $AA,$00,$AA,$00
  .db $55,$00,$55,$00
  .db $AA,$00,$AA,$00
  .db $55,$00,$55,$00

  ; tiles 5..15 empty
  .dsb 352, 0

; digits 0..9 at tiles 16..25, color 5 (planes 0+2)
Digit0:
  .db $3C,$00,$3C,$00
  .db $66,$00,$66,$00
  .db $6E,$00,$6E,$00
  .db $76,$00,$76,$00
  .db $66,$00,$66,$00
  .db $66,$00,$66,$00
  .db $3C,$00,$3C,$00
  .db $00,$00,$00,$00
Digit1:
  .db $18,$00,$18,$00
  .db $38,$00,$38,$00
  .db $18,$00,$18,$00
  .db $18,$00,$18,$00
  .db $18,$00,$18,$00
  .db $18,$00,$18,$00
  .db $3C,$00,$3C,$00
  .db $00,$00,$00,$00
Digit2:
  .db $3C,$00,$3C,$00
  .db $66,$00,$66,$00
  .db $06,$00,$06,$00
  .db $0C,$00,$0C,$00
  .db $18,$00,$18,$00
  .db $30,$00,$30,$00
  .db $7E,$00,$7E,$00
  .db $00,$00,$00,$00
Digit3:
  .db $3C,$00,$3C,$00
  .db $66,$00,$66,$00
  .db $06,$00,$06,$00
  .db $1C,$00,$1C,$00
  .db $06,$00,$06,$00
  .db $66,$00,$66,$00
  .db $3C,$00,$3C,$00
  .db $00,$00,$00,$00
Digit4:
  .db $0C,$00,$0C,$00
  .db $1C,$00,$1C,$00
  .db $3C,$00,$3C,$00
  .db $6C,$00,$6C,$00
  .db $7E,$00,$7E,$00
  .db $0C,$00,$0C,$00
  .db $0C,$00,$0C,$00
  .db $00,$00,$00,$00
Digit5:
  .db $7E,$00,$7E,$00
  .db $60,$00,$60,$00
  .db $7C,$00,$7C,$00
  .db $06,$00,$06,$00
  .db $06,$00,$06,$00
  .db $66,$00,$66,$00
  .db $3C,$00,$3C,$00
  .db $00,$00,$00,$00
Digit6:
  .db $1C,$00,$1C,$00
  .db $30,$00,$30,$00
  .db $60,$00,$60,$00
  .db $7C,$00,$7C,$00
  .db $66,$00,$66,$00
  .db $66,$00,$66,$00
  .db $3C,$00,$3C,$00
  .db $00,$00,$00,$00
Digit7:
  .db $7E,$00,$7E,$00
  .db $66,$00,$66,$00
  .db $06,$00,$06,$00
  .db $0C,$00,$0C,$00
  .db $18,$00,$18,$00
  .db $18,$00,$18,$00
  .db $18,$00,$18,$00
  .db $00,$00,$00,$00
Digit8:
  .db $3C,$00,$3C,$00
  .db $66,$00,$66,$00
  .db $66,$00,$66,$00
  .db $3C,$00,$3C,$00
  .db $66,$00,$66,$00
  .db $66,$00,$66,$00
  .db $3C,$00,$3C,$00
  .db $00,$00,$00,$00
Digit9:
  .db $3C,$00,$3C,$00
  .db $66,$00,$66,$00
  .db $66,$00,$66,$00
  .db $3E,$00,$3E,$00
  .db $06,$00,$06,$00
  .db $0C,$00,$0C,$00
  .db $38,$00,$38,$00
  .db $00,$00,$00,$00

TileDataEnd:

.org $7FF0
  ; SMS header: exactly 16 bytes ($7FF0-$7FFF)
  .db "TMR SEGA"
  .db $00,$00,$00,$00,$00,$00,$4C,$00
