*
* CIRTECH SCSI PROBE - milestone 1
*
* Finds the Cirtech SCSI Interface, reports its mode, and optionally
* attempts a raw SCSI selection of one target using the register map in
* docs/hardware.md.  Nothing here calls the card's ROM; the point is to
* prove we can drive the hardware ourselves.
*
* ProDOS 8, assembles with Merlin.  BRUN it.
*
* WARNING: the selection test drives the SCSI bus directly.  It does no disk
* I/O of its own, so running it from a SCSI volume is safe as long as nothing
* else is writing.  Back up the SD card first, and reboot when it finishes.
* On exit it resets the bus through the card's own SmartPort INIT call.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         org   $2000
         typ   $06
         lst   off
         DSK    ProbeCompiled

*---------- Monitor

COUT     =     $FDED
PRBYTE   =     $FDDA
CROUT    =     $FD8E

*---------- Zero page scratch

ptr      =     $06
mptr     =     $08

*---------- Card registers, indexed by X = slot * 16
*           (so $C080,X reaches base+0 for the card's slot)

rDATAOUT =     $C080                ; +0  write, inverted
rCTRL    =     $C081                ; +1  write, bus drive
rXFER    =     $C082                ; +2  write, transfer engine
rPHASE   =     $C083                ; +3  write, expected phase
rBUS     =     $C084                ; +4  read, SCSI bus status
rSTAT    =     $C085                ; +5  read, card status
rLAST    =     $C086                ; +6  read, final byte
rSTROBE  =     $C087                ; +7  read, strobe
rDATAIN  =     $C088                ; +8  read, inverted
rFIFO    =     $C08C                ; +C  block data port

*---------- Configurable

TARGET   =     3                    ; SCSI ID to select
INITID   =     7                    ; the card's own ID
IDMASK   =     $88                  ; (1<<TARGET) + (1<<INITID), edit with them

*---------- Entry

start    jsr   CROUT
         lda   #<msgTITLE
         ldy   #>msgTITLE
         jsr   puts

         jsr   findCARD
         bcc   found

         lda   #<msgNONE
         ldy   #>msgNONE
         jsr   puts
         rts

found    lda   #<msgSLOT
         ldy   #>msgSLOT
         jsr   puts
         lda   slot
         ora   #"0"
         jsr   COUT
         jsr   CROUT

*--- FAST or SAFE, from $Cs07

         ldy   #$07
         lda   (ptr),y
         bne   :safe
         lda   #<msgFAST
         ldy   #>msgFAST
         jmp   :show
:safe    lda   #<msgSAFE
         ldy   #>msgSAFE
:show    jsr   puts

*--- slot * 16, the index every register access uses

         lda   slot
         asl
         asl
         asl
         asl
         sta   idx

*--- current bus state, before we touch anything

         lda   #<msgBUS
         ldy   #>msgBUS
         jsr   puts
         ldx   idx
         lda   rBUS,x
         jsr   PRBYTE
         lda   #" "
         jsr   COUT
         ldx   idx
         lda   rSTAT,x
         jsr   PRBYTE
         jsr   CROUT

         jmp   select

*---------- Find the card
*
* Returns carry clear and slot/ptr set up when the ID bytes match.

findCARD ldx   #7
:loop    stx   slot
         txa
         ora   #$C0
         sta   ptr+1
         lda   #$00
         sta   ptr

         ldy   #$01                 ; ID byte 1 = $20
         lda   (ptr),y
         cmp   #$20
         bne   :next
         ldy   #$03                 ; ID byte 2 = $00
         lda   (ptr),y
         bne   :next
         ldy   #$05                 ; ID byte 3 = $03
         lda   (ptr),y
         cmp   #$03
         bne   :next
         ldy   #$FB                 ; ID byte 4 = $02
         lda   (ptr),y
         cmp   #$02
         bne   :next

         clc                        ; found it
         rts

:next    ldx   slot
         dex
         bne   :loop
         sec
         rts

*---------- Raw selection of TARGET
*
* Follows the ROM: quiesce ($CB96), arm and wait on +1 ($CBCF),
* then assert SEL and wait for target BSY on +4 ($CC09).

select   lda   #<msgSEL
         ldy   #>msgSEL
         jsr   puts

         ldx   idx

*--- quiesce: drop everything we might be driving, then the bus must read idle
*    ($CB96: the ROM zeroes +1..+4, strobes +7, and expects +4 = $00)

         lda   #$00
         sta   rCTRL,x
         sta   rXFER,x
         sta   rPHASE,x
         sta   rBUS,x
         lda   rSTROBE,x
         lda   rBUS,x
         beq   :quiet

         pha                        ; show what the bus is holding
         lda   #<msgNOTQ
         ldy   #>msgNOTQ
         jsr   puts
         pla
         jsr   PRBYTE
         jsr   CROUT
         jmp   release

*--- arm: drive the complement of the data lines, start the engine

:quiet   lda   rDATAIN,x
         eor   #$FF
         sta   rDATAOUT,x
         lda   #$01
         sta   rXFER,x

*--- wait for the card to be ready: +1 read back, bit 6 set
*    (+1 is write control, read status - $CBDC)

         ldy   #$00
:arm     lda   rCTRL,x
         asl                        ; N = bit 6 = ready
         bmi   :armed
         lda   rSTAT,x              ; +5 bit 4 aborts the wait
         and   #$10
         bne   :armerr
         dey
         bne   :arm

:armerr  lda   #<msgARM
         ldy   #>msgARM
         jsr   puts
         ldx   idx
         lda   rCTRL,x
         jsr   PRBYTE
         lda   #" "
         jsr   COUT
         ldx   idx
         lda   rSTAT,x
         jsr   PRBYTE
         jsr   CROUT
         jmp   release

*--- bit 5 of +1 means the card is unhappy ($CBEC)

:armed   lda   rCTRL,x
         and   #$20
         beq   :isfree
         lda   #<msgBUSY
         ldy   #>msgBUSY
         jmp   fail

*--- put both IDs on the bus and assert SEL

:isfree  lda   #$0C
         sta   rCTRL,x
         lda   rDATAIN,x
         eor   #$FF
         ora   #IDMASK
         sta   rDATAOUT,x
         lda   #$00
         sta   rXFER,x
         sta   rBUS,x
         lda   #$05
         sta   rCTRL,x

*--- wait for the target to assert BSY

         lda   #$69
         sta   cnt
         ldy   #$00
:wait    lda   rBUS,x
         asl
         bmi   :gotit
         dey
         bne   :wait
         dec   cnt
         bne   :wait

         lda   #<msgNORSP
         ldy   #>msgNORSP
         jmp   fail

*--- selected: finish the handshake and report the phase

:gotit   lda   #$04
         sta   rXFER,x
         lda   rSTROBE,x
         lda   #$00
         sta   rCTRL,x

         lda   #<msgOK
         ldy   #>msgOK
         jsr   puts

         lda   #<msgBUS
         ldy   #>msgBUS
         jsr   puts
         ldx   idx
         lda   rBUS,x
         jsr   PRBYTE
         lda   #" "
         jsr   COUT
         ldx   idx
         lda   rSTAT,x
         jsr   PRBYTE
         jsr   CROUT

*--- always let the bus go

release  ldx   idx
         lda   #$00
         sta   rDATAOUT,x
         lda   #$04
         sta   rCTRL,x
         sta   rXFER,x

*---------- Reset the SCSI bus through the card's own firmware
*
* SmartPort INIT ($05) with unit $00: "Resets all devices on the SCSI bus"
* (manual, ch. 6).  This is the documented way back to a sane bus if our
* selection left a target holding BSY.  Entry point is $Cs00 + $CsFF + 3.

busRESET lda   #<msgRESET
         ldy   #>msgRESET
         jsr   puts

         ldy   #$FF
         lda   (ptr),y               ; $CsFF = $12
         clc
         adc   #$03                  ; SmartPort entry = $Cs15
         sta   spcall+1
         lda   ptr+1
         sta   spcall+2

spcall   jsr   $0000                 ; patched above
         dfb   $05                   ; INIT
         da    spparm
         rts

spparm   dfb   $01                   ; parameter count
         dfb   $00                   ; unit 0 = the interface itself

fail     jsr   puts
         jmp   release

*---------- Print the string at A/Y, terminated by $00

puts     sta   mptr
         sty   mptr+1
         ldy   #$00
:loop    lda   (mptr),y
         beq   :done
         jsr   COUT
         iny
         bne   :loop
:done    rts

*---------- Variables

slot     ds    1
idx      ds    1
cnt      ds    1

*---------- Messages (high ASCII for COUT)

msgTITLE asc   "CIRTECH SCSI PROBE"
         hex   8D00
msgNONE  asc   "NO CIRTECH CARD FOUND"
         hex   8D00
msgSLOT  asc   "CARD IN SLOT "
         hex   00
msgFAST  asc   "MODE: FAST"
         hex   8D00
msgSAFE  asc   "MODE: SAFE"
         hex   8D00
msgBUS   asc   "BUS/STAT: "
         hex   00
msgSEL   asc   "SELECTING TARGET..."
         hex   8D00
msgBUSY  asc   "CARD REPORTS BUS ERROR"
         hex   8D00
msgNORSP asc   "NO RESPONSE FROM TARGET"
         hex   8D00
msgOK    asc   "TARGET RESPONDED"
         hex   8D00
msgRESET asc   "RESETTING SCSI BUS"
         hex   8D00
msgNOTQ  asc   "BUS NOT IDLE: "
         hex   00
msgARM   asc   "ARM TIMEOUT, +1/+5: "
         hex   00
