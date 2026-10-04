; Farkle for the Braille Lite 2000. Rules and computer player from PlayPalace's farkle.
; 1-4 players; 1 player plays the computer. First to 500 at the end of a round wins.
; Keys: space+dot4 next option, space+dot1 previous, e-chord pick,
;       r roll, b bank, t turn score, s scores, d dice, z-chord quit.

TARGET	equ	500
STACK_SIZE equ	128		; firmware calls switch to their own stack; sim.py saw 15 bytes used
K_NEXT	equ	0xFF60
K_PREV	equ	0xFF41
K_PICK	equ	0xFF45
K_QUIT	equ	0xFF5A
T_ROLL	equ	20
T_BANK	equ	21

	org	0x1000
	jr	start			; header: build.py fills in the words
	db	"BNS", 0
	dw	0, 0, 0, 0

start:	ld	(sp0), sp
	ld	hl, obuf
	ld	(optr), hl
	ld	a, 0x12			; time and date seed the dice
	rst	0x38
	add	hl, de
	add	hl, bc
	ld	a, r
	xor	l
	ld	l, a
	or	h
	jr	nz, st1
	inc	l
st1:	ld	(seed), hl
	ld	hl, s_title
	call	sayz

newgame:
	ld	hl, vars
	ld	de, vars + 1
	ld	bc, vars_end - vars - 1
	ld	(hl), 0
	ldir
	ld	a, 0xFF		; no computer
	ld	(comp), a
askn:	ld	hl, s_howmany
	call	sayz
	call	getkey
	ld	a, h
	or	a
	jr	nz, askn
	ld	a, l
	sub	'1'
	cp	4
	jr	c, gotn
	ld	a, l			; a-d: the digits without the number sign
	sub	'a'
	cp	4
	jr	nc, askn
gotn:	inc	a
	cp	1
	jr	nz, setn
	ld	(comp), a		; one player: the computer is player 2
	inc	a
setn:	ld	(nplay), a

	xor	a
nm_l:	ld	(cur), a
	ld	b, a
	ld	a, (comp)
	cp	b
	jr	z, nm_c
	call	askname
	jr	nm_n
nm_c:	call	curname
	ex	de, hl
	ld	hl, s_computer
	call	strcpy
nm_n:	ld	a, (cur)
	ld	e, a
	ld	d, 0
	ld	hl, active
	add	hl, de
	ld	(hl), 1
	inc	a
	ld	hl, nplay
	cp	(hl)
	jr	c, nm_l

round:	xor	a
	ld	(cur), a
rd_l:	ld	a, (cur)
	ld	e, a
	ld	d, 0
	ld	hl, active
	add	hl, de
	ld	a, (hl)
	or	a
	call	nz, turn
	ld	a, (cur)
	inc	a
	ld	(cur), a
	ld	hl, nplay
	cp	(hl)
	jr	c, rd_l
	call	checkwin
	jr	round

; ---------------------------------------------------------------- names

askname:
	ld	hl, s_player
	call	pstr
	ld	a, (cur)
	inc	a
	ld	l, a
	ld	h, 0
	call	pnum
	ld	hl, s_namep
	call	sayz
	call	curname			; the unit's own line input, up to 10 letters
	push	hl
	ld	de, 10
	ld	bc, 0
	ld	a, 7
	rst	0x38
	pop	de
	ld	a, h
	or	a
	jr	nz, an_def
	ld	a, l
	cp	11
	jr	nc, an_def
	ex	de, hl
	ld	e, a
	ld	d, 0
	add	hl, de
	ld	(hl), d
	or	a
	ret	nz
an_def:	call	curname			; no name: "player N"
	ex	de, hl
	ld	hl, s_player
	call	strcpy
	dec	de
	ld	a, (cur)
	add	a, '1'
	ld	(de), a
	inc	de
	xor	a
	ld	(de), a
	ret

; ---------------------------------------------------------------- a turn

turn:	ld	hl, 0
	ld	(tscore), hl
	xor	a
	ld	(nroll), a
	ld	(nbank), a
	ld	(taken), a
	call	zcnt
	call	pcur
	ld	hl, s_turn
	call	pstr
	call	getscore
	call	pnum
	call	flush
	ld	a, (comp)
	ld	hl, cur
	cp	(hl)
	jp	z, bot

human:	call	build
hu_new:	xor	a
	ld	(sel), a
hu_say:	call	selix
	call	pitem
	call	flush
hu_key:	call	getkey
	ld	de, K_NEXT
	call	cphlde
	jr	z, hu_nx
	ld	de, K_PREV
	call	cphlde
	jr	z, hu_pv
	ld	de, K_PICK
	call	cphlde
	jp	z, hu_pk
	ld	a, h
	or	a
	jr	nz, hu_hlp
	ld	a, l
	ld	c, T_ROLL
	cp	'r'
	jr	z, hu_fnd
	ld	c, T_BANK
	cp	'b'
	jr	z, hu_fnd
	ld	hl, s_turnsc
	cp	't'
	jr	z, hu_t
	cp	's'
	jr	z, hu_s
	cp	'd'
	jr	z, hu_d
hu_hlp:	ld	hl, s_help
hu_msg:	call	sayz
	jr	hu_key
hu_t:	call	pstr
	ld	hl, (tscore)
	call	pnum
	call	flush
	jr	hu_key
hu_s:	call	pscores
	jr	hu_key
hu_d:	ld	hl, s_dicec
	call	pstr
	call	pdice
	call	flush
	jr	hu_key
hu_nx:	ld	a, (sel)
	inc	a
	ld	hl, nmenu
	cp	(hl)
	jr	c, hu_set
	xor	a
	jr	hu_set
hu_pv:	ld	a, (sel)
	or	a
	jr	nz, hu_p1
	ld	a, (nmenu)
hu_p1:	dec	a
hu_set:	ld	(sel), a
	jp	hu_say
hu_fnd:	ld	ix, menu		; the roll or bank item, if offered
	ld	a, (nmenu)
	ld	b, a
hu_f1:	ld	a, (ix+0)
	cp	c
	jr	z, hu_ex
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	djnz	hu_f1
	ld	hl, s_cant
	jr	hu_msg
hu_pk:	call	selix
hu_ex:	call	exec
	ret	z
	jp	hu_new

bot:	call	build
	ld	a, (ncomb)
	or	a
	jr	z, bt_no
	call	skip5
	jr	z, bt_rl
	call	best
	call	dotake
	jr	bt_nx
bt_no:	call	shouldbank
	jr	z, bt_bk
bt_rl:	call	doroll
	jr	bt_nx
bt_bk:	call	dobank
bt_nx:	ret	z
	jr	bot

; ---------------------------------------------------------------- actions (Z = turn over)

exec:	ld	a, (ix+0)
	cp	T_ROLL
	jr	z, doroll
	cp	T_BANK
	jp	z, dobank
	jp	dotake

doroll:	call	nextn
	ld	(nroll), a
	ld	b, a
	call	zcnt
dr_l:	push	bc
dr_d:	call	rng			; a die: 1-6 from 3 random bits
	ld	a, l
	and	7
	jr	z, dr_d
	cp	7
	jr	z, dr_d
	ld	e, a
	ld	d, 0
	ld	hl, cnt
	add	hl, de
	inc	(hl)
	pop	bc
	djnz	dr_l
	xor	a
	ld	(taken), a
	call	pcur
	ld	hl, s_rolls
	call	pstr
	call	pdice
	call	flush
	call	build
	ld	a, (ncomb)
	or	a
	ret	nz
	ld	hl, t_farkle
	call	tune
	ld	hl, s_farkle
	call	pstr
	call	pcur
	ld	hl, s_loses
	call	pstr
	ld	hl, (tscore)
	call	pnum
	ld	hl, s_points
	call	pstr
	call	flush
	xor	a
	ret

dotake:	ld	hl, (tscore)
	ld	e, (ix+2)
	ld	d, (ix+3)
	add	hl, de
	ld	(tscore), hl
	ld	c, (ix+1)
	ld	a, (ix+0)
	cp	2
	jr	c, tk_1
	cp	6
	jr	c, tk_k
	jr	z, tk_ss
	ld	a, (nroll)		; straights, pairs, triplets: every die
	ld	b, a
	call	zcnt
	jr	tk_d
tk_1:	ld	e, 1			; single 1 or single 5
	or	a
	jr	z, tk_11
	ld	e, 5
tk_11:	ld	d, 0
	ld	hl, cnt
	add	hl, de
	dec	(hl)
	ld	b, 1
	jr	tk_d
tk_k:	inc	a			; n of a kind: type + 1 dice
	ld	b, a
	ld	e, c
	ld	d, 0
	ld	hl, cnt
	add	hl, de
	ld	a, (hl)
	sub	b
	ld	(hl), a
	jr	tk_d
tk_ss:	ld	hl, cnt + 1		; small straight: 1-5 if there, else 2-6
	push	hl
	call	run5
	pop	hl
	jr	z, tk_s1
	inc	hl
tk_s1:	ld	b, 5
tk_s2:	dec	(hl)
	inc	hl
	djnz	tk_s2
	ld	b, 5
tk_d:	ld	a, (nroll)
	sub	b
	ld	(nroll), a
	ld	a, (nbank)
	add	a, b
	ld	(nbank), a
	ld	a, 1
	ld	(taken), a
	call	pcur
	ld	hl, s_takes
	call	pstr
	call	pitem
	call	flush
	ld	a, (nroll)
	or	a
	jr	nz, tk_e
	ld	a, (nbank)
	cp	6
	jr	nz, tk_e
	ld	hl, t_hot
	call	tune
	ld	hl, s_hot
	call	sayz
tk_e:	call	build
	or	1
	ret

dobank:	call	scoreptr
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	push	hl
	ld	hl, (tscore)
	add	hl, de
	ex	de, hl
	pop	hl
	ld	(hl), d
	dec	hl
	ld	(hl), e
	call	pcur
	ld	hl, s_banks
	call	pstr
	ld	hl, (tscore)
	call	pnum
	ld	hl, s_total
	call	pstr
	call	getscore
	call	pnum
	call	flush
	xor	a
	ret

; dice the next roll throws: what is left, or 6 after hot dice
nextn:	ld	a, (nroll)
	or	a
	ret	nz
	ld	a, (nbank)
	neg
	add	a, 6
	ret	nz
	ld	(nbank), a
	ld	a, 6
	ret

zcnt:	ld	hl, cnt
	ld	c, 7
	xor	a
zc_l:	ld	(hl), a
	inc	hl
	dec	c
	jr	nz, zc_l
	ret

; ---------------------------------------------------------------- the menu

; menu: 4 bytes an item: type, number, points (word). Types 0 single 1, 1 single 5,
; 2-5 three to six of a kind, 6 small straight, 7 large straight, 8 three pairs,
; 9 double triplets, 10 four of a kind and a pair, 20 roll, 21 bank.
build:	ld	hl, menu
	ld	(mptr), hl
	xor	a
	ld	(nmenu), a
	ld	b, 6
	call	kinds
	ld	b, 5
	call	kinds
	ld	b, 4
	call	kinds
	ld	hl, cnt + 1		; large straight: one of each
	ld	b, 6
bl_ls:	ld	a, (hl)
	dec	a
	jr	nz, bl_s
	inc	hl
	djnz	bl_ls
	ld	a, 7
	ld	de, 200
	call	additem
bl_s:	ld	hl, cnt + 1
	call	run5
	jr	z, bl_s1
	ld	hl, cnt + 2
	call	run5
	jr	nz, bl_6
bl_s1:	ld	a, 6
	ld	de, 100
	call	additem
bl_6:	ld	a, (nroll)
	cp	6
	jr	nz, bl_3
	ld	c, 3
	call	nexact
	cp	2
	jr	nz, bl_fh
	ld	a, 9
	ld	de, 250
	call	additem
bl_fh:	ld	c, 4
	call	nexact
	or	a
	jr	z, bl_tp
	ld	c, 2
	call	nexact
	or	a
	jr	z, bl_tp
	ld	a, 10
	ld	de, 150
	call	additem
bl_tp:	ld	c, 2
	call	nexact
	cp	3
	jr	nz, bl_3
	ld	a, 8
	ld	de, 150
	call	additem
bl_3:	ld	b, 3
	call	kinds
	ld	a, (cnt + 1)
	or	a
	jr	z, bl_5
	xor	a
	ld	de, 10
	call	additem
bl_5:	ld	a, (cnt + 5)
	or	a
	jr	z, bl_srt
	ld	a, 1
	ld	de, 5
	call	additem
bl_srt:	call	sort
	ld	a, (nmenu)
	ld	(ncomb), a
	ld	de, 0
	ld	a, (nroll)		; roll: before any roll, or after taking points
	or	a
	jr	z, bl_r
	ld	a, (taken)
	or	a
	jr	z, bl_b
bl_r:	ld	a, T_ROLL
	call	additem
bl_b:	ld	hl, (tscore)		; bank: points, and nothing left to take
	ld	a, h
	or	l
	ret	z
	ld	a, (nroll)
	or	a
	jr	z, bl_b1
	ld	a, (ncomb)
	or	a
	ret	nz
bl_b1:	ld	a, T_BANK
	; fall through

additem:			; A type, C number, DE points
	ld	hl, (mptr)
	ld	(hl), a
	inc	hl
	ld	(hl), c
	inc	hl
	ld	(hl), e
	inc	hl
	ld	(hl), d
	inc	hl
	ld	(mptr), hl
	ld	hl, nmenu
	inc	(hl)
	ret

kinds:	ld	c, 1			; B of a kind, for each number C
kd_l:	ld	e, c
	ld	d, 0
	ld	hl, cnt
	add	hl, de
	ld	a, (hl)
	cp	b
	jr	c, kd_n
	ld	hl, 100
	ld	a, c
	cp	1
	jr	z, kd_p
	ld	l, c			; number * 10
	ld	h, 0
	add	hl, hl
	ld	d, h
	ld	e, l
	add	hl, hl
	add	hl, hl
	add	hl, de
kd_p:	ld	a, b			; doubled for each die past three
	sub	3
kd_s:	jr	z, kd_a
	add	hl, hl
	dec	a
	jr	kd_s
kd_a:	ex	de, hl
	ld	a, b
	dec	a
	push	bc
	call	additem
	pop	bc
kd_n:	inc	c
	ld	a, c
	cp	7
	jr	c, kd_l
	ret

run5:	ld	b, 5			; Z if 5 numbers in a row from HL
r5_l:	ld	a, (hl)
	or	a
	jr	z, r5_n
	inc	hl
	djnz	r5_l
	xor	a
	ret
r5_n:	inc	a
	ret

nexact:	ld	hl, cnt + 1		; A = how many numbers appear exactly C times
	ld	b, 6
	ld	e, 0
ne_l:	ld	a, (hl)
	cp	c
	jr	nz, ne_n
	inc	e
ne_n:	inc	hl
	djnz	ne_l
	ld	a, e
	ret

sort:	ld	a, (nmenu)		; by points, highest first, ties kept in order
	cp	2
	ret	c
	ld	b, 1
so_i:	ld	c, b
so_j:	ld	a, c
	or	a
	jr	z, so_n
	add	a, a
	add	a, a
	ld	e, a
	ld	d, 0
	ld	ix, menu
	add	ix, de
	ld	l, (ix+2)
	ld	h, (ix+3)
	ld	e, (ix-2)
	ld	d, (ix-1)
	ex	de, hl
	or	a
	sbc	hl, de
	jr	nc, so_n
	push	bc
	ld	b, 4
so_sw:	ld	a, (ix+0)
	ld	c, (ix-4)
	ld	(ix-4), a
	ld	(ix+0), c
	inc	ix
	djnz	so_sw
	pop	bc
	dec	c
	jr	so_j
so_n:	inc	b
	ld	a, (nmenu)
	cp	b
	jr	nz, so_i
	ret

selix:	ld	a, (sel)
	add	a, a
	add	a, a
	ld	e, a
	ld	d, 0
	ld	ix, menu
	add	ix, de
	ret

pitem:	ld	a, (ix+0)		; the item at IX, in words
	cp	T_ROLL
	jr	z, pi_r
	cp	T_BANK
	jr	z, pi_b
	ld	hl, ctab
	call	pword
	ld	a, (ix+0)
	cp	2
	jr	c, pi_p
	cp	6
	jr	nc, pi_p
	ld	a, ' '
	call	pchr
	ld	a, (ix+1)
	dec	a
	ld	hl, ptab
	call	pword
pi_p:	ld	hl, s_comma
	call	pstr
	ld	l, (ix+2)
	ld	h, (ix+3)
	call	pnum
	ld	hl, s_points
	jp	pstr
pi_r:	ld	hl, s_roll
	call	pstr
	call	nextn
	ld	l, a
	ld	h, 0
	call	pnum
	ld	hl, s_dice
	jp	pstr
pi_b:	ld	hl, s_bank
	call	pstr
	ld	hl, (tscore)
	call	pnum
	ld	hl, s_points
	jp	pstr

pword:	add	a, a			; string A of the table at HL
	ld	e, a
	ld	d, 0
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	jp	pstr

; ---------------------------------------------------------------- the computer

; Z: take the lone 5 no more; roll the dice left instead (PlayPalace's rule)
skip5:	ld	a, (taken)
	or	a
	jr	z, nz_r
	ld	a, (ncomb)
	dec	a
	jr	nz, nz_r
	ld	a, (menu)
	dec	a
	jr	nz, nz_r
	call	getscore
	ld	de, (tscore)
	add	hl, de
	push	hl
	ld	de, TARGET - 5
	or	a
	sbc	hl, de
	pop	hl
	jr	nc, nz_r
	ld	de, TARGET - 40		; near the goal: take it
	or	a
	sbc	hl, de
	jr	nc, nz_r
	ld	a, (nroll)
	cp	4
	jr	nc, z_r
	cp	3
	jr	nz, nz_r
	ld	hl, (tscore)
	ld	de, 70
	or	a
	sbc	hl, de
	jr	nc, nz_r
	call	bestother		; behind by more than 60
	push	hl
	call	getscore
	ld	de, 60
	add	hl, de
	pop	de
	or	a
	sbc	hl, de
	jr	nc, nz_r
z_r:	xor	a
	ret
nz_r:	or	1
	ret

; Z: bank now
shouldbank:
	ld	hl, (tscore)
	ld	a, h
	or	l
	jr	z, nz_r
	call	getscore
	ld	(tmps), hl
	ld	de, (tscore)
	add	hl, de
	ld	(tmpt), hl
	ld	de, TARGET
	or	a
	sbc	hl, de
	jr	nc, z_r
	call	bestother
	ld	(tmpb), hl
	ld	de, TARGET
	or	a
	sbc	hl, de
	jr	c, sb_1
	ld	hl, (tmpb)		; someone has won already: beat them
	ld	de, (tmpt)
	or	a
	sbc	hl, de
	jr	nc, nz_r
sb_1:	call	nextn
	ld	e, a
	ld	d, 0
	ld	hl, thr - 1
	add	hl, de
	ld	l, (hl)
	ld	h, d
	push	hl
	ld	hl, (tmpt)
	ld	de, TARGET - 60
	or	a
	sbc	hl, de
	pop	hl
	ld	a, 85
	call	nc, scale
	push	hl
	ld	hl, (tmps)
	ld	de, 100
	add	hl, de
	ld	de, (tmpb)
	or	a
	sbc	hl, de
	pop	hl
	ld	a, 115
	call	c, scale
	push	hl
	ld	hl, (tmpb)
	ld	de, 100
	add	hl, de
	ld	de, (tmps)
	or	a
	sbc	hl, de
	pop	hl
	ld	a, 90
	call	c, scale
	ex	de, hl
	ld	hl, (tscore)
	or	a
	sbc	hl, de
	jp	nc, z_r
	jp	nz_r

scale:	call	mul8			; HL = HL * A / 100, rounded
	ld	de, 50
	add	hl, de
	ld	e, 100
	jp	div8

bestother:			; HL = the best score of the others
	ld	hl, 0
	ld	b, 0
bo_l:	ld	a, (cur)
	cp	b
	jr	z, bo_n
	push	hl
	ld	a, b
	call	scorea
	pop	de
	push	hl
	or	a
	sbc	hl, de
	pop	hl
	jr	nc, bo_n
	ex	de, hl
bo_n:	inc	b
	ld	a, (nplay)
	cp	b
	jr	nz, bo_l
	ret

; IX = the scoring item to take: hot dice, then a combination over singles,
; then points per die, then dice left to roll, then points.
best:	xor	a
	ld	(bi), a
	ld	(ci), a
	ld	ix, menu
	call	keys
	call	keep
bs_l:	ld	a, (ci)
	inc	a
	ld	(ci), a
	ld	hl, ncomb
	cp	(hl)
	jr	nc, bs_e
	add	a, a
	add	a, a
	ld	e, a
	ld	d, 0
	ld	ix, menu
	add	ix, de
	call	keys
	ld	hl, kt
	ld	de, kb
	ld	b, 6
bs_c:	ld	a, (de)
	cp	(hl)
	jr	c, bs_gt
	jr	nz, bs_l
	inc	hl
	inc	de
	djnz	bs_c
	jr	bs_l
bs_gt:	call	keep
	ld	a, (ci)
	ld	(bi), a
	jr	bs_l
bs_e:	ld	a, (bi)
	ld	(sel), a
	jp	selix

keep:	ld	hl, kt
	ld	de, kb
	ld	bc, 6
	ldir
	ret

keys:	ld	a, (ix+0)		; kt: the item's rank, most significant byte first
	ld	b, 1
	cp	2
	jr	c, ky_u
	inc	b
	inc	b
	inc	b
	cp	6
	jr	c, ky_k
	ld	b, 5
	jr	z, ky_u
	ld	b, 6
	jr	ky_u
ky_k:	ld	b, a
	inc	b
ky_u:	ld	a, (nroll)
	sub	b
	ld	(kt+3), a
	ld	c, 0
	jr	nz, ky_1
	ld	a, (nbank)
	add	a, b
	cp	6
	jr	nz, ky_1
	ld	c, 4
ky_1:	ld	a, (ix+0)
	cp	2
	jr	c, ky_2
	inc	c
	inc	c
ky_2:	ld	a, c
	ld	(kt), a
	ld	l, (ix+2)
	ld	h, (ix+3)
	ld	a, h
	ld	(kt+4), a
	ld	a, l
	ld	(kt+5), a
	push	bc
	ld	a, 60
	call	mul8
	pop	bc
	ld	e, b
	call	div8
	ld	a, h
	ld	(kt+1), a
	ld	a, l
	ld	(kt+2), a
	ret

; ---------------------------------------------------------------- end of a round

checkwin:
	ld	hl, 0
	ld	(tmpb), hl
	xor	a
	ld	(nwin), a
	ld	b, a
cw_l:	call	isact
	jr	z, cw_n
	ld	a, b
	call	scorea
	ld	de, TARGET
	push	hl
	or	a
	sbc	hl, de
	pop	hl
	jr	c, cw_n
	ld	de, (tmpb)
	push	hl
	or	a
	sbc	hl, de
	pop	hl
	jr	c, cw_n
	jr	z, cw_eq
	ld	(tmpb), hl
	xor	a
	ld	(nwin), a
cw_eq:	ld	hl, nwin
	inc	(hl)
cw_n:	inc	b
	ld	a, (nplay)
	cp	b
	jr	nz, cw_l
	ld	a, (nwin)
	or	a
	ret	z
	dec	a
	jr	z, cw_one
	ld	b, a			; a tie: the leaders play on
ct_l:	ld	a, b
	call	scorea
	ld	de, (tmpb)
	or	a
	sbc	hl, de
	jr	z, ct_n
	ld	hl, active
	ld	e, b
	ld	d, 0
	add	hl, de
	ld	(hl), d
ct_n:	inc	b
	ld	a, (nplay)
	cp	b
	jr	nz, ct_l
	ld	hl, s_tie
	jp	sayz
cw_one:	ld	b, a
co_l:	call	isact
	jr	z, co_n
	ld	a, b
	call	scorea
	ld	de, (tmpb)
	or	a
	sbc	hl, de
	jr	z, co_w
co_n:	inc	b
	jr	co_l
co_w:	ld	a, b
	ld	(cur), a
	ld	hl, t_win
	ld	a, (comp)		; the computer won: you lost
	cp	b
	jr	nz, co_t
	ld	hl, t_lose
co_t:	call	tune
	call	pcur
	ld	hl, s_wins
	call	pstr
	ld	hl, (tmpb)
	call	pnum
	ld	hl, s_points
	call	pstr
	call	flush
	call	pscores
pa_l:	ld	hl, s_again		; y or n only
	call	sayz
	call	getkey
	ld	a, l
	or	0x20
	cp	'n'
	jr	z, bye
	cp	'y'
	jr	nz, pa_l
	ld	sp, (sp0)
	jp	newgame
bye:	ld	hl, s_bye
	call	sayz
	xor	a
	rst	0x38			; back to the unit

isact:	ld	hl, active		; Z if player B is out
	ld	e, b
	ld	d, 0
	add	hl, de
	ld	a, (hl)
	or	a
	ret

; ---------------------------------------------------------------- players

curname:
	ld	a, (cur)
namea:	ld	l, a			; HL = name of player A
	add	a, a
	add	a, a
	add	a, a
	add	a, l
	add	a, l
	add	a, l
	ld	e, a
	ld	d, 0
	ld	hl, names
	add	hl, de
	ret

pcur:	call	curname
	jp	pstr

getscore:
	ld	a, (cur)
scorea:	call	scorep			; HL = score of player A
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	ex	de, hl
	ret
scoreptr:
	ld	a, (cur)
scorep:	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, scores
	add	hl, de
	ret

pscores:
	ld	b, 0
ps_l:	push	bc
	ld	a, b
	call	namea
	call	pstr
	ld	a, ' '
	call	pchr
	pop	bc
	push	bc
	ld	a, b
	call	scorea
	call	pnum
	ld	hl, s_comma
	call	pstr
	pop	bc
	inc	b
	ld	a, (nplay)
	cp	b
	jr	nz, ps_l
	jp	flush

pdice:	ld	c, 1			; the dice in hand, low to high
	ld	b, 0
pd_v:	ld	e, c
	ld	d, 0
	ld	hl, cnt
	add	hl, de
	ld	a, (hl)
pd_c:	or	a
	jr	z, pd_n
	push	af
	ld	a, b
	or	a
	jr	z, pd_1
	ld	hl, s_comma
	call	pstr
pd_1:	ld	b, 1
	ld	a, c
	add	a, '0'
	call	pchr
	pop	af
	dec	a
	jr	pd_c
pd_n:	inc	c
	ld	a, c
	cp	7
	jr	c, pd_v
	ret

; ---------------------------------------------------------------- keys, words, numbers

getkey:	ld	a, 6
	rst	0x38
	push	hl			; the moment of each key stirs the dice
	ld	hl, (seed)
	ld	a, r
	xor	h
	ld	h, a
	or	l
	jr	nz, gk_1
	inc	l
gk_1:	ld	(seed), hl
	pop	hl
	ld	de, K_QUIT
	call	cphlde
	ret	nz
	ld	hl, s_quit
	call	sayz
	ld	a, 6
	rst	0x38
	ld	a, l
	or	0x20
	cp	'y'
	jp	z, bye
	ld	hl, s_cont
	call	sayz
	jr	getkey

rng:	ld	hl, (seed)		; xorshift, J. Metcalf
	ld	a, h
	rra
	ld	a, l
	rra
	xor	h
	ld	h, a
	ld	a, l
	rra
	ld	a, h
	rra
	xor	l
	ld	l, a
	xor	h
	ld	h, a
	ld	(seed), hl
	ret

cphlde:	or	a			; Z if HL = DE
	sbc	hl, de
	add	hl, de
	ret

strcpy:	ld	a, (hl)
	ld	(de), a
	inc	hl
	inc	de
	or	a
	jr	nz, strcpy
	ret

mul8:	ex	de, hl			; HL = HL * A
	ld	hl, 0
	ld	b, 8
m8_l:	add	hl, hl
	add	a, a
	jr	nc, m8_n
	add	hl, de
m8_n:	djnz	m8_l
	ret

div8:	xor	a			; HL = HL / E, A = remainder
	ld	b, 16
d8_l:	add	hl, hl
	rla
	cp	e
	jr	c, d8_n
	sub	e
	inc	l
d8_n:	djnz	d8_l
	ret

pnum:	ld	d, 0			; HL in decimal
pn_l:	ld	e, 10
	call	div8
	push	af
	inc	d
	ld	a, h
	or	l
	jr	nz, pn_l
pn_o:	pop	af
	add	a, '0'
	call	pchr
	dec	d
	jr	nz, pn_o
	ret

pchr:	ld	hl, (optr)
	ld	(hl), a
	inc	hl
	ld	(optr), hl
	ret

pstr:	ld	de, (optr)
ps_c:	ld	a, (hl)
	or	a
	jr	z, ps_e
	ld	(de), a
	inc	hl
	inc	de
	jr	ps_c
ps_e:	ld	(optr), de
	ret

sayz:	call	pstr
flush:	ld	a, 13			; speak and show the line
	call	pchr
	xor	a
	call	pchr
	ld	hl, obuf
	ld	(optr), hl
	ld	a, 2
	rst	0x38
	ret

; ---------------------------------------------------------------- tunes

; HL = notes: pitch, length in ~1/20 s; 0 ends. As run.bns plays BASIC's "sound":
; the SSI-263 in mode 1 holds one sound at the pitch set in R1 until stopped.
; R2, R4 and the stop as Blazie's graphit.bns does them.
; Pitch: f = 125900 / (2047 - 8 * R1) Hz (fitted to notes heard with R2 = FF, then
; adjusted for R2 = F9's low inflection bits).
tune:	push	hl
	ld	a, 3			; wait until the unit stops speaking
	ld	hl, 0
	rst	0x38
	ld	a, 0x44			; the voice: E volume, B pitch, C rate
	ld	hl, 0
	ld	d, h
	ld	e, l
	rst	0x38
	ld	(voice), de
	ld	(voice + 2), bc
	ld	a, e			; tones at the unit's volume
	and	0x0F
	ld	(amp), a
	pop	hl
	ld	a, 0x80			; mode 1: hold the sound
	out	(0xC3), a
	ld	a, 0x40
	out	(0xC0), a
	ld	a, 0x70
	out	(0xC3), a
tn_n:	ld	a, (hl)
	or	a
	jr	z, tn_e
	inc	hl
	out	(0xC1), a		; pitch
	ld	a, 0xF9			; rate and inflection, as graphit.bns
	out	(0xC2), a
	ld	a, (amp)
	out	(0xC3), a
	ld	a, 0xFA			; filter, as graphit.bns
	out	(0xC4), a
	ld	a, 0x37
	out	(0xC0), a
	ld	b, (hl)
	inc	hl
	call	ticks
	jr	tn_n
tn_e:	xor	a			; stop; pitch down; mode 3 again for speech
	out	(0xC0), a
	ld	a, 0x40
	out	(0xC1), a
	ld	a, 0x80
	out	(0xC3), a
	ld	a, 0xC0
	out	(0xC0), a
	ld	a, 0x70
	out	(0xC3), a
	ld	a, 0x44			; set the voice again: the firmware rewrites
	ld	hl, (voice)		; the chip's pitch, rate and volume
	ld	de, (voice + 2)
	rst	0x38
	ret

ticks:	ld	de, 4800		; B * ~1/20 s at 6 MHz
tk_l:	dec	de
	ld	a, d
	or	e
	jr	nz, tk_l
	djnz	ticks
	ret

t_farkle:	db	0x88, 4, 0x5F, 4, 0x0F, 10, 0		; c3 g2 c2
t_hot:		db	0xC4, 3, 0xD8, 3, 0xE2, 6, 0		; c4 g4 c5
t_win:		db	0xE2, 6, 0xE8, 6, 0xEC, 6, 0xF1, 16, 0
t_lose:		db	0xB0, 3, 0xA6, 3, 0xA0, 3, 0x95, 3, 0x88, 6, 0	; g3 f3 e3 d3 c3	; c5 e5 g5 c6

; ---------------------------------------------------------------- words

thr:	db	30, 50, 70, 90, 120, 150	; the computer banks at this, by dice left

ctab:	dw	c_s1, c_s5, c_3, c_4, c_5, c_6, c_ss, c_ls, c_tp, c_dt, c_fh
ptab:	dw	p_1, p_2, p_3, p_4, p_5, p_6
c_s1:	dz	"single one"
c_s5:	dz	"single five"
c_3:	dz	"three"
c_4:	dz	"four"
c_5:	dz	"five"
c_6:	dz	"six"
c_ss:	dz	"small straight"
c_ls:	dz	"large straight"
c_tp:	dz	"three pairs"
c_dt:	dz	"double triplets"
c_fh:	dz	"four of a kind and a pair"
p_1:	dz	"ones"
p_2:	dz	"twos"
p_3:	dz	"threes"
p_4:	dz	"fours"
p_5:	dz	"fives"
p_6:	dz	"sixes"

s_title:	dz	"farkle. first to 500 points wins."
s_howmany:	dz	"how many players, 1 to 4? 1 plays the computer."
s_player:	dz	"player "
s_namep:	dz	" name, then e chord"
s_computer:	dz	"computer"
s_turn:		dz	"'s turn, score "
s_rolls:	dz	" rolls "
s_farkle:	dz	"farkle! "
s_loses:	dz	" loses "
s_points:	dz	" points"
s_takes:	dz	" takes "
s_hot:		dz	"hot dice"
s_banks:	dz	" banks "
s_total:	dz	", total "
s_roll:		dz	"roll "
s_dice:		dz	" dice"
s_bank:		dz	"bank "
s_comma:	dz	", "
s_cant:		dz	"not now"
s_turnsc:	dz	"turn score "
s_dicec:	dz	"dice "
s_help:		dz	"dot 4 chord next, dot 1 chord back, e chord picks, r roll, b bank, t turn, s scores, d dice, z chord quits"
s_quit:		dz	"quit game? y or n"
s_cont:		dz	"continuing"
s_tie:		dz	"a tie. the leaders play on."
s_wins:		dz	" wins with "
s_again:	dz	"play again? y or n"
s_bye:		dz	"bye"

code_end:
; ---------------------------------------------------------------- RAM (in the file, after the code)

seed:	dw	0
voice:	ds	4
amp:	db	0
sp0:	dw	0
optr:	dw	0
obuf:	ds	128
vars:
nplay:	db	0
comp:	db	0
cur:	db	0
active:	ds	4
scores:	ds	8
names:	ds	44
tscore:	dw	0
nroll:	db	0
nbank:	db	0
taken:	db	0
cnt:	ds	7
menu:	ds	64
nmenu:	db	0
ncomb:	db	0
mptr:	dw	0
sel:	db	0
tmps:	dw	0
tmpt:	dw	0
tmpb:	dw	0
nwin:	db	0
kt:	ds	6
kb:	ds	6
bi:	db	0
ci:	db	0
vars_end:
