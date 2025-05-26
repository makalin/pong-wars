; Amiga Pong Wars Demo
; Assemble with vasm: vasmm68k_mot -Fhunkexe -o demo demo.s

    include "hardware/custom.i"
    include "hardware/cia.i"

    section code,code

; Constants
SCREEN_WIDTH    = 320
SCREEN_HEIGHT   = 256
GRID_SIZE       = 16
BALL_SIZE       = 8
MIN_SPEED       = 2
MAX_SPEED       = 4

; Grid dimensions
GRID_WIDTH      = SCREEN_WIDTH/GRID_SIZE
GRID_HEIGHT     = SCREEN_HEIGHT/GRID_SIZE

; Colors
DAY_COLOR       = $fff    ; White
NIGHT_COLOR     = $000    ; Black
DAY_BALL_COLOR  = $000    ; Black
NIGHT_BALL_COLOR = $fff   ; White

start:
    ; Save system state
    movem.l d0-d7/a0-a6,-(sp)
    
    ; Disable interrupts
    move.w #$7fff,intena(a6)
    move.w #$7fff,intreq(a6)
    move.w #$7fff,dmacon(a6)
    
    ; Store old copper list
    move.l $80,a0
    move.l a0,oldcopper
    
    ; Setup our copper list
    lea copperlist,a0
    move.l a0,cop1lc(a6)
    
    ; Enable copper DMA
    move.w #$8080,dmacon(a6)
    
    ; Initialize game state
    bsr init_grid
    bsr init_balls
    
    ; Main game loop
mainloop:
    ; Wait for vertical blank
    btst #0,vposr(a6)
    beq.s mainloop
    
    ; Check for mouse button (exit)
    btst #6,ciaapra
    beq.s exit_game
    
    ; Update game state
    bsr update_game
    bsr draw_game
    
    bra.s mainloop

exit_game:
    ; Restore system state
    move.l oldcopper,cop1lc(a6)
    move.w #$7fff,dmacon(a6)
    move.w #$c000,intena(a6)
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

; Initialize grid
init_grid:
    lea grid,a0
    move.w #GRID_WIDTH-1,d0
.init_x:
    move.w #GRID_HEIGHT-1,d1
.init_y:
    move.b #0,(a0)+    ; Initialize all cells as night (0)
    dbra d1,.init_y
    dbra d0,.init_x
    rts

; Initialize balls
init_balls:
    ; Day ball (left side)
    move.w #SCREEN_WIDTH/4,ball1_x
    move.w #SCREEN_HEIGHT/2,ball1_y
    move.w #MAX_SPEED,ball1_dx
    move.w #-MAX_SPEED,ball1_dy
    
    ; Night ball (right side)
    move.w #(SCREEN_WIDTH/4)*3,ball2_x
    move.w #SCREEN_HEIGHT/2,ball2_y
    move.w #-MAX_SPEED,ball2_dx
    move.w #MAX_SPEED,ball2_dy
    rts

; Update game state
update_game:
    ; Update ball 1 (Day)
    bsr update_ball
    lea ball1_x,a0
    bsr move_ball
    
    ; Update ball 2 (Night)
    bsr update_ball
    lea ball2_x,a0
    bsr move_ball
    
    ; Update scores
    bsr update_scores
    rts

; Update single ball
update_ball:
    ; Add randomness to ball movement
    move.w vhposr(a6),d0
    and.w #$7,d0
    sub.w #4,d0
    add.w d0,ball1_dx
    add.w d0,ball1_dy
    
    ; Limit speed
    move.w ball1_dx,d0
    cmp.w #MAX_SPEED,d0
    ble.s .not_max_x
    move.w #MAX_SPEED,ball1_dx
.not_max_x:
    cmp.w #-MAX_SPEED,d0
    bge.s .not_min_x
    move.w #-MAX_SPEED,ball1_dx
.not_min_x:
    
    move.w ball1_dy,d0
    cmp.w #MAX_SPEED,d0
    ble.s .not_max_y
    move.w #MAX_SPEED,ball1_dy
.not_max_y:
    cmp.w #-MAX_SPEED,d0
    bge.s .not_min_y
    move.w #-MAX_SPEED,ball1_dy
.not_min_y:
    rts

; Move ball and handle collisions
move_ball:
    ; Move ball
    move.w (a0),d0    ; x
    move.w 2(a0),d1   ; y
    move.w 4(a0),d2   ; dx
    move.w 6(a0),d3   ; dy
    
    add.w d2,d0
    add.w d3,d1
    
    ; Check boundary collisions
    cmp.w #SCREEN_WIDTH-BALL_SIZE,d0
    bge.s .reverse_x
    cmp.w #0,d0
    bgt.s .check_y
.reverse_x:
    neg.w d2
    move.w d2,4(a0)
.check_y:
    cmp.w #SCREEN_HEIGHT-BALL_SIZE,d1
    bge.s .reverse_y
    cmp.w #0,d1
    bgt.s .update_pos
.reverse_y:
    neg.w d3
    move.w d3,6(a0)
.update_pos:
    move.w d0,(a0)
    move.w d1,2(a0)
    
    ; Check grid collisions
    lsr.w #4,d0       ; Divide by GRID_SIZE
    lsr.w #4,d1
    bsr check_grid_collision
    rts

; Check and handle grid collisions
check_grid_collision:
    ; Calculate grid index
    mulu.w #GRID_WIDTH,d1
    add.w d0,d1
    lea grid,a0
    move.b (a0,d1.w),d0
    
    ; If cell color doesn't match ball's color, change it
    tst.b d0
    beq.s .is_night
    ; Cell is day, ball is night
    move.b #0,(a0,d1.w)
    bra.s .done
.is_night:
    ; Cell is night, ball is day
    move.b #1,(a0,d1.w)
.done:
    rts

; Update scores
update_scores:
    clr.w day_score
    clr.w night_score
    
    lea grid,a0
    move.w #GRID_WIDTH*GRID_HEIGHT-1,d0
.count_loop:
    tst.b (a0)+
    beq.s .is_night
    addq.w #1,day_score
    bra.s .next
.is_night:
    addq.w #1,night_score
.next:
    dbra d0,.count_loop
    rts

; Draw game
draw_game:
    ; Clear screen
    lea screen,a0
    move.w #SCREEN_WIDTH*SCREEN_HEIGHT/8-1,d0
    moveq #0,d1
.clear_loop:
    move.l d1,(a0)+
    dbra d0,.clear_loop
    
    ; Draw grid
    lea grid,a0
    lea screen,a1
    move.w #GRID_HEIGHT-1,d0
.draw_y:
    move.w #GRID_WIDTH-1,d1
.draw_x:
    tst.b (a0)+
    beq.s .draw_night
    ; Draw day cell
    move.w #GRID_SIZE-1,d2
.draw_day_cell:
    move.b #$ff,(a1)
    add.l #SCREEN_WIDTH/8,a1
    dbra d2,.draw_day_cell
    sub.l #SCREEN_WIDTH*GRID_SIZE/8,a1
    addq.l #1,a1
    bra.s .next_x
.draw_night:
    add.l #SCREEN_WIDTH/8*GRID_SIZE,a1
    addq.l #1,a1
.next_x:
    dbra d1,.draw_x
    dbra d0,.draw_y
    
    ; Draw balls
    bsr draw_ball
    lea ball1_x,a0
    bsr draw_ball
    lea ball2_x,a0
    bsr draw_ball
    
    ; Draw score
    bsr draw_score
    rts

; Draw single ball
draw_ball:
    move.w (a0),d0    ; x
    move.w 2(a0),d1   ; y
    lsr.w #3,d0       ; Convert to byte offset
    mulu.w #SCREEN_WIDTH/8,d1
    lea screen,a1
    add.l d0,a1
    add.l d1,a1
    
    ; Draw ball (simple 8x8 square)
    move.w #BALL_SIZE-1,d0
.draw_ball_loop:
    move.b #$ff,(a1)
    add.l #SCREEN_WIDTH/8,a1
    dbra d0,.draw_ball_loop
    rts

; Draw score
draw_score:
    lea screen,a0
    add.l #SCREEN_WIDTH/8*10,a0    ; Position score at top
    
    ; Draw day score
    move.w day_score,d0
    bsr draw_number
    
    ; Draw separator
    move.b #'|',(a0)+
    
    ; Draw night score
    move.w night_score,d0
    bsr draw_number
    rts

; Draw number (0-9)
draw_number:
    add.b #'0',d0
    move.b d0,(a0)+
    rts

    section data,data_c

copperlist:
    dc.w $1fc,0        ; Slow fetch mode
    dc.w $100,$0200    ; BPLCON0 - 1 bitplane
    dc.w $180,$000     ; COLOR00 - background
    dc.w $182,$fff     ; COLOR01 - foreground
    dc.w $ffff,$fffe   ; End of copper list

oldcopper:
    dc.l 0

    section bss,bss

screen:
    ds.b SCREEN_WIDTH*SCREEN_HEIGHT/8

grid:
    ds.b GRID_WIDTH*GRID_HEIGHT

ball1_x:
    ds.w 1
ball1_y:
    ds.w 1
ball1_dx:
    ds.w 1
ball1_dy:
    ds.w 1

ball2_x:
    ds.w 1
ball2_y:
    ds.w 1
ball2_dx:
    ds.w 1
ball2_dy:
    ds.w 1

day_score:
    ds.w 1
night_score:
    ds.w 1

    ds.b 1024          ; Stack space
stack: 