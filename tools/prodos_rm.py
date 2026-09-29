#!/usr/bin/env python3
"""Delete a file from a ProDOS disk image.

For getting out of trouble: if something installed into a System folder stops
the volume booting, pull the SD card, delete the file here, put it back.

usage: prodos_rm.py <image.po> <path>
       prodos_rm.py "gsvolume.po" /SYSTEM/TCPIP/BSLINK

The path is inside the volume, so it starts after the volume name.
"""
import sys

ENTRY_LEN = 39
ENTRIES_PER_BLOCK = 13


def blk(img, n):
    return img[n*512:(n+1)*512]


def put(img, n, data):
    img[n*512:(n+1)*512] = data


class Bitmap:
    def __init__(self, img, start, total):
        self.img, self.start, self.total = img, start, total

    def _bit(self, n):
        return self.start * 512 + n // 8, 0x80 >> (n % 8)

    def free(self, n):
        if n == 0 or n >= self.total:
            return
        byte, mask = self._bit(n)
        self.img[byte] |= mask


def entries(img, keyblk):
    """Yield (dirblk, offset, entry bytes) for every slot in a directory."""
    b, first = keyblk, True
    while b:
        B = blk(img, b)
        for i in range(ENTRIES_PER_BLOCK):
            if first and i == 0:
                continue
            off = 4 + i * ENTRY_LEN
            yield b, off, B[off:off+ENTRY_LEN]
        b, first = B[2] | B[3] << 8, False


def find(img, keyblk, name):
    for dirblk, off, e in entries(img, keyblk):
        st, nl = e[0] >> 4, e[0] & 15
        if st == 0:
            continue
        if e[1:1+nl].decode('ascii', 'replace').upper() == name.upper():
            return dirblk, off, e
    return None, None, None


def file_blocks(img, storage, key):
    """Every block a file occupies, including its index blocks."""
    out = []
    if storage == 1:
        out.append(key)
    elif storage == 2:
        out.append(key)
        ib = blk(img, key)
        for i in range(256):
            b = ib[i] | ib[256+i] << 8
            if b:
                out.append(b)
    elif storage == 3:
        out.append(key)
        mb = blk(img, key)
        for j in range(128):
            m = mb[j] | mb[256+j] << 8
            if not m:
                continue
            out.append(m)
            ib = blk(img, m)
            for i in range(256):
                b = ib[i] | ib[256+i] << 8
                if b:
                    out.append(b)
    else:
        raise SystemExit(f'storage type {storage} not supported by this tool')
    return out


def remove(image_path, path):
    img = bytearray(open(image_path, 'rb').read())
    if img[:4] == b'2IMG':
        raise SystemExit('give me a raw .po image, not a .2mg')

    vol = blk(img, 2)
    bitmap_ptr = vol[4+0x23] | vol[4+0x24] << 8
    total_blocks = vol[4+0x25] | vol[4+0x26] << 8
    bitmap = Bitmap(img, bitmap_ptr, total_blocks)

    parts = [p for p in path.upper().split('/') if p]
    keyblk = 2
    for part in parts[:-1]:
        dirblk, off, e = find(img, keyblk, part)
        if e is None or e[0] >> 4 != 0xD:
            raise SystemExit(f'no such directory: {part}')
        keyblk = e[0x11] | e[0x12] << 8

    dirblk, off, e = find(img, keyblk, parts[-1])
    if e is None:
        raise SystemExit(f'not found: {path}')

    storage = e[0] >> 4
    key = e[0x11] | e[0x12] << 8
    used = e[0x13] | e[0x14] << 8

    for b in file_blocks(img, storage, key):
        bitmap.free(b)

    B = bytearray(blk(img, dirblk))                  # clear the entry
    B[off] = 0x00
    put(img, dirblk, bytes(B))

    H = bytearray(blk(img, keyblk))                  # one fewer file here
    count = (H[4+0x21] | H[4+0x22] << 8)
    if count:
        count -= 1
    H[4+0x21], H[4+0x22] = count & 0xFF, count >> 8
    put(img, keyblk, bytes(H))

    open(image_path, 'wb').write(img)
    print(f'deleted {path}: storage {storage}, key block {key}, {used} blocks freed')


if __name__ == '__main__':
    remove(sys.argv[1], sys.argv[2])
