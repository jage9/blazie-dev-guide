"""Assemble a Braille Lite program: python build.py hello  ->  hello.bns
Run it in the folder that contains hello.asm.

Source is sjasmplus syntax, `org 0x1000`, starting with the 14-byte header
(jr start / "BNS",0 / 4 words that this script fills in). The label `code_end`
marks the end of checksummed code; what follows (variables) is RAM the program
changes while it runs, and STACK bytes (or the source's STACK_SIZE) are added after it.
"""
import os
import re
import struct
import subprocess
import sys

SJASM = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sjasmplus.exe')
STACK = 256


def checksum(code):
    """Firmware phys 0x027b."""
    hl = 0
    for a in code:
        hl <<= 1
        if hl > 0xFFFF:
            hl = (hl ^ 0xA000) & 0xFF00 | (((hl & 0xFF) + a) & 0xFF) ^ 0x97
        else:
            hl = hl & 0xFF00 | ((hl & 0xFF) + a) & 0xFF
    return hl


def build(name):
    subprocess.run([SJASM, '--nologo', '--msg=war', f'--raw={name}.raw', f'--sym={name}.sym',
                    f'--lst={name}.lst', name + '.asm'], check=True)
    code_end = int(re.search(r'^code_end: EQU 0x([0-9A-F]+)', open(name + '.sym').read(), re.M).group(1), 16)
    st = re.search(r'^STACK_SIZE: EQU 0x([0-9A-F]+)', open(name + '.sym').read(), re.M)
    img = bytearray(open(name + '.raw', 'rb').read() + bytes(int(st.group(1), 16) if st else STACK))
    n = code_end - 0x100E
    struct.pack_into('<4H', img, 6, n, len(img) - 15, checksum(img[0xE:0xE + n]), 0x1000 + len(img) - 1)
    open(name + '.bns', 'wb').write(img)
    print(f'{name}.bns: {len(img)} bytes ({n + 14} code)')


if __name__ == '__main__':
    build(sys.argv[1])
