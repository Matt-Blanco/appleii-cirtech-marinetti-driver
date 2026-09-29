*
* CIRTECH SCSI TOOLBOX - milestone 3a
*
* Sends BLUESCSI_TOOLBOX_METADATA ($D9) sub-command GET_CAPABILITIES ($01)
* to the DaynaPORT and prints the API version and capability flags.
*
* This is step 4 of the Marinetti recipe in ../../scsi2/README.md, and the
* CDB layout comes from scsiTOOLBOXD9 in ../../scsi2/bluescsi.s: a 10-byte
* command, sub-command in byte 1, allocation length in byte 8.
*
* ProDOS 8, Merlin, BRUN it.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         org   $2000
         typ   $06
         lst   off
         DSK   ToolboxCompiled

COUT     =     $FDED
PRBYTE   =     $FDDA
CROUT    =     $FD8E

ptr      =     $06
mptr     =     $08

TARGETID =     3
IDMASK   =     $88                  ; ID 3 + ID 7
BUFLEN   =     32

*---------- Toolbox constants, from ../../scsi2/bluescsi.s

TB_METADATA =  $D9
TB_GET_CAPABILITIES = $01
NB_BYTES =     8                    ; allocation length for this sub-command

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
         beq   :ok
         lda   #<msgODD
         ldy   #>msgODD
         jsr   puts
         lda   phase
         jsr   PRBYTE
         jsr   CROUT

:ok      lda   status
         bne   :bad
         lda   datIDX
         beq   :bad

*--- byte 0: API version

         lda   #<msgAPI
         ldy   #>msgAPI
         jsr   puts
         lda   buf
         jsr   PRBYTE
         jsr   CROUT

*--- byte 1: capability flags

         lda   #<msgCAP
         ldy   #>msgCAP
         jsr   puts
         lda   buf+1
         jsr   PRBYTE
         jsr   CROUT

         lda   #<msgLARGE
         ldy   #>msgLARGE
         jsr   puts
         lda   buf+1
         and   #$01
         jsr   yesno

         lda   #<msgSEND
         ldy   #>msgSEND
         jsr   puts
         lda   buf+1
         and   #$02
         jsr   yesno

         lda   #<msgWDIR
         ldy   #>msgWDIR
         jsr   puts
         lda   buf+1
         and   #$04
         jsr   yesno

*--- everything we got, in hex

         lda   #<msgHEX
         ldy   #>msgHEX
         jsr   puts
         ldy   #$00
:hex     cpy   datIDX
         bcs   :hexend
         lda   buf,y
         jsr   prhex
         iny
         bne   :hex
:hexend  jmp   CROUT

:bad     lda   #<msgNODATA
         ldy   #>msgNODATA
         jmp   puts

*---------- Print YES or NO for a zero/non-zero A

yesno    bne   :yes
         lda   #<msgNO
         ldy   #>msgNO
         jmp   puts
:yes     lda   #<msgYES
         ldy   #>msgYES
         jmp   puts

*---------- The command
*
* $D9, sub-command, six zeroes, allocation length, control

cdb      dfb   TB_METADATA
         dfb   TB_GET_CAPABILITIES
         hex   000000000000
         dfb   NB_BYTES
         hex   00
cdbLEN   dfb   10

*---------- No data-out phase for this command

outBUF   ds    1
outLEN   da    0

buf      ds    BUFLEN

*---------- Messages

msgTITLE asc   "BLUESCSI TOOLBOX $D9/$01, TARGET 3"
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
msgAPI   asc   "API VERSION: "
         hex   00
msgCAP   asc   "CAPABILITIES: "
         hex   00
msgLARGE asc   "  LARGE TRANSFERS: "
         hex   00
msgSEND  asc   "  LARGE SEND:      "
         hex   00
msgWDIR  asc   "  SET WORKING DIR: "
         hex   00
msgYES   asc   "YES"
         hex   8D00
msgNO    asc   "NO"
         hex   8D00
msgHEX   asc   "DATA: "
         hex   00
msgNODATA asc  "NO USABLE DATA RETURNED"
         hex   8D00

         PUT   02 scsicore
