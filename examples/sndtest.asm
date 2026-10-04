; sndtest.bns: real tones, as run.bns (the BASIC "sound" command) plays them:
; the SSI-263 put in mode 1 holds one sound at a set pitch until told to stop.
; a-f play sounds, each followed by "ok" to check the speech after it. z-chord quits.
	org	0x1000
	jr	start
	db	"BNS", 0
	dw	0, 0, 0, 0

start:	ld	hl, s_hello
	call	say
loop:	ld	a, 6
	rst	0x38
	ld	de, 0xFF5A
	or	a
	sbc	hl, de
	add	hl, de
	jr	z, quit
	ld	a, h
	or	a
	jr	nz, loop
	ld	a, l
	sub	'a'
	cp	6
	jr	nc, help
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, sounds
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	play
	ld	hl, s_ok
	call	say
	jr	loop
help:	ld	hl, s_hello
	call	say
	jr	loop
quit:	xor	a
	rst	0x38

say:	ld	a, 2
	rst	0x38
	ret

; HL = notes: pitch, length (in ~1/20 s); 0 ends
play:	call	quiet
	ld	a, 0x80			; mode 1: hold the sound
	out	(0xC3), a
	ld	a, 0x40
	out	(0xC0), a
	ld	a, 0x70
	out	(0xC3), a
pl_n:	ld	a, (hl)
	or	a
	jr	z, pl_e
	inc	hl
	out	(0xC1), a		; pitch
	ld	a, 0xFF
	out	(0xC2), a
	ld	a, 0x0C			; loudness
	out	(0xC3), a
	ld	a, 0xF8			; filter
	out	(0xC4), a
	ld	a, 0x37
	out	(0xC0), a
	ld	b, (hl)
	inc	hl
pl_w:	call	tick
	djnz	pl_w
	jr	pl_n
pl_e:	xor	a			; stop, and back to mode 3 for speech
	out	(0xC0), a
	ld	a, 0x80
	out	(0xC3), a
	ld	a, 0xC0
	out	(0xC0), a
	ld	a, 0x70
	out	(0xC3), a
	ret

tick:	ld	de, 4800		; about 1/20 s at 6 MHz
tk:	dec	de
	ld	a, d
	or	e
	jr	nz, tk
	ret

; wait until the unit stops speaking (call 0x03)
quiet:	ld	a, 3
	ld	hl, 0
	rst	0x38
	ret

sounds:	dw	snd_a, snd_b, snd_c, snd_d, snd_e, snd_f
snd_a:	db	0x80, 6, 0				; one note
snd_b:	db	0x60, 3, 0x80, 3, 0xA0, 3, 0xC0, 6, 0	; rising
snd_c:	db	0xA0, 4, 0x80, 4, 0x50, 12, 0		; falling: farkle?
snd_d:	db	0x40, 6, 0				; low
snd_e:	db	0xE0, 6, 0				; high
snd_f:	db	0x80, 2, 0xA0, 2, 0x80, 2, 0xA0, 2, 0xC0, 8, 0	; fanfare: win?

s_hello: db	"tone test. a to f play sounds, z chord quits.", 13, 0
s_ok:	db	"ok", 13, 0
code_end:
