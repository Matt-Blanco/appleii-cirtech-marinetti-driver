#!/usr/bin/env python3
"""Map the Cirtech SCSI 2764 ROM and extract its regions.

The 8 KB EPROM holds two independent 4 KB banks, selected by the card's
Autostart Selector (manual, ch. 6 "FAST Mode And SAFE Mode"):

    bank 0  file $0000-$0FFF   FAST mode ($Cs07 = $00)
    bank 1  file $1000-$1FFF   SAFE mode ($Cs07 = $3C)

Each bank is laid out as:

    +$000-$0FF   copyright banner (not mapped into the Apple II)
    +$100-$7FF   seven pre-built slot ROM pages, one per slot 1-7,
                 mapped at $Cs00 with slot-specific addresses patched in
    +$800-$FFF   the shared 2 KB expansion ROM, mapped at $C800-$CFFF

usage: rommap.py <rom.bin> [--extract <outdir>]
"""
import sys, os

BANKS = {0: ('fast', 0x0000), 1: ('safe', 0x1000)}


def slot_page(bank_base, slot):
    return bank_base + 0x100 * slot


def expansion(bank_base):
    return bank_base + 0x800


def describe(data):
    for bank, (name, base) in BANKS.items():
        mode = data[slot_page(base, 1) + 7]
        print(f'bank {bank} ({name}, $Cs07 = ${mode:02X})  file ${base:04X}-${base + 0xFFF:04X}')
        print(f'  banner            ${base:04X}')
        for slot in range(1, 8):
            off = slot_page(base, slot)
            print(f'  slot {slot} page      ${off:04X}  -> $C{slot}00   '
                  f'ID bytes ${data[off+1]:02X} ${data[off+3]:02X} ${data[off+5]:02X} '
                  f'${data[off+7]:02X}  $CsFB=${data[off+0xFB]:02X}  entry $Cs{data[off+0xFF]:02X}')
        print(f'  expansion ROM     ${expansion(base):04X}  -> $C800-$CFFF')


def extract(data, outdir):
    os.makedirs(outdir, exist_ok=True)
    for bank, (name, base) in BANKS.items():
        for slot in range(1, 8):
            off = slot_page(base, slot)
            p = os.path.join(outdir, f'slot{slot}_{name}.bin')
            open(p, 'wb').write(data[off:off+0x100])
        p = os.path.join(outdir, f'expansion_{name}.bin')
        open(p, 'wb').write(data[expansion(base):expansion(base)+0x800])
    print(f'extracted to {outdir}/')


if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()
    if len(data) != 8192:
        sys.exit(f'expected an 8192-byte dump, got {len(data)}')
    describe(data)
    if '--extract' in sys.argv:
        extract(data, sys.argv[sys.argv.index('--extract') + 1])
