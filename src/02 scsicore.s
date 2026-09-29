*
* CIRTECH SCSI CORE
*
* Shared routines for driving the Cirtech card directly.  PUT this into a
* program, fill in cdb/cdbLEN (and outBUF/outLEN for a data-out command),
* then JSR runSCSI.  Results land in buf/datIDX, status and message.
*
* Confirmed working on hardware 2026-09-22: selection, command out, data in,
* status and message in, verified with INQUIRY against a BlueSCSI DaynaPORT.
*
* Register map and sequences: ../docs/hardware.md
*

*---------- Card registers, X = slot * 16

rDATA    =     $C080                ; +0  data in and out
rCTRL    =     $C081                ; +1  write control, read status
rXFER    =     $C082                ; +2  transfer engine
rPHASE   =     $C083                ; +3  expected phase
rBUS     =     $C084                ; +4  BSY $40, REQ $20, phase $1C
rSTAT    =     $C085                ; +5  card status
rSTROBE  =     $C087                ; +7  strobe
rDATAIN  =     $C088                ; +8  inverted readback

bDRIVE   =     $01                  ; +1 bit 0: drive the data bus
bACK     =     $10                  ; +1 bit 4: assert ACK

*---------- Phases, as (bus & $1C) >> 1

phDATAOUT =    $00
phDATAIN =     $02
phCOMMAND =    $04
phSTATUS =     $06
phMSGOUT =     $0C
phMSGIN  =     $0E

*---------- Run one SCSI command.  Carry set if it never got started.

runSCSI  lda   #$00
         sta   cdbIDX
         sta   datIDX
         sta   outIDX
         sta   outIDX+1
         sta   oddPHASE
         sta   totalIN
         sta   totalIN+1
         lda   #<outBUF               ; data-out reads through a patched
         sta   ofetch+1               ; absolute address, so a transfer can
         lda   #>outBUF               ; be longer than 256 bytes
         sta   ofetch+2

         lda   #$FF
         sta   status
         sta   message

         jsr   selectIT
         bcs   :out
         jsr   phaseLOOP
:out     rts

*---------- Find the card.  Carry clear when found; slot and ptr are set.

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

         lda   slot                 ; X index every register access uses
         asl
         asl
         asl
         asl
         sta   idx
         clc
         rts

:next    ldx   slot
         dex
         bne   :loop
         sec
         rts

*---------- Select TARGETID.  Carry clear on success.

selectIT ldx   idx

         lda   #$00                 ; quiesce ($CB96)
         sta   rCTRL,x
         sta   rXFER,x
         sta   rPHASE,x
         sta   rBUS,x
         lda   rSTROBE,x
         lda   rBUS,x
         beq   :quiet
         sec
         rts

:quiet   lda   rDATAIN,x            ; arm ($CBCF)
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

*---------- One byte per pass, until the target drops BSY

phaseLOOP ldx  idx
         lda   #$00                 ; clear ACK and the drive bit
         sta   rCTRL,x

         lda   rBUS,x
         asl
         bpl   :done                ; BSY gone: finished

:wreq    lda   rBUS,x
         and   #$20
         bne   :req
         lda   rSTAT,x
         and   #$10
         bne   :abort
         lda   rBUS,x
         asl
         bpl   :done
         jmp   :wreq

:req     lda   rBUS,x
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
         cmp   #phDATAOUT
         beq   :dout
         cmp   #phSTATUS                ; these three sit past branch range
         bne   :notsts                 ; now that the data loops are inline
         jmp   :sts
:notsts  cmp   #phMSGIN
         bne   :notmsg
         jmp   :msg
:notmsg  cmp   #phMSGOUT
         bne   :notmout
         jmp   :mout
:notmout =     *

         lda   #$01
         sta   oddPHASE
:done    clc
         rts
:abort   sec
         rts

:cmd     ldy   cdbIDX
         cpy   cdbLEN
         bcs   :pad
         lda   cdb,y
         jmp   :send
:pad     lda   #$00
:send    jsr   sendBYTE
         inc   cdbIDX
         jmp   phaseLOOP

:din     jsr   recvBYTE
         inc   totalIN                ; 16-bit count of everything received
         bne   :nocarry
         inc   totalIN+1
:nocarry ldy   datIDX
         cpy   #BUFLEN
         bcs   :skip
         sta   buf,y
         inc   datIDX

*   Staying in the phase while REQ keeps coming saves six register reads per
*   byte.  The firmware times out if we dawdle; its log shows that as
*   scsi_accel_rp2040_finishRead timeout.

:skip    lda   rBUS,x
         and   #$20                   ; REQ still up?
         beq   :slow
         lda   rBUS,x
         and   #$1C
         lsr
         cmp   #phDATAIN
         beq   :din
:slow    jmp   phaseLOOP

:dout    lda   outIDX+1               ; 16-bit: sent < outLEN ?
         cmp   outLEN+1
         bcc   :ofetch
         bne   :opad
         lda   outIDX
         cmp   outLEN
         bcc   :ofetch

:opad    lda   #$00                   ; past the end: pad with zeroes
         jmp   :osend

:ofetch  =     *
ofetch   lda   $FFFF                  ; patched by runSCSI, walked below
         inc   ofetch+1
         bne   :osend
         inc   ofetch+2

:osend   jsr   sendBYTE
         inc   outIDX
         bne   :onc
         inc   outIDX+1
:onc     =     *
         lda   rBUS,x
         and   #$20
         beq   :oslow
         lda   rBUS,x
         and   #$1C
         lsr
         cmp   #phDATAOUT
         beq   :dout
:oslow   jmp   phaseLOOP

:sts     jsr   recvBYTE
         sta   status
         jmp   phaseLOOP

:msg     jsr   recvBYTE
         sta   message
         jmp   phaseLOOP

:mout    lda   #$07                 ; message reject, as the ROM does
         jsr   sendBYTE
         jmp   phaseLOOP

*---------- Transfer one byte.  X = idx, byte returned in A.

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

*---------- Release the bus, then reset it through the card's firmware

cleanup  ldx   idx
         lda   #$00
         sta   rDATA,x
         lda   #$04
         sta   rCTRL,x
         sta   rXFER,x

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

*---------- Print the null-terminated string at A/Y

puts     sta   mptr
         sty   mptr+1
         ldy   #$00
:loop    lda   (mptr),y
         beq   :done
         jsr   COUT
         iny
         bne   :loop
:done    rts

*---------- Print A as two hex digits and a space

prhex    jsr   PRBYTE
         lda   #" "
         jmp   COUT

*---------- Core variables

slot     ds    1
idx      ds    1
cnt      ds    1
phase    ds    1
oddPHASE ds    1
cdbIDX   ds    1
datIDX   ds    1
outIDX   ds    2
status   ds    1
message  ds    1
totalIN  ds    2                      ; bytes received, including any past BUFLEN
