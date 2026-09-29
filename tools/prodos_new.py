#!/usr/bin/env python3
"""Create an empty ProDOS volume, optionally bootable.

With --boot, the boot blocks and the PRODOS file are copied from an existing
image, so the new volume starts the first .SYSTEM file added after it.  Add
the rest with prodos_add.py.

usage: prodos_new.py <image.po> <VOLNAME> <blocks> [--boot <source.po>]
       prodos_new.py disk/BlueSCSILink.po BLUESCSILINK 1600 \\
                     --boot "disk/FD60_512 probe.po"
"""
import sys, struct, datetime, subprocess, os, tempfile

ENTRY_LEN = 39
ENTRIES_PER_BLOCK = 13
DIR_BLOCKS = (2, 3, 4, 5)                            # the usual four-block root
BITMAP = 6


def blk(img, n):
    return img[n*512:(n+1)*512]


def prodos_date():
    now = datetime.datetime.now()
    d = ((now.year % 100) << 9) | (now.month << 5) | now.day
    t = (now.hour << 8) | now.minute
    return struct.pack('<HH', d, t)


def read_file(img, path):
    """The data fork and entry of a file in the root of a ProDOS image."""
    name = path.strip('/').upper()
    b, first = 2, True
    while b:
        B = blk(img, b)
        for i in range(ENTRIES_PER_BLOCK):
            if first and i == 0:
                continue
            e = B[4+i*ENTRY_LEN:4+(i+1)*ENTRY_LEN]
            st, nl = e[0] >> 4, e[0] & 15
            if st and e[1:1+nl].decode() == name:
                key = e[0x11] | e[0x12] << 8
                eof = e[0x15] | e[0x16] << 8 | e[0x17] << 16
                if st == 1:
                    data = blk(img, key)
                elif st == 2:
                    ib = blk(img, key)
                    data = b''.join(blk(img, ib[j] | ib[256+j] << 8)
                                    for j in range((eof + 511) // 512))
                else:
                    raise SystemExit(f'{name}: storage type {st} not supported')
                return data[:eof], e
        b, first = B[2] | B[3] << 8, False
    raise SystemExit(f'{name} not found in the source image')


def new(image_path, volname, total, boot=None):
    volname = volname.upper()
    if not 1 <= len(volname) <= 15:
        raise SystemExit('ProDOS names are 1 to 15 characters')
    if not 280 <= total <= 65535:
        raise SystemExit('a ProDOS volume is 280 to 65535 blocks')
    nbitmap = (total + 4095) // 4096
    img = bytearray(total * 512)

    # volume directory: four linked blocks, header in the first
    for i, b in enumerate(DIR_BLOCKS):
        prev = DIR_BLOCKS[i-1] if i else 0
        nxt = DIR_BLOCKS[i+1] if i + 1 < len(DIR_BLOCKS) else 0
        img[b*512:b*512+4] = struct.pack('<HH', prev, nxt)
    h = bytearray(ENTRY_LEN)
    h[0] = 0xF0 | len(volname)
    h[1:1+len(volname)] = volname.encode()
    h[0x18:0x1C] = prodos_date()
    h[0x1E] = 0xC3                                   # destroy, rename, write, read
    h[0x1F] = ENTRY_LEN
    h[0x20] = ENTRIES_PER_BLOCK
    h[0x23:0x25] = struct.pack('<H', BITMAP)
    h[0x25:0x27] = struct.pack('<H', total)
    img[2*512+4:2*512+4+ENTRY_LEN] = h

    # bitmap: a set bit is a free block
    used = BITMAP + nbitmap                          # boot, directory, bitmap
    for n in range(used, total):
        img[BITMAP*512 + n//8] |= 0x80 >> (n % 8)

    if boot:
        src = open(boot, 'rb').read()
        img[0:1024] = src[0:1024]                    # the loader that finds PRODOS

    open(image_path, 'wb').write(img)
    print(f'/{volname}: {total} blocks, {total - used} free', flush=True)

    if boot:
        data, e = read_file(src, 'PRODOS')
        aux = e[0x1F] | e[0x20] << 8
        here = os.path.dirname(os.path.abspath(__file__))
        with tempfile.NamedTemporaryFile(delete=False) as t:
            t.write(data)
        try:
            subprocess.run([sys.executable, os.path.join(here, 'prodos_add.py'),
                            image_path, t.name, 'PRODOS',
                            hex(e[0x10]), hex(aux)], check=True)
        finally:
            os.unlink(t.name)


if __name__ == '__main__':
    args = sys.argv[1:]
    boot = None
    if '--boot' in args:
        i = args.index('--boot')
        boot = args[i+1]
        del args[i:i+2]
    if len(args) != 3:
        raise SystemExit(__doc__)
    new(args[0], args[1], int(args[2], 0), boot)
