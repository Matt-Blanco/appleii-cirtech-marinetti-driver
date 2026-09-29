*
* CIRTECH SCSI DHCP DISCOVER - milestone 3e
*
* Sends a DHCP DISCOVER and listens for the offer.
*
* Why DHCP rather than another ARP: the earlier ARP claimed 10.23.8.177, an
* address nothing had leased us.  A managed network running dynamic ARP
* inspection or IP source guard drops frames whose source address was never
* handed out, which would explain a frame the radio accepted but nobody
* answered.  DHCP is what a station is allowed to send before it has a lease,
* so it gets through where the ARP would not.
*
* The BOOTP broadcast flag is set, so the server broadcasts its reply.  That
* also survives client isolation, which blocks client-to-client traffic but
* not traffic from the gateway.
*
* The frame is 291 bytes, which is why the core now carries a 16-bit data-out
* length.  Generated with the checksum already computed.
*
*   1. Enable the interface   0E 00 00 00 00 80
*   2. Write the frame        0A 00 00 01 23 00   (291 bytes, no preamble)
*   3. Read packets           08 00 00 LL LL C0   once a second
*
* ProDOS 8, Merlin, BRUN it.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         org   $2000
         typ   $06
         lst   off
         DSK   DhcpCompiled

COUT     =     $FDED
PRBYTE   =     $FDDA
CROUT    =     $FD8E

ptr      =     $06
mptr     =     $08

TARGETID =     3
IDMASK   =     $88
BUFLEN   =     128
FRAMELEN =     291
TRIES    =     20

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
         jsr   delay

*--- send the DISCOVER

         lda   #<msgSEND
         ldy   #>msgSEND
         jsr   puts

         lda   #<FRAMELEN
         sta   outLEN
         lda   #>FRAMELEN
         sta   outLEN+1
         lda   #<cdbWRITE
         ldy   #>cdbWRITE
         jsr   setCDB
         jsr   runSCSI
         jsr   shoRESULT

         lda   #$00
         sta   outLEN
         sta   outLEN+1

*--- listen

         lda   #<msgWAIT
         ldy   #>msgWAIT
         jsr   puts
         jsr   delay

         lda   #TRIES
         sta   tries

:rloop   lda   #<cdbREAD
         ldy   #>cdbREAD
         jsr   setCDB
         jsr   runSCSI

         lda   datIDX
         cmp   #$06
         bcc   :next
         lda   buf
         ora   buf+1
         bne   :gotone

:next    lda   $C000
         bmi   :keyed
         lda   #"."
         jsr   COUT
         jsr   slowpause
         dec   tries
         bne   :rloop

:keyed   sta   $C010
         jsr   CROUT
         lda   #<msgQUIET
         ldy   #>msgQUIET
         jsr   puts
         jmp   cleanup

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

*---------- Status, message, byte count

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

*---------- Delays

pause    ldx   #$00
:mid     ldy   #$00
:inner   dey
         bne   :inner
         dex
         bne   :mid
         rts

delay    lda   #$04
         sta   dcnt
:outer   jsr   pause
         dec   dcnt
         bne   :outer
         rts

slowpause lda  #$08
         sta   scnt
:loop    jsr   pause
         dec   scnt
         bne   :loop
         rts

*---------- Commands

cdbENABLE hex  0E,00,00,00,00,80
cdbWRITE hex   0A,00,00,01,23,00    ; 291 bytes, raw packet image
cdbREAD  hex   08,00,00,02,00,C0

cdb      ds    6
cdbLEN   dfb   6

*---------- The DHCP DISCOVER frame

outBUF   =     *
         hex   FFFFFFFFFFFF008019171E9508004500
         hex   011500000000401179D900000000FFFF
         hex   FFFF0044004301010000010106001E95
         hex   17080000800000000000000000000000
         hex   000000000000008019171E9500000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000000000000000000000000
         hex   00000000000063825363350101370301
         hex   0306FF
outLEN   ds    2

buf      ds    BUFLEN
tries    ds    1
dcnt     ds    1
scnt     ds    1

*---------- Messages

msgTITLE asc   "DHCP DISCOVER, TARGET 3"
         hex   8D00
msgNONE  asc   "NO CIRTECH CARD FOUND"
         hex   8D00
msgNOSEL asc   "SELECTION FAILED"
         hex   8D00
msgENAB  asc   "ENABLE INTERFACE $0E"
         hex   8D00
msgSEND  asc   "SEND DHCP DISCOVER, 291 BYTES"
         hex   8D00
msgWAIT  asc   "LISTENING FOR THE OFFER"
         hex   8D00
msgSTS   asc   "  STATUS: "
         hex   00
msgMSG   asc   " MESSAGE: "
         hex   00
msgGOT   asc   " BYTES: "
         hex   00
msgLEN   asc   "PACKET LENGTH: "
         hex   00
msgPKT   asc   "PACKET:"
         hex   8D00
msgQUIET asc   "NO OFFER SEEN"
         hex   8D00

         PUT   02 scsicore
