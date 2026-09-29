         mx    %00                 ; 16-bit A and index: this is
*                                   65816 module code, whatever the
*                                   host program was assembling in


*---------- Toolbox

TOOLBOX  =     $E10000
NewHandle =    $0902

*---------- Our slice of Marinetti's direct page
*
* The guide reserves $E0-$FF on Marinetti's direct page for the module, and
* promises they survive between calls.  The 65816 can only use [dp],y with a
* pointer in the direct page, so every pointer we dereference lives here.

ptr1     =     $E0                  ; general pointer, and handle scratch
ptr2     =     $E4                  ; second pointer, cache entries
inPTR    =     $E8                  ; where a data-in transfer lands
outPTR   =     $EC                  ; where a data-out transfer comes from

*---------- Marinetti error codes, already masked with terrmask

*   Real Marinetti codes, low byte only: the guide says a module returns a
*   terr_* value ANDed with terrmask, and the codes themselves are $36xx.
*   Invented numbers land on unrelated meanings - $0008 reads as
*   terrINITNOTFOUND, "the Marinetti init is not loaded", which is not
*   something to tell Marinetti from inside one of its own calls.

*   The trace beacon does a SCSI transaction inside every call.  That has
*   never been controlled for: it runs while Marinetti is loading the module.
*   TRACEON 0 builds a silent module so the instrument can be ruled in or out.

TRACEON  =     1

terrOK   =     $0000                ; terrOK
terrLINKERROR = $0004               ; $3604 problem with the link layer
terrNORECON = $0014                 ; $3614 module does not support reconnect
terrBADPARM = $0017                 ; $3617 invalid parameter for this call
terrNOIFACE = $001B                 ; $361B no interface - no card found

*---------- Cirtech registers, reached in bank $E0 where slot timing is right
*           X carries slot * 16, as in the ProDOS 8 programs

IOBASE   =     $E0C080
rDATA    =     IOBASE+0
rCTRL    =     IOBASE+1
rXFER    =     IOBASE+2
rPHASE   =     IOBASE+3
rBUS     =     IOBASE+4
rSTAT    =     IOBASE+5
rSTROBE  =     IOBASE+7
rDATAIN  =     IOBASE+8

bDRIVE   =     $01
bACK     =     $10

phDATAOUT =    $00
phDATAIN =     $02
phCOMMAND =    $04
phSTATUS =     $06
phMSGOUT =     $0C
phMSGIN  =     $0E

TARGETID =     3
IDMASK   =     $88

MTU      =     1500
FRAMEMAX =     1514
ETHHDR   =     14
ETHMIN   =     60                   ; shortest frame on the wire, CRC excluded
DPHDR    =     6

*---------- Drop N bytes of parameters.  Destroys A and the carry, so it
*           runs before the handler sets its result.

DROP     MAC
         tsc
         clc
         adc   #]1
         tcs
         <<<

*===========================================================================
* Entry
*===========================================================================
*
* Stash what we were handed, take the return address off the stack so the
* parameters sit at 1,s, then dispatch.

entry    phb
         phk
         plb                        ; our bank: our variables are absolute

         stx theCALL
         sty theUSER
         sta theDP

         sep   #$20                 ; our bank, for building long pointers
         phk
         pla
         sta   myBank
         stz   myBank+1
         rep   #$20

*   phb left the caller's data bank byte on the stack, above the return
*   address.  Take that off first, or every parameter offset below is out by
*   one and the return address we stash is garbage.

         sep #$20
         pla                        ; the caller's data bank
         sta dbkSAVE
         rep #$20

         pla                        ; return address, low word
         sta rtlADDR
         sep #$20
         pla                        ; and its bank
         sta rtlADDR+2
         rep #$20

*   Trace every call except LinkInterfaceV.  With a beacon in that call the
*   module never finished loading; without it, LinkStartup runs.  Touching
*   the bus that early is evidently not safe, so the load path stays silent.

         do    TRACEON
         lda   theCALL
         beq   :notrace
         sep   #$20
         lda   theCALL
         jsr   traceBYTE
         rep   #$20
:notrace =     *
         fin

         lda theCALL
         cmp #lastCALL
         bcc :ok
         lda #terrBADPARM
         sec
         bra exitLINK

:ok      tax
         jmp   (dispatch,x)         ; a JSR here would put its own return
                                    ; address on top of the parameters

*--- Every handler lands here.  Put the return address back, keeping the
*    error code in A and the carry the handler set.

exitLINK sta errSAVE

         do    TRACEON              ; which call returned: marker = $80 + call
         lda   theCALL
         beq   :noexit
         php
         sep   #$20
         lda   theCALL
         ora   #$80
         jsr   traceBYTE

         lda   errSAVE              ; and what it returned: marker = $40 + err
         and   #$3F
         ora   #$40
         jsr   traceBYTE
         rep   #$20
         plp
:noexit  =     *
         fin

*   Capture the flags BEFORE narrowing the accumulator, or the width we hand
*   back is the one used to save them, not the one the caller gave us.  The
*   caller then pulls half a word and the stack walks.

         php                        ; carry and widths as the handler left them
         sep   #$20
         pla
         sta   pSAVE

         lda rtlADDR+2
         pha                        ; bank of the return address
         rep #$20
         lda rtlADDR
         pha                        ; then its low word

*   One last marker, with the return address already rebuilt on the stack:
*   $20 + call means "about to RTL".  It has to go BEFORE the data bank is
*   handed back, or traceBYTE's absolute accesses land in Marinetti's bank -
*   which is both useless as a signal and a write into memory we do not own.

         do    TRACEON
         sep   #$20
         lda   theCALL
         beq   :nortl
         lda   theCALL
         ora   #$20
         jsr   traceBYTE
:nortl   =     *
         fin

*   Read everything we need BEFORE the caller's data bank goes back.  After
*   plb, an absolute load reads the caller's bank at our offset.  In MODTEST
*   both banks are 0, so that went unseen; under Marinetti it handed back a
*   garbage result and garbage flags from every call.  LinkConnect is the one
*   Marinetti judges by A (STA 5,S / PLA), so it dumped the link layer and
*   TCPIPConnect returned the garbage ORed with $3600: $B648.

         rep   #$30
         ldy   errSAVE              ; the result rides across plb in Y
         sep   #$20
         lda   pSAVE                ; the handler's flags, pulled last
         pha
         lda   dbkSAVE              ; the caller's data bank
         pha
         plb                        ; no absolute loads of ours past here
         rep   #$20
         tya                        ; A = result
         plp                        ; flags and widths as the handler left them
         rtl

dispatch da    doInterfaceV         ; $0000
         da    doStartup            ; $0002
         da    doShutDown           ; $0004
         da    doModuleInfo         ; $0006
         da    doGetDatagram        ; $0008
         da    doSendDatagram       ; $000A
         da    doConnect            ; $000C
         da    doReconStatus        ; $000E
         da    doReconnect          ; $0010
         da    doDisconnect         ; $0012
         da    doGetVariables       ; $0014
         da    doConfigure          ; $0016
         da    doCfgFile     ; $0018
lastCALL =     $001A

*===========================================================================
* The twelve calls
*===========================================================================

*---------- $0000 LinkInterfaceV - a word of space at 1,s
*
* Every handler is jumped to, so 1,s is the first parameter.  Result space is
* left in place for the caller; real parameters are dropped before exit.

         mx    %00                 ; entered 16-bit, whatever precedes
*   Version 2.  The Technical Update says a module returns $0002 to say it
*   supports the version 2 calls, and LinkConfigFileName ($0018) is the only
*   one of those - which we now implement.  Every module Marinetti ships is
*   built with LKV $02, and the run where we claimed version 1 got no further
*   than LinkInterfaceV.

*   Back to version 2, now that the log can prove what we return.
*
*   LOADLINKLAYER accepts LLMININTVERSION..LLMAXINTVERSION.  Run 06 showed us
*   returning 1 cleanly (marker $61, error $40) and still being rejected with
*   no LinkStartup, which means this Marinetti's minimum is 2 - consistent
*   with every module it ships being built LKV $02.  The one version 2 call,
*   LinkConfigFileName, is implemented.

*   Version 1.  The module was listed in the control panel when it returned
*   1, and disappeared from TCPIPGetModuleNames when it returned 2 - so this
*   Marinetti's LLMAXINTVERSION is 1.  The runs that seemed to reject version
*   1 were confounded by a trace beacon inside this very call, which stopped
*   the module loading at all.

doInterfaceV lda #$0001
         sta   1,s

*   No beacon in this call: a SCSI transaction here stops the module loading.

         lda   #terrOK
         clc
         jmp   exitLINK

*---------- $0002 LinkStartup
*
* Find the card and wake the DaynaPORT.  No connection yet.

         mx    %00                 ; entered 16-bit, whatever precedes
doStartup lda  #$0001
         sta   lvVersion
         lda   #MTU
         sta   lvMTU
         stz   lvConnected
         stz   lvErrors
         stz   lvErrors+2
         stz   arpNEXT

         jsr   findCARD
         bcc   :found
         lda   #terrNOIFACE
         sec
         jmp   exitLINK

:found   jsr   netENABLE
         jsr   netSTATS             ; learns myMAC
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- $0004 LinkShutDown - Marinetti purges us regardless

         mx    %00                 ; entered 16-bit, whatever precedes
doShutDown jsr netDISABLE
         stz   lvConnected
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- $0006 LinkModuleInfo - a long pointer at 1,s

         mx    %00                 ; entered 16-bit, whatever precedes
doModuleInfo lda 1,s
         sta   ptr1
         lda   3,s
         sta   ptr1+2

         sep   #$20
         ldy   #$0000
:copy    lda   infoBLK,y
         sta   [ptr1],y
         iny
         cpy   #infoLEN
         bcc   :copy
         rep   #$20

         DROP  4
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- $0008 LinkGetDatagram - a long of space at 1,s
*
* Poll the DaynaPORT.  ARP is handled here and never reaches Marinetti; only
* IP goes up, in a handle belonging to Marinetti.

         mx    %00                 ; entered 16-bit, whatever precedes
doGetDatagram jsr netREAD
         bcs   :none
         lda   frameLEN
         beq   :none

         lda   frameBUF+12          ; ethertype, stored big-endian
         cmp   #$0608               ; $0806, ARP
         bne   :isIP
         jsr   arpINPUT
         bra   :none

:isIP    cmp   #$0008               ; $0800, IPv4
         bne   :none

         lda   frameLEN
         sec
         sbc   #ETHHDR
         beq   :none
         bcc   :none
         sta   dgramLEN

         jsr   newDGRAM             ; handle comes back in hResult
         bcs   :none

         lda   hResult              ; dereference it
         sta   ptr1
         lda   hResult+2
         sta   ptr1+2
         lda   [ptr1]
         sta   ptr2
         ldy   #$0002
         lda   [ptr1],y
         sta   ptr2+2

         sep   #$20
         ldy   #$0000
:cp      lda   frameBUF+ETHHDR,y
         sta   [ptr2],y
         iny
         cpy   dgramLEN
         bcc   :cp
         rep   #$20

         lda   hResult
         sta   1,s
         lda   hResult+2
         sta   3,s
         lda   #terrOK
         clc
         jmp   exitLINK

:none    lda   #$0000               ; nil: nothing waiting
         sta   1,s
         sta   3,s
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- $000A LinkSendDatagram
*
* Length at 1,s, then a long pointer to the datagram at 3,s.

         mx    %00                 ; entered 16-bit, whatever precedes
doSendDatagram lda 1,s
         sta   dgramLEN
         lda   3,s
         sta   ptr1
         lda   5,s
         sta   ptr1+2

*   Marinetti never sends more than lvMTU, but nothing else stands between a
*   bad length and the code that follows frameBUF.  MODTEST once passed an
*   address here: the copy below ran 9K, over the ARP routines and onward.

         lda   dgramLEN
         beq   :bad
         cmp   #MTU+1
         bcs   :bad

         jsr   routeMAC             ; fills dstMAC, carry set if unresolved
         bcs   :fail

         sep   #$20
         ldy   #$0000
:dst     lda   dstMAC,y
         sta   frameBUF,y
         lda   myMAC,y
         sta   frameBUF+6,y
         iny
         cpy   #$0006
         bcc   :dst
         rep   #$20

         lda   #$0008               ; ethertype $0800
         sta   frameBUF+12

         sep   #$20
         ldy   #$0000
:body    lda   [ptr1],y
         sta   frameBUF+ETHHDR,y
         iny
         cpy   dgramLEN
         bcc   :body
         rep   #$20

         lda   dgramLEN
         clc
         adc   #ETHHDR
         sta   frameLEN
         jsr   netWRITE

         DROP  6
         lda   #terrOK
         clc
         jmp   exitLINK

:fail    inc   lvErrors
         DROP  6
         lda   #terrLINKERROR
         sec
         jmp   exitLINK

:bad     inc   lvErrors
         DROP  6
         lda   #terrBADPARM
         sec
         jmp   exitLINK

*---------- $000C LinkConnect
*
* conHandle at 1,s; 22 bytes of parameters in total.  The radio has already
* joined the network from bluescsi.ini, so there is nothing to dial.

         mx    %00                 ; entered 16-bit, whatever precedes
*   Stage markers, so a crash inside this call says where.  $70 on entry,
*   then one after each step; the last one in the log is the step that died.

doConnect jsr  :mark70
         lda   1,s
         sta   ptr1
         lda   3,s
         sta   ptr1+2
         jsr   readCONFIG
         bcs   :fail
         jsr   :mark71

         jsr   netENABLE
         jsr   :mark72

*   Resolve the gateway now if we can, but do not fail the connection over
*   it.  routeMAC resolves again on the first datagram, and reporting a dead
*   link because one ARP went unanswered is worse than connecting optimistically.

         ldx   #gateIP
         jsr   arpRESOLVE
         jsr   :mark73

*   Network order, exactly as myIP holds it.  Marinetti copies these four
*   bytes into MYIPADDRESS unchanged and compares them word for word with the
*   destination of every incoming datagram (I.IP.S: LDY #ip_dst / CMP
*   MYIPADDRESS, with loopback tested as CMP #$007F).  A byte-swapped copy
*   was once added here to "fix" $B648 - really the exitLINK bank bug - and
*   made Marinetti believe it was 99.2.168.192, so it dropped every ping.

         lda   myIP
         sta   lvIPaddress
         lda   myIP+2
         sta   lvIPaddress+2
         lda   #$8000
         sta   lvConnected
         jsr   :mark74

         DROP  22
         lda   #terrOK
         clc
         jmp   exitLINK

:fail    stz   lvConnected
         DROP  22
         lda   #terrLINKERROR
         sec
         jmp   exitLINK

:mark70  lda   #$70
         bra   :emit
:mark71  lda   #$71
         bra   :emit
:mark72  lda   #$72
         bra   :emit
:mark73  lda   #$73
         bra   :emit
:mark74  lda   #$74
*   Every stage marker is followed by the canary: the high byte of the
*   immediate operand in arpSTORE, which is $80 in the file and came back as
*   $00 in both crash dumps.  The log therefore reads
*
*       70 80  71 80  72 80  73 00
*
*   and the pair that turns is the stage that overwrote the code.

:emit    do    TRACEON
         php
         sep   #$20
         jsr   traceBYTE
         lda   macSET+2
         jsr   traceBYTE
         rep   #$20
         plp
         fin
         rts

*---------- $000E LinkReconStatus - a word of space at 1,s

         mx    %00                 ; entered 16-bit, whatever precedes
doReconStatus lda #$0000            ; false: we do not support reconnecting
         sta   1,s
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- $0010 LinkReconnect - displayPtr at 1,s

         mx    %00                 ; entered 16-bit, whatever precedes
doReconnect DROP 4
         lda   #terrNORECON
         sec
         jmp   exitLINK

*---------- $0012 LinkDisconnect - 18 bytes of parameters

         mx    %00                 ; entered 16-bit, whatever precedes
doDisconnect jsr netDISABLE
         stz   lvConnected
         DROP  18
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- $0014 LinkGetVariables - a long of space at 1,s

         mx    %00                 ; entered 16-bit, whatever precedes
doGetVariables lda #lvVersion
         sta   1,s
         lda   myBank
         sta   3,s
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- $0016 LinkConfigure: see config.s, which holds the dialog

*---------- $0018 LinkConfigFileName
*
* A Marinetti 3.0 call: return the name of the file our configuration lives
* in, as a pstring in the caller's 16 byte buffer (Technical Update, page 15).
*
* We still report interface version 1, so in principle this is never called.
* It is implemented anyway, because rejecting a call without removing its
* parameters leaves the caller's stack four bytes out - and that is a freeze,
* not an error message.  Anything Marinetti might reasonably call, we answer.

         mx    %00                 ; entered 16-bit, whatever precedes
doCfgFile lda  1,s
         sta   ptr1
         lda   3,s
         sta   ptr1+2

         sep   #$20
         ldy   #$0000
:copy    lda   cfgNAME,y
         sta   [ptr1],y
         iny
         cpy   #cfgLEN
         bcc   :copy
         rep   #$20

         DROP  4
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- A handle for one datagram, owned by Marinetti
*
* Marinetti's UserID was handed to us at entry; allocations must use it.

newDGRAM php
         rep #$30
         pea $0000                  ; space for the handle
         pea $0000
         pea $0000                  ; size, high word
         lda dgramLEN
         pha                        ; size, low word
         lda theUSER
         pha                        ; Marinetti's UserID
         pea $0000                  ; attributes: movable, purge level 0
         pea $0000                  ; location, unused
         pea $0000
         ldx #NewHandle
         jsl TOOLBOX
         bcs :err

         pla
         sta hResult
         pla
         sta hResult+2
         plp
         clc
         rts

:err     pla                        ; discard whatever came back
         pla
         stz hResult
         stz hResult+2
         plp
         sec
         rts

*---------- Connect data
*
* Our own layout, stored by Marinetti on our behalf:
*
*   +0  word  version, $0001
*   +2  long  IP address       (network order)
*   +6  long  subnet mask
*   +10 long  gateway
*
* ptr1 holds the handle on entry.

readCONFIG php
         rep #$30
         lda ptr1                   ; dereference the handle
         ora ptr1+2
         beq :bad
         lda [ptr1]
         sta ptr2
         ldy #$0002
         lda [ptr1],y
         sta ptr2+2
         lda ptr2
         ora ptr2+2
         beq :bad

         lda [ptr2]                 ; version we understand?
         cmp #$0001
         bne :bad

         ldy #$0002
         lda [ptr2],y
         sta myIP
         ldy #$0004
         lda [ptr2],y
         sta myIP+2
         ldy #$0006
         lda [ptr2],y
         sta myMASK
         ldy #$0008
         lda [ptr2],y
         sta myMASK+2
         ldy #$000A
         lda [ptr2],y
         sta gateIP
         ldy #$000C
         lda [ptr2],y
         sta gateIP+2

         plp
         clc
         rts

*   No saved configuration yet, because LinkConfigure has no dialog to gather
*   one.  Fall back to the built-in defaults rather than refusing to connect:
*   that way the link can be exercised end to end now, and the dialog becomes
*   an improvement rather than a prerequisite.

:bad     jsr   defaultCONFIG
         plp
         clc
         rts

*---------- Defaults for an empty configuration
*
* 192.168.2.99 / 255.255.255.0 / 192.168.2.1 - the Mac Internet Sharing setup
* the transport was proven against.  Stored in network order.

defaultCONFIG php
         rep #$30
         lda #$A8C0                 ; 192.168
         sta myIP
         lda #$6302                 ; .2.99
         sta myIP+2
         lda #$FFFF
         sta myMASK
         lda #$00FF
         sta myMASK+2
         lda #$A8C0
         sta gateIP
         lda #$0102                 ; .2.1
         sta gateIP+2
         plp
         rts

*===========================================================================
* Data
*===========================================================================

*---------- The variables record Marinetti reads through LinkGetVariables

*   Layout confirmed against Marinetti's own I.EQU.S:
*     lvVersion +0, lvConnected +2, lvIPaddress +4, lvRefCon +8,
*     lvErrors +12, lvMTU +16, lvlen 18.  The Programmers' Guide prints
*     lvMTU at +14, which is a typo in the PDF.  true = $8000.

lvVersion ds   2                    ; lvVer = $0001
lvConnected ds 2                    ; $8000 connected, $0000 not
lvIPaddress ds 4
lvRefCon ds    4
lvErrors ds    4
lvMTU    ds    2

*---------- LinkModuleInfo response, 29 bytes

*   conTest ($0005) is the ID the guide sets aside for development: "not for
*   public release".  Registered methods run $0001-$0008, so a value outside
*   that range was never going to be right.  Applying to Marinetti's author
*   for our own ID is a release-time job.

infoBLK  da    $0005                ; liMethodID = conTest
         str   'BlueSCSI DaynaPORT'
         ds    21-19                ; liName pads to 21 bytes
         adrl  $00800001            ; liVersion: major $01, minor $00,
*                                   stage $80 (final), release $00, in the
*                                   rVersion byte order
         da    $0000                ; liFlags: no serial port, no rIcon
infoLEN  =     *-infoBLK

cfgNAME  str   'BSLink.Config'      ; pstring, inside ProDOS 15 character rules
cfgLEN   =     *-cfgNAME

*---------- Module storage

theCALL  ds    2
theUSER  ds    2
theDP    ds    2
rtlADDR  ds    4
myBank   ds    2
errSAVE  ds    2
pSAVE    ds    2
dbkSAVE  ds    2
hResult  ds    4
dgramLEN ds    2
myIP     ds    4
myMASK   ds    4
gateIP   ds    4

