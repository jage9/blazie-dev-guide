"""Check a Blazie .bns program header: python verify_header.py RECLAIM.BNS
Reads the four header words, recomputes the checksum over the word6 bytes
counted from offset 14, and reports match or mismatch. Works on old-format
(18 18, 26-byte header) and new-format (18 0C, 14-byte header) files.
Needs only the Python standard library. The .bns file stays untouched."""
import struct
import sys


def checksum(data):
    """Firmware checksum routine (see programming-guide.md section 4)."""
    hl = 0
    for byte in data:
        hl <<= 1
        if hl > 0xFFFF:
            hl = (hl ^ 0xA000) & 0xFF00 | (((hl & 0xFF) + byte) & 0xFF) ^ 0x97
        else:
            hl = hl & 0xFF00 | ((hl & 0xFF) + byte) & 0xFF
    return hl & 0xFFFF


def main(path):
    img = open(path, 'rb').read()
    if len(img) < 14 or img[2:6] != b'BNS\x00':
        print(f'{path}: not a .bns file (missing BNS tag)')
        return 1
    magic = f'{img[0]:02X} {img[1]:02X}'
    w6, w8, w10, w12 = struct.unpack_from('<4H', img, 6)
    old = img[0:2] == b'\x18\x18'
    print(f'{path}: {len(img)} bytes, header {magic} '
          f'({"old 26-byte" if old else "new 14-byte"})')
    print(f'w6 (checksum length) = {w6}')
    print(f'w8 = {w8} '
          f'({"file size - 1" if w8 == len(img) - 1 else "file size - 15" if w8 == len(img) - 15 else "see old-format note"})')
    print(f'w12 (stack pointer) = 0x{w12:04X}')
    if 14 + w6 > len(img):
        print('w6 runs past the end of the file: corrupt header')
        return 1
    calc = checksum(img[14:14 + w6])
    print(f'w10 (stored checksum) = 0x{w10:04X}, recomputed = 0x{calc:04X}')
    if calc == w10:
        print('checksum OK')
        return 0
    print('MISMATCH: the unit would say "program is corrupted"')
    return 1


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('usage: python verify_header.py PROGRAM.BNS')
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
