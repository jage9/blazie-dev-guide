; keytest.bns: speaks each key you push: "key" or "chord", then the
; key code as two hex bytes (H, then L). z-chord ends the program.
	org	0x1000
	jr	start			; header: filled in by build.py
	db	"BNS"
	db	0
	dw	0, 0, 0, 0

start:
	ld	hl, msg_hello
	call	say
	ld	hl, msg_keys
	call	say
loop:
	ld	a, 6			; wait for a key
	rst	0x38
	ld	a, h
	or	a
	jr	z, plain
	ld	a, l
	cp	'z'
	jr	z, quit
	ld	de, msg_chord
	jr	show
plain:
	ld	de, msg_key
show:
	push	hl
	ex	de, hl
	ld	de, buf
copy:	ld	a, (hl)			; word into buf
	or	a
	jr	z, copied
	ld	(de), a
	inc	hl
	inc	de
	jr	copy
copied:	pop	hl
	ld	a, h
	call	hex
	ld	a, ' '
	ld	(de), a
	inc	de
	ld	a, l
	call	hex
	ld	a, 13
	ld	(de), a
	inc	de
	xor	a
	ld	(de), a
	ld	hl, buf
	call	say
	jr	loop
quit:
	ld	hl, msg_bye
	call	say
	xor	a
	rst	0x38			; exit

say:	ld	a, 2
	rst	0x38
	ret

hex:	push	af			; A as two hex digits with a space, at DE
	rrca
	rrca
	rrca
	rrca
	call	nib
	ld	a, ' '
	ld	(de), a
	inc	de
	pop	af
nib:	and	0x0F
	add	a, '0'
	cp	'9'+1
	jr	c, nib1
	add	a, 'a'-'9'-1
nib1:	ld	(de), a
	inc	de
	ret

; SSI-263 at C0-C4, as simon.bns drives it on the Braille Lite
tone_init:
	call	quiet
	xor	a
	out	(0xC0), a
	ld	a, 0x40
	out	(0xC1), a
	ld	a, 0x80
	out	(0xC3), a
	ld	a, 0xC0
	out	(0xC0), a
	ld	a, 0x70
	out	(0xC3), a
	ret

tone:	call	quiet			; B = pitch
	ld	a, b
	out	(0xC1), a
	ld	a, 0xFF
	out	(0xC2), a
	ld	a, 0x0C		; amplitude
	out	(0xC3), a
	ld	a, 0xF8		; filter
	out	(0xC4), a
	ld	a, 0x37
	out	(0xC0), a
	call	delay
	ld	a, 0x80		; stop
	out	(0xC3), a
	ld	a, 0x40
	out	(0xC0), a
	ld	a, 0x70
	out	(0xC3), a
	; fall through: short gap
delay:	ld	de, 0
dl:	dec	de
	ld	a, d
	or	e
	jr	nz, dl
	ret

; Wait while the firmware is speaking: it enables INT2 (the SSI-263's
; request, ITC bit 2) for the length of its speech. Give up after ~3 s.
quiet:	ld	bc, 0
q1:	db	0xED, 0x38, 0x34	; in0 a, (0x34)
	and	4
	ret	z
	ld	a, 30
q2:	dec	a
	jr	nz, q2
	dec	bc
	ld	a, b
	or	c
	jr	nz, q1
	ret

msg_hello:	db	"key test"
		db	13, 0
msg_keys:	db	"press keys, z chord quits"
		db	13, 0
msg_key:	dz	"key "
msg_chord:	dz	"chord "
msg_bye:	db	"bye"
		db	13, 0
code_end:
buf:		ds	32
