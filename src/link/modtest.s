*
* MODTEST - call the link layer module from ProDOS 8
*
* BSLink is a GS/OS module, so the obvious way to test it is to install it and
* let Marinetti call it.  That turned out to be a bad loop: Marinetti loads
* every module in System:TCPIP while GS/OS boots, so a module that hangs takes
* the whole machine with it, and the only way back is to delete the file from
* outside.
*
* This program assembles the same module source into a ProDOS 8 binary and
* calls it directly, using the register convention from the Marinetti
* Programmers' Guide:
*
*     A    the module's direct page, or $0000 for none
*     X    the call number
*     Y    Marinetti's UserID
*     DP   Marinetti's direct page ($E0-$FF belong to the module)
*     S    the RTL address, then the parameters
*
* It prints LinkInterfaceV and LinkModuleInfo - the two calls Marinetti makes
* while building the link layer list - then makes every call once and checks
* that each leaves the stack level and writes nothing into the module's code.
*
* One gap: if an IP frame arrives during LinkGetDatagram, the module asks the
* Memory Manager for a handle, and that toolbox call has not been exercised
* from ProDOS 8.  ARP frames, and silence, never reach it.
*
* BRUN it.  A hang costs a reboot, not a rescue.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         mx    %11
         org   $2000
         typ   $06
         dsk   ModTest
         lst   on

COUT     =     $FDED
PRBYTE   =     $FDDA
CROUT    =     $FD8E

TESTDP   =     $1F00                ; a spare page to stand in for Marinetti's

*===========================================================================

start    jsr   CROUT
         ldx   #<msgTITLE
         ldy   #>msgTITLE
         jsr   puts

*---------- LinkInterfaceV ($0000): expect $0001 back

         ldx   #<msgIV
         ldy   #>msgIV
         jsr   puts

         clc                        ; into native mode for the call
         xce
         rep   #$30
         mx    %00

         lda   #TESTDP
         tcd
         pea   $0000                ; a word of space for the result
         lda   #$0000               ; no direct page of our own
         ldx   #$0000               ; call number
         ldy   #$1234               ; a stand-in UserID
         jsl   entry
         rep   #$30                 ; do not trust a callee's exit width
         pla
         sta   ivRESULT
         lda   #$0000
         tcd

         sep   #$30
         mx    %11
         sec
         xce

         lda   ivRESULT+1
         jsr   PRBYTE
         lda   ivRESULT
         jsr   PRBYTE
         jsr   CROUT

*---------- LinkModuleInfo ($0006): 29 bytes into our buffer

         ldx   #<msgMI
         ldy   #>msgMI
         jsr   puts

         ldx   #$00                 ; clear the buffer first, so we can see
         lda   #$00                 ; exactly what the module wrote
:clr     sta   infoBUF,x
         inx
         cpx   #32
         bcc   :clr

         clc
         xce
         rep   #$30
         mx    %00

         lda   #TESTDP
         tcd
         pea   $0000                ; pointer, bank word
         pea   infoBUF              ; pointer, low word
         lda   #$0000
         ldx   #$0006
         ldy   #$1234
         jsl   entry
         rep   #$30
         lda   #$0000
         tcd

         sep   #$30
         mx    %11
         sec
         xce

*--- method ID, then the name, then the raw bytes

         ldx   #<msgMETH
         ldy   #>msgMETH
         jsr   puts
         lda   infoBUF+1
         jsr   PRBYTE
         lda   infoBUF
         jsr   PRBYTE
         jsr   CROUT

         ldx   #<msgNAME
         ldy   #>msgNAME
         jsr   puts
         ldx   infoBUF+2            ; pstring length
         beq   :noname
         cpx   #21
         bcs   :noname
         ldy   #$00
:name    lda   infoBUF+3,y
         ora   #$80
         jsr   COUT
         iny
         dex
         bne   :name
:noname  jsr   CROUT

         ldx   #<msgRAW
         ldy   #>msgRAW
         jsr   puts
         ldy   #$00
:raw     lda   infoBUF,y
         jsr   PRBYTE
         lda   #" "
         jsr   COUT
         iny
         cpy   #29
         bcs   :rawend
         tya
         and   #$07
         bne   :raw
         jsr   CROUT
         bra   :raw
:rawend  jsr   CROUT

         jsr   stackTEST

         ldx   #<msgOK
         ldy   #>msgOK
         jsr   puts
         rts

*===========================================================================
* Does every call leave the stack exactly as it should?
*===========================================================================
*
* The callee removes its own parameters and leaves any result space in place.
* Get that wrong and the caller's stack walks - which is how Marinetti froze
* on Configure.  Each entry is: call number, parameter longs, parameter
* words, result bytes.

stackTEST jsr  snapSHOT             ; a clean copy to compare against
         ldx   #<msgSTK
         ldy   #>msgSTK
         jsr   puts

         lda   #$00
         sta   tIDX

:each    lda   tIDX
         cmp   #NTESTS
         bcc   :go                  ; the loop body is past branch range
         rts

:go      asl                        ; sixteen bytes per entry
         asl
         asl
         asl
         tax
         lda   tblCALL,x
         sta   tCALL
         lda   tblCALL+1,x
         sta   tCALL+1
         lda   tblCALL+2,x
         sta   tLONGS
         lda   tblCALL+4,x
         sta   tWORDS
         lda   tblCALL+6,x
         sta   tRESULT
         lda   tblCALL+8,x
         sta   tTOP
         lda   tblCALL+10,x
         sta   tWVAL
         lda   tblCALL+11,x
         sta   tWVAL+1
         lda   tblCALL+12,x
         sta   tPTR
         lda   tblCALL+13,x
         sta   tPTR+1

         lda   tCALL+1              ; name the call before running it, so a
         jsr   PRBYTE                ; crash leaves its number on screen
         lda   tCALL
         jsr   PRBYTE
         lda   #" "
         jsr   COUT

         jsr   oneTEST

         lda   tCALL+1              ; report: call number, then the verdict
         jsr   PRBYTE
         lda   tCALL
         jsr   PRBYTE
         lda   #" "
         jsr   COUT

         ldx   #<msgA               ; what it returned: A, and C if carry set
         ldy   #>msgA
         jsr   puts
         lda   tA+1
         jsr   PRBYTE
         lda   tA
         jsr   PRBYTE
         lda   tP
         and   #$01                 ; bit 0 of P is the carry
         beq   :nocar
         lda   #"C"
         bne   :car
:nocar   lda   #" "
:car     jsr   COUT
         lda   #" "
         jsr   COUT

         lda   tDELTA               ; zero means the stack came back level
         bne   :bad
         ldx   #<msgPASS
         ldy   #>msgPASS
         jsr   puts
         bra   :next
:bad     ldx   #<msgFAIL
         ldy   #>msgFAIL
         jsr   puts
         lda   tDELTA
         jsr   PRBYTE
         jsr   CROUT

:next    jsr   snapCHK              ; did that call write into the code?
         inc   tIDX
         brl   :each

*--- one call, with dummy parameters that all point at a scratch buffer

oneTEST  clc
         xce
         rep   #$30
         mx    %00

         lda   #TESTDP
         tcd
         tsc
         sta   sBEFORE

         lda   tRESULT              ; result space, in words
         lsr
         beq   :params
         tax
:space   pea   $0000
         dex
         bne   :space

*   Parameters go on in the order the Programmers' Guide draws them.  This
*   used to push every word before every long, which put LinkSendDatagram's
*   pointer on top where its length belongs: the module read scratch's
*   address as a 9K length and copied the text screen over its own ARP code.

:params  lda   tTOP
         bne   :lfirst

         ldx   tWORDS              ; words deepest, a long on top
         beq   :l1
:w1      lda   tWVAL
         pha
         dex
         bne   :w1
:l1      ldx   tLONGS
         beq   :call
:p1      pea   $0000               ; bank word: everything is in bank 0
         lda   tPTR
         pha
         dex
         bne   :p1
         bra   :call

:lfirst  ldx   tLONGS              ; longs deepest, a word on top
         beq   :w2
:p2      pea   $0000
         lda   tPTR
         pha
         dex
         bne   :p2
:w2      ldx   tWORDS
         beq   :call
:w3      lda   tWVAL
         pha
         dex
         bne   :w3

:call    lda   tCALL
         tax

*   Call with a data bank that is not the module's, as Marinetti does.  With
*   both in bank 0, MODTEST never saw exitLINK reading its result and flags
*   out of the caller's bank - the bug behind TCPIPConnect's $B648.

         sep   #$20
         lda   #$01
         pha
         plb
         rep   #$20
         lda   #$0000
         ldy   #$1234
         jsl   entry
         php                       ; the flags it handed back
         phk                       ; our bank again before any variable
         plb
         rep   #$30              ; never trust a callee's exit width
         sta   tA                  ; the result it handed back
         sep   #$20
         pla
         sta   tP
         rep   #$20

         lda   tRESULT             ; take the result space back off
         lsr
         beq   :check
         tax
:drop    pla
         dex
         bne   :drop

:check   tsc                       ; should match where we started
         sec
         sbc   sBEFORE
         sta   sDELTA

         lda   #$0000
         tcd
         sep   #$30
         mx    %11
         sec
         xce

         lda   sDELTA
         sta   tDELTA
         rts

*--- what to call, and what each call takes
*
*    call, longs, words, result bytes, word on top?, word value, pointer, 0
*
*    Every long parameter is the same pointer.  scratch takes the calls that
*    write through theirs; nilH is a nil handle, so LinkConnect's conHandle
*    falls back to the default configuration; dgram is a real 20 byte IPv4
*    header, so LinkSendDatagram sends something the length describes.

*   $0002 and $0004 matter most: LinkStartup is the only call that runs the
*   SCSI transport, and Marinetti's LOADLINKLAYER ends with PLD - so a single
*   byte left on the stack by that path becomes a garbage direct page.

tblCALL  da    $0000,0,0,2,0,0,nilH,0        ; LinkInterfaceV
         da    $0002,0,0,0,0,0,nilH,0        ; LinkStartup - runs the transport
         da    $0004,0,0,0,0,0,nilH,0        ; LinkShutDown - runs the transport
         da    $0006,1,0,0,0,0,scratch,0     ; LinkModuleInfo - writes 29 bytes
         da    $0008,0,0,4,0,0,nilH,0        ; LinkGetDatagram
         da    $000A,1,1,0,1,DGLEN,dgram,0   ; LinkSendDatagram - length on top
         da    $000C,5,1,0,0,0,nilH,0        ; LinkConnect - conHandle on top
         da    $0012,4,1,0,0,0,nilH,0        ; LinkDisconnect - 18 bytes
         da    $000E,0,0,2,0,0,nilH,0        ; LinkReconStatus
         da    $0010,1,0,0,0,0,nilH,0        ; LinkReconnect
         da    $0014,0,0,4,0,0,nilH,0        ; LinkGetVariables
*   $0016 LinkConfigure opens a desktop window: it cannot run under ProDOS 8
         da    $0018,1,0,0,0,0,scratch,0     ; LinkConfigFileName - writes 14
NTESTS   =     12

*===========================================================================
* Watch the module's own code for writes
*===========================================================================
*
* The module's instructions at $332B came back changed after a call, and no
* store in the source can reach that address.  Three builds have now gone on
* guessing which one did it.  This copies the whole module aside before the
* stack tests start and, after every call, names the addresses that no longer
* match - so the machine says which call wrote where instead of us inferring
* it from a register dump.
*
* Storage the module is supposed to write is excluded by range, and each
* reported byte is re-synced, so every line is a change that call made.

SHADOW   =     $6000                ; clear of the binary, and of hires page 2
*                                     at $4000 which test $000A was wiping
SHADLO   =     $60
*   The pages to watch and the ranges to skip come from the module's own
*   labels.  They were typed in by hand for three builds, and every edit to
*   the module moved them.
SNAPMAX  =     12                   ; lines per call, so one bug cannot
*                                     scroll the rest of the run away

snapSRC  =     $08
snapDST  =     $0A

snapSHOT lda   #$00
         sta   snapSRC
         sta   snapDST
         lda   #>entry              ; first page of the module
         sta   snapSRC+1
         lda   #SHADLO
         sta   snapDST+1
:page    ldy   #$00
:byte    lda   (snapSRC),y
         sta   (snapDST),y
         iny
         bne   :byte
         inc   snapSRC+1
         inc   snapDST+1
         lda   snapSRC+1
         cmp   #>modEND+$100        ; one past its last page
         bcc   :page
         rts

*--- compare against the copy, report, and re-sync as we go

snapCHK  lda   #$00
         sta   snapSRC
         sta   snapDST
         sta   snapN
         lda   #>entry              ; first page of the module
         sta   snapSRC+1
         lda   #SHADLO
         sta   snapDST+1
:page    ldy   #$00
:byte    lda   (snapSRC),y
         cmp   (snapDST),y
         beq   :same
         jsr   snapSAY
         lda   (snapSRC),y          ; re-sync: each report is new news
         sta   (snapDST),y
:same    iny
         bne   :byte
         inc   snapSRC+1
         inc   snapDST+1
         lda   snapSRC+1
         cmp   #>modEND+$100        ; one past its last page
         bcc   :page
         rts

*--- one changed byte: "  WROTE $33AB=5C"

snapSAY  sty   snapY
         lda   snapSRC+1
         sta   curHI
         sty   curLO
         jsr   snapEXCL             ; storage it is allowed to write?
         bcs   :out
         lda   snapN
         cmp   #SNAPMAX
         bcs   :out
         inc   snapN
         ldx   #<msgWROTE
         ldy   #>msgWROTE
         jsr   puts
         lda   curHI
         jsr   PRBYTE
         lda   curLO
         jsr   PRBYTE
         lda   #"="
         jsr   COUT
         ldy   snapY               ; what the module holds now
         lda   (snapSRC),y
         jsr   PRBYTE
         lda   #"/"                ; and what the copy holds
         jsr   COUT
         ldy   snapY
         lda   (snapDST),y
         jsr   PRBYTE
         jsr   CROUT
:out     ldy   snapY
         rts

*--- carry set if curLO/curHI is inside a range the module owns

snapEXCL ldx   #$00
:next    cpx   #NRANGE*4
         bcs   :no
         lda   curHI                ; below the start of this range?
         cmp   rngTBL+1,x
         bcc   :adv
         bne   :hi
         lda   curLO
         cmp   rngTBL,x
         bcc   :adv
:hi      lda   curHI                ; below its end?
         cmp   rngTBL+3,x
         bcc   :yes
         bne   :adv
         lda   curLO
         cmp   rngTBL+2,x
         bcc   :yes
:adv     inx
         inx
         inx
         inx
         bra   :next
:yes     sec
         rts
:no      clc
         rts

*   Start and end of every block the module writes to on purpose.  Anything
*   outside these is code, and nothing should ever write to it.

rngTBL   da    ivRESULT,stoEND      ; this program's own storage
         da    lvVersion,gateIP+4   ; variables record through configuration
         da    cdbTRC,myMAC+6       ; CDB templates, transport vars, buffers
         da    macKNOWN,dstMAC+6    ; ARP state
NRANGE   =     4

*---------- Print the string at X/Y

puts     stx   sptr
         sty   sptr+1
         ldy   #$00
:loop    lda   (sptr),y
         beq   :done
         jsr   COUT
         iny
         bne   :loop
:done    rts

*---------- Storage

sptr     =     $06
ivRESULT ds    2
infoBUF  ds    32
scratch  ds    64
sBEFORE  ds    2
sDELTA   ds    2
tIDX     ds    1
tCALL    ds    2
tLONGS   ds    2
tWORDS   ds    2
tRESULT  ds    2
tDELTA   ds    2
tTOP     ds    2
tWVAL    ds    2
tPTR     ds    2
tA       ds    2
tP       ds    2
snapN    ds    1
snapY    ds    1
curLO    ds    1
curHI    ds    1
nilH     ds    4                    ; a nil handle

*   192.168.2.99 to the gateway, 192.168.2.1: version 4, 20 byte header,
*   protocol 253 (reserved for experiments), checksum computed.  Nothing
*   answers it; it exists so the send path runs with an honest length.

dgram    hex   45,00,00,14,00,00,00,00,40,FD
         hex   F4,38
         hex   C0,A8,02,63,C0,A8,02,01
DGLEN    =     *-dgram
stoEND   =     *                    ; end of this program's own storage

msgTITLE asc   "MODTEST BUILD 14 - CONFIG DIALOG"
         hex   8D8D00
msgIV    asc   "LINKINTERFACEV: "
         hex   00
msgMI    asc   "LINKMODULEINFO"
         hex   8D00
msgMETH  asc   "  METHOD ID: "
         hex   00
msgNAME  asc   "  NAME: "
         hex   00
msgRAW   asc   "  RAW:"
         hex   8D00
msgSTK   asc   "STACK BALANCE PER CALL"
         hex   8D00
msgPASS  asc   "OK"
         hex   8D00
msgFAIL  asc   "OUT BY $"
         hex   00
msgOK    asc   "RETURNED CLEANLY"
         hex   8D00
msgA     asc   "A="
         hex   00
msgWROTE asc   "  WROTE $"
         hex   00

*---------- The module under test, assembled in place
*
* The module is 65816 code and must assemble with 16-bit registers.  The
* harness above runs 8-bit, so the switch has to happen here, in this file:
* an mx inside a PUT file does not carry back out to the host assembly.

         mx    %00

         PUT   module
         PUT   scsi16
         PUT   arp
         PUT   config

modEND   =     *                    ; the watcher stops here
