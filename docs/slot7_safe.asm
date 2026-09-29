C700: A0 20     LDY     #$20
C702: C9 00     CMP     #$00
C704: C9 03     CMP     #$03
C706: C9 3C     CMP     #$3C
C708: 2C A0 03  BIT     $03A0
C70B: 2C A0 02  BIT     $02A0
C70E: 2C A0 01  BIT     $01A0
C711: 2C A0 00  BIT     $00A0
C714: 2C A0 04  BIT     $04A0
C717: D8        CLD
C718: 2C FF CF  BIT     $CFFF
C71B: A2 F3     LDX     #$F3
C71D: B5 4F     LDA     $4F,X
C71F: 48        PHA
C720: E8        INX
C721: D0 FA     BNE     $C71D
C723: A9 FD     LDA     #$FD
C725: 8D 78 07  STA     $0778
C728: A9 C7     LDA     #$C7
C72A: 8D F8 07  STA     $07F8
C72D: AD 7F 05  LDA     $057F
C730: 18        CLC
C731: 6D FF 05  ADC     $05FF
C734: 6D FF 06  ADC     $06FF
C737: 6D 7F 07  ADC     $077F
C73A: 6D 7F 06  ADC     $067F
C73D: 69 A5     ADC     #$A5
C73F: 6D 7F 04  ADC     $047F
C742: 6D FF 04  ADC     $04FF
C745: CD FF 07  CMP     $07FF
C748: F0 08     BEQ     $C752
C74A: 20 03 CA  JSR     $CA03
C74D: B0 06     BCS     $C755
C74F: 20 E2 C9  JSR     $C9E2
C752: 20 57 C9  JSR     $C957
C755: A2 0D     LDX     #$0D
C757: 68        PLA
C758: 95 41     STA     $41,X
C75A: CA        DEX
C75B: D0 FA     BNE     $C757
C75D: 98        TYA
C75E: AE 78 05  LDX     $0578
C761: AC F8 05  LDY     $05F8
C764: C9 01     CMP     #$01
C766: 09 00     ORA     #$00
C768: 60        RTS
C769: A9 02     LDA     #$02
C76B: 85 4B     STA     $4B
C76D: A2 FF     LDX     #$FF
C76F: AD F5 C0  LDA     $C0F5
C772: 2A        ROL     
C773: 10 29     BPL     $C79E
C775: AD FC C0  LDA     $C0FC
C778: 91 44     STA     ($44),Y
C77A: C8        INY
C77B: D0 02     BNE     $C77F
C77D: E6 45     INC     $45
C77F: CA        DEX
C780: D0 ED     BNE     $C76F
C782: C6 4B     DEC     $4B
C784: D0 E9     BNE     $C76F
C786: AD F5 C0  LDA     $C0F5
C789: 2A        ROL     
C78A: 30 06     BMI     $C792
C78C: 29 20     AND     #$20
C78E: F0 F6     BEQ     $C786
C790: D0 10     BNE     $C7A2
C792: A9 04     LDA     #$04
C794: 8D F2 C0  STA     $C0F2
C797: AD F6 C0  LDA     $C0F6
C79A: 91 44     STA     ($44),Y
C79C: 18        CLC
C79D: 60        RTS
C79E: 29 20     AND     #$20
C7A0: F0 CD     BEQ     $C76F
C7A2: 38        SEC
C7A3: 60        RTS
C7A4: A9 06     LDA     #$06
C7A6: 8D F2 C0  STA     $C0F2
C7A9: A9 01     LDA     #$01
C7AB: 8D F1 C0  STA     $C0F1
C7AE: 8D F5 C0  STA     $C0F5
C7B1: A0 00     LDY     #$00
C7B3: A2 02     LDX     #$02
C7B5: AD F5 C0  LDA     $C0F5
C7B8: 2A        ROL     
C7B9: 30 06     BMI     $C7C1
C7BB: 29 20     AND     #$20
C7BD: F0 F6     BEQ     $C7B5
C7BF: D0 E1     BNE     $C7A2
C7C1: B1 44     LDA     ($44),Y
C7C3: 8D FC C0  STA     $C0FC
C7C6: C8        INY
C7C7: D0 EC     BNE     $C7B5
C7C9: E6 45     INC     $45
C7CB: CA        DEX
C7CC: D0 E7     BNE     $C7B5
C7CE: A9 04     LDA     #$04
C7D0: 8D F2 C0  STA     $C0F2
C7D3: 18        CLC
C7D4: 60        RTS
C7D5: FF        .db     $FF
C7D6: FF        .db     $FF
C7D7: FF        .db     $FF
C7D8: FF        .db     $FF
C7D9: FF        .db     $FF
C7DA: FF        .db     $FF
C7DB: FF        .db     $FF
C7DC: FF        .db     $FF
C7DD: FF        .db     $FF
C7DE: FF        .db     $FF
C7DF: FF        .db     $FF
C7E0: FF        .db     $FF
C7E1: FF        .db     $FF
C7E2: FF        .db     $FF
C7E3: FF        .db     $FF
C7E4: FF        .db     $FF
C7E5: FF        .db     $FF
C7E6: FF        .db     $FF
C7E7: FF        .db     $FF
C7E8: FF        .db     $FF
C7E9: FF        .db     $FF
C7EA: FF        .db     $FF
C7EB: FF        .db     $FF
C7EC: FF        .db     $FF
C7ED: FF        .db     $FF
C7EE: FF        .db     $FF
C7EF: FF        .db     $FF
C7F0: FF        .db     $FF
C7F1: FF        .db     $FF
C7F2: FF        .db     $FF
C7F3: FF        .db     $FF
C7F4: FF        .db     $FF
C7F5: FF        .db     $FF
C7F6: FF        .db     $FF
C7F7: FF        .db     $FF
C7F8: C0 00     CPY     #$00
C7FA: A5 02     LDA     $02
C7FC: 00        BRK
C7FD: 00        BRK
C7FE: 7F        .db     $7F
C7FF: 12        .db     $12
