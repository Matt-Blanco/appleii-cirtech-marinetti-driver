*
* CIRTECH SCSI INQUIRY - milestone 2
*
* Selects a target and runs a full SCSI command through it: command out,
* data in, status, message in.  Sends INQUIRY ($12) and prints what comes
* back, so we can see the BlueSCSI's "Dayna" / "SCSI/Link" strings.
*
* Everything is done by driving the card's registers.  The only ROM call is
* the SmartPort bus reset on the way out.
*
* Byte handshake follows the ROM primitives at $CEA1/$CEA7 and $CEE0-$CEF7.
* One byte per pass of the phase loop: slower than the ROM's block engine,
* but it re-reads the phase every byte, so it cannot desynchronise.
*
* ProDOS 8, Merlin, BRUN it.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         org   $2000
         typ   $06
         lst   off
         DSK   InquiryCompiled

*---------- Monitor

COUT     =     $FDED
PRBYTE   =     $FDDA
CROUT    =     $FD8E

*---------- Zero page scratch

ptr      =     $06
mptr     =     $08

*---------- Card registers, X = slot * 16

rDATA    =     $C080                ; +0  data in and out
rCTRL    =     $C081                ; +1  write control, read status
rXFER    =     $C082                ; +2  transfer engine
rPHASE   =     $C083                ; +3  expected phase
rBUS     =     $C084                ; +4  bus status: BSY $40, REQ $20, phase $1C
rSTAT    =     $C085                ; +5  card status
rSTROBE  =     $C087                ; +7  strobe
rDATAIN  =     $C088                ; +8  inverted readback

*---------- Bus control bits (register +1)

bDRIVE   =     $01                  ; drive the data bus
bACK     =     $10                  ; assert ACK

*---------- Phases, as (bus & $1C) >> 1

phDATAOUT =    $00
phDATAIN =     $02
phCOMMAND =    $04
phSTATUS =     $06
phMSGIN  =     $0E

*---------- Configurable

IDMASK   =     $88                  ; ID 3 (target) + ID 7 (initiator)

*---------- Entry

start    jsr   CROUT
         lda   #<msgTITLE
         ldy   #>msgTITLE
         jsr   puts

         jsr   findCARD
         bcc   :ok
         lda   #<msgNONE
         ldy   #>msgNONE
         jsr   puts
         rts

:ok      lda   slot
         asl
         asl
         asl
         asl
         sta   idx

         jsr   selectIT
         bcc   :sel
         lda   #<msgNOSEL
         ldy   #>msgNOSEL
         jsr   puts
         jmp   cleanup

:sel     jsr   phaseLOOP
         jsr   report
         jmp   cleanup

*---------- Find the card

findCARD ldx   #7
:loop    stx   slot
         txa
         ora   #$C0
         sta   ptr+1
         lda   #$00
         sta   ptr
         ldy   #$01
         lda   (ptr),y
         cmp   #$20
         bne   :next
         ldy   #$03
         lda   (ptr),y
         bne   :next
         ldy   #$05
         lda   (ptr),y
         cmp   #$03
         bne   :next
         ldy   #$FB
         lda   (ptr),y
         cmp   #$02
         bne   :next
         clc
         rts
:next    ldx   slot
         dex
         bne   :loop
         sec
         rts

*---------- Select the target.  Carry clear on success.

selectIT ldx   idx

         lda   #$00                 ; quiesce
         sta   rCTRL,x
         sta   rXFER,x
         sta   rPHASE,x
         sta   rBUS,x
         lda   rSTROBE,x
         lda   rBUS,x
         beq   :quiet
         sec
         rts

:quiet   lda   rDATAIN,x            ; arm
         eor   #$FF
         sta   rDATA,x
         lda   #$01
         sta   rXFER,x

         ldy   #$00
:arm     lda   rCTRL,x
         asl
         bmi   :armed
         lda   rSTAT,x
         and   #$10
         bne   :bad
         dey
         bne   :arm
:bad     sec
         rts

:armed   lda   rCTRL,x
         and   #$20
         bne   :bad

         lda   #$0C                 ; both IDs on the bus, assert SEL
         sta   rCTRL,x
         lda   rDATAIN,x
         eor   #$FF
         ora   #IDMASK
         sta   rDATA,x
         lda   #$00
         sta   rXFER,x
         sta   rBUS,x
         lda   #$05
         sta   rCTRL,x

         lda   #$69
         sta   cnt
         ldy   #$00
:wait    lda   rBUS,x
         asl
         bmi   :got
         dey
         bne   :wait
         dec   cnt
         bne   :wait
         sec
         rts

:got     lda   #$04
         sta   rXFER,x
         lda   rSTROBE,x
         lda   #$00
         sta   rCTRL,x
         clc
         rts

*---------- The phase loop: one byte per pass
*
* Runs until the target drops BSY, which it does after message in.

phaseLOOP ldx  idx
         lda   #$00                 ; clear ACK and the drive bit
         sta   rCTRL,x

         lda   rBUS,x               ; BSY gone means we are done
         asl
         bpl   :done

:wreq    lda   rBUS,x
         and   #$20                 ; REQ?
         bne   :req
         lda   rSTAT,x
         and   #$10                 ; card giving up?
         bne   :abort
         lda   rBUS,x
         asl
         bpl   :done                ; BSY dropped while waiting
         jmp   :wreq

:req     lda   rBUS,x               ; latch the phase
         and   #$1C
         lsr
         sta   phase
         lsr
         sta   rPHASE,x
         lda   rSTROBE,x

         lda   phase
         cmp   #phCOMMAND
         beq   :cmd
         cmp   #phDATAIN
         beq   :din
         cmp   #phSTATUS
         beq   :sts
         cmp   #phMSGIN
         beq   :msg

         lda   #$01                 ; anything else is a surprise
         sta   oddPHASE
:done    clc
         rts
:abort   sec
         rts

:cmd     ldy   cdbIDX
         lda   cdb,y
         jsr   sendBYTE
         inc   cdbIDX
         jmp   phaseLOOP

:din     jsr   recvBYTE
         ldy   datIDX
         cpy   #BUFLEN
         bcs   :skip
         sta   buf,y
         inc   datIDX
:skip    jmp   phaseLOOP

:sts     jsr   recvBYTE
         sta   status
         jmp   phaseLOOP

:msg     jsr   recvBYTE
         sta   message
         jmp   phaseLOOP

*---------- Transfer one byte.  X = idx, byte returned in A.
*
* sendBYTE puts A on the bus first; recvBYTE just reads.  Both then do the
* REQ/ACK handshake the ROM does at $CEA8.

sendBYTE sta   rDATA,x
         sec
         bcs   xfer

recvBYTE clc

xfer     lda   rBUS,x               ; wait for REQ
         and   #$20
         bne   :req
         lda   rSTAT,x
         and   #$10
         bne   :out
         jmp   xfer

:req     bcc   :read
         lda   rCTRL,x              ; writing: enable the data drive
         ora   #bDRIVE
         sta   rCTRL,x

:read    lda   rDATA,x
         pha

         lda   rCTRL,x              ; ACK on
         ora   #bACK
         sta   rCTRL,x

:wack    lda   rBUS,x               ; wait for REQ to drop
         and   #$20
         beq   :ackoff
         lda   rSTAT,x
         and   #$10
         beq   :wack

:ackoff  lda   rCTRL,x              ; ACK off
         and   #$FF-bACK
         sta   rCTRL,x
         pla
         rts

:out     lda   #$00
         rts

*---------- Report

report   lda   #<msgSTS
         ldy   #>msgSTS
         jsr   puts
         lda   status
         jsr   PRBYTE
         lda   #<msgMSG
         ldy   #>msgMSG
         jsr   puts
         lda   message
         jsr   PRBYTE
         jsr   CROUT

         lda   #<msgGOT
         ldy   #>msgGOT
         jsr   puts
         lda   datIDX
         jsr   PRBYTE
         jsr   CROUT

         lda   oddPHASE
         beq   :nodd
         lda   #<msgODD
         ldy   #>msgODD
         jsr   puts
         lda   phase
         jsr   PRBYTE
         jsr   CROUT

:nodd    lda   datIDX
         beq   :none

*--- device type, low five bits of byte 0

         lda   #<msgTYPE
         ldy   #>msgTYPE
         jsr   puts
         lda   buf
         and   #$1F
         jsr   PRBYTE
         jsr   CROUT

*--- hex of the first 32 bytes

         lda   #<msgHEX
         ldy   #>msgHEX
         jsr   puts
         ldy   #$00
:hex     cpy   datIDX
         bcs   :hexend
         cpy   #32
         bcs   :hexend
         lda   buf,y
         jsr   PRBYTE
         iny
         tya
         and   #$07
         bne   :hex
         jsr   CROUT
         jmp   :hex
:hexend  jsr   CROUT

*--- vendor at +8 (8 bytes), product at +16 (16 bytes)

         lda   #<msgVEND
         ldy   #>msgVEND
         jsr   puts
         ldy   #$08
         ldx   #$08
         jsr   pstr
         jsr   CROUT

         lda   #<msgPROD
         ldy   #>msgPROD
         jsr   puts
         ldy   #$10
         ldx   #$10
         jsr   pstr
         jsr   CROUT
         rts

:none    lda   #<msgNODATA
         ldy   #>msgNODATA
         jmp   puts

*---------- Print X characters of buf starting at Y

pstr     cpy   datIDX
         bcs   :done
         lda   buf,y
         cmp   #$20
         bcs   :ok
         lda   #$2E                 ; show control bytes as a dot
:ok      ora   #$80
         jsr   COUT
         iny
         dex
         bne   pstr
:done    rts

*---------- Release the bus, then reset it through the ROM

cleanup  ldx   idx
         lda   #$00
         sta   rDATA,x
         lda   #$04
         sta   rCTRL,x
         sta   rXFER,x

         lda   #<msgRESET
         ldy   #>msgRESET
         jsr   puts

         ldy   #$FF
         lda   (ptr),y
         clc
         adc   #$03
         sta   spcall+1
         lda   ptr+1
         sta   spcall+2
spcall   jsr   $0000
         dfb   $05
         da    spparm
         rts
spparm   dfb   $01
         dfb   $00

*---------- Print the string at A/Y

puts     sta   mptr
         sty   mptr+1
         ldy   #$00
:loop    lda   (mptr),y
         beq   :done
         jsr   COUT
         iny
         bne   :loop
:done    rts

*---------- The command

cdb      hex   12000000             ; INQUIRY, LUN 0, page 0
         dfb   BUFLEN               ; allocation length
         hex   00                   ; control

*---------- Variables

BUFLEN   =     36

slot     ds    1
idx      ds    1
cnt      ds    1
phase    ds    1
oddPHASE ds    1
cdbIDX   ds    1
datIDX   ds    1
status   ds    1
message  ds    1
buf      ds    BUFLEN

*---------- Messages

msgTITLE asc   "CIRTECH SCSI INQUIRY, TARGET 3"
         hex   8D00
msgNONE  asc   "NO CIRTECH CARD FOUND"
         hex   8D00
msgNOSEL asc   "SELECTION FAILED"
         hex   8D00
msgSTS   asc   "STATUS: "
         hex   00
msgMSG   asc   "  MESSAGE: "
         hex   00
msgGOT   asc   "BYTES IN: "
         hex   00
msgODD   asc   "UNEXPECTED PHASE: "
         hex   00
msgTYPE  asc   "DEVICE TYPE: "
         hex   00
msgHEX   asc   "DATA:"
         hex   8D00
msgVEND  asc   "VENDOR:  "
         hex   00
msgPROD  asc   "PRODUCT: "
         hex   00
msgNODATA asc  "NO DATA RETURNED"
         hex   8D00
msgRESET asc   "RESETTING SCSI BUS"
         hex   8D00
