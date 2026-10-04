	org	0x1000
	jr	start			; header: build.py fills in the 4 words
	db	"BNS", 0
	dw	0, 0, 0, 0

start:	ld	hl, hello
	ld	a, 2			; call 0x02: speak a line
	rst	0x38
loop:	ld	a, 6			; call 0x06: get a key
	rst	0x38
	ld	de, 0xFF5A		; z-chord
	or	a
	sbc	hl, de
	jr	z, done
	ld	hl, key
	ld	a, 2
	rst	0x38
	jr	loop
done:	xor	a			; call 0x00: end the program
	rst	0x38

hello:	db	"hello", 13, 0
key:	db	"key", 13, 0
code_end:
STACK_SIZE equ	128
