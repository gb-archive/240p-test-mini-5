;
; Shadow sprite test for 240p test suite
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

  rsset hLocals
Ltopbyte rb 1
Lbottombyte rb 1

  rsset hTestState
xpos rb 1
ypos rb 1
cur_facing rb 1
cur_shape rb 1
shadow_is_striped rb 1
cur_frame rb 1
cur_bg_style rb 1
held_keys rb 1
wy_countdown rb 1

; Shadow sprite ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; The 4 backgrounds of shadow sprite are
; Gus, GHZ, stripes-H, stripes-diag

section "gus_portrait",ROMX
portrait_chr:
  incbin "obj/gb/Gus_portrait.u.chrgb.pb16"
portrait_nam:
  incbin "obj/gb/Gus_portrait.nam"
sizeof_portrait_chr = 2048

section "shadow_sprite",ROM0,align[4]
hepsie_chr:
  incbin "obj/gb/hepsie.chrgb16.pb16"
sizeof_hepsie_chr = 16*3*4
shadow_reticle_chr:
  incbin "obj/gb/shadow_reticle.chrgb16.pb16"
sizeof_shadow_reticle_chr = 16*4*4
hepsie_palette_gbc:
  drgb $FF00FF
  drgb $000000
  drgb $00FF00  ; skirt
  drgb $FFFF00
  drgb $FF00FF
  drgb $000000
  drgb $FF00DD  ; cape
  drgb $FFAA55
hepsie_palette_gbc_end:

activity_shadow_sprite::
  ld a,72
  ldh [xpos],a
  ldh [ypos],a
  xor a
  ldh [cur_facing],a
  ldh [cur_shape],a
  ldh [shadow_is_striped],a
  ldh [cur_frame],a
  ldh [cur_bg_style],a
  ldh [wy_countdown],a

.restart:
  call clear_gbc_attr
  ldh [held_keys],a

  call load_frame_type_names
  ld de,hepsie_chr
  ld hl,CHRRAM0
  ld b,sizeof_hepsie_chr/16
  call pb16_unpack_block
  ld de,shadow_reticle_chr
  ld hl,CHRRAM0+24*16
  ld b,sizeof_shadow_reticle_chr/16
  call pb16_unpack_block
  ; Make shadow sprites
  call make_shadow_chr

  call load_bg

  xor a
  ldh [rSCX],a
  dec a
  ldh [rLYC],a  ; disable lyc irq until something needs it
  call set_obp0
  call set_obp1
  ld a,LCDCF_ON|BG_NT0|WINDOW_NT1|BG_CHR21|OBJ_8X16
  ld [vblank_lcdc_value],a
  ld [stat_lcdc_value],a
  ldh [rLCDC],a
  
.loop:
  ld b,helpsect_shadow_sprite
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

  ; Select: toggle 8-point star vs. Hepsie
  bit PADB_SELECT,b
  jr z,.no_toggle_shape
    ldh a,[cur_shape]
    xor 1
    ldh [cur_shape],a
  .no_toggle_shape:

  ld a,[cur_keys]
  ld b,a
  bit PADB_A,a
  jr nz,.a_held
  
    ; B: held keys
    ldh a,[xpos]
    ld hl,cur_facing
    bit PADB_LEFT,b
    jr z,.not_left
      set BOAM_HFLIP,[hl]
      dec a
      cp 8
      jr c,.not_left
      ldh [xpos],a
    .not_left:
    bit PADB_RIGHT,b
    jr z,.not_right
      res BOAM_HFLIP,[hl]
      inc a
      cp 137
      jr nc,.not_right
      ldh [xpos],a
    .not_right:

    ldh a,[ypos]
    bit PADB_UP,b
    jr z,.not_up
      dec a
      cp 16
      jr c,.not_up
      ldh [ypos],a
    .not_up:
    bit PADB_DOWN,b
    jr z,.not_down
      inc a
      cp 129
      jr nc,.not_down
      ldh [ypos],a
    .not_down:

    ; Release A: Increment frame/substyle
    ldh a,[held_keys]
    and PADF_A
    jr z,.no_release_A
      ldh a,[shadow_is_striped]
      add 2
      ld b,a  ; B = maximum frame/substyle for this style
      ldh a,[cur_frame]
      inc a
      cp b
      jr c,.no_wrap_frame
        xor a
      .no_wrap_frame:
      ldh [cur_frame],a
      xor a
      ldh [held_keys],a
      ld a,68
      ldh [wy_countdown],a
    .no_release_A:

    jr .a_done
  .a_held:
    ld a,[new_keys]
    and PADF_UP|PADF_LEFT|PADF_RIGHT
    ld b,a
    jr z,.a_done

    ; A+Up: Toggle Flicker or stripes
    bit PADB_UP,b
    jr z,.not_change_shadow_type
      ldh a,[shadow_is_striped]
      xor 1
      ldh [shadow_is_striped],a
      xor a
      ldh [cur_frame],a
      ld a,68
      ldh [wy_countdown],a
      ld hl,held_keys
      res PADB_A,[hl]
      jr .a_done
    .not_change_shadow_type:

    ; A+Left, A+Right: Change bg
    ldh a,[cur_bg_style]
    bit PADB_RIGHT,b
    jr nz,.next_bg_style
      dec a
      jr .have_bg_style
    .next_bg_style:
      inc a
    .have_bg_style:
    and $03
    ldh [cur_bg_style],a
    jp .restart
  .a_done:

  ; Draw sprite
  xor a
  ld [oam_used],a
  call draw_shadow_sprite
  call lcd_clear_oam

  call wait_vblank_irq
  call run_dma

  ld a,%00101100  ; palette for bottom half of Hepsie
  ldh [rOBP0],a
  ld a,%00011100  ; palette for top half of Hepsie
  ldh [rOBP1],a
  ld a,$80
  ld bc,(hepsie_palette_gbc_end - hepsie_palette_gbc) * 256 + LOW(rOCPS)
  ld hl,hepsie_palette_gbc
  call set_gbc_palette

  ; Move window
  ldh a,[wy_countdown]
  ld b,a
  cp 8
  jr c,.wy_leaving
    ld a,8
  .wy_leaving:
  cpl
  add 144+1
  ldh [rWY],a

  ; Draw text in window if necessary
  ld a,b
  or a
  jr z,.no_wy
    dec a
    ldh [wy_countdown],a
    ; Decide what to say
    ldh a,[shadow_is_striped]
    add a
    ld b,a
    ld a,[cur_frame]
    add b
    ; Convert to a tile number
    add a
    add a
    add a
    add $D8
    ld b,8
    ld hl,_SCRN1
    .wtileloop:
      ld [hl+],a
      inc a
      dec b
      jr nz,.wtileloop
  .no_wy:

  ; If GHZ, set scroll
  ld a,[cur_bg_style]
  xor 1
  jr nz,.not_ghz_scroll
    ld h,a
    ldh a,[xpos]
    ld l,a
    add hl,hl
    add hl,hl
    call set_hillzone_scroll_pos
  .not_ghz_scroll:

  jp .loop

;;
; Fills tiles $D8-$FF with messages about what framestyle is in
load_frame_type_names:
  ld de,CHRRAM0+$D8*16
  ld hl,frame_type_msgs
.lineloop:
  push de
  push hl
  call vwfClearBuf
  pop hl
  ld b,6
  call vwfPuts
  pop de

  push hl
  ld l,e
  ld h,d
  ld bc,$FF08  ; $FF: use colors 0 and 3; $08: copy 8 half tiles
  call vwfPutBuf03_lenC
  ld d,h
  ld e,l
  pop hl
  ld a,[hl+]
  or a
  jr nz,.lineloop

  ld a,167-64
  ldh [rWX],a
  ret

frame_type_msgs:
  db "even frames",10
  db "odd frames",10
  db "horizontal",10
  db "vertical",10
  db "diagonal",0

; Sprite drawing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Produces the shadow sprite variations
make_shadow_chr:
  ; Produce a shadow for Hepsie, ORing both bitplanes into plane 0.
  ld hl,CHRRAM0
  ld de,CHRRAM0+12*16
  ld b,12*8
.loop:
  ; Read both bitplanes
  ld a,[hl+]
  ld c,a
  ld a,[hl+]

  ; Write their union as color 1
  or c
  ld [de],a
  inc de
  xor a
  ld [de],a
  inc de
  dec b
  jr nz,.loop

  ; Now AND each shadow with a mask
  ld de,CHRRAM0+12*16+sizeof_hepsie_chr+sizeof_shadow_reticle_chr
  ld bc,`11111111
  call .someshadow
  ld bc,`03030303
  call .someshadow
  ld bc,`12121212
.someshadow:

  ld a,b
  ldh [Ltopbyte],a
  ld a,c
  ldh [Lbottombyte],a
  ld b,(sizeof_hepsie_chr+sizeof_shadow_reticle_chr)/4
  ld hl,CHRRAM0+12*16
.shadowcalcloop:
  ldh a,[Ltopbyte]
  ld c,a
  ld a,[hl+]
  inc hl
  and c
  ld [de],a
  inc de
  xor a
  ld [de],a
  inc de
  ldh a,[Lbottombyte]
  ld c,a
  ld a,[hl+]
  inc hl
  and c
  ld [de],a
  inc de
  xor a
  ld [de],a
  inc de
  dec b
  jr nz,.shadowcalcloop
  ret

draw_shadow_sprite:
  ldh a,[ypos]
  ldh [Lspriterect_y],a
  ldh a,[xpos]
  ldh [Lspriterect_x],a
  ld a,16
  ldh [Lspriterect_rowht],a
  ldh a,[cur_shape]
  or a
  jr nz,.shape_is_hepsie

  ; 8-point star
  ld a,2
  ldh [Lspriterect_height],a
  add a
  ldh [Lspriterect_width],a
  add a
  ldh [Lspriterect_tilestride],a
  xor a
  ldh [Lspriterect_attr],a

  ; Choose a starting tile
  call get_shadow_frame_number
  ret c
  add 24
  ldh [Lspriterect_tile],a
  jp draw_spriterect

.shape_is_hepsie:
  ld a,3
  ldh [Lspriterect_width],a
  add a
  ldh [Lspriterect_tilestride],a
  xor a
  ldh [Lspriterect_tile],a

  ; Top half: cape
  ld a,1
  ldh [Lspriterect_height],a
  ldh a,[cur_facing]
  or 1|OAMF_PAL1
  ldh [Lspriterect_attr],a
  call draw_spriterect

  ; Bottom half: skirt
  ldh a,[xpos]
  ldh [Lspriterect_x],a
  ld a,1
  ldh [Lspriterect_height],a
  ldh a,[cur_facing]
  ldh [Lspriterect_attr],a
  call draw_spriterect

  ; Shadow: black or nothing
  ldh a,[ypos]
  add 8
  ldh [Lspriterect_y],a
  ldh a,[xpos]
  add 8
  ldh [Lspriterect_x],a
  ld a,2
  ldh [Lspriterect_height],a
  ldh a,[cur_facing]
  ldh [Lspriterect_attr],a

  ; Choose a starting tile
  call get_shadow_frame_number
  ret c
  add 12
  ldh [Lspriterect_tile],a
  jp draw_spriterect

  ret

;;
; Finds which shadow frame number should be drawn this frame.
; @return CY true if flicker shadow should be skipped this frame;
; A: 0 for solid flicker or 28, 56, or 84 for striped shadow substyles
get_shadow_frame_number:

  ; Choose a starting tile based on the chosen shadow style
  ; (flicker or stripe) and frame
  ld a,[shadow_is_striped]
  or a
  jr nz,.is_striped

  ; If flashing reticle, the chosen frame must match the low bit
  ; of the retrace count
  ld a,[cur_frame]
  ld b,a
  ld a,[nmis]
  add b
  rra
  ret c
  ; Match? Use frame 0
  xor a
  ret
.is_striped:
  ; Shadow substyles 0-2 use shadow frames 1-3
  ld a,[cur_frame]
  inc a
  ; The tiles for each shadow frame are 28 tiles apart in CHR RAM.
  ld b,a
  add a
  add a
  add a
  sub b
  add a
  add a
  ret


; Background loaders ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

load_bg:
  ldh a,[cur_bg_style]
  ld de,shadow_sprite_bg_loaders
  call de_index_a
  jp hl

shadow_sprite_bg_loaders:
  dw load_gus_portrait
  dw load_hillzone_bg
  dw load_horizontal_stripes
  dw load_diagonal_stripes

load_gus_portrait:
  ld a,[initial_a]
  cp $11
  jr z,load_gus_portrait_gbc

  ; Load Gus portrait for background
  ld a,bank(portrait_chr)
  ld [rMBC1BANK1],a

  ld de,portrait_chr
  ld hl,CHRRAM2
  ld b,sizeof_portrait_chr/16
  call pb16_unpack_block
  ld h,0
  ld de,_SCRN0
  ld bc,32*18
  call memset
  ld hl,portrait_nam
  ld de,_SCRN0+4
  ld bc,13*256+18
  call load_nam
  ld a,%11100100
  jp set_bgp

load_gus_portrait_gbc:
  ; Load Gus portrait for background
  ld a,bank(Gus_portrait_GBC_pb16)
  ld [rMBC1BANK1],a

  ld de,Gus_portrait_GBC_pb16
  ld hl,CHRRAM2
  ld b,Gus_portrait_GBC_utiles
  call pb16_unpack_block

  ; Prepare plane 1
  ld a,1
  ldh [rVBK],a
  ld h,0
  ld de,_SCRN0
  ld bc,32*18
  call memset
  ld hl,Gus_portrait_GBC_attr
  ld de,_SCRN0+4
  ld bc,13*256+18
  call load_nam

  ; Prepare plane 0
  xor a
  ldh [rVBK],a
  ld h,a
  ld de,_SCRN0
  ld bc,32*18
  call memset
  ld hl,Gus_portrait_GBC_map
  ld de,_SCRN0+4
  ld bc,13*256+18
  call load_nam
  
  ld hl,Gus_portrait_GBC_pal
  ld a,$80
  ld bc,(Gus_portrait_GBC_pal_end-Gus_portrait_GBC_pal)*256+low(rBCPS)
  jp set_gbc_palette

load_horizontal_stripes:
  call clear_gbc_attr
  ld a,$FF
  jr load_shadow_sprite_bg_stripes

load_diagonal_stripes:
  call clear_gbc_attr
  ld a,$55
load_shadow_sprite_bg_stripes:
  ld hl,CHRRAM2
  ld b,8
  .loop:
    ld [hl+],a
    ld [hl+],a
    cpl
    dec b
    jr nz,.loop

  ld h,0
  ld de,_SCRN0
  ld bc,32*18
  call memset

  ld a,%11100100
  jp set_bgp
