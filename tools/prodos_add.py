#!/usr/bin/env python3
"""Add a file to the root directory of a ProDOS disk image.

Does what Cadius ADDFILE or AppleCommander -p would do, so the probe can be
put on a disk without installing either.

usage: prodos_add.py <image.po> <local-file> <PRODOS.NAME> <type> <auxtype> [--text]
       prodos_add.py disk/probe.po src/compiled/ProbeCompiled PROBE 0x06 0x2000

--text turns the file's line feeds into the carriage returns ProDOS text
files end their lines with, so a text file can be kept in the repo as usual.
"""
import sys, struct, datetime

ENTRY_LEN = 39
ENTRIES_PER_BLOCK = 13


def blk(img, n):
    return img[n*512:(n+1)*512]


def put(img, n, data):
    assert len(data) == 512
    img[n*512:(n+1)*512] = data


def prodos_date():
    now = datetime.datetime.now()
    d = ((now.year % 100) << 9) | (now.month << 5) | now.day
    t = (now.hour << 8) | now.minute
    return struct.pack('<HH', d, t)


class Bitmap:
    def __init__(self, img, start, total):
        self.img, self.start, self.total = img, start, total
        self.nblocks = (total + 4095) // 4096

    def _bit(self, n):
        byte = self.start * 512 + n // 8
        return byte, 0x80 >> (n % 8)

    def is_free(self, n):
        byte, mask = self._bit(n)
        return bool(self.img[byte] & mask)

    def take(self, n):
        byte, mask = self._bit(n)
        self.img[byte] &= ~mask & 0xFF

    def allocate(self, count):
        out = []
        for n in range(self.total):
            if self.is_free(n):
                out.append(n)
                if len(out) == count:
                    for b in out:
                        self.take(b)
                    return out
        raise SystemExit('not enough free blocks on the volume')


def add(image_path, local_path, name, ftype, aux, text=False):
    img = bytearray(open(image_path, 'rb').read())
    if img[:4] == b'2IMG':
        raise SystemExit('give me a raw .po image, not a .2mg')

    data = open(local_path, 'rb').read()
    if text:
        data = data.replace(b'\r\n', b'\r').replace(b'\n', b'\r')
    eof = len(data)
    name = name.upper()
    if not 1 <= len(name) <= 15:
        raise SystemExit('ProDOS names are 1 to 15 characters')

    vol = blk(img, 2)
    # volume directory header: file_count +$21, bit_map_pointer +$23,
    # total_blocks +$25, all relative to the start of the 39-byte header
    bitmap_ptr = vol[4+0x23] | vol[4+0x24] << 8
    total_blocks = vol[4+0x25] | vol[4+0x26] << 8
    bitmap = Bitmap(img, bitmap_ptr, total_blocks)

    # data blocks, padded to 512
    chunks = [data[i:i+512].ljust(512, b'\0') for i in range(0, max(eof, 1), 512)]

    if eof <= 512:                                   # seedling
        storage = 1
        blocks = bitmap.allocate(1)
        put(img, blocks[0], chunks[0])
        key, used = blocks[0], 1
    elif len(chunks) <= 256:                         # sapling
        storage = 2
        blocks = bitmap.allocate(len(chunks) + 1)
        index, dblocks = blocks[0], blocks[1:]
        idx = bytearray(512)
        for i, (b, chunk) in enumerate(zip(dblocks, chunks)):
            idx[i] = b & 0xFF
            idx[256+i] = b >> 8
            put(img, b, chunk)
        put(img, index, bytes(idx))
        key, used = index, len(blocks)
    else:
        raise SystemExit('file too big for this tool (tree files not supported)')

    # find a free directory entry, walking the directory chain
    dirblk = 2
    while dirblk:
        B = bytearray(blk(img, dirblk))
        for i in range(ENTRIES_PER_BLOCK):
            if dirblk == 2 and i == 0:
                continue                             # volume header
            off = 4 + i * ENTRY_LEN
            if B[off] >> 4 == 0:
                now = prodos_date()
                e = bytearray(ENTRY_LEN)
                e[0] = (storage << 4) | len(name)
                e[1:1+len(name)] = name.encode()
                e[0x10] = ftype
                e[0x11], e[0x12] = key & 0xFF, key >> 8
                e[0x13], e[0x14] = used & 0xFF, used >> 8
                e[0x15], e[0x16], e[0x17] = eof & 0xFF, (eof >> 8) & 0xFF, (eof >> 16) & 0xFF
                e[0x18:0x1C] = now
                e[0x1C] = 0x00                       # version
                e[0x1D] = 0x00                       # min_version
                e[0x1E] = 0xE3                       # access: destroy/rename/read/write
                e[0x1F], e[0x20] = aux & 0xFF, aux >> 8
                e[0x21:0x25] = now
                e[0x25], e[0x26] = dirblk & 0xFF, dirblk >> 8
                B[off:off+ENTRY_LEN] = e
                put(img, dirblk, bytes(B))

                V = bytearray(blk(img, 2))           # bump the volume file count
                count = (V[4+0x21] | V[4+0x22] << 8) + 1
                V[4+0x21], V[4+0x22] = count & 0xFF, count >> 8
                put(img, 2, bytes(V))

                open(image_path, 'wb').write(img)
                print(f'{name}: type ${ftype:02X} aux ${aux:04X} eof {eof} '
                      f'storage {storage} key block {key} ({used} blocks)')
                return
        dirblk = B[2] | B[3] << 8
    raise SystemExit('no free directory entry in the volume root')


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if a != '--text']
    img, local, name = args[0], args[1], args[2]
    add(img, local, name, int(args[3], 0), int(args[4], 0),
        text='--text' in sys.argv[1:])
