*
* CIRTECH SCSI NETWORK RECEIVE - milestone 3c
*
* Talks to the DaynaPORT the way a real SCSI/Link driver does:
*
*   1. Enable the interface   0E 00 00 00 00 80, then wait ~0.5s
*   2. Retrieve statistics    09 00 00 00 12 00   (18 bytes, MAC first)
*   3. Read packets           08 00 00 LL LL C0   (repeatedly)
*
* Command set from ../../scsi2/other/dayna/SLINKCMD.txt, "DaynaPort SCSI/Link:
* SCSI Command Set", Roger Burrows, revision 1.20.
*
* A read returns:  LL LL NN NN NN NN <packet> CC CC CC CC
*   LLLL = packet length including the 4 CRC bytes, excluding the header
*   NNNNNNNN = 00000000 last packet, 00000010 more waiting,
*              FFFFFFFF a packet was dropped (length then reads 4000)
*   LLLL = 0000 means nothing is waiting.
*
* Note byte 5 of the read CDB must be C0 or 80, not 00.  The ERS calls those
* bits vendor unique; for a DaynaPORT they are required.
*
* ProDOS 8, Merlin, BRUN it.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         org   $2000
         typ   $06
         lst   off
         DSK   NetRecvCompiled

COUT     =     $FDED
PRBYTE   =     $FDDA
CROUT    =     $FD8E

ptr      =     $06
mptr     =     $08

TARGETID =     3
IDMASK   =     $88
BUFLEN   =     128
TRIES    =     16                   ; read attempts before giving up

*---------- Entry

start    jsr   CROUT
         lda   #<msgTITLE
         ldy   #>msgTITLE
         jsr   puts

         jsr   findCARD
         bcc   :ok
         lda   #<msgNONE
         ldy   #>msgNONE
         jmp   puts

*--- 1. enable the interface

:ok      lda   #<msgENAB
         ldy   #>msgENAB
         jsr   puts

         lda   #<cdbENABLE
         ldy   #>cdbENABLE
         jsr   setCDB
         jsr   runSCSI
         bcc   :en2
         lda   #<msgNOSEL
         ldy   #>msgNOSEL
         jsr   puts
         jmp   cleanup

:en2     jsr   shoRESULT
         jsr   delay                ; the spec asks for about half a second

*--- 1b. allow broadcast frames (SLINKCMD.txt, Set Interface Mode)

         lda   #<msgBCAST
         ldy   #>msgBCAST
         jsr   puts
         lda   #<cdbBCAST
         ldy   #>cdbBCAST
         jsr   setCDB
         jsr   runSCSI
         jsr   shoRESULT

*--- 2. statistics, for the MAC address

         lda   #<msgSTATS
         ldy   #>msgSTATS
         jsr   puts

         lda   #<cdbSTATS
         ldy   #>cdbSTATS
         jsr   setCDB
         jsr   runSCSI
         jsr   shoRESULT

         lda   datIDX
         cmp   #$06
         bcc   :read

         lda   #<msgMAC
         ldy   #>msgMAC
         jsr   puts
         ldy   #$00
:mloop   lda   buf,y
         jsr   PRBYTE
         iny
         cpy   #$06
         bcc   :mloop
         jsr   CROUT

*--- 3. read packets

:read    lda   #<msgREAD
         ldy   #>msgREAD
         jsr   puts

         lda   #<msgWAIT
         ldy   #>msgWAIT
         jsr   puts

         lda   #TRIES
         sta   tries

:rloop   lda   #<cdbREAD
         ldy   #>cdbREAD
         jsr   setCDB
         jsr   runSCSI

         lda   datIDX               ; did we get a header at all?
         cmp   #$06
         bcc   :next

         lda   buf                  ; length, big-endian
         ora   buf+1
         bne   :gotone

:next    lda   $C000                ; any key stops the wait
         bmi   :keyed
         jsr   pause                 ; about an eighth of a second
         dec   tries
         bne   :rloop

         lda   #"."                  ; one dot per pass of the whole count
         jsr   COUT
         lda   #TRIES
         sta   tries
         jmp   :rloop

:keyed   sta   $C010
         jsr   CROUT
         lda   #<msgQUIET
         ldy   #>msgQUIET
         jsr   puts
         jmp   cleanup

*--- a packet

:gotone  jsr   CROUT
         jsr   shoRESULT

         lda   #<msgLEN
         ldy   #>msgLEN
         jsr   puts
         lda   buf
         jsr   PRBYTE
         lda   buf+1
         jsr   PRBYTE
         jsr   CROUT

         lda   #<msgFLAG
         ldy   #>msgFLAG
         jsr   puts
         ldy   #$02
:floop   lda   buf,y
         jsr   PRBYTE
         iny
         cpy   #$06
         bcc   :floop
         jsr   CROUT

         lda   #<msgPKT
         ldy   #>msgPKT
         jsr   puts
         ldy   #$06
:ploop   cpy   datIDX
         bcs   :pdone
         lda   buf,y
         jsr   prhex
         iny
         tya
         and   #$07
         bne   :ploop
         jsr   CROUT
         jmp   :ploop
:pdone   jsr   CROUT
         jmp   cleanup

*---------- Show status, message and byte count

shoRESULT lda  #<msgSTS
         ldy   #>msgSTS
         jsr   puts
         lda   status
         jsr   PRBYTE
         lda   #<msgMSG
         ldy   #>msgMSG
         jsr   puts
         lda   message
         jsr   PRBYTE
         lda   #<msgGOT
         ldy   #>msgGOT
         jsr   puts
         lda   totalIN+1
         jsr   PRBYTE
         lda   totalIN
         jsr   PRBYTE
         jmp   CROUT

*---------- Copy the six-byte CDB at A/Y into place

setCDB   sta   :src+1
         sty   :src+2
         ldy   #$05
:src     lda   $FFFF,y
         sta   cdb,y
         dey
         bpl   :src
         lda   #$06
         sta   cdbLEN
         rts

*---------- Roughly an eighth of a second

pause    ldx   #$00
:mid     ldy   #$00
:inner   dey
         bne   :inner
         dex
         bne   :mid
         rts

*---------- Roughly half a second

delay    lda   #$04
         sta   dcnt
:outer   ldx   #$00
:mid     ldy   #$00
:inner   dey
         bne   :inner
         dex
         bne   :mid
         dec   dcnt
         bne   :outer
         rts

*---------- Commands, from SLINKCMD.txt

cdbENABLE hex  0E,00,00,00,00,80    ; enable interface
cdbBCAST hex   0C,00,00,00,04,80    ; set interface mode: allow broadcast
cdbSTATS hex   09,00,00,00,12,00    ; retrieve statistics, 18 bytes
cdbREAD  hex   08,00,00,02,00,C0    ; read a packet, allocation $0200

*---------- Filled in by setCDB

cdb      ds    6
cdbLEN   dfb   6

outBUF   ds    1                    ; no data-out phase here
outLEN   da    0

buf      ds    BUFLEN
tries    ds    1
dcnt     ds    1

*---------- Messages

msgTITLE asc   "DAYNAPORT RECEIVE, TARGET 3"
         hex   8D00
msgNONE  asc   "NO CIRTECH CARD FOUND"
         hex   8D00
msgNOSEL asc   "SELECTION FAILED"
         hex   8D00
msgENAB  asc   "ENABLE INTERFACE $0E"
         hex   8D00
msgBCAST asc   "ALLOW BROADCAST $0C"
         hex   8D00
msgSTATS asc   "STATISTICS $09"
         hex   8D00
msgREAD  asc   "READING $08"
         hex   8D00
msgSTS   asc   "  STATUS: "
         hex   00
msgMSG   asc   " MESSAGE: "
         hex   00
msgGOT   asc   " BYTES: "
         hex   00
msgMAC   asc   "  MAC: "
         hex   00
msgLEN   asc   "PACKET LENGTH: "
         hex   00
msgFLAG  asc   "FLAGS: "
         hex   00
msgPKT   asc   "PACKET:"
         hex   8D00
msgWAIT  asc   "LISTENING - PRESS A KEY TO STOP"
         hex   8D00
msgQUIET asc   "STOPPED, NO PACKETS SEEN"
         hex   8D00

         PUT   02 scsicore
