"""Run farkle.bns on a plain Z80 with the firmware calls faked, and check it against
PlayPalace's rules.  python sim.py [games] [-v]

Build farkle first (the test reads farkle.sym), and install the Z80 emulator
with `pip install z80`.

Keys are random (menu moves, picks, r/b/t/s/d), so every path gets walked. After each
key the program's own menu is compared with the combinations PlayPalace offers for the
dice in hand, and scores are checked to be what was banked.
"""
import random
import re
import sys

import z80  # pip install z80

K = dict(next=0xFF60, prev=0xFF41, pick=0xFF45, quit=0xFF5A)


def reference(counts):
    """PlayPalace get_available_combinations, as (type, number, points), in its order."""
    n = sum(counts[1:])
    out = []
    for k in (6, 5, 4):
        for v in range(1, 7):
            if counts[v] >= k:
                out.append((k - 1, v, (100 if v == 1 else v * 10) << (k - 3)))
    if all(counts[v] == 1 for v in range(1, 7)):
        out.append((7, 0, 200))
    if all(counts[v] for v in range(1, 6)) or all(counts[v] for v in range(2, 7)):
        out.append((6, 0, 100))
    if n == 6:
        if sum(c == 3 for c in counts[1:]) == 2:
            out.append((9, 0, 250))
        if any(c == 4 for c in counts[1:]) and any(c == 2 for c in counts[1:]):
            out.append((10, 0, 150))
        if sum(c == 2 for c in counts[1:]) == 3:
            out.append((8, 0, 150))
    for v in range(1, 7):
        if counts[v] >= 3:
            out.append((2, v, 100 if v == 1 else v * 10))
    if counts[1]:
        out.append((0, 1, 10))
    if counts[5]:
        out.append((1, 5, 5))
    return sorted(out, key=lambda c: -c[2])  # stable, like Python's sort


def play(seed, players, verbose=False):
    rnd = random.Random(seed)
    img = open('farkle.bns', 'rb').read()
    sym = {m[1]: int(m[2], 16) for m in re.finditer(r'^(\w+): EQU 0x([0-9A-F]+)', open('farkle.sym').read(), re.M)
           for m in [(None, m[1], m[2])]}
    m = z80.Z80Machine()
    m.set_memory_block(0x1000, bytes(img))
    m.sp = 0x1000 + len(img) - 1
    m.pc = 0x1000
    m.set_breakpoint(0x38)
    mem = m.memory
    rd = lambda a: mem[a]
    rw = lambda a: mem[a] | mem[a + 1] << 8
    said = []
    keys = [ord(str(players))]
    names = rnd.sample(['', 'ann', 'bob', 'cy', 'dee'], players if players > 1 else 1)
    banked = {}
    steps = 0
    while True:
        for _ in range(100):  # run() also stops at frame ends
            m.ticks_to_stop = 100_000
            m.run()
            if m.pc == 0x38:
                break
        else:
            raise RuntimeError(f'stuck at {m.pc:04x}')
        fn = m.a
        if fn == 0:
            return said
        if fn == 2:
            hl, s = m.hl, b''
            while mem[hl]:
                s += bytes([mem[hl]])
                hl += 1
            said.append(s.decode().strip())
            if verbose:
                print('  ', said[-1])
            if b' banks ' in s:
                who, pts, total = re.match(rb'(.+) banks (\d+), total (\d+)', s).groups()
                banked[who] = banked.get(who, 0) + int(pts)
                assert banked[who] == int(total), s
        elif fn == 0x03:  # wait for speech: nothing to wait for
            pass
        elif fn == 0x07:  # type a line: the next name
            name = names.pop(0).encode()
            for i, c in enumerate(name):
                mem[m.hl + i] = c
            m.hl = len(name)
        elif fn == 0x44:  # voice: get with HL=DE=0, else set
            if m.hl == 0 and m.de == 0:
                m.de, m.bc = 0x0008, 0x5005
        elif fn == 0x12:
            m.hl, m.de, m.bc = rnd.getrandbits(16), 0x0930, 0x7E2B
        elif fn == 6:
            steps += 1
            assert steps < 20000, 'game too long'
            # the menu must be PlayPalace's for the dice in hand
            counts = [0] + [rd(sym['cnt'] + v) for v in range(1, 7)]
            nc = rd(sym['ncomb'])
            menu = [(rd(sym['menu'] + 4 * i), rd(sym['menu'] + 4 * i + 1), rw(sym['menu'] + 4 * i + 2))
                    for i in range(nc)]
            if rd(sym['nplay']):
                got = [(t, n if 2 <= t <= 5 else 0, p) for t, n, p in menu]
                want = [(t, n if 2 <= t <= 5 else 0, p) for t, n, p in reference(counts)]
                assert got == want, (counts, got, want)
                assert sum(counts) == rd(sym['nroll'])
            if keys:
                k = keys.pop(0)
            elif said and said[-1].endswith('y or n'):
                k = ord('n')
            else:
                k = rnd.choice([K['pick']] * 6 + [K['next'], K['prev'], ord('r'), ord('b'), ord('b'),
                                                  ord('t'), ord('s'), ord('d'), ord('x')])
            m.hl = k
        else:
            raise RuntimeError(f'unexpected call {fn:#x}')
        m.pc = rw(m.sp)  # return from RST 38
        m.sp += 2


if __name__ == '__main__':
    games = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 200
    verbose = '-v' in sys.argv
    wins = 0
    for g in range(games):
        said = play(g, 1 + g % 4, verbose)
        assert any(' wins with ' in s for s in said), said[-5:]
        wins += any(s.startswith('computer wins') for s in said)
        assert (g % 4 == 0) == any(s.startswith('computer') for s in said), g
    print(f'ok: {games} games, computer won {wins} of {len(range(0, games, 4))} against one player')
