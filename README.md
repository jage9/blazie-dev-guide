# blazie-dev-guide

A guide and a small toolkit for writing programs for the Blazie Engineering Braille Lite 2000 notetaker. The Braille 'n Speak 2000 uses the same firmware, so most of the guide also applies to it.

Start with [programming-guide.md](programming-guide.md). It explains how the unit runs a program, how to build and install one, and what each firmware call does.

## How this guide was made

This guide was written with the help of AI (Claude, by Anthropic). The information comes from the 2003 English firmware, from programs that Blazie Engineering and others wrote for these units, and from test programs that were run on the Blazie emulator. The guide marks each firmware call that was not tested.

There can be errors. Test your programs on the emulator before you use them on a real unit, and keep a backup of your files. If you find an error, please open an issue.

## What you need

- Python 3, to run `build.py`.
- The Blazie emulator, to run and test programs on a PC. Download `blazie-emu-<version>-windows.zip` from the [ssi263-speech releases](https://github.com/tgeczy/ssi263-speech/releases). Linux versions are also available. The emulator includes `blazie_files.exe`, which copies files into and out of the emulator.
- To run the Farkle test (`examples/farkle/sim.py`), the Python package `z80`. Install it with `pip install z80`.

The assembler, sjasmplus 1.24, is included.

## Build the first example

```
cd examples
python ..\build.py hello
```

This makes `hello.bns`. Section 13 of the guide tells you how to copy it to the emulator.

## Contents

| Item | Function |
|---|---|
| `programming-guide.md` | The programming guide |
| `build.py` | Assembles a program and adds the header, checksum and stack |
| `sjasmplus.exe`, `sjasmplus-LICENSE.txt` | The Z80 assembler and its licence |
| `examples/hello.asm` | The first program in the guide |
| `examples/keytest.asm` | Speaks the code of each key that you push |
| `examples/sndtest.asm` | Plays tones on the speech chip |
| `examples/farkle/` | The dice game Farkle for 1 to 4 players, with a computer player and tunes |

## Licence

The guide, `build.py` and the examples are under the MIT licence. See `LICENSE`. sjasmplus has its own licence.

## Credits

- sjasmplus is by aprisobal and other contributors, under a BSD licence. See `sjasmplus-LICENSE.txt`.
- The Blazie emulator is part of [ssi263-speech](https://github.com/tgeczy/ssi263-speech) by Tamas Geczy.
- The scoring and computer player of Farkle follow the Farkle game in PlayPalace.
- The Braille Lite 2000 and its firmware are by Blazie Engineering, later Freedom Scientific. The firmware is not part of this repository.
