         mx    %00                 ; 16-bit A and index: this is
*                                   65816 module code, whatever the
*                                   host program was assembling in

*
* SCSI16 - the Cirtech transport, ported to 65816 for the link layer
*
* A direct port of ../src/02 scsicore.s, which is proven on hardware.  The
* differences are all mechanical:
*
*   - registers are reached with long addressing in bank $E0, which is also
*     where slot timing is correct
*   - counters are 16-bit, and buffers are addressed through [ptr],y so a
*     transfer can be a full 1514 byte frame
*   - A stays 8-bit through the transfer loops, X holds slot * 16
*
* Register map and phase sequences: ../docs/hardware.md
*

*---------- Find the card
*
* ID bytes $Cs01 = $20, $Cs03 = $00, $Cs05 = $03, $CsFB = $02.
* X walks the slot ROMs at $E0Cs00; slotIDX ends up as slot * 16.

findCARD php
         sep #$20
         rep #$10
         ldx #$0700                 ; slot 7 downwards

:try     ldal $E0C001,x
         cmp #$20
         bne :next
         ldal $E0C003,x
         bne :next
         ldal $E0C005,x
         cmp #$03
         bne :next
         ldal $E0C0FB,x
         cmp #$02
         bne :next

         rep #$30                   ; slot * 256 becomes slot * 16
         txa
         xba
         and #$000F
         asl
         asl
         asl
         asl
         sta slotIDX
         plp
         clc
         rts

:next    rep #$20
         txa
         sec
         sbc #$0100
         tax
         sep #$20
         cpx #$0100
         bcs :try

         plp
         sec
         rts

*---------- Run one command
*
* Fill cdb/cdbLEN, inPTR/inLEN for a data-in command, outPTR/outLEN for a
* data-out one, then call.  Carry set means selection never happened.

*   Two things this did not do before, both of which matter because GS/OS
*   drives its boot disk through the same card:
*
*   - it never released the card.  The ProDOS 8 programs always put $00 on
*     the data lines and $04 into the control and transfer registers when
*     they finished; leaving the transfer engine armed or the data bus driven
*     leaves the card unusable by the ROM, and the machine stops being able
*     to read the disk - which is exactly what the log shows.
*   - plp restored the caller's carry, so every "bcs" on a runSCSI result was
*     testing the caller's own flag rather than ours.

runSCSI  php
         sei                        ; nothing else touches the card mid-command
         rep #$30
         stz cdbIDX
         stz inCNT
         stz outCNT
         lda #$FFFF
         sta status
         sta message

         jsr selectIT
         bcs :fail
         jsr phaseLOOP
         bcs :fail

         jsr relCARD
         plp                        ; restores the caller's flags, and the
         clc                        ; interrupt state along with them
         rts

:fail    jsr relCARD
         plp
         sec
         rts

*---------- Put the card back where the ROM expects to find it

relCARD  php
         sep   #$20
         rep   #$10
         ldx   slotIDX
         lda   #$00
         stal  rDATA,x
         lda   #$04
         stal  rCTRL,x
         stal  rXFER,x
         plp
         rts

*---------- Selection

selectIT php
         sep #$20
         rep #$10
         ldx slotIDX

         lda #$00                   ; quiesce
         stal rCTRL,x
         stal rXFER,x
         stal rPHASE,x
         stal rBUS,x
         ldal rSTROBE,x
         ldal rBUS,x
         beq :quiet
         plp
         sec
         rts

:quiet   ldal rDATAIN,x             ; arm
         eor #$FF
         stal rDATA,x
         lda #$01
         stal rXFER,x

         ldy #$0000
:arm     ldal rCTRL,x
         asl
         bmi :armed
         ldal rSTAT,x
         and #$10
         bne :bad
         dey
         bne :arm
:bad     plp
         sec
         rts

:armed   ldal rCTRL,x
         and #$20
         bne :bad

         lda #$0C                   ; both IDs on the bus, assert SEL
         stal rCTRL,x
         ldal rDATAIN,x
         eor #$FF
         ora #IDMASK
         stal rDATA,x
         lda #$00
         stal rXFER,x
         stal rBUS,x
         lda #$05
         stal rCTRL,x

         ldy #$6900                 ; the ROM's timeout, near enough
:wait    ldal rBUS,x
         asl
         bmi :got
         dey
         bne :wait
         plp
         sec
         rts

:got     lda #$04
         stal rXFER,x
         ldal rSTROBE,x
         lda #$00
         stal rCTRL,x
         plp
         clc
         rts

*---------- The phase loop, one byte per pass

phaseLOOP php
         sep #$20
         rep #$10

:top     ldx slotIDX
         lda #$00
         stal rCTRL,x               ; clear ACK and the data drive

         ldal rBUS,x
         asl
         bpl :done                  ; BSY gone: the command is over

:wreq    ldal rBUS,x
         and #$20
         bne :req
         ldal rSTAT,x
         and #$10
         bne :abort
         ldal rBUS,x
         asl
         bpl :done
         bra :wreq

:req     ldal rBUS,x
         and #$1C
         lsr
         sta phase
         lsr
         stal rPHASE,x
         ldal rSTROBE,x

         lda phase                  ; the handlers sit past branch range,
         cmp #phCOMMAND             ; so each test needs a long jump
         bne :n0
         brl :cmd
:n0      cmp #phDATAIN
         bne :n1
         brl :din
:n1      cmp #phDATAOUT
         bne :n2
         brl :dout
:n2      cmp #phSTATUS
         bne :n3
         brl :sts
:n3      cmp #phMSGIN
         bne :n4
         brl :msg
:n4      cmp #phMSGOUT
         bne :n5
         brl :mout
:n5      brl :top                   ; a phase we do not use: ignore it

:done    plp
         clc
         rts
:abort   plp
         sec
         rts

*--- command out

:cmd     rep #$20
         lda cdbIDX
         cmp cdbLEN
         bcc :cmdget
         sep #$20
         lda #$00
         bra :cmdsend
:cmdget  tay
         sep #$20
         lda cdb,y
:cmdsend jsr sendBYTE
         rep #$20
         inc cdbIDX
         sep #$20
         brl :top

*--- data in, staying in the phase while REQ keeps coming

:din     jsr recvBYTE
         pha
         rep #$20
         lda inCNT
         cmp inLEN
         bcs :dinskip
         tay
         sep #$20
         pla
         sta [inPTR],y
         rep #$20
         inc inCNT
         sep #$20
         bra :dinmore
:dinskip sep #$20
         pla
         rep #$20
         inc inCNT                  ; still count what we could not store
         sep #$20

:dinmore ldx slotIDX
         ldal rBUS,x
         and #$20
         beq :backtop
         ldal rBUS,x
         and #$1C
         lsr
         cmp #phDATAIN
         beq :din
:backtop brl :top

*--- data out

:dout    rep #$20
         lda outCNT
         cmp outLEN
         bcc :doget
         sep #$20
         lda #$00
         bra :dosend
:doget   tay
         sep #$20
         lda [outPTR],y
:dosend  jsr sendBYTE
         rep #$20
         inc outCNT
         sep #$20

         ldx slotIDX
         ldal rBUS,x
         and #$20
         beq :obacktop
         ldal rBUS,x
         and #$1C
         lsr
         cmp #phDATAOUT
         beq :dout
:obacktop brl :top

*--- the short phases

:sts     jsr recvBYTE
         sta status
         brl :top

:msg     jsr recvBYTE
         sta message
         brl :top

:mout    lda #$07                   ; message reject, as the ROM does
         jsr sendBYTE
         brl :top

*---------- One byte, A 8-bit, X = slotIDX
*
* sendBYTE puts A on the bus first, recvBYTE just reads.  Both then run the
* handshake from $CEA8 in the Cirtech ROM.

sendBYTE stal rDATA,x
         sec
         bra xfer

recvBYTE clc

xfer     ldal rBUS,x                ; wait for REQ
         and #$20
         bne :req
         ldal rSTAT,x
         and #$10
         bne :out
         bra xfer

:req     bcc :read
         ldal rCTRL,x               ; sending: drive the bus
         ora #bDRIVE
         stal rCTRL,x

:read    ldal rDATA,x
         pha
         ldal rCTRL,x               ; ACK on
         ora #bACK
         stal rCTRL,x

:wack    ldal rBUS,x                ; wait for REQ to drop
         and #$20
         beq :ackoff
         ldal rSTAT,x
         and #$10
         beq :wack

:ackoff  ldal rCTRL,x               ; ACK off
         and #$FF-bACK
         stal rCTRL,x
         pla
         rts

:out     lda #$00
         rts

*===========================================================================
* The DaynaPORT command set (../../scsi2/other/dayna/SLINKCMD.txt)
*===========================================================================

*---------- $0E enable and disable

*   Both are called from 16-bit code, so the prologue sets the width before
*   anything width-sensitive, rather than inheriting whatever preceded it.

netENABLE php
         rep   #$30
         lda   #$0080
         bra   netTOG2
netDISABLE php
         rep   #$30
         lda   #$0000

netTOG2  sep   #$20                 ; the flag is one byte: a 16-bit store
         sta   cdbENA+5             ; here would run into the next CDB
         rep   #$20
         ldx #cdbENA
         jsr loadCDB
         stz inLEN
         stz outLEN
         jsr runSCSI
         plp
         rts

*---------- $09 statistics: the MAC address comes back first

netSTATS php
         rep #$30
         ldx #cdbSTA
         jsr loadCDB
         lda #statBUF
         sta inPTR
         lda   myBank
         sta   inPTR+2
         lda #18
         sta inLEN
         stz outLEN
         jsr runSCSI

         ldy #$0000                 ; keep our hardware address
:cp      lda statBUF,y
         sta myMAC,y
         iny
         iny
         cpy #$0006
         bcc :cp
         plp
         rts

*---------- $08 read a frame
*
* The reply is a 6 byte header then the frame.  Length counts the 4 CRC
* bytes, so strip them.  Carry set means nothing arrived.

netREAD  php
         rep #$30
         ldx #cdbRD
         jsr loadCDB
         lda #readBUF
         sta inPTR
         lda   myBank
         sta   inPTR+2
         lda #DPHDR+FRAMEMAX
         sta inLEN
         stz outLEN
         jsr runSCSI
         bcs :none

         lda inCNT
         cmp #DPHDR
         bcc :none

         sep #$20                   ; length is big-endian in the header
         lda readBUF
         xba
         lda readBUF+1
         rep #$20
         and #$FFFF
         beq :none
         cmp #FRAMEMAX+5            ; a frame plus its CRC, at most: a longer
         bcs :none                  ; claim would carry copies past readBUF

         sec                        ; drop the CRC
         sbc #$0004
         bcc :none
         sta frameLEN
         plp
         clc
         rts

:none    stz frameLEN
         plp
         sec
         rts

*---------- $0A write a frame
*
* cdb[5] = 0 means a raw packet image and cdb[3..4] is its length.

netWRITE php
         rep #$30
         lda frameLEN
         beq :out

*   Pad to the ethernet minimum.  MACAP, the only program that has had an ARP
*   reply back, always sent 60 bytes; an ARP here is 42.  Whether the Pico
*   pads short frames itself has never been tested, so do not rely on it.

         cmp #ETHMIN
         bcs :sized
         tay                        ; zero from the end of the frame up
         sep #$20
         lda #$00
:pad     sta frameBUF,y
         iny
         cpy #ETHMIN
         bcc :pad
         rep #$20
         lda #ETHMIN
         sta frameLEN

:sized   sep #$20
         lda frameLEN+1             ; length, big-endian into the CDB
         sta cdbWR+3
         lda frameLEN
         sta cdbWR+4
         rep #$20

         ldx #cdbWR
         jsr loadCDB
         lda #frameBUF
         sta outPTR
         lda   myBank
         sta   outPTR+2
         lda frameLEN
         sta outLEN
         stz inLEN
         jsr runSCSI
:out     plp
         rts

*---------- Trace beacon
*
* A freeze leaves no output, so the module reports its progress over the SCSI
* bus instead: a read command whose allocation length carries a marker byte.
* The BlueSCSI log then shows
*
*     OUT: 0x08 0x00 0x00 0x00 <marker> 0xC0
*
* which survives anything that happens to GS/OS afterwards.  Entry markers are
* the call number; exit markers are the call number with bit 7 set, so a call
* that goes in and never comes out is obvious.
*
* A = marker, 8-bit.  Does nothing until the card has been found, because
* slotIDX of zero would aim the register writes at slot 0 - the language card
* soft switches - which would be a far worse bug than the one being chased.

traceBYTE php
         rep   #$30
         and   #$00FF
         pha

         lda   slotIDX
         bne   :ready
         jsr   findCARD             ; only reads slot ROM: safe
         bcc   :ready
         pla
         plp
         rts

:ready   pla
         sep   #$20
         sta   cdbTRC+4             ; the marker rides in the length field
         rep   #$20

         ldx   #cdbTRC
         jsr   loadCDB
         stz   inLEN
         stz   outLEN
         jsr   runSCSI
         plp
         rts

cdbTRC   hex   08,00,00,00,00,C0

*---------- Copy six CDB bytes from X into place

loadCDB  php
         rep #$30
         phx
         pla
         sta :src+1
         ldy #$0000
:src     lda $FFFF,y
         sta cdb,y
         iny
         iny
         cpy #$0006
         bcc :src
         lda #$0006
         sta cdbLEN
         plp
         rts

*---------- Command templates

cdbENA   hex   0E,00,00,00,00,80
cdbSTA   hex   09,00,00,00,12,00
cdbRD    hex   08,00,00,06,00,C0    ; allocation $0600
cdbWR    hex   0A,00,00,00,00,00    ; length filled in above

*---------- Transport storage

slotIDX  ds    2
cdb      ds    12
cdbLEN   ds    2
cdbIDX   ds    2
inLEN    ds    2
inCNT    ds    2
outLEN   ds    2
outCNT   ds    2
status   ds    2
message  ds    2
phase    ds    2
statBUF  ds    18
readBUF  ds    DPHDR+FRAMEMAX
frameBUF =     readBUF+DPHDR        ; the frame sits just past the header
frameLEN ds    2
myMAC    ds    6
