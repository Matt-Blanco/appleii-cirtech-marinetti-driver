C800: 00        BRK
C801: 03        .db     $03
C802: 20 03 20  JSR     $2003
C805: 4A        LSR     
C806: C9 85     CMP     #$85
C808: 46 20     LSR     $20
C80A: 4A        LSR     
C80B: C9 85     CMP     #$85
C80D: 47        .db     $47
C80E: 20 4A C9  JSR     $C94A
C811: 85 48     STA     $48
C813: 4C D3 C8  JMP     $C8D3
C816: A0 00     LDY     #$00
C818: 60        RTS
C819: 20 4A C9  JSR     $C94A
C81C: AA        TAX
C81D: 05 43     ORA     $43
C81F: D0 1F     BNE     $C840
C821: AE F8 07  LDX     $07F8
C824: A0 00     LDY     #$00
C826: BD B8 03  LDA     $03B8,X
C829: 20 4E C9  JSR     $C94E
C82C: BD 38 04  LDA     $0438,X
C82F: 20 4E C9  JSR     $C94E
C832: 98        TYA
C833: A0 00     LDY     #$00
C835: 91 44     STA     ($44),Y
C837: A9 00     LDA     #$00
C839: C8        INY
C83A: C0 08     CPY     #$08
C83C: D0 F7     BNE     $C835
C83E: F0 59     BEQ     $C899
C840: A5 43     LDA     $43
C842: D0 03     BNE     $C847
C844: A0 28     LDY     #$28
C846: 60        RTS
C847: 8A        TXA
C848: F0 07     BEQ     $C851
C84A: C9 03     CMP     #$03
C84C: F0 03     BEQ     $C851
C84E: A0 21     LDY     #$21
C850: 60        RTS
C851: 48        PHA
C852: 20 F8 CE  JSR     $CEF8
C855: A0 00     LDY     #$00
C857: A9 F8     LDA     #$F8
C859: 91 44     STA     ($44),Y
C85B: C8        INY
C85C: AD 78 05  LDA     $0578
C85F: 91 44     STA     ($44),Y
C861: C8        INY
C862: AD F8 05  LDA     $05F8
C865: 91 44     STA     ($44),Y
C867: C8        INY
C868: A5 49     LDA     $49
C86A: 91 44     STA     ($44),Y
C86C: C8        INY
C86D: 68        PLA
C86E: B0 31     BCS     $C8A1
C870: A2 04     LDX     #$04
C872: C9 03     CMP     #$03
C874: D0 23     BNE     $C899
C876: A9 08     LDA     #$08
C878: 91 44     STA     ($44),Y
C87A: A0 C5     LDY     #$C5
C87C: 20 FB CA  JSR     $CAFB
C87F: B0 20     BCS     $C8A1
C881: A9 20     LDA     #$20
C883: A0 0D     LDY     #$0D
C885: 91 44     STA     ($44),Y
C887: C8        INY
C888: C0 15     CPY     #$15
C88A: D0 F9     BNE     $C885
C88C: A2 04     LDX     #$04
C88E: BD FF C7  LDA     $C7FF,X
C891: 91 44     STA     ($44),Y
C893: C8        INY
C894: CA        DEX
C895: D0 F7     BNE     $C88E
C897: A2 19     LDX     #$19
C899: 8E 78 05  STX     $0578
C89C: A0 00     LDY     #$00
C89E: 8C F8 05  STY     $05F8
C8A1: 60        RTS
C8A2: A0 8C     LDY     #$8C
C8A4: 4C FB CA  JMP     $CAFB
C8A7: A5 43     LDA     $43
C8A9: D0 03     BNE     $C8AE
C8AB: A0 28     LDY     #$28
C8AD: 60        RTS
C8AE: 20 4A C9  JSR     $C94A
C8B1: C9 81     CMP     #$81
C8B3: 90 25     BCC     $C8DA
C8B5: C9 88     CMP     #$88
C8B7: B0 21     BCS     $C8DA
C8B9: 29 7F     AND     #$7F
C8BB: AA        TAX
C8BC: A0 02     LDY     #$02
C8BE: B1 44     LDA     ($44),Y
C8C0: 99 46 00  STA     $0046,Y
C8C3: 88        DEY
C8C4: 10 F8     BPL     $C8BE
C8C6: A5 44     LDA     $44
C8C8: 18        CLC
C8C9: 69 03     ADC     #$03
C8CB: 85 44     STA     $44
C8CD: A5 45     LDA     $45
C8CF: 69 00     ADC     #$00
C8D1: 85 45     STA     $45
C8D3: BD DD C8  LDA     $C8DD,X
C8D6: A8        TAY
C8D7: 4C FB CA  JMP     $CAFB
C8DA: A0 21     LDY     #$21
C8DC: 60        RTS
C8DD: C0 C1     CPY     #$C1
C8DF: A2 83     LDX     #$83
C8E1: C4 06     CPY     $06
C8E3: 87        .db     $87
C8E4: 88        DEY
C8E5: BA        TSX
C8E6: BD 10 01  LDA     $0110,X
C8E9: 85 44     STA     $44
C8EB: 18        CLC
C8EC: 69 03     ADC     #$03
C8EE: 9D 10 01  STA     $0110,X
C8F1: BD 11 01  LDA     $0111,X
C8F4: 85 45     STA     $45
C8F6: 69 00     ADC     #$00
C8F8: 9D 11 01  STA     $0111,X
C8FB: A0 01     LDY     #$01
C8FD: B1 44     LDA     ($44),Y
C8FF: 85 42     STA     $42
C901: AA        TAX
C902: C9 06     CMP     #$06
C904: 90 03     BCC     $C909
C906: A0 01     LDY     #$01
C908: 60        RTS
C909: C8        INY
C90A: B1 44     LDA     ($44),Y
C90C: 85 4B     STA     $4B
C90E: C8        INY
C90F: B1 44     LDA     ($44),Y
C911: 85 4C     STA     $4C
C913: A0 00     LDY     #$00
C915: 20 4A C9  JSR     $C94A
C918: DD 44 C9  CMP     $C944,X
C91B: F0 03     BEQ     $C920
C91D: A0 04     LDY     #$04
C91F: 60        RTS
C920: 20 4A C9  JSR     $C94A
C923: 85 43     STA     $43
C925: C9 05     CMP     #$05
C927: 90 03     BCC     $C92C
C929: A0 28     LDY     #$28
C92B: 60        RTS
C92C: 20 4A C9  JSR     $C94A
C92F: 85 44     STA     $44
C931: 20 4A C9  JSR     $C94A
C934: 85 45     STA     $45
C936: A9 C8     LDA     #$C8
C938: 48        PHA
C939: BD 3E C9  LDA     $C93E,X
C93C: 48        PHA
C93D: 60        RTS
C93E: 18        CLC
C93F: 03        .db     $03
C940: 03        .db     $03
C941: 15 A6     ORA     $A6,X
C943: A1 03     LDA     ($03,X)
C945: 03        .db     $03
C946: 03        .db     $03
C947: 01 03     ORA     ($03,X)
C949: 01 B1     ORA     ($B1,X)
C94B: 4B        .db     $4B
C94C: C8        INY
C94D: 60        RTS
C94E: 30 01     BMI     $C951
C950: C8        INY
C951: 29 08     AND     #$08
C953: D0 01     BNE     $C956
C955: C8        INY
C956: 60        RTS
C957: C0 04     CPY     #$04
C959: B0 03     BCS     $C95E
C95B: 4C B4 CA  JMP     $CAB4
C95E: D0 03     BNE     $C963
C960: 4C E5 C8  JMP     $C8E5
C963: 20 89 FE  JSR     $FE89
C966: 20 93 FE  JSR     $FE93
C969: 20 E2 C9  JSR     $C9E2
C96C: A9 08     LDA     #$08
C96E: 85 45     STA     $45
C970: A0 00     LDY     #$00
C972: 84 46     STY     $46
C974: 84 47     STY     $47
C976: 84 48     STY     $48
C978: 84 44     STY     $44
C97A: C8        INY
C97B: 84 43     STY     $43
C97D: A0 C1     LDY     #$C1
C97F: 20 FB CA  JSR     $CAFB
C982: B0 15     BCS     $C999
C984: AE 00 08  LDX     $0800
C987: CA        DEX
C988: D0 0F     BNE     $C999
C98A: AD 01 08  LDA     $0801
C98D: F0 0A     BEQ     $C999
C98F: AD 78 07  LDA     $0778
C992: 38        SEC
C993: E9 8D     SBC     #$8D
C995: AA        TAX
C996: 4C 01 08  JMP     $0801
C999: 20 89 FE  JSR     $FE89
C99C: 20 93 FE  JSR     $FE93
C99F: A2 00     LDX     #$00
C9A1: BD BD C9  LDA     $C9BD,X
C9A4: F0 06     BEQ     $C9AC
C9A6: 20 ED FD  JSR     $FDED
C9A9: E8        INX
C9AA: D0 F5     BNE     $C9A1
C9AC: A5 01     LDA     $01
C9AE: CD F8 07  CMP     $07F8
C9B1: D0 07     BNE     $C9BA
C9B3: A5 00     LDA     $00
C9B5: D0 03     BNE     $C9BA
C9B7: 4C BA FA  JMP     $FABA
C9BA: 4C 00 E0  JMP     $E000
C9BD: 8D 8D C3  STA     $C38D
C9C0: C1 CE     CMP     ($CE,X)
C9C2: CE CF D4  DEC     $D4CF
C9C5: A0 D3     LDY     #$D3
C9C7: D4        .db     $D4
C9C8: C1 D2     CMP     ($D2,X)
C9CA: D4        .db     $D4
C9CB: D5 D0     CMP     $D0,X
C9CD: A0 C6     LDY     #$C6
C9CF: D2        .db     $D2
C9D0: CF        .db     $CF
C9D1: CD A0 D3  CMP     $D3A0
C9D4: C3        .db     $C3
C9D5: D3        .db     $D3
C9D6: C9 A0     CMP     #$A0
C9D8: C9 CE     CMP     #$CE
C9DA: D4        .db     $D4
C9DB: C5 D2     CMP     $D2
C9DD: C6 C1     DEC     $C1
C9DF: C3        .db     $C3
C9E0: C5 00     CMP     $00
C9E2: AE F8 07  LDX     $07F8
C9E5: A9 00     LDA     #$00
C9E7: 9D B8 04  STA     $04B8,X
C9EA: 9D 38 05  STA     $0538,X
C9ED: 9D 38 06  STA     $0638,X
C9F0: 9D B8 06  STA     $06B8,X
C9F3: 9D B8 05  STA     $05B8,X
C9F6: A9 A5     LDA     #$A5
C9F8: 18        CLC
C9F9: 7D B8 03  ADC     $03B8,X
C9FC: 7D 38 04  ADC     $0438,X
C9FF: 9D 38 07  STA     $0738,X
CA02: 60        RTS
CA03: AE F8 07  LDX     $07F8
CA06: A9 FF     LDA     #$FF
CA08: 9D B8 03  STA     $03B8,X
CA0B: 9D 38 04  STA     $0438,X
CA0E: A5 43     LDA     $43
CA10: 48        PHA
CA11: 98        TYA
CA12: 48        PHA
CA13: A9 07     LDA     #$07
CA15: 85 43     STA     $43
CA17: 20 93 CA  JSR     $CA93
CA1A: B0 51     BCS     $CA6D
CA1C: AE F8 07  LDX     $07F8
CA1F: 20 67 CA  JSR     $CA67
CA22: 09 F0     ORA     #$F0
CA24: 9D B8 03  STA     $03B8,X
CA27: 20 93 CA  JSR     $CA93
CA2A: B0 09     BCS     $CA35
CA2C: 20 5A CA  JSR     $CA5A
CA2F: 5D B8 03  EOR     $03B8,X
CA32: 9D B8 03  STA     $03B8,X
CA35: 20 93 CA  JSR     $CA93
CA38: B0 0B     BCS     $CA45
CA3A: AE F8 07  LDX     $07F8
CA3D: 20 67 CA  JSR     $CA67
CA40: 09 F0     ORA     #$F0
CA42: 9D 38 04  STA     $0438,X
CA45: 20 93 CA  JSR     $CA93
CA48: B0 09     BCS     $CA53
CA4A: 20 5A CA  JSR     $CA5A
CA4D: 5D 38 04  EOR     $0438,X
CA50: 9D 38 04  STA     $0438,X
CA53: 18        CLC
CA54: 68        PLA
CA55: A8        TAY
CA56: 68        PLA
CA57: 85 43     STA     $43
CA59: 60        RTS
CA5A: AE F8 07  LDX     $07F8
CA5D: 20 67 CA  JSR     $CA67
CA60: 0A        ASL     
CA61: 0A        ASL     
CA62: 0A        ASL     
CA63: 0A        ASL     
CA64: 49 F0     EOR     #$F0
CA66: 60        RTS
CA67: A5 43     LDA     $43
CA69: 18        CLC
CA6A: 69 01     ADC     #$01
CA6C: 60        RTS
CA6D: 68        PLA
CA6E: C9 20     CMP     #$20
CA70: D0 03     BNE     $CA75
CA72: 4C 99 C9  JMP     $C999
CA75: C9 04     CMP     #$04
CA77: D0 12     BNE     $CA8B
CA79: BA        TSX
CA7A: BD 11 01  LDA     $0111,X
CA7D: 18        CLC
CA7E: 69 03     ADC     #$03
CA80: 9D 11 01  STA     $0111,X
CA83: BD 12 01  LDA     $0112,X
CA86: 69 00     ADC     #$00
CA88: 9D 12 01  STA     $0112,X
CA8B: A9 28     LDA     #$28
CA8D: 48        PHA
CA8E: 38        SEC
CA8F: B0 C3     BCS     $CA54
CA91: C6 43     DEC     $43
CA93: A4 43     LDY     $43
CA95: 10 02     BPL     $CA99
CA97: 38        SEC
CA98: 60        RTS
CA99: A9 01     LDA     #$01
CA9B: 88        DEY
CA9C: 30 04     BMI     $CAA2
CA9E: 18        CLC
CA9F: 2A        ROL     
CAA0: 90 F9     BCC     $CA9B
CAA2: AC 78 07  LDY     $0778
CAA5: 49 FF     EOR     #$FF
CAA7: D9 FB BF  CMP     $BFFB,Y
CAAA: F0 E5     BEQ     $CA91
CAAC: 20 81 CB  JSR     $CB81
CAAF: C6 43     DEC     $43
CAB1: B0 E0     BCS     $CA93
CAB3: 60        RTS
CAB4: 84 48     STY     $48
CAB6: A0 01     LDY     #$01
CAB8: A5 43     LDA     $43
CABA: 10 01     BPL     $CABD
CABC: C8        INY
CABD: A6 48     LDX     $48
CABF: D0 0F     BNE     $CAD0
CAC1: 29 70     AND     #$70
CAC3: C9 20     CMP     #$20
CAC5: D0 09     BNE     $CAD0
CAC7: AD F8 07  LDA     $07F8
CACA: C9 C5     CMP     #$C5
CACC: D0 02     BNE     $CAD0
CACE: C8        INY
CACF: C8        INY
CAD0: 84 43     STY     $43
CAD2: A4 42     LDY     $42
CAD4: D0 17     BNE     $CAED
CAD6: 20 F8 CE  JSR     $CEF8
CAD9: B0 11     BCS     $CAEC
CADB: A5 49     LDA     $49
CADD: 38        SEC
CADE: E5 48     SBC     $48
CAE0: F0 08     BEQ     $CAEA
CAE2: A9 FF     LDA     #$FF
CAE4: 8D 78 05  STA     $0578
CAE7: 8D F8 05  STA     $05F8
CAEA: A0 00     LDY     #$00
CAEC: 60        RTS
CAED: C0 03     CPY     #$03
CAEF: F0 F9     BEQ     $CAEA
CAF1: 90 03     BCC     $CAF6
CAF3: A0 27     LDY     #$27
CAF5: 60        RTS
CAF6: 98        TYA
CAF7: AA        TAX
CAF8: 4C D3 C8  JMP     $C8D3
CAFB: A5 42     LDA     $42
CAFD: 48        PHA
CAFE: A5 43     LDA     $43
CB00: 48        PHA
CB01: 84 42     STY     $42
CB03: C0 06     CPY     #$06
CB05: D0 28     BNE     $CB2F
CB07: 20 8C CE  JSR     $CE8C
CB0A: A0 00     LDY     #$00
CB0C: 84 4A     STY     $4A
CB0E: A9 00     LDA     #$00
CB10: AC 78 07  LDY     $0778
CB13: 99 F4 BF  STA     $BFF4,Y
CB16: 99 F5 BF  STA     $BFF5,Y
CB19: 99 F6 BF  STA     $BFF6,Y
CB1C: 99 F7 BF  STA     $BFF7,Y
CB1F: B9 FA BF  LDA     $BFFA,Y
CB22: A4 4A     LDY     $4A
CB24: 30 70     BMI     $CB96
CB26: 68        PLA
CB27: 85 43     STA     $43
CB29: 68        PLA
CB2A: 85 42     STA     $42
CB2C: C0 01     CPY     #$01
CB2E: 60        RTS
CB2F: AE F8 07  LDX     $07F8
CB32: BD B8 05  LDA     $05B8,X
CB35: A6 43     LDX     $43
CB37: C0 C1     CPY     #$C1
CB39: F0 0E     BEQ     $CB49
CB3B: C0 A2     CPY     #$A2
CB3D: D0 13     BNE     $CB52
CB3F: 4A        LSR     
CB40: CA        DEX
CB41: D0 FC     BNE     $CB3F
CB43: 90 0D     BCC     $CB52
CB45: A0 2B     LDY     #$2B
CB47: D0 C3     BNE     $CB0C
CB49: 0A        ASL     
CB4A: CA        DEX
CB4B: D0 FC     BNE     $CB49
CB4D: 90 03     BCC     $CB52
CB4F: 4C 7F CE  JMP     $CE7F
CB52: 20 1F CF  JSR     $CF1F
CB55: 18        CLC
CB56: 65 47     ADC     $47
CB58: 85 47     STA     $47
CB5A: A5 48     LDA     $48
CB5C: 69 00     ADC     #$00
CB5E: 85 48     STA     $48
CB60: A6 43     LDX     $43
CB62: AC F8 07  LDY     $07F8
CB65: B9 B8 03  LDA     $03B8,Y
CB68: E0 03     CPX     #$03
CB6A: 90 03     BCC     $CB6F
CB6C: B9 38 04  LDA     $0438,Y
CB6F: 46 43     LSR     $43
CB71: B0 04     BCS     $CB77
CB73: 4A        LSR     
CB74: 4A        LSR     
CB75: 4A        LSR     
CB76: 4A        LSR     
CB77: 29 0F     AND     #$0F
CB79: C9 0F     CMP     #$0F
CB7B: 90 0E     BCC     $CB8B
CB7D: A0 28     LDY     #$28
CB7F: B0 8B     BCS     $CB0C
CB81: A5 42     LDA     $42
CB83: 48        PHA
CB84: A9 C0     LDA     #$C0
CB86: 85 42     STA     $42
CB88: A5 43     LDA     $43
CB8A: 48        PHA
CB8B: A8        TAY
CB8C: A9 00     LDA     #$00
CB8E: 38        SEC
CB8F: 2A        ROL     
CB90: 18        CLC
CB91: 88        DEY
CB92: 10 FB     BPL     $CB8F
CB94: 85 43     STA     $43
CB96: AC 78 07  LDY     $0778
CB99: A9 00     LDA     #$00
CB9B: 85 4A     STA     $4A
CB9D: 85 4D     STA     $4D
CB9F: 99 F4 BF  STA     $BFF4,Y
CBA2: 99 F5 BF  STA     $BFF5,Y
CBA5: 99 F6 BF  STA     $BFF6,Y
CBA8: 99 F7 BF  STA     $BFF7,Y
CBAB: B9 FA BF  LDA     $BFFA,Y
CBAE: AA        TAX
CBAF: B9 F7 BF  LDA     $BFF7,Y
CBB2: F0 1B     BEQ     $CBCF
CBB4: 20 2E CB  JSR     $CB2E
CBB7: 20 2E CB  JSR     $CB2E
CBBA: 20 2E CB  JSR     $CB2E
CBBD: D9 F7 BF  CMP     $BFF7,Y
CBC0: D0 0D     BNE     $CBCF
CBC2: CA        DEX
CBC3: D0 EF     BNE     $CBB4
CBC5: C6 4D     DEC     $4D
CBC7: D0 EB     BNE     $CBB4
CBC9: 20 8C CE  JSR     $CE8C
CBCC: 4C 96 CB  JMP     $CB96
CBCF: B9 FB BF  LDA     $BFFB,Y
CBD2: 49 FF     EOR     #$FF
CBD4: 99 F3 BF  STA     $BFF3,Y
CBD7: A9 01     LDA     #$01
CBD9: 99 F5 BF  STA     $BFF5,Y
CBDC: B9 F4 BF  LDA     $BFF4,Y
CBDF: 0A        ASL     
CBE0: 30 09     BMI     $CBEB
CBE2: B9 F8 BF  LDA     $BFF8,Y
CBE5: 29 10     AND     #$10
CBE7: F0 F3     BEQ     $CBDC
CBE9: D0 AB     BNE     $CB96
CBEB: EA        NOP
CBEC: B9 F4 BF  LDA     $BFF4,Y
CBEF: 29 20     AND     #$20
CBF1: D0 A3     BNE     $CB96
CBF3: B9 F3 BF  LDA     $BFF3,Y
CBF6: 59 FB BF  EOR     $BFFB,Y
CBF9: C9 FF     CMP     #$FF
CBFB: F0 05     BEQ     $CC02
CBFD: D9 FB BF  CMP     $BFFB,Y
CC00: 90 94     BCC     $CB96
CC02: B9 F4 BF  LDA     $BFF4,Y
CC05: 29 20     AND     #$20
CC07: D0 8D     BNE     $CB96
CC09: A9 0C     LDA     #$0C
CC0B: 99 F4 BF  STA     $BFF4,Y
CC0E: B9 FB BF  LDA     $BFFB,Y
CC11: 49 FF     EOR     #$FF
CC13: 05 43     ORA     $43
CC15: 99 F3 BF  STA     $BFF3,Y
CC18: A9 00     LDA     #$00
CC1A: 99 F5 BF  STA     $BFF5,Y
CC1D: 99 F7 BF  STA     $BFF7,Y
CC20: A9 05     LDA     #$05
CC22: 99 F4 BF  STA     $BFF4,Y
CC25: A9 69     LDA     #$69
CC27: 85 4D     STA     $4D
CC29: A2 00     LDX     #$00
CC2B: B9 F7 BF  LDA     $BFF7,Y
CC2E: 0A        ASL     
CC2F: 30 25     BMI     $CC56
CC31: CA        DEX
CC32: D0 F7     BNE     $CC2B
CC34: C6 4D     DEC     $4D
CC36: D0 F1     BNE     $CC29
CC38: A9 00     LDA     #$00
CC3A: 99 F3 BF  STA     $BFF3,Y
CC3D: A9 04     LDA     #$04
CC3F: 99 F4 BF  STA     $BFF4,Y
CC42: A2 0F     LDX     #$0F
CC44: B9 F7 BF  LDA     $BFF7,Y
CC47: 0A        ASL     
CC48: 30 0C     BMI     $CC56
CC4A: CA        DEX
CC4B: D0 F7     BNE     $CC44
CC4D: 8A        TXA
CC4E: 99 F4 BF  STA     $BFF4,Y
CC51: A0 28     LDY     #$28
CC53: 4C 0C CB  JMP     $CB0C
CC56: A9 04     LDA     #$04
CC58: 99 F5 BF  STA     $BFF5,Y
CC5B: B9 FA BF  LDA     $BFFA,Y
CC5E: A9 00     LDA     #$00
CC60: 99 F4 BF  STA     $BFF4,Y
CC63: B9 F8 BF  LDA     $BFF8,Y
CC66: 4A        LSR     
CC67: 4A        LSR     
CC68: 4A        LSR     
CC69: B0 57     BCS     $CCC2
CC6B: 4A        LSR     
CC6C: 29 01     AND     #$01
CC6E: D0 52     BNE     $CCC2
CC70: B0 F1     BCS     $CC63
CC72: B9 F7 BF  LDA     $BFF7,Y
CC75: 29 20     AND     #$20
CC77: F0 EA     BEQ     $CC63
CC79: B9 F7 BF  LDA     $BFF7,Y
CC7C: 29 1C     AND     #$1C
CC7E: 4A        LSR     
CC7F: AA        TAX
CC80: 4A        LSR     
CC81: 99 F6 BF  STA     $BFF6,Y
CC84: B9 FA BF  LDA     $BFFA,Y
CC87: A5 42     LDA     $42
CC89: E0 0E     CPX     #$0E
CC8B: D0 03     BNE     $CC90
CC8D: 4C 6C CE  JMP     $CE6C
CC90: E0 0C     CPX     #$0C
CC92: D0 08     BNE     $CC9C
CC94: A9 07     LDA     #$07
CC96: 20 A1 CE  JSR     $CEA1
CC99: 4C 5E CC  JMP     $CC5E
CC9C: E0 06     CPX     #$06
CC9E: D0 0A     BNE     $CCAA
CCA0: 20 A7 CE  JSR     $CEA7
CCA3: 29 1E     AND     #$1E
CCA5: 85 4A     STA     $4A
CCA7: 4C 5E CC  JMP     $CC5E
CCAA: B0 13     BCS     $CCBF
CCAC: A5 42     LDA     $42
CCAE: 3D C5 CC  AND     $CCC5,X
CCB1: DD C6 CC  CMP     $CCC6,X
CCB4: D0 09     BNE     $CCBF
CCB6: BD CC CC  LDA     $CCCC,X
CCB9: 48        PHA
CCBA: BD CB CC  LDA     $CCCB,X
CCBD: 48        PHA
CCBE: 60        RTS
CCBF: 20 8C CE  JSR     $CE8C
CCC2: 4C 7F CE  JMP     $CE7F
CCC5: E0 20     CPX     #$20
CCC7: C0 40     CPY     #$40
CCC9: 80        .db     $80
CCCA: 80        .db     $80
CCCB: D0 CC     BNE     $CC99
CCCD: 17        .db     $17
CCCE: CD D2 CD  CMP     $CDD2
CCD1: A5 42     LDA     $42
CCD3: 29 0F     AND     #$0F
CCD5: C9 02     CMP     #$02
CCD7: F0 1B     BEQ     $CCF4
CCD9: A2 01     LDX     #$01
CCDB: 86 4B     STX     $4B
CCDD: 20 AC CD  JSR     $CDAC
CCE0: F0 2C     BEQ     $CD0E
CCE2: A4 4B     LDY     $4B
CCE4: B1 44     LDA     ($44),Y
CCE6: E6 4B     INC     $4B
CCE8: AC 78 07  LDY     $0778
CCEB: 99 F3 BF  STA     $BFF3,Y
CCEE: 20 C1 CD  JSR     $CDC1
CCF1: 4C DD CC  JMP     $CCDD
CCF4: A2 A6     LDX     #$A6
CCF6: 20 A5 CD  JSR     $CDA5
CCF9: AC 78 07  LDY     $0778
CCFC: A9 04     LDA     #$04
CCFE: 99 F5 BF  STA     $BFF5,Y
CD01: B0 BC     BCS     $CCBF
CD03: 20 AC CD  JSR     $CDAC
CD06: F0 06     BEQ     $CD0E
CD08: 20 C1 CD  JSR     $CDC1
CD0B: 4C 03 CD  JMP     $CD03
CD0E: A9 00     LDA     #$00
CD10: 99 F4 BF  STA     $BFF4,Y
CD13: A9 9F     LDA     #$9F
CD15: 4C 09 CE  JMP     $CE09
CD18: A5 42     LDA     $42
CD1A: 29 0F     AND     #$0F
CD1C: D0 39     BNE     $CD57
CD1E: 20 A7 CE  JSR     $CEA7
CD21: D0 31     BNE     $CD54
CD23: 20 A7 CE  JSR     $CEA7
CD26: 85 49     STA     $49
CD28: 20 A7 CE  JSR     $CEA7
CD2B: 8D F8 05  STA     $05F8
CD2E: 20 A7 CE  JSR     $CEA7
CD31: 8D 78 05  STA     $0578
CD34: 20 A7 CE  JSR     $CEA7
CD37: 20 A7 CE  JSR     $CEA7
CD3A: 20 A7 CE  JSR     $CEA7
CD3D: C9 02     CMP     #$02
CD3F: 90 13     BCC     $CD54
CD41: 20 A7 CE  JSR     $CEA7
CD44: EE 78 05  INC     $0578
CD47: D0 08     BNE     $CD51
CD49: EE F8 05  INC     $05F8
CD4C: D0 03     BNE     $CD51
CD4E: E8        INX
CD4F: 86 49     STX     $49
CD51: 4C 0E CD  JMP     $CD0E
CD54: 4C BF CC  JMP     $CCBF
CD57: C9 01     CMP     #$01
CD59: D0 0E     BNE     $CD69
CD5B: A9 06     LDA     #$06
CD5D: 99 F5 BF  STA     $BFF5,Y
CD60: 99 FA BF  STA     $BFFA,Y
CD63: A0 00     LDY     #$00
CD65: A2 68     LDX     #$68
CD67: D0 8D     BNE     $CCF6
CD69: C9 0A     CMP     #$0A
CD6B: D0 04     BNE     $CD71
CD6D: A2 03     LDX     #$03
CD6F: D0 14     BNE     $CD85
CD71: C9 09     CMP     #$09
CD73: F0 F8     BEQ     $CD6D
CD75: A2 00     LDX     #$00
CD77: C9 05     CMP     #$05
CD79: D0 0A     BNE     $CD85
CD7B: A2 08     LDX     #$08
CD7D: 20 A7 CE  JSR     $CEA7
CD80: CA        DEX
CD81: D0 FA     BNE     $CD7D
CD83: A2 05     LDX     #$05
CD85: 86 4B     STX     $4B
CD87: 20 AC CD  JSR     $CDAC
CD8A: F0 C5     BEQ     $CD51
CD8C: B9 F3 BF  LDA     $BFF3,Y
CD8F: A4 4B     LDY     $4B
CD91: 91 44     STA     ($44),Y
CD93: E6 4B     INC     $4B
CD95: AC 78 07  LDY     $0778
CD98: 20 C1 CD  JSR     $CDC1
CD9B: 4C 87 CD  JMP     $CD87
CD9E: A9 06     LDA     #$06
CDA0: 99 F5 BF  STA     $BFF5,Y
CDA3: A2 68     LDX     #$68
CDA5: AD F8 07  LDA     $07F8
CDA8: 48        PHA
CDA9: 8A        TXA
CDAA: 48        PHA
CDAB: 60        RTS
CDAC: 20 E0 CE  JSR     $CEE0
CDAF: D0 0A     BNE     $CDBB
CDB1: 20 DA CE  JSR     $CEDA
CDB4: F0 F6     BEQ     $CDAC
CDB6: 68        PLA
CDB7: 68        PLA
CDB8: 4C C2 CC  JMP     $CCC2
CDBB: B9 F8 BF  LDA     $BFF8,Y
CDBE: 29 08     AND     #$08
CDC0: 60        RTS
CDC1: 20 E6 CE  JSR     $CEE6
CDC4: 20 E0 CE  JSR     $CEE0
CDC7: D0 03     BNE     $CDCC
CDC9: 4C EF CE  JMP     $CEEF
CDCC: 20 DA CE  JSR     $CEDA
CDCF: D0 E5     BNE     $CDB6
CDD1: F0 F1     BEQ     $CDC4
CDD3: A5 42     LDA     $42
CDD5: 29 07     AND     #$07
CDD7: 0A        ASL     
CDD8: AA        TAX
CDD9: BD E3 CD  LDA     $CDE3,X
CDDC: 48        PHA
CDDD: BD E2 CD  LDA     $CDE2,X
CDE0: 48        PHA
CDE1: 60        RTS
CDE2: F9 CD 0F  SBC     $0FCD,Y
CDE5: CE 13 CE  DEC     $CE13
CDE8: 30 CE     BMI     $CDB8
CDEA: 3A        .db     $3A
CDEB: CE 3D CE  DEC     $CE3D
CDEE: BE CC 54  LDX     $54CC,Y
CDF1: CE 58 CE  DEC     $CE58
CDF4: 5C        .db     $5C
CDF5: CE 60 CE  DEC     $CE60
CDF8: 67        .db     $67
CDF9: CE A9 25  DEC     $25A9
CDFC: 20 A1 CE  JSR     $CEA1
CDFF: A2 09     LDX     #$09
CE01: 20 9F CE  JSR     $CE9F
CE04: CA        DEX
CE05: D0 FA     BNE     $CE01
CE07: A9 7F     LDA     #$7F
CE09: 25 42     AND     $42
CE0B: 85 42     STA     $42
CE0D: 4C 5E CC  JMP     $CC5E
CE10: A9 08     LDA     #$08
CE12: D0 02     BNE     $CE16
CE14: A9 0A     LDA     #$0A
CE16: 20 A1 CE  JSR     $CEA1
CE19: A5 48     LDA     $48
CE1B: 20 A1 CE  JSR     $CEA1
CE1E: A5 47     LDA     $47
CE20: 20 A1 CE  JSR     $CEA1
CE23: A5 46     LDA     $46
CE25: 20 A1 CE  JSR     $CEA1
CE28: A9 01     LDA     #$01
CE2A: 20 A1 CE  JSR     $CEA1
CE2D: A2 01     LDX     #$01
CE2F: D0 D0     BNE     $CE01
CE31: A9 04     LDA     #$04
CE33: 20 A1 CE  JSR     $CEA1
CE36: A2 05     LDX     #$05
CE38: 4C 01 CE  JMP     $CE01
CE3B: A2 20     LDX     #$20
CE3D: 2C A2 10  BIT     $10A2
CE40: A9 12     LDA     #$12
CE42: 20 A1 CE  JSR     $CEA1
CE45: 20 9F CE  JSR     $CE9F
CE48: 20 9F CE  JSR     $CE9F
CE4B: 20 9F CE  JSR     $CE9F
CE4E: 8A        TXA
CE4F: 20 A1 CE  JSR     $CEA1
CE52: 4C 2D CE  JMP     $CE2D
CE55: A9 16     LDA     #$16
CE57: D0 DA     BNE     $CE33
CE59: A9 17     LDA     #$17
CE5B: D0 D6     BNE     $CE33
CE5D: A9 03     LDA     #$03
CE5F: D0 02     BNE     $CE63
CE61: A9 1A     LDA     #$1A
CE63: A6 46     LDX     $46
CE65: 4C 42 CE  JMP     $CE42
CE68: A9 15     LDA     #$15
CE6A: D0 F7     BNE     $CE63
CE6C: 20 A7 CE  JSR     $CEA7
CE6F: D0 13     BNE     $CE84
CE71: A4 4A     LDY     $4A
CE73: F0 0C     BEQ     $CE81
CE75: A0 80     LDY     #$80
CE77: C9 08     CMP     #$08
CE79: F0 06     BEQ     $CE81
CE7B: C9 18     CMP     #$18
CE7D: F0 02     BEQ     $CE81
CE7F: A0 27     LDY     #$27
CE81: 4C 0C CB  JMP     $CB0C
CE84: A9 02     LDA     #$02
CE86: 99 F4 BF  STA     $BFF4,Y
CE89: 4C 63 CC  JMP     $CC63
CE8C: AC 78 07  LDY     $0778
CE8F: A9 80     LDA     #$80
CE91: 99 F4 BF  STA     $BFF4,Y
CE94: A2 04     LDX     #$04
CE96: CA        DEX
CE97: D0 FD     BNE     $CE96
CE99: A9 00     LDA     #$00
CE9B: 99 F4 BF  STA     $BFF4,Y
CE9E: 60        RTS
CE9F: A9 00     LDA     #$00
CEA1: 99 F3 BF  STA     $BFF3,Y
CEA4: 38        SEC
CEA5: B0 01     BCS     $CEA8
CEA7: 18        CLC
CEA8: 20 E0 CE  JSR     $CEE0
CEAB: D0 07     BNE     $CEB4
CEAD: 20 DA CE  JSR     $CEDA
CEB0: D0 23     BNE     $CED5
CEB2: F0 F4     BEQ     $CEA8
CEB4: 90 08     BCC     $CEBE
CEB6: B9 F4 BF  LDA     $BFF4,Y
CEB9: 09 01     ORA     #$01
CEBB: 99 F4 BF  STA     $BFF4,Y
CEBE: B9 F3 BF  LDA     $BFF3,Y
CEC1: 48        PHA
CEC2: 20 E6 CE  JSR     $CEE6
CEC5: 20 E0 CE  JSR     $CEE0
CEC8: D0 05     BNE     $CECF
CECA: 20 EF CE  JSR     $CEEF
CECD: 68        PLA
CECE: 60        RTS
CECF: 20 DA CE  JSR     $CEDA
CED2: F0 F1     BEQ     $CEC5
CED4: 68        PLA
CED5: 68        PLA
CED6: 68        PLA
CED7: 4C BF CC  JMP     $CCBF
CEDA: B9 F8 BF  LDA     $BFF8,Y
CEDD: 29 10     AND     #$10
CEDF: 60        RTS
CEE0: B9 F7 BF  LDA     $BFF7,Y
CEE3: 29 20     AND     #$20
CEE5: 60        RTS
CEE6: B9 F4 BF  LDA     $BFF4,Y
CEE9: 09 10     ORA     #$10
CEEB: 99 F4 BF  STA     $BFF4,Y
CEEE: 60        RTS
CEEF: B9 F4 BF  LDA     $BFF4,Y
CEF2: 29 EF     AND     #$EF
CEF4: 99 F4 BF  STA     $BFF4,Y
CEF7: 60        RTS
CEF8: 20 1F CF  JSR     $CF1F
CEFB: AA        TAX
CEFC: D0 08     BNE     $CF06
CEFE: A0 C0     LDY     #$C0
CF00: 20 FB CA  JSR     $CAFB
CF03: 90 16     BCC     $CF1B
CF05: 60        RTS
CF06: B9 38 06  LDA     $0638,Y
CF09: A6 43     LDX     $43
CF0B: CA        DEX
CF0C: F0 03     BEQ     $CF11
CF0E: B9 B8 06  LDA     $06B8,Y
CF11: 8D F8 05  STA     $05F8
CF14: A9 00     LDA     #$00
CF16: 8D 78 05  STA     $0578
CF19: 85 49     STA     $49
CF1B: A0 00     LDY     #$00
CF1D: 18        CLC
CF1E: 60        RTS
CF1F: A6 43     LDX     $43
CF21: AC F8 07  LDY     $07F8
CF24: B9 B8 04  LDA     $04B8,Y
CF27: CA        DEX
CF28: F0 08     BEQ     $CF32
CF2A: B9 38 05  LDA     $0538,Y
CF2D: CA        DEX
CF2E: F0 02     BEQ     $CF32
CF30: A9 00     LDA     #$00
CF32: 60        RTS
CF33: B1 B2     LDA     ($B2),Y
CF35: AD CE CF  LDA     $CFCE
CF38: D6 AD     DEC     $AD,X
CF3A: B5 B9     LDA     $B9,X
CF3C: FF        .db     $FF
CF3D: FF        .db     $FF
CF3E: FF        .db     $FF
CF3F: FF        .db     $FF
CF40: FF        .db     $FF
CF41: FF        .db     $FF
CF42: FF        .db     $FF
CF43: FF        .db     $FF
CF44: FF        .db     $FF
CF45: FF        .db     $FF
CF46: FF        .db     $FF
CF47: FF        .db     $FF
CF48: FF        .db     $FF
CF49: FF        .db     $FF
CF4A: FF        .db     $FF
CF4B: FF        .db     $FF
CF4C: FF        .db     $FF
CF4D: FF        .db     $FF
CF4E: FF        .db     $FF
CF4F: FF        .db     $FF
CF50: FF        .db     $FF
CF51: FF        .db     $FF
CF52: FF        .db     $FF
CF53: FF        .db     $FF
CF54: FF        .db     $FF
CF55: FF        .db     $FF
CF56: FF        .db     $FF
CF57: FF        .db     $FF
CF58: FF        .db     $FF
CF59: FF        .db     $FF
CF5A: FF        .db     $FF
CF5B: FF        .db     $FF
CF5C: FF        .db     $FF
CF5D: FF        .db     $FF
CF5E: FF        .db     $FF
CF5F: FF        .db     $FF
CF60: FF        .db     $FF
CF61: FF        .db     $FF
CF62: FF        .db     $FF
CF63: FF        .db     $FF
CF64: FF        .db     $FF
CF65: FF        .db     $FF
CF66: FF        .db     $FF
CF67: FF        .db     $FF
CF68: FF        .db     $FF
CF69: FF        .db     $FF
CF6A: FF        .db     $FF
CF6B: FF        .db     $FF
CF6C: FF        .db     $FF
CF6D: FF        .db     $FF
CF6E: FF        .db     $FF
CF6F: FF        .db     $FF
CF70: FF        .db     $FF
CF71: FF        .db     $FF
CF72: FF        .db     $FF
CF73: FF        .db     $FF
CF74: FF        .db     $FF
CF75: FF        .db     $FF
CF76: FF        .db     $FF
CF77: FF        .db     $FF
CF78: FF        .db     $FF
CF79: FF        .db     $FF
CF7A: FF        .db     $FF
CF7B: FF        .db     $FF
CF7C: FF        .db     $FF
CF7D: FF        .db     $FF
CF7E: FF        .db     $FF
CF7F: FF        .db     $FF
CF80: FF        .db     $FF
CF81: FF        .db     $FF
CF82: FF        .db     $FF
CF83: FF        .db     $FF
CF84: FF        .db     $FF
CF85: FF        .db     $FF
CF86: FF        .db     $FF
CF87: FF        .db     $FF
CF88: FF        .db     $FF
CF89: FF        .db     $FF
CF8A: FF        .db     $FF
CF8B: FF        .db     $FF
CF8C: FF        .db     $FF
CF8D: FF        .db     $FF
CF8E: FF        .db     $FF
CF8F: FF        .db     $FF
CF90: FF        .db     $FF
CF91: FF        .db     $FF
CF92: FF        .db     $FF
CF93: FF        .db     $FF
CF94: FF        .db     $FF
CF95: FF        .db     $FF
CF96: FF        .db     $FF
CF97: FF        .db     $FF
CF98: FF        .db     $FF
CF99: FF        .db     $FF
CF9A: FF        .db     $FF
CF9B: FF        .db     $FF
CF9C: FF        .db     $FF
CF9D: FF        .db     $FF
CF9E: FF        .db     $FF
CF9F: FF        .db     $FF
CFA0: FF        .db     $FF
CFA1: FF        .db     $FF
CFA2: FF        .db     $FF
CFA3: FF        .db     $FF
CFA4: FF        .db     $FF
CFA5: FF        .db     $FF
CFA6: FF        .db     $FF
CFA7: FF        .db     $FF
CFA8: FF        .db     $FF
CFA9: FF        .db     $FF
CFAA: FF        .db     $FF
CFAB: FF        .db     $FF
CFAC: FF        .db     $FF
CFAD: FF        .db     $FF
CFAE: FF        .db     $FF
CFAF: FF        .db     $FF
CFB0: FF        .db     $FF
CFB1: FF        .db     $FF
CFB2: FF        .db     $FF
CFB3: FF        .db     $FF
CFB4: FF        .db     $FF
CFB5: FF        .db     $FF
CFB6: FF        .db     $FF
CFB7: FF        .db     $FF
CFB8: FF        .db     $FF
CFB9: FF        .db     $FF
CFBA: FF        .db     $FF
CFBB: FF        .db     $FF
CFBC: FF        .db     $FF
CFBD: FF        .db     $FF
CFBE: FF        .db     $FF
CFBF: FF        .db     $FF
CFC0: 00        BRK
CFC1: 00        BRK
CFC2: 00        BRK
CFC3: 00        BRK
CFC4: 00        BRK
CFC5: 00        BRK
CFC6: 00        BRK
CFC7: 00        BRK
CFC8: 00        BRK
CFC9: 00        BRK
CFCA: 00        BRK
CFCB: 00        BRK
CFCC: 00        BRK
CFCD: 00        BRK
CFCE: 00        BRK
CFCF: 00        BRK
CFD0: 00        BRK
CFD1: 00        BRK
CFD2: 00        BRK
CFD3: 00        BRK
CFD4: 00        BRK
CFD5: 00        BRK
CFD6: 00        BRK
CFD7: 00        BRK
CFD8: 00        BRK
CFD9: 00        BRK
CFDA: 00        BRK
CFDB: 00        BRK
CFDC: 00        BRK
CFDD: 00        BRK
CFDE: 00        BRK
CFDF: 00        BRK
CFE0: 00        BRK
CFE1: 00        BRK
CFE2: 00        BRK
CFE3: 00        BRK
CFE4: 00        BRK
CFE5: 00        BRK
CFE6: 00        BRK
CFE7: 00        BRK
CFE8: 00        BRK
CFE9: 00        BRK
CFEA: 00        BRK
CFEB: 00        BRK
CFEC: 00        BRK
CFED: 00        BRK
CFEE: 00        BRK
CFEF: 00        BRK
CFF0: 00        BRK
CFF1: 00        BRK
CFF2: 00        BRK
CFF3: 00        BRK
CFF4: 00        BRK
CFF5: 00        BRK
CFF6: 00        BRK
CFF7: 00        BRK
CFF8: 00        BRK
CFF9: 00        BRK
CFFA: 00        BRK
CFFB: 00        BRK
CFFC: 00        BRK
CFFD: 00        BRK
CFFE: 00        BRK
CFFF: 00        BRK
