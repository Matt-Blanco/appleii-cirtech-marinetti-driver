*
* CIRTECH SCSI WIFI INFO - milestone 3b
*
* Sends RECEIVE DIAGNOSTIC RESULTS ($1C) with sub-command WIFI_CMD_INFO ($04)
* and dumps whatever the DaynaPORT returns.
*
* $1C is a group 0 opcode, so the CDB is six bytes.  From scsiWIFI in
* ../../scsi2/bluescsi.s: byte 1 is the sub-command, bytes 3/4 are the
* allocation length, MSB first.
*
* This is read-only.  It does not scan and does not join, so it cannot disturb
* a Wi-Fi link the firmware already brought up from bluescsi.ini.
*
* The response layout is not documented in the repo - bluescsi.s only ever uses
* sub-commands $01, $02, $03 and $05 - so this prints raw hex and ASCII.
*
* ProDOS 8, Merlin, BRUN it.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         org   $2000
         typ   $06
         lst   off
         DSK   WifiCompiled

COUT     =     $FDED
PRBYTE   =     $FDDA
CROUT    =     $FD8E

ptr      =     $06
mptr     =     $08

TARGETID =     3
IDMASK   =     $88
BUFLEN   =     128

SCSI_RECEIVE_DIAG = $1C
WIFI_CMD_INFO =  $04

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

:ok      jsr   runSCSI
         bcc   :ran
         lda   #<msgNOSEL
         ldy   #>msgNOSEL
         jsr   puts
         jmp   cleanup

:ran     jsr   report
         jsr   cleanup
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
         beq   :chk
         lda   #<msgODD
         ldy   #>msgODD
         jsr   puts
         lda   phase
         jsr   PRBYTE
         jsr   CROUT

:chk     lda   status
         beq   :any
         lda   #<msgCHECK
         ldy   #>msgCHECK
         jsr   puts

:any     lda   datIDX
         bne   :hex
         lda   #<msgNODATA
         ldy   #>msgNODATA
         jmp   puts

*--- hex, eight bytes to a line

:hex     lda   #<msgHEX
         ldy   #>msgHEX
         jsr   puts
         ldy   #$00
:hloop   cpy   datIDX
         bcs   :hdone
         lda   buf,y
         jsr   prhex
         iny
         tya
         and   #$07
         bne   :hloop
         jsr   CROUT
         jmp   :hloop
:hdone   jsr   CROUT

*--- the same bytes as text

         lda   #<msgTXT
         ldy   #>msgTXT
         jsr   puts
         ldy   #$00
:tloop   cpy   datIDX
         bcs   :tdone
         lda   buf,y
         cmp   #$20
         bcc   :dot
         cmp   #$7F
         bcc   :chr
:dot     lda   #$2E
:chr     ora   #$80
         jsr   COUT
         iny
         tya
         and   #$1F
         bne   :tloop
         jsr   CROUT
         jmp   :tloop
:tdone   jmp   CROUT

*---------- The command: $1C, sub-command, page, length MSB/LSB, control

cdb      dfb   SCSI_RECEIVE_DIAG
         dfb   WIFI_CMD_INFO
         hex   00
         dfb   >BUFLEN
         dfb   <BUFLEN
         hex   00
cdbLEN   dfb   6

*---------- No data-out phase for this command

outBUF   ds    1
outLEN   da    0

buf      ds    BUFLEN

*---------- Messages

msgTITLE asc   "WIFI INFO $1C/$04, TARGET 3"
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
msgCHECK asc   "NONZERO STATUS: COMMAND REFUSED?"
         hex   8D00
msgHEX   asc   "HEX:"
         hex   8D00
msgTXT   asc   "TEXT:"
         hex   8D00
msgNODATA asc  "NO DATA RETURNED"
         hex   8D00

         PUT   02 scsicore
