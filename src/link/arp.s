         mx    %00                 ; 16-bit A and index: this is
*                                   65816 module code, whatever the
*                                   host program was assembling in

*
* ARP - address resolution for the link layer
*
* Marinetti deals only in IP datagrams, so everything below that is ours.
* Ethernet needs a destination hardware address for every frame, which means
* this module has to speak ARP: answer requests for our own address, and
* resolve the address we are about to send to.
*
* Offsets inside an ARP frame, from the start of the ethernet header:
*
*   14  hardware type      16  protocol type
*   18  hardware length    19  protocol length
*   20  operation          22  sender hardware address
*   28  sender protocol    32  target hardware address
*   38  target protocol
*

ARPLEN   =     42                   ; 14 ethernet + 28 ARP
ARPTRIES =     32                   ; read attempts while resolving

*---------- A frame arrived and it is ARP

arpINPUT php
         rep #$30
         lda frameLEN
         cmp #ARPLEN
         bcc :out

         sep #$20
         lda frameBUF+21            ; operation, low byte of a big-endian word
         cmp #$01
         beq :request
         cmp #$02
         beq :reply
:out     plp
         rts

*--- a reply: remember who answered

:reply   rep #$30
         ldx #frameBUF+28           ; sender protocol address
         ldy #frameBUF+22           ; sender hardware address
         jsr arpSTORE
         plp
         rts

*--- a request: answer it if it is asking about us

:request rep #$30
         ldx #frameBUF+38           ; target protocol address
         ldy #myIP
         jsr ip4EQUAL
         bcs :out2

         jsr arpREPLY
:out2    plp
         rts

*---------- Turn the request in frameBUF into a reply and send it

arpREPLY php
         rep #$30

         ldy #$0000                 ; their hardware address becomes the
:dst     lda frameBUF+22,y          ; destination, and the sender fields
         sta frameBUF,y             ; move across to the target fields
         lda frameBUF+22,y
         sta frameBUF+32,y
         iny
         iny
         cpy #$0006
         bcc :dst

         ldy #$0000
:tpa     lda frameBUF+28,y          ; their address becomes the target
         sta frameBUF+38,y
         iny
         iny
         cpy #$0004
         bcc :tpa

         ldy #$0000
:src     lda myMAC,y                ; we are the source and the sender
         sta frameBUF+6,y
         lda myMAC,y
         sta frameBUF+22,y
         iny
         iny
         cpy #$0006
         bcc :src

         ldy #$0000
:spa     lda myIP,y
         sta frameBUF+28,y
         iny
         iny
         cpy #$0004
         bcc :spa

         sep #$20
         lda #$02                   ; operation: reply
         sta frameBUF+21
         rep #$20

         lda #ARPLEN
         sta frameLEN
         jsr netWRITE
         plp
         rts

*---------- Ask who owns the address at X

arpREQUEST php
         rep #$30
         stx :target+1

         sep #$20                   ; broadcast destination
         ldy #$0000
         lda #$FF
:bcast   sta frameBUF,y
         iny
         cpy #$0006
         bcc :bcast
         rep #$20

         ldy #$0000
:src     lda myMAC,y
         sta frameBUF+6,y
         lda myMAC,y
         sta frameBUF+22,y
         iny
         iny
         cpy #$0006
         bcc :src

         lda #$0608                 ; ethertype $0806, stored big-endian
         sta frameBUF+12
         lda #$0100                 ; hardware type 1
         sta frameBUF+14
         lda #$0008                 ; protocol type $0800
         sta frameBUF+16
         lda #$0406                 ; hardware 6, protocol 4
         sta frameBUF+18
         lda #$0100                 ; operation 1, request
         sta frameBUF+20

         ldy #$0000
:spa     lda myIP,y
         sta frameBUF+28,y
         iny
         iny
         cpy #$0004
         bcc :spa

         ldy #$0000                 ; target hardware address unknown
         lda #$0000
:tha     sta frameBUF+32,y
         iny
         iny
         cpy #$0006
         bcc :tha

:target  ldx #$FFFF                 ; patched above
         ldy #$0000
:tpa     lda |$0000,x
         sta frameBUF+38,y
         inx
         inx
         iny
         iny
         cpy #$0004
         bcc :tpa

         lda #ARPLEN
         sta frameLEN
         jsr netWRITE
         plp
         rts

*---------- Resolve the address at X into dstMAC
*
* Uses the remembered address if there is one, otherwise asks and reads for a
* while.  Carry set if we never found out.

arpRESOLVE php
         rep #$30
         stx :addr+1
         lda |$0000,x               ; the address we are after, for arpSTORE
         sta askIP                  ; and arpLOOKUP to check replies against
         lda |$0002,x
         sta askIP+2

         jsr arpLOOKUP
         bcc :done

:addr    ldx #$FFFF
         jsr arpREQUEST

         lda #ARPTRIES
         sta :count+1

:poll    jsr netREAD
         bcs :again

         lda frameBUF+12            ; did an ARP frame come back?
         cmp #$0608
         bne :again
         jsr arpINPUT

:again   ldx :addr+1
         jsr arpLOOKUP
         bcc :done

:count   lda #$FFFF
         dec
         sta :count+1
         bne :poll

         plp
         sec
         rts

:done    plp
         clc
         rts

*---------- About a sixteenth of a second

arpPAUSE php
         rep   #$30
         ldy   #$8000
:spin    dey
         bne   :spin
         plp
         rts

*---------- One remembered address, not a cache
*
* We only ever need one hardware address - whoever we are sending through -
* so keep exactly that.  (A four entry cache was removed in build 6, blamed
* for writing over this code.  The real culprit turned out to be MODTEST
* passing LinkSendDatagram an address as its length; see doSendDatagram.)

arpSTORE php                        ; X = sender IP, Y = sender hardware addr
         rep   #$30
         stx   :ip+1
         sty   :mac+1

:ip      ldx   #$FFFF               ; only interested in the one we asked for
         ldy   #askIP
         jsr   ip4EQUAL
         bcs   arpSDONE

:mac     ldx   #$FFFF
         ldy   #$0000
:copy    lda   |$0000,x
         sta   dstMAC,y
         inx
         inx
         iny
         iny
         cpy   #$0006
         bcc   :copy

         lda   askIP                ; and whose address dstMAC now holds
         sta   macIP
         lda   askIP+2
         sta   macIP+2

*   macSET+2 is the high byte of that immediate operand.  It is the byte that
*   came back as $00 in two crash dumps, so the module reads it as a canary
*   after every stage of a connect: see :emit in module.s.  It must be $80.

macSET   lda   #$8000
         sta   macKNOWN
arpSDONE plp
         rts

*---------- Have we already got it?  Carry clear if dstMAC is askIP's.
*
* The flag alone is not enough: once the gateway is known, a datagram for a
* host on our own subnet must not go to the gateway's hardware address.

arpLOOKUP php
         rep   #$30
         lda   macKNOWN
         beq   :no
         ldx   #askIP
         ldy   #macIP
         jsr   ip4EQUAL
         bcs   :no
         plp
         clc
         rts
:no      plp
         sec
         rts

*---------- Compare the four byte addresses at X and Y

ip4EQUAL php
         rep   #$30
         phx
         phy
         lda   |$0000,x
         cmp   $0000,y
         bne   :no
         lda   |$0002,x
         cmp   $0002,y
         bne   :no
         ply
         plx
         plp
         clc
         rts
:no      ply
         plx
         plp
         sec
         rts

*---------- Which hardware address should this datagram go to?
*
* On our own subnet we ask for the host itself, otherwise for the gateway.
* The destination address sits 16 bytes into an IP datagram.

routeMAC php
         rep #$30

         ldy #$0010                 ; copy the destination out of the header
         lda [ptr1],y
         sta wantIP
         ldy #$0012
         lda [ptr1],y
         sta wantIP+2

         lda wantIP                 ; same subnet?
         and myMASK
         sta ptr2
         lda myIP
         and myMASK
         cmp ptr2
         bne :viaGATE
         lda wantIP+2
         and myMASK+2
         sta ptr2
         lda myIP+2
         and myMASK+2
         cmp ptr2
         bne :viaGATE

         ldx #wantIP                ; local: ask the host directly
         bra :resolve

:viaGATE ldx #gateIP

*   plp restores the carry along with everything else, so it cannot be the
*   last word on arpRESOLVE's result.  It was: an unresolved address came
*   back as success, and MODTEST's LinkSendDatagram sent to a MAC it never
*   learned after 32 empty reads.

:resolve jsr arpRESOLVE
         bcs :unres
         plp
         clc
         rts
:unres   plp
         sec
         rts

*---------- ARP storage

macKNOWN ds    2                    ; true once dstMAC holds a real address
arpNEXT  ds    2                    ; kept: doStartup clears it
wantIP   ds    4                    ; where the datagram is going
askIP    ds    4                    ; whose hardware address we are asking for:
*                                     wantIP, or the gateway when it is remote
macIP    ds    4                    ; whose hardware address dstMAC holds
dstMAC   ds    6
