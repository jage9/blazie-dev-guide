# Writing programs for the Braille Lite 2000

This guide tells you how to write, build, test and install programs for the Blazie Engineering Braille Lite 2000. The Braille 'n Speak 2000 uses the same firmware, so most of this guide also applies to it. All information is for the 2003 English firmware (`BL2ENG.BNS`).

## 1. Before you start

Programs for the unit are written in Z80 assembly language. The unit has a Z180 processor. The Z180 runs Z80 code and has some more instructions.

To build programs, you need Python 3 and the files in this repository. To test programs, you need the Blazie emulator. `README.md` lists the files and tells you where to get the emulator.

## 2. How the unit runs a program

A program is a file with the extension `.bns`. The unit gives `.bns` files the type X. The unit runs only type X files.

To start a program, select it in the file menu. Or type o-chord x, then the program name.

The unit runs the program directly from the program file:

- The program starts at address 0x1000.
- The program file contains the code, the variables and the stack.
- Variables keep their values after the program ends. The next run starts with these values.
- Addresses 0x0000 to 0x0FFF contain firmware. Do not write to these addresses.

The unit keeps files in pages of 4,096 bytes. A program of 4,095 bytes or less uses one page.

## 3. Write a first program

This program says "hello". Then it says "key" each time you push a key. Push z-chord to stop the program.

```asm
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
```

To build the program:

1. Save the code as `hello.asm`.
2. In the folder that contains `hello.asm`, type `python path\to\build.py hello`.
3. Make sure that the file `hello.bns` is created.

The file `examples/hello.asm` contains this program.

### What build.py does

The unit runs a program only if its header is correct (section 4). sjasmplus assembles the source code, but it does not know the header format of the unit. When you type `python build.py name`, `build.py`:

1. Runs sjasmplus on `name.asm`. sjasmplus must be in the same folder as `build.py`.
2. Adds the stack to the end of the program. The stack size is the value of `STACK_SIZE` in the source code. If the source does not set `STACK_SIZE`, the stack is 256 bytes.
3. Writes the four header values: the checksum length, the file size minus 15, the checksum and the stack pointer.
4. Saves the result as `name.bns`.

Your source code must:

- start with the header of section 3: `jr start`, `"BNS"`, a zero byte and four empty words
- set `org 0x1000`
- put the label `code_end` after the code and fixed data, and before the variables

sjasmplus also writes the files `name.raw`, `name.sym` and `name.lst`. `name.lst` shows the address of each instruction. `name.sym` gives the address of each label. You do not need these files on the unit.

## 4. The program header

Each program starts with a header of 14 bytes. `build.py` writes the header for you.

| Offset | Size | Contents |
|---|---|---|
| 0 | 2 | Bytes 18 0C (a jump over the header) |
| 2 | 4 | The text `BNS` and a zero byte |
| 6 | 2 | The number of bytes in the checksum, counted from offset 14 |
| 8 | 2 | The file size minus 15 |
| 10 | 2 | The checksum |
| 12 | 2 | The stack pointer at start: 0x1000 + file size - 1 |

All 16-bit values are little-endian.

The unit calculates the checksum before it runs the program. If the checksum is incorrect, the unit says "program is corrupted" and does not run the program.

Put only the code and fixed data in the checksum. Do not put the variables or the stack in the checksum, because they change during a run. `build.py` puts all bytes before the label `code_end` in the checksum.

This Python function calculates the checksum:

```python
def checksum(data):
    hl = 0
    for byte in data:
        hl <<= 1
        if hl > 0xFFFF:
            hl &= 0xFFFF
            hl = (hl ^ 0xA000) & 0xFF00 | (((hl & 0xFF) + byte) & 0xFF) ^ 0x97
        else:
            hl = hl & 0xFF00 | ((hl & 0xFF) + byte) & 0xFF
    return hl
```

## 5. Firmware calls

To make a firmware call:

1. Put the call number in register A.
2. Put the arguments in registers HL, DE and BC.
3. Execute `RST 38h`.

The result is in HL. Some calls also give results in DE and BC.

Obey these rules:

- A string is the address of the text in your program. A zero byte ends the string.
- The firmware keeps the value of IX. It can change A, BC, DE, HL and IY.
- The firmware uses its own stack during a call. A stack of 128 bytes is sufficient for most programs.
- A 32-bit value has the low 16 bits in DE and the high 16 bits in BC.

All calls in sections 6 to 10 were tested on the Blazie emulator, except where a table says "Not tested".

## 6. System calls

| A | Function | Arguments | Result |
|---|---|---|---|
| 0x00 | End the program | | The call does not return |
| 0x05 | Is a key waiting? | | HL = 1 if a key is waiting, else 0. The key stays for call 0x06 |
| 0x06 | Get a key | | HL = key code (see section 7). The call waits for a key |
| 0x07 | Type a line | HL = buffer, DE = maximum length (80 or less), BC = 0 | HL = length. The user types text and pushes e-chord |
| 0x0F | Interface version | | HL = 8 on the 2003 firmware |
| 0x10 | Read memory | HL = physical address bits 0 to 15, DE = bits 16 to 19 | HL = the 16-bit value at the address |
| 0x11 | Write memory | HL = byte, DE = address bits 0 to 15, BC = bits 16 to 19 | Not tested. An incorrect address can damage files |
| 0x12 | Get the time | | HL = hour × 256 + minute, DE = month × 256 + day, BC = (year - 1900) × 256 + second |
| 0x14 | Braille to print | HL = grade 2 text in braille ASCII, DE = buffer | The buffer contains the print text. Maximum length is approximately 100 characters |
| 0x15 | Get the command line | HL = buffer | The buffer contains the command line. HL = 13 when there are no arguments. Not tested with arguments |
| 0x3C | Unit type | | HL = 5 on the Braille Lite 2000 |

The unit clock can keep only the years 1989 to 2020. The Blazie emulator sets the clock to an earlier year with the same calendar. For example, in 2026 call 0x12 gives the year 2015.

## 7. Keys

Call 0x06 gives a key code in HL:

| You push | H | L |
|---|---|---|
| A key | 0x00 | The character. Letters are lower case |
| A chord (a key with the space bar) | 0xFF | The character. Letters are upper case |

A key gives the character of its braille dots. For example, dot 4 gives 0x60.

| Keys | HL |
|---|---|
| a | 0x0061 |
| z | 0x007A |
| dot 4 | 0x0060 |
| e-chord | 0xFF45 |
| z-chord | 0xFF5A |
| space with dot 1 | 0xFF41 |
| space with dot 4 | 0xFF60 |

Use z-chord to end a program. Use e-chord to accept an entry.

## 8. Speech calls

| A | Function | Arguments | Result |
|---|---|---|---|
| 0x01 | Speak text | HL = string | The call returns immediately. The text waits behind speech that is in progress |
| 0x02 | Speak a line | HL = string. End the line with byte 13 | The call returns after the text is spoken |
| 0x03 | Wait for speech | HL = 0 | The call returns after all speech is complete |
| 0x44 | Voice settings | To read: HL = 0, DE = 0. To set: HL and DE as given by a read | After a read: E = volume, B = pitch, C = rate |
| 0x49 | Speak a character | HL = string | Speaks the first character only |
| 0x60 | Speak braille | HL = grade 2 text in braille ASCII | Translates the text to print and speaks it. Returns immediately |
| 0x61 | Speak braille | HL = grade 2 text in braille ASCII | As 0x60, but returns after the text is spoken. Not tested |

Calls 0x01 and 0x02 speak the characters as they are. Call 0x60 translates braille contractions first. For example, call 0x60 speaks `,! cat & ! dog r` as "the cat and the dog are".

When you set the voice with call 0x44, the firmware writes the volume, pitch and rate to the speech chip. Use this after you play tones (section 10).

## 9. File calls

You can open a maximum of 12 files at the same time. A file handle is a number from 0 to 11. A file position is the number of bytes from the start of the file.

| A | Function | Arguments | Result |
|---|---|---|---|
| 0x19 | Find the first file | HL = buffer of 21 bytes or more that contains a pattern, for example `*.bns` | The buffer contains the first file name that agrees with the pattern. DE = directory number |
| 0x1A | Find the next file | HL = the same buffer | The buffer contains the next file name. The search goes from the newest file to the oldest |
| 0x1B | Open a file | HL = name | HL = handle |
| 0x1C | Close a file | HL = handle | HL = 0 |
| 0x1D | Close all files | | HL = 0 |
| 0x1E | Create a file | HL = name | HL = handle. If a file has the same name, the firmware deletes it |
| 0x1F | Delete a file | HL = name | HL = 0 |
| 0x20 | Rename a file | HL = name, DE = new name | HL = 0 |
| 0x21 | Read a byte | HL = handle | HL = byte. At the end of the file, HL = 0xFFFF |
| 0x22 | Write a byte | HL = handle, DE = byte | |
| 0x23 | Read bytes | HL = handle, DE = buffer, BC = number of bytes | HL = number of bytes read |
| 0x24 | Write bytes | HL = handle, DE = buffer, BC = number of bytes | HL = number of bytes written |
| 0x25 | Insert bytes | HL = handle, DE = buffer, BC = number of bytes | Inserts the bytes at the position. HL = 0 |
| 0x26 | Remove bytes | HL = handle, DE and BC = number of bytes | Removes bytes at the position. HL = 0 |
| 0x27 | Get the size | HL = handle | DE and BC = size |
| 0x28 | Get the file date | HL = handle | HL, DE and BC as for call 0x12 |
| 0x29 | Is it the end? | HL = handle | HL = 1 at the end of the file, else 0 |
| 0x2A | Set the position | HL = handle, DE and BC = position | |
| 0x35 | Get the position | HL = handle | DE and BC = position |
| 0x6D | Read the byte before | HL = handle | HL = byte. The position moves back 1. At the start of the file, HL = 0xFFFF |

Do not use call 0x6C (relative seek). It does not operate correctly. To move the position, get it with call 0x35, add the distance, and set it with call 0x2A.

If a call fails, HL contains a negative number. Only -1 is tested:

| HL | Error |
|---|---|
| 0xFFFF (-1) | The file does not exist, or the position is at the end of the file |
| 0xFFFE (-2) | You cannot delete the help file, the clipboard or the open document |
| 0xFFFD (-3) | 12 files are open |
| 0xFFFB (-5) | The file name is not correct |
| 0xFFFA (-6) | A file with the new name exists |
| 0xFFF9 (-7) | There is not sufficient memory to make the file larger |

The unit gives each file a type from its extension:

| Extension | Type |
|---|---|
| No extension, or an extension that starts with `br` | B (grade 2 braille) |
| `.bns` | X (program) |
| `.com`, `.exe`, `.dic`, `.bin`, `.zip`, `.sys`, `.bcf` | ? (binary) |
| All other extensions | A (text) |

## 10. Sound

The speech chip (SSI-263, ports 0xC0 to 0xC4) can also play tones. To play a tune:

1. Wait until the unit stops speaking. Use call 0x03 with HL = 0.
2. Read the voice settings with call 0x44.
3. Set tone mode. Write 0x80 to port 0xC3, 0x40 to port 0xC0, then 0x70 to port 0xC3.
4. For each note, write these values:
   - the pitch to port 0xC1
   - 0xF9 to port 0xC2
   - the volume (0 to 15) to port 0xC3
   - 0xFA to port 0xC4
   - 0x37 to port 0xC0

   The note continues until you write a new note or stop the tune.
5. Stop the tune. Write 0 to port 0xC0, 0x40 to port 0xC1, 0x80 to port 0xC3, 0xC0 to port 0xC0, then 0x70 to port 0xC3.
6. Set the voice settings again with call 0x44. If you do not, the next speech starts at the pitch of the last note.

A pitch value R gives a frequency of approximately 125900 / (2047 - 8 × R) Hz.

| Note | Pitch value | Note | Pitch value |
|---|---|---|---|
| C2 | 0x0F | C4 | 0xC4 |
| G2 | 0x5F | G4 | 0xD8 |
| C3 | 0x88 | C5 | 0xE2 |
| D3 | 0x95 | E5 | 0xE8 |
| E3 | 0xA0 | G5 | 0xEC |
| F3 | 0xA6 | C6 | 0xF1 |
| G3 | 0xB0 | | |

The program must control the length of each note with a delay loop. Adjust the delay until the notes sound correct.

These ports are correct for the Braille Lite and the Braille 'n Speak. The Type 'n Speak uses ports 0x90 to 0x94. Call 0x3C gives 1 or 3 on a Type 'n Speak.

## 11. Serial port calls

These calls are not tested.

| A | Function | Arguments |
|---|---|---|
| 0x0A | Select a serial port | HL = 0 or 1 |
| 0x0B | Set the serial port on or off | HL = 1 for on, 0 for off |
| 0x0C | Send a byte | HL = byte |
| 0x0D | Receive a byte | Result in HL |
| 0x0E | Get the serial port status | Result in HL |

## 12. Test a program on a PC

`examples/farkle/sim.py` runs the game Farkle on a Z80 simulator in Python. It stops at address 0x0038 and gives a result for each firmware call. Before you use it, install the simulator with `pip install z80`, then build Farkle. To test a different program:

1. Copy `sim.py`.
2. Change it to load your program.
3. Give a simulated result for each call that your program uses.

The simulator runs only Z80 instructions. If your program uses a Z180 instruction such as `IN0`, replace the instruction in the loaded program before the test. Shipped Blazie programs confirm this matters: they contain real `ED 38`/`ED 39` (`in0`/`out0`) bytes, which a stock Z80 disassembler misreads, so use a Z180 table when disassembling.

## 13. Install and run a program on the emulator

The Blazie emulator saves the unit when you close it. Close the emulator before you change files.

The saved unit is in `%APPDATA%\ssi263-speech\blazie-emu\english.state`. To install a program, use these commands:

```
blazie_files export english.state unit.img
blazie_files unpack unit.img unit
copy hello.bns "unit\ram startup"
blazie_files pack unit new.img
blazie_files import english.state new.img
```

The import keeps the previous version as `english.state.before-import`.

Then start the emulator and run the program.

To record test results, write them into a variable in your program. The variable is in the program file. After the test, close the emulator and copy the program file out with `blazie_files extract`. Then read the results from the file.

## 14. Calls that are not fully known

The firmware has more calls than sections 6 to 11 describe. Test these calls before you use them in a program.

These calls are known from the firmware code but are not tested:

| A | Function | Arguments | Notes |
|---|---|---|---|
| 0x0A to 0x0E | Serial port | See section 11 | The BASIC interpreter `run.bns` uses these calls |
| 0x11 | Write memory | HL = byte, DE = address bits 0 to 15, BC = bits 16 to 19 | An incorrect address can damage files |
| 0x38 | Set the file date | HL = handle, DE and BC as for call 0x28 | |
| 0x61 | Speak braille and wait | HL = grade 2 text in braille ASCII | Expected to operate as 0x60 and then wait |

These calls were tested, but their function is not known:

| A | Arguments used in the test | Result |
|---|---|---|
| 0x13 | HL, DE and BC = 0xFFFF | HL = 1, DE = 1. Possibly speech and keyboard settings |
| 0x2B | | DE = 12289, BC = 8. Possibly free memory: free RAM in bytes and free flash in units of 256 KB |
| 0x2C | HL = handle, DE = 0xFF to read, or a new value | HL = file attributes. Bit 0 can be set, but it did not prevent call 0x1F from deleting the file |
| 0x43 | | HL = 1 |
| 0x45 | | HL = 278, DE = 278, BC = 0xFFFF |
| 0x46, 0x47 | HL = string | Speech is the same as calls 0x01 and 0x02 |
| 0x48 | HL = string | No speech. Possibly text to the braille display. Not tested with a braille display |
| 0x4A | | HL = 11 |
| 0x4B | | HL = 222 |
| 0x50 | | HL = 192 |
| 0x52 | HL = 0xFFFF | HL = 128 |
| 0x57 | | HL = 255 |
| 0x64 | HL = 0 | HL = 187. A setting byte. Bit 3 switches on the beeps of the unit |
| 0x67 | HL = string, DE = buffer | HL = 13. The buffer did not change |

These calls are used by the old programs, but they are not decoded and not tested:

| A | Used by |
|---|---|
| 0x09 | Checkbook, Graph-it, Reclaim, Chess, Blackjack |
| 0x2E | UPAC |
| 0x33 | BASIC compiler, Hangman 2 |
| 0x3B | Freedom Scientific games of 2001 |
| 0x6F | Freedom Scientific games of 2001 |


## 15. Rules and limits

- Set all variables when the program starts. Variables keep their values from the last run.
- Keep a program at 4,095 bytes or less if you want it to use one page of memory.
- If a program stops unexpectedly, the unit restarts. Files that the program created stay in memory. Delete them at the start of the next run.
- Do not use call 0x6C.
