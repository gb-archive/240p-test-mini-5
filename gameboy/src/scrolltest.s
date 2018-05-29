;
; Scrolling tests for 240p test suite
; Copyright 2018 Damian Yerrick
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
;
include "src/gb.inc"
include "src/global.inc"

  rsset hTestState
curpalette rb 1
held_keys rb 1
cur_x rb 2
cur_y rb 2
cur_speed rb 1
cur_dir rb 1
unpaused rb 1


KT_SAND0 equ $00
KT_SAND1 equ $01
KT_WALLTOP equ $02
KT_FLOORTILE equ $03
KT_WALL equ $04
KT_SHADOW_L equ $05
KT_SHADOW_U equ $06
KT_SHADOW_UL equ $07
KT_SHADOW_U_L equ $08
KT_SHADOW_UL_U equ $09
KT_SHADOW_UL_L equ $0A

section "scrolltestgfx",ROMX
hillzone_chr:
  incbin "obj/gb/greenhillzone.u.chrgb.pb16"
sizeof_hillzone_chr = 1648
hillzone_nam:
  incbin "obj/gb/greenhillzone.nam.pb16"
hillzone_palette_gbc:
  drgb $FFFFFF  ; Clouds, water
  drgb $8FA1FF
  drgb $D1D8FF
  drgb $FF00FF
  drgb $8FA1FF  ; Mountain peaks and near squares
  drgb $BDAC2C
  drgb $6D5C00
  drgb $342800
  drgb $C5FC00  ; Grass and sky
  drgb $85BC00
  drgb $077704
  drgb $8FA1FF
  drgb $C5FC00  ; Grass and dirt
  drgb $85BC00
  drgb $077704
  drgb $342800
  drgb $FFFFFF  ; Far shore (brown parts)
  drgb $8FA1FF
  drgb $6D5C00
  drgb $342800
  drgb $FFFFFF  ; Far shore (green parts)
  drgb $8FA1FF
  drgb $077704
  drgb $342800
hillzone_palette_gbc_end:

kikitiles_chr:
  incbin "obj/gb/kikitiles.chrgb"

section "kikimtbelow",ROM0,align[5]
mt_below:
  db KT_SAND0,      KT_SAND0,    KT_WALL,     KT_SAND0
  db KT_SHADOW_U,   KT_SHADOW_UL,KT_SAND0,    KT_SAND0
  db KT_SHADOW_UL_L,KT_SAND0,    KT_SHADOW_UL

; Alternate most common tile below if a wall block is to the left
mt_belowR:
  db KT_SHADOW_L,   KT_SHADOW_L,   KT_WALL,       KT_SAND0
  db KT_SHADOW_U_L, KT_SHADOW_UL_L,KT_SHADOW_L,   KT_SHADOW_L
  db KT_SHADOW_UL_L,KT_SHADOW_L,   KT_SHADOW_UL_L

section "gridscroll",ROM0
gridtile_pb16:
  db %00011111
  dw `11111111
  db %10000001
  db %11111101
  db %11111111
kikimap:
  incbin "obj/gb/kikimap.chr1"
kikibgpalette_gbc:
  drgb $FFFFAA  ; 0: orange (sand)
  drgb $FFAA55
  drgb $AA5500
  drgb $550000
  drgb $FFFF80  ; 1: green (floor tiles)
  drgb $A8FF33
  drgb $408000
  drgb $000000
kikibgpalette_gbc_end:

activity_grid_scroll::
  call init_grid_scroll_vars
  ld a,$03
  ldh [curpalette],a
  ld a,PADF_RIGHT
  ld [cur_dir],a
.restart:
  call clear_gbc_attr

  ; Blow away the tilemap
  ld h,a
  ld de,_SCRN0
  ld bc,1024
  call memset

  ; Load grid tile
  ld hl,CHRRAM2
  ld de,gridtile_pb16
  ld b,1
  call pb16_unpack_block

  xor a
  call set_bgp  ; blank the palette
  ld a,$FF
  ldh [rLYC],a  ; disable lyc irq
  ld a,LCDCF_ON|BG_NT0|BG_CHR21
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a

.loop:
  ld b,helpsect_grid_scroll_test
  call read_pad_help_check
  jr nz,.restart

  ; Process input
  ld a,[new_keys]
  ld b,a
  ldh a,[held_keys]
  or b
  ldh [held_keys],a
  
  bit PADB_B,b
  ret nz
  bit PADB_SELECT,b
  jr z,.not_select
    ldh a,[curpalette]
    cpl
    ldh [curpalette],a
  .not_select:

  ; A+Direction: Change direction
  ld a,[cur_keys]
  bit PADB_A,a
  jr nz,.a_held
    ; If A was pressed and released, toggle pause and clear
    ; held key
    ld hl,held_keys
    bit PADB_A,[hl]
    jr z,.not_release_A
      ldh a,[unpaused]
      cpl
      ldh [unpaused],a
      res PADB_A,[hl]
    .not_release_A:

    ; Change speed in range 1-4
    ldh a,[cur_speed]
    bit PADB_UP,b
    jr z,.not_increase_speed
      inc a
      cp 5
      jr nc,.not_writeback_speed
    .not_increase_speed:
    bit PADB_DOWN,b
    jr z,.not_decrease_speed
      dec a
      jr z,.not_writeback_speed
    .not_decrease_speed:
    ldh [cur_speed],a
    .not_writeback_speed:

    jr .a_done
  .a_held:
    ; Up, Down, Left, Right: Change direction
    ld a,PADF_UP|PADF_DOWN|PADF_LEFT|PADF_RIGHT
    and b
    jr z,.a_done
    ld [cur_dir],a

    ; Invalidate A hold
    ld hl,held_keys
    res PADB_A,[hl]
  .a_done:

  call move_by_speed
  call wait_vblank_irq
  ldh a,[curpalette]
  call set_bgp
  ldh a,[cur_y]
  ldh [rSCY],a
  ldh a,[cur_x]
  ldh [rSCX],a
  jp .loop

activity_hillzone_scroll::
  call init_grid_scroll_vars
  ld a,PADF_RIGHT
  ld [cur_dir],a
.restart:
  call load_hillzone_bg

  ld a,[vblank_lcdc_value]
  ldh [rLCDC],a
.loop:
  ld b,helpsect_hill_zone_scroll_test
  call read_pad_help_check
  jr nz,.restart

  ld a,[new_keys]
  bit PADB_B,a
  ret nz

  call process_1d_input
  call wait_vblank_irq
  xor a
  ldh [rSCY],a
  ldh a,[cur_x]
  ld l,a
  ldh a,[cur_x+1]
  ld h,a
  call set_hillzone_scroll_pos
  jp .loop

activity_kiki_scroll::
  call init_grid_scroll_vars
  ld a,PADF_RIGHT
  ld [cur_dir],a
.restart:
  call load_kiki_bg
.loop:
  ld b,helpsect_vertical_scroll_test
  call read_pad_help_check
  jr nz,.restart

  ld a,[new_keys]
  bit PADB_B,a
  ret nz

  call process_1d_input
  call wait_vblank_irq
  xor a
  ldh [rSCX],a
  ldh a,[cur_x+1]
  rra
  ldh a,[cur_x]
  rra
  ldh [rSCY],a

  jp .loop

; Scroll test movement ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_grid_scroll_vars:
  xor a
  ldh [cur_x],a
  ldh [cur_x+1],a
  ldh [cur_y],a
  ldh [cur_y+1],a
  ldh [held_keys],a
  dec a
  ldh [unpaused],a
  ld a,$01
  ld [cur_speed],a
  ret

process_1d_input:
  ; Process input
  ld a,[new_keys]
  ld b,a

  ; Left/Right: Change direction
  ld a,PADF_LEFT|PADF_RIGHT
  and b
  jr z,.no_toggle_dir
    ldh a,[cur_dir]
    xor PADF_LEFT|PADF_RIGHT
    ldh [cur_dir],a
  .no_toggle_dir:

  bit PADB_A,b
  jr z,.no_toggle_pause
    ldh a,[unpaused]
    cpl
    ldh [unpaused],a
  .no_toggle_pause:

  ; Change speed in range 1-16
  ldh a,[cur_speed]
  bit PADB_UP,b
  jr z,.not_increase_speed
    inc a
    cp 17
    jr nc,.not_writeback_speed
  .not_increase_speed:
  bit PADB_DOWN,b
  jr z,.not_decrease_speed
    dec a
    jr z,.not_writeback_speed
  .not_decrease_speed:
  ldh [cur_speed],a
.not_writeback_speed:
  ; Fall through to move_by_speed

move_by_speed:
  ldh a,[unpaused]
  and a
  ret z
  ldh a,[cur_speed]
  ld b,a
  ld a,[cur_dir]

  add a
  jr nc,.not_down
    ldh a,[cur_y]
    add b
    ldh [cur_y],a
    ldh a,[cur_y+1]
    adc 0
    ldh [cur_y+1],a
    ret
  .not_down:

  add a
  jr nc,.not_up
    ldh a,[cur_y]
    sub b
    ldh [cur_y],a
    ldh a,[cur_y+1]
    sbc 0
    ldh [cur_y+1],a
    ret
  .not_up:

  add a
  jr nc,.not_left
    ldh a,[cur_x]
    sub b
    ldh [cur_x],a
    ldh a,[cur_x+1]
    sbc 0
    ldh [cur_x+1],a
    ret
  .not_left:

  add a
  ret nc
    ldh a,[cur_x]
    add b
    ldh [cur_x],a
    ldh a,[cur_x+1]
    adc 0
    ldh [cur_x+1],a
    ret

;;
; Draws the scroll strips for hill zone between 0 and 2048
; 0-15 12.5% speed, 16-111 25% speed, 112-143 100% speed.
; Also changes BGP so that GB and GBC can use one set of tiles.
; @param HL scroll distance
set_hillzone_scroll_pos::
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  add hl,hl
  ld a,h
  ldh [rSCX],a
  ld a,%01010000
  ldh [rBGP],a

  ; uses HALT until IRQ, not
  add hl,hl
  ld bc,16*256 + %11100100
  di
  call .waitandwrite
  add hl,hl
  add hl,hl
  ld bc,112*256 + %01100100
  call .waitandwrite
  ld bc,120*256 + %11100100
  call .waitandwrite
  reti

.waitandwrite:
  ld a,b
  dec a
  ldh [rLYC],a
.wwloop:
  halt
  ldh a,[rLY]
  cp b
  jr nz,.wwloop
  ld a,h
  ldh [rSCX],a
  ld a,c
  ldh [rBGP],a
  ret

; Load scrolling backgrounds ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

load_hillzone_bg::
  call clear_gbc_attr

  ld a,bank(hillzone_nam)
  ld [rMBC1BANK1],a

  ; Load the tilemap
  ld hl,_SCRN0
  ld de,hillzone_nam
  ld b,32*18/16
  call pb16_unpack_block

  ; Load tiles
  ld hl,CHRRAM2
  ld de,hillzone_chr
  ld b,sizeof_hillzone_chr/16
  call pb16_unpack_block

  ; Set up palette
  ld a,LCDCF_ON|BG_NT0|BG_CHR21
  ld [vblank_lcdc_value],a
  ld [stat_lcdc_value],a

  ld a,[initial_a]
  cp $11
  jr nz,.not_gbc_attrs
  ld a,1
  ldh [rVBK],a

  ; Set up approximate attribute table (to be refined later)
  ld hl,_SCRN0
  ld de,.attrstrips
.attrloop1:
  ld a,[de]
  inc de
  or a
  jr z,.attrloop1end
  ld c,a
  ld a,[de]
  inc de
  call memset_tiny
  jr .attrloop1
.attrstrips:
  db 32*2,0  ; sky
  db 32*5,1  ; peaks
  db 32*2,3  ; foliage
  db 32*2,4  ; far shore
  db 32*3,0  ; water
  db 32*1,2  ; grass and sky
  db 32*1,3  ; grass and dirt
  db 32*2,1  ; squares
  db 0       ; separator

  ; Top of waterfall
  dw _SCRN0+7*32+16
  db 8,0
  dw _SCRN0+8*32+16
  db 8,0
  dw _SCRN0+9*32+8
  ; Bushes near shore
  db 4,3
  dw _SCRN0+10*32+8
  db 4,5
  dw _SCRN0+9*32+26
  db 4,3
  dw _SCRN0+10*32+26
  db 4,5
  ; Near low grass
  dw _SCRN0+16*32+3
  db 5,3
  dw _SCRN0+16*32+15
  db 3,3
  dw _SCRN0+16*32+23
  db 7,3
  dw $0000   ; Terminator  
.attrloop1end:

  ; Correct areas not matching the rest of the horizontal strip
.attrloop2:
  ld a,[de]
  inc de
  ld l,a
  ld a,[de]
  inc de
  ld h,a
  or l
  jr z,.attrloop2end
  ld a,[de]
  inc de
  ld c,a
  ld a,[de]
  inc de
  call memset_tiny
  jr .attrloop2
.attrloop2end:

  xor a
  ldh [rVBK],a  ; close attribute plane
  ld hl,hillzone_palette_gbc
  ld bc,(hillzone_palette_gbc_end-hillzone_palette_gbc) * 256 + low(rBCPS)
  ld a,$80
  call set_gbc_palette
.not_gbc_attrs:

  xor a
  ldh [rBGP],a
  ; Enable rSTAT IRQ on rLY=rLYC but put it on hold
  ld a,255
  ldh [rLYC],a  ; disable lyc irq
  ld a,STAT_LYCIRQ
  ld [rSTAT],a
  ld a,IEF_VBLANK|IEF_LCDC
  ldh [rIE],a  ; enable rSTAT IRQ

  ret

; Kiki's tilemap is compressed. Hard.

  rsset hLocals
Lwallbits rb 3
Lpathbits rb 2
Ltiletotopleft rb 1

load_kiki_bg:
  call clear_gbc_attr

  ld a,bank(kikitiles_chr)
  ld [rMBC1BANK1],a

  ; Load tiles
  ld hl,kikitiles_chr
  ld de,CHRRAM2
  ld bc,12*16
  call memcpy

  ; Copy packed map into an aligned buffer; possibly decompress later
  ld hl,kikimap
  ld de,lineImgBuf
  ld bc,128
  call memcpy
  
  ; Clear row history
  ld hl,help_line_buffer
  ld c,20
  ld a,KT_SAND0
  call memset_tiny

  ; Bad hack: Approximate the right edges of bottom row
  ; for correct wrapping to the top row
  ld a,KT_SHADOW_L
  ld [help_line_buffer+3],a
  ld [help_line_buffer+19],a
  ld a,KT_WALLTOP
  ld [help_line_buffer+2],a
  ld [help_line_buffer+18],a

  ; Bitunpack tiles within the map
  ; using help_line_buffer as a temporary row
  ld hl,lineImgBuf
  ld de,_SCRN0
  ld b,32
  .bitunpack_rowloop:
    ; Load map bits for this row
    ld a,[hl]
    ldh [Lwallbits+0],a
    ld a,l
    add 32
    ld l,a
    ld a,[hl]
    ldh [Lwallbits+1],a
    ld a,l
    add 32
    ld l,a
    ld a,[hl]
    and $F0
    ldh [Lwallbits+2],a
    ld a,[hl]
    and $0F
    ldh [Lpathbits+0],a
    ld a,l
    add 32
    ld l,a
    ld a,[hl]
    ldh [Lpathbits+1],a
    ld a,l
    add -95
    ld l,a
    push hl
    push de

    ; Find most common tile below each tile
    xor a
    ld e,a  ; E: tile to top left
    ld c,20
    ld hl,help_line_buffer
    .mcbelow_loop:
      push bc
      ld d,[hl]

      ; If tile to left is a wall front, read from the alternate table
      cp KT_WALL
      jr nz,.mcb_not_wallfront

        ; Look up the most common tile below this one if a wall is
        ; to the left
        ld bc,mt_belowR
        ld a,d
        add c
        ld c,a
        ld a,[bc]
        jr .mcb_have
      .mcb_not_wallfront:

        ; Look up the most common tile below this one if a wall is
        ; not to the left
        ld bc,mt_below
        ld a,d
        add c
        ld c,a
        ld a,[bc]

        ; If this tile is a shadow below a wall, and there's another
        ; wall to the top left, then there should also be shadow
        ; to the left. So extend the shadow leftward to meet it.
        cp KT_SHADOW_U
        jr nz,.mcb_have
        ld a,e
        cp KT_WALL
        jr nz,.not4to5
          ld a,KT_SHADOW_UL_U
          jr .mcb_have
        .not4to5:
        ld a,KT_SHADOW_U
      .mcb_have:      
      ld e,[hl]
      ld [hl+],a

      pop bc
      dec c
      jr nz,.mcbelow_loop

    ; Replace tiles with wall tops and path tiles as needed
    ld c,20
    ld hl,help_line_buffer
    pop de
    .wallbits_loop:
      ldh a,[Lwallbits+2]
      add a
      ldh [Lwallbits+2],a
      ldh a,[Lwallbits+1]
      adc a
      ldh [Lwallbits+1],a
      ldh a,[Lwallbits+0]
      adc a
      ldh [Lwallbits+0],a
      jr nc,.no_wall_replace
        ld a,KT_WALLTOP
        ld [hl],a
      .no_wall_replace:

      ldh a,[Lpathbits+1]
      add a
      ldh [Lpathbits+1],a
      ldh a,[Lpathbits+0]
      adc a
      ldh [Lpathbits+0],a
      jr nc,.no_path_replace
        ld a,KT_FLOORTILE
        ld [hl],a
      .no_path_replace:

      ; Write this tile to the tilemap
      ld a,[hl+]
      or a
      jr nz,.tmwrite_notsand
        ld a,b
        xor c
        and 1
      .tmwrite_notsand:
      ld [de],a
      inc de
      dec c
      jr nz,.wallbits_loop
    ld a,12
    add e
    ld e,a
    jr nc,.no_d_wrap
      inc d
    .no_d_wrap:

    pop hl
    dec b
    jp nz,.bitunpack_rowloop

  ; Disable raster interrupt and set palette
  ld a,$FF
  ldh [rLYC],a
  ld a,%11100100
  ldh [rBGP],a

  ld a,[initial_a]
  cp $11
  jr nz,.not_gbc

    ld hl,kikibgpalette_gbc
    ld bc,(kikibgpalette_gbc_end-kikibgpalette_gbc) * 256 + low(rBCPS)
    ld a,$80
    call set_gbc_palette

    ; Set tiles 2-4 to use secondary palette
	ld hl,_SCRN0
	ld bc,$0100+low(rVBK)
	.attrloop:
	  ld a,[hl]
	  sub 2
	  cp 3  ; CF=1 if alternate palette else 0
	  ld a,0
	  rla   ; A=1 if alternate palette else 0
	  ld d,a
	  ld a,b
	  ld [$FF00+c],a
	  ld a,d
	  ld [hl+],a
	  xor a
	  ld [$FF00+c],a
	  ld a,h
	  cp high(_SCRN1)
	  jr c,.attrloop
  .not_gbc:

  ld a,LCDCF_ON|BG_CHR21|BG_NT0
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a
  ; Expects palette %11100100 during action
  ret
