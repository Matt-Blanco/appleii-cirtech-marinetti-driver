#!/usr/bin/env python3
"""Minimal 6502 disassembler for the Cirtech SCSI ROM.

usage: dis6502.py <file> <file-offset> <length> <load-address>
       dis6502.py rom/cirtech_scsi_2764.bin 0x800 0x800 0xC800
"""
import sys

IMP, ACC, IMM, ZP, ZPX, ZPY, ABS, ABX, ABY, IND, IZX, IZY, REL = range(13)
SIZE = {IMP: 1, ACC: 1, IMM: 2, ZP: 2, ZPX: 2, ZPY: 2, ABS: 3,
        ABX: 3, ABY: 3, IND: 3, IZX: 2, IZY: 2, REL: 2}

T = {}
def row(base, *pairs):
    for off, mne, mode in pairs:
        T[base + off] = (mne, mode)

row(0x00, (0x00,'BRK',IMP),(0x01,'ORA',IZX),(0x05,'ORA',ZP),(0x06,'ASL',ZP),
         (0x08,'PHP',IMP),(0x09,'ORA',IMM),(0x0A,'ASL',ACC),(0x0D,'ORA',ABS),(0x0E,'ASL',ABS))
row(0x10, (0x00,'BPL',REL),(0x01,'ORA',IZY),(0x05,'ORA',ZPX),(0x06,'ASL',ZPX),
         (0x08,'CLC',IMP),(0x09,'ORA',ABY),(0x0D,'ORA',ABX),(0x0E,'ASL',ABX))
row(0x20, (0x00,'JSR',ABS),(0x01,'AND',IZX),(0x04,'BIT',ZP),(0x05,'AND',ZP),(0x06,'ROL',ZP),
         (0x08,'PLP',IMP),(0x09,'AND',IMM),(0x0A,'ROL',ACC),(0x0C,'BIT',ABS),(0x0D,'AND',ABS),(0x0E,'ROL',ABS))
row(0x30, (0x00,'BMI',REL),(0x01,'AND',IZY),(0x05,'AND',ZPX),(0x06,'ROL',ZPX),
         (0x08,'SEC',IMP),(0x09,'AND',ABY),(0x0D,'AND',ABX),(0x0E,'ROL',ABX))
row(0x40, (0x00,'RTI',IMP),(0x01,'EOR',IZX),(0x05,'EOR',ZP),(0x06,'LSR',ZP),
         (0x08,'PHA',IMP),(0x09,'EOR',IMM),(0x0A,'LSR',ACC),(0x0C,'JMP',ABS),(0x0D,'EOR',ABS),(0x0E,'LSR',ABS))
row(0x50, (0x00,'BVC',REL),(0x01,'EOR',IZY),(0x05,'EOR',ZPX),(0x06,'LSR',ZPX),
         (0x08,'CLI',IMP),(0x09,'EOR',ABY),(0x0D,'EOR',ABX),(0x0E,'LSR',ABX))
row(0x60, (0x00,'RTS',IMP),(0x01,'ADC',IZX),(0x05,'ADC',ZP),(0x06,'ROR',ZP),
         (0x08,'PLA',IMP),(0x09,'ADC',IMM),(0x0A,'ROR',ACC),(0x0C,'JMP',IND),(0x0D,'ADC',ABS),(0x0E,'ROR',ABS))
row(0x70, (0x00,'BVS',REL),(0x01,'ADC',IZY),(0x05,'ADC',ZPX),(0x06,'ROR',ZPX),
         (0x08,'SEI',IMP),(0x09,'ADC',ABY),(0x0D,'ADC',ABX),(0x0E,'ROR',ABX))
row(0x80, (0x01,'STA',IZX),(0x04,'STY',ZP),(0x05,'STA',ZP),(0x06,'STX',ZP),
         (0x08,'DEY',IMP),(0x0A,'TXA',IMP),(0x0C,'STY',ABS),(0x0D,'STA',ABS),(0x0E,'STX',ABS))
row(0x90, (0x00,'BCC',REL),(0x01,'STA',IZY),(0x04,'STY',ZPX),(0x05,'STA',ZPX),(0x06,'STX',ZPY),
         (0x08,'TYA',IMP),(0x09,'STA',ABY),(0x0A,'TXS',IMP),(0x0D,'STA',ABX))
row(0xA0, (0x00,'LDY',IMM),(0x01,'LDA',IZX),(0x02,'LDX',IMM),(0x04,'LDY',ZP),(0x05,'LDA',ZP),(0x06,'LDX',ZP),
         (0x08,'TAY',IMP),(0x09,'LDA',IMM),(0x0A,'TAX',IMP),(0x0C,'LDY',ABS),(0x0D,'LDA',ABS),(0x0E,'LDX',ABS))
row(0xB0, (0x00,'BCS',REL),(0x01,'LDA',IZY),(0x04,'LDY',ZPX),(0x05,'LDA',ZPX),(0x06,'LDX',ZPY),
         (0x08,'CLV',IMP),(0x09,'LDA',ABY),(0x0A,'TSX',IMP),(0x0C,'LDY',ABX),(0x0D,'LDA',ABX),(0x0E,'LDX',ABY))
row(0xC0, (0x00,'CPY',IMM),(0x01,'CMP',IZX),(0x04,'CPY',ZP),(0x05,'CMP',ZP),(0x06,'DEC',ZP),
         (0x08,'INY',IMP),(0x09,'CMP',IMM),(0x0A,'DEX',IMP),(0x0C,'CPY',ABS),(0x0D,'CMP',ABS),(0x0E,'DEC',ABS))
row(0xD0, (0x00,'BNE',REL),(0x01,'CMP',IZY),(0x05,'CMP',ZPX),(0x06,'DEC',ZPX),
         (0x08,'CLD',IMP),(0x09,'CMP',ABY),(0x0D,'CMP',ABX),(0x0E,'DEC',ABX))
row(0xE0, (0x00,'CPX',IMM),(0x01,'SBC',IZX),(0x04,'CPX',ZP),(0x05,'SBC',ZP),(0x06,'INC',ZP),
         (0x08,'INX',IMP),(0x09,'SBC',IMM),(0x0A,'NOP',IMP),(0x0C,'CPX',ABS),(0x0D,'SBC',ABS),(0x0E,'INC',ABS))
row(0xF0, (0x00,'BEQ',REL),(0x01,'SBC',IZY),(0x05,'SBC',ZPX),(0x06,'INC',ZPX),
         (0x08,'SED',IMP),(0x09,'SBC',ABY),(0x0D,'SBC',ABX),(0x0E,'INC',ABX))


def operand(mode, pc, lo, hi):
    a = lo | hi << 8
    return {IMP: '', ACC: '', IMM: f'#${lo:02X}', ZP: f'${lo:02X}', ZPX: f'${lo:02X},X',
            ZPY: f'${lo:02X},Y', ABS: f'${a:04X}', ABX: f'${a:04X},X', ABY: f'${a:04X},Y',
            IND: f'(${a:04X})', IZX: f'(${lo:02X},X)', IZY: f'(${lo:02X}),Y',
            REL: f'${pc + 2 + (lo - 256 if lo > 127 else lo):04X}'}[mode]


def disassemble(data, load):
    pc, out = load, []
    i = 0
    while i < len(data):
        op = data[i]
        ent = T.get(op)
        if ent is None:
            out.append((pc, data[i:i+1], f'.db     ${op:02X}'))
            i, pc = i + 1, pc + 1
            continue
        mne, mode = ent
        n = SIZE[mode]
        if i + n > len(data):
            out.append((pc, data[i:], f'.db     ${op:02X}'))
            break
        lo = data[i+1] if n > 1 else 0
        hi = data[i+2] if n > 2 else 0
        text = mne + (' ' * (8 - len(mne)) + operand(mode, pc, lo, hi) if mode != IMP else '')
        out.append((pc, data[i:i+n], text))
        i, pc = i + n, pc + n
    return out


if __name__ == '__main__':
    path, off, ln, load = sys.argv[1], int(sys.argv[2], 0), int(sys.argv[3], 0), int(sys.argv[4], 0)
    data = open(path, 'rb').read()[off:off+ln]
    for pc, raw, text in disassemble(data, load):
        print(f'{pc:04X}: {" ".join(f"{b:02X}" for b in raw):<9} {text}')
