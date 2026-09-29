*
* CIRTECH SCSI MAC-AS-ACCESS-POINT ARP TEST - milestone 3g
*
* Aimed at a Mac running Internet Sharing, which puts the Mac itself on
* 192.168.2.1 as the gateway.  We claim 192.168.2.99.
*
* This beats a phone hotspot as a test, because the Mac is the access point:
* you can watch every frame we send arrive, with
*
*     sudo tcpdump -i bridge100 -e -n
*
* and the Mac answers the ARP itself.  That splits the remaining question for
* good.  If the request shows up on bridge100, transmit works and only the
* receive path is left.  If the Mac's reply goes out to 00:80:19:17:1E:95 and
* we still read nothing, the firmware's receive bridge is at fault, and we can
* say so with evidence.
*
* Check the subnet first - ifconfig bridge100 - and tell me if it is not
* 192.168.2.x, because these two addresses are baked into the frame below.
*
* Set WiFiSSID and WiFiPassword in bluescsi.ini to the shared network first.
*
*   1. Enable the interface   0E 00 00 00 00 80, then wait
*   2. Write a packet         0A 00 00 00 3C 00  (60 bytes, no preamble)
*   3. Read packets           08 00 00 LL LL C0
*
* Command set from ../../scsi2/other/dayna/SLINKCMD.txt.  With byte 5 of the
* write CDB set to 00 the data is a raw packet image and LLLL is its length,
* which matches the BlueSCSI firmware: cdb[5] == 0 means no preamble.
*
* Why ARP: the gateway answers an ARP request with a unicast frame addressed
* to our MAC.  That gets through even on a network with client isolation,
* where broadcast traffic between clients is blocked - which would explain a
* passive listen hearing nothing at all.
*
* This is also the first command that uses the data-out phase.
*
* ProDOS 8, Merlin, BRUN it.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         org   $2000
         typ   $06
         lst   off
         DSK   MacApCompiled

COUT     =     $FDED
PRBYTE   =     $FDDA
CROUT    =     $FD8E

ptr      =     $06
mptr     =     $08

TARGETID =     3
IDMASK   =     $88
BUFLEN   =     128
FRAMELEN =     60                   ; padded to the ethernet minimum
TRIES    =     20                   ; twenty polls, one per second

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

*--- enable

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

*--- send the ARP request

         lda   #<msgSEND
         ldy   #>msgSEND
         jsr   puts

         lda   #FRAMELEN
         sta   outLEN
         lda   #$00
         sta   outLEN+1
         lda   #<cdbWRITE
         ldy   #>cdbWRITE
         jsr   setCDB
         jsr   runSCSI
         jsr   shoRESULT

         lda   #$00                 ; no data out for the reads that follow
         sta   outLEN
         sta   outLEN+1

         lda   status
         beq   :listen
         lda   #<msgWFAIL
         ldy   #>msgWFAIL
         jsr   puts

*--- listen for the reply

:listen  lda   #<msgWAIT
         ldy   #>msgWAIT
         jsr   puts

         jsr   delay                ; let the radio breathe before we start

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
         jsr   pause
         dec   tries
         bne   :rloop

         jsr   CROUT
         lda   #<msgQUIET
         ldy   #>msgQUIET
         jsr   puts
         jmp   cleanup

:keyed   sta   $C010
         jsr   CROUT
         lda   #<msgQUIET
         ldy   #>msgQUIET
         jsr   puts
         jmp   cleanup

*--- a packet came back

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

*---------- About a second: the firmware needs time to service the radio

slowpause lda  #$08
         sta   scnt
:loop    jsr   pause
         dec   scnt
         bne   :loop
         rts

*---------- Commands

cdbENABLE hex  0E,00,00,00,00,80    ; enable interface
cdbWRITE hex   0A,00,00,00,3C,00    ; write 60 bytes, raw packet image
cdbREAD  hex   08,00,00,02,00,C0    ; read a packet

cdb      ds    6
cdbLEN   dfb   6

*---------- The ARP request
*
* who has 192.168.2.1?  tell 192.168.2.99 at 00:80:19:17:1E:95

outBUF   hex   FFFFFFFFFFFF         ; destination: broadcast
         hex   008019171E95         ; source: our MAC
         hex   0806                 ; ethertype: ARP
         hex   0001                 ; hardware type: ethernet
         hex   0800                 ; protocol type: IPv4
         hex   06                   ; hardware address length
         hex   04                   ; protocol address length
         hex   0001                 ; operation: request
         hex   008019171E95         ; sender hardware address
         hex   C0A80263             ; sender IP 192.168.2.99
         hex   000000000000         ; target hardware address: unknown
         hex   C0A80201             ; target IP 192.168.2.1
         hex   000000000000000000   ; pad to the 60 byte minimum
         hex   000000000000000000

outLEN   ds    2

buf      ds    BUFLEN
tries    ds    1
dcnt     ds    1
scnt     ds    1

*---------- Messages

msgTITLE asc   "MAC AP ARP TEST, TARGET 3"
         hex   8D00
msgNONE  asc   "NO CIRTECH CARD FOUND"
         hex   8D00
msgNOSEL asc   "SELECTION FAILED"
         hex   8D00
msgENAB  asc   "ENABLE INTERFACE $0E"
         hex   8D00
msgSEND  asc   "SEND ARP FOR 192.168.2.1 $0A"
         hex   8D00
msgWFAIL asc   "WRITE REPORTED AN ERROR"
         hex   8D00
msgWAIT  asc   "LISTENING FOR THE REPLY"
         hex   8D00
msgSTS   asc   "  STATUS: "
         hex   00
msgMSG   asc   " MESSAGE: "
         hex   00
msgGOT   asc   " BYTES: "
         hex   00
msgLEN   asc   "PACKET LENGTH: "
         hex   00
msgFLAG  asc   "FLAGS: "
         hex   00
msgPKT   asc   "PACKET:"
         hex   8D00
msgQUIET asc   "NO REPLY SEEN"
         hex   8D00

         PUT   02 scsicore
