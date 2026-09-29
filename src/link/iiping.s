*
* PING - round trips through Marinetti and the BlueSCSI link layer
*
* Two tests in one program, both with Marinetti doing the IP work:
*
*   1. Out: four ICMP echoes to the gateway, 192.168.2.1 - the Mac running
*      Internet Sharing - each timed in ticks (60 to the second).
*   2. In:  thirty seconds of polling, so the IIgs answers the Mac's
*      "ping 192.168.2.99".  Marinetti replies to echo requests itself
*      (I.ICMP.S, ECHORQ); it only needs someone to keep calling TCPIPPoll.
*      Its own RunQ task polls every half second, but only while a desktop
*      application's event loop is running.
*
* It leaves Marinetti as it found it: connects only if it was not already
* connected, and starts the tool set only if it was not already started.
*
* Tool calls and their stack layouts are read from the Marinetti source
* (Init/I.INIT.S): Login $2336, Logout $2436, SendICMPEcho $2A36,
* ReceiveICMPEcho $2B36, Poll $2236.  Addresses are in network order.
*
* GS/OS S16.  Launch it from the Finder.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         mx    %00
         rel
         lst   off

TOOLBOX  =     $E10000
GSOS     =     $E100A8

TLStartUp =    $0201
TLShutDown =   $0301
LoadOneTool =  $0F01
MMStartUp =    $0202
MMShutDown =   $0302
MTStartUp =    $0203
TextStartUp =  $020C
SetInGlobals = $090C
SetOutGlobals = $0A0C
SetErrGlobals = $0B0C
SetInputDevice = $0F0C
SetOutputDevice = $100C
SetErrorDevice = $110C
InitTextDev =  $150C
MTShutDown =   $0303
TextShutDown = $030C
WriteChar =    $180C
WriteCString = $200C

MARINETTI =    $36

TCPIPStartUp = $0236
TCPIPShutDown = $0336
TCPIPStatus =  $0636
TCPIPGetConnectStatus = $0936
TCPIPGetMyIPAddress = $0F36
TCPIPSetConnectMethod = $1136
TCPIPConnect = $1236
TCPIPDisconnect = $1336

conTest  =     $0005                ; our module's method ID

TCPIPPoll =    $2236
TCPIPLogin =   $2336
TCPIPLogout =  $2436
TCPIPSendICMPEcho = $2A36
TCPIPReceiveICMPEcho = $2B36
GetTick  =     $2503

GATEHI   =     $0102                ; 192.168.2.1 as Marinetti holds it: the
GATELO   =     $A8C0                ; bytes C0 A8 02 01, low word first.
*                                     Only used when no gateway is saved.
TCPIPGetConnectData = $1636         ; (userid,method):handle, I.INIT.S
DisposeHandle = $1002

dpH      =     $00                  ; our own direct page: the handle
dpP      =     $04                  ; and what it points at
ECHOS    =     4
WAITTIX  =     180                  ; three seconds for each reply
LISTENTX =     1800                 ; thirty seconds answering the Mac

*===========================================================================

main     phk
         plb
         sep   #$20
         phk
         pla
         sta   myBank
         stz   myBank+1
         rep   #$20

         jsr   toolsUP

         lda   #msgTITLE
         jsr   say

*---------- Marinetti present, started and connected?

         lda   #msgLOAD
         jsr   say
         lda   #MARINETTI
         pha
         pea   $0300
         ldx   #LoadOneTool
         jsl   TOOLBOX
         bcc   :loaded
         jsr   shoERR
         brl   finish
:loaded  jsr   shoOK

         pea   $0000
         ldx   #TCPIPStatus
         jsl   TOOLBOX
         pla
         bne   :active
         lda   #msgSTART
         jsr   say
         ldx   #TCPIPStartUp
         jsl   TOOLBOX
         php                        ; shoERR prints, and printing clears
         jsr   shoERR               ; the carry: keep the call's own
         plp
         bcc   :started
         brl   finish
:started lda   #$FFFF
         sta   weStarted

:active  pea   $0000
         ldx   #TCPIPGetConnectStatus
         jsl   TOOLBOX
         pla
         bne   :online

         lda   #msgCONN
         jsr   say
         pea   conTest
         ldx   #TCPIPSetConnectMethod
         jsl   TOOLBOX
         pea   $0000                ; displayPtr = nil
         pea   $0000
         ldx   #TCPIPConnect
         jsl   TOOLBOX
         php                        ; shoERR prints, and printing clears
         jsr   shoERR               ; the carry: keep the call's own
         plp
         bcc   :joined
         brl   unwind
:joined  lda   #$FFFF
         sta   weConnected

:online  lda   #msgMYIP
         jsr   say
         pea   $0000
         pea   $0000
         ldx   #TCPIPGetMyIPAddress
         jsl   TOOLBOX
         pla
         sta   ipLO
         sta   myLO
         pla
         sta   ipHI
         sta   myHI
         jsr   prIP
         jsr   crout

*---------- Which gateway?  The one saved by the link layer's Configure
*           dialog (config.s), in its layout: version word, then address,
*           mask and gateway as network-order longs.

         lda   #GATELO
         sta   gwLO
         lda   #GATEHI
         sta   gwHI
         pea   $0000                ; space for the handle
         pea   $0000
         lda   userID
         pha
         pea   conTest
         ldx   #TCPIPGetConnectData
         jsl   TOOLBOX
         pla
         sta   dpH
         pla
         sta   dpH+2
         bcs   :nocfg
         ora   dpH
         beq   :nocfg
         lda   [dpH]                ; dereference
         sta   dpP
         ldy   #$0002
         lda   [dpH],y
         sta   dpP+2
         ora   dpP
         beq   :dispose             ; nothing saved yet
         lda   [dpP]
         cmp   #$0001
         bne   :dispose
         ldy   #$000A
         lda   [dpP],y
         sta   gwLO
         ldy   #$000C
         lda   [dpP],y
         sta   gwHI
:dispose lda   dpH+2                ; the handle is ours to dispose of
         pha
         lda   dpH
         pha
         ldx   #DisposeHandle
         jsl   TOOLBOX
:nocfg   = *

*---------- An ipid to send and receive echoes with

         pea   $0000                ; space for the ipid
         lda   userID               ; userid
         pha
         lda   gwHI                 ; destip, a long: high word first
         pha
         lda   gwLO
         pha
         pea   $0000                ; destport: unused by ICMP
         pea   $0000                ; defaultTOS
         pea   $0040                ; defaultTTL: 64
         ldx   #TCPIPLogin
         jsl   TOOLBOX
         pla
         sta   ipid
         bcc   :login
         pha
         lda   #msgLOGIN
         jsr   say
         pla
         jsr   hexWORD
         jsr   crout
         brl   unwind
:login   = *

*---------- Test 1: echoes out to the gateway

         lda   #msgOUT
         jsr   say
         lda   gwLO
         sta   ipLO
         lda   gwHI
         sta   ipHI
         jsr   prIP
         lda   #msgGW
         jsr   say
         lda   #$0000
         sta   gotN
         lda   #1
         sta   seq

:echo    lda   #msgSEQ
         jsr   say
         lda   seq
         jsr   prDEC
         lda   #msgSPC
         jsr   say

         lda   ipid
         pha
         lda   seq
         pha
         ldx   #TCPIPSendICMPEcho
         jsl   TOOLBOX
         bcc   :sent
         pha
         lda   #msgSERR
         jsr   say
         pla
         jsr   hexWORD
         jsr   crout
         bra   :nextseq

:sent    jsr   ticks
         sta   t0

:wait    ldx   #TCPIPPoll           ; Marinetti calls LinkGetDatagram here
         jsl   TOOLBOX
         pea   $0000                ; space for the sequence number
         lda   ipid
         pha
         ldx   #TCPIPReceiveICMPEcho
         jsl   TOOLBOX
         pla                        ; pla leaves the carry alone
         bcs   :none
         cmp   seq                  ; a late reply to an earlier echo?
         bne   :none
         jsr   ticks
         sec
         sbc   t0
         pha
         lda   #msgREPLY
         jsr   say
         pla
         jsr   prNUM
         lda   #msgTICKS
         jsr   say
         inc   gotN
         bra   :nextseq

:none    jsr   ticks
         sec
         sbc   t0
         cmp   #WAITTIX
         bcc   :wait
         lda   #msgTIMEOUT
         jsr   say

:nextseq inc   seq
         lda   seq
         cmp   #ECHOS+1
         bcs   :outdone
         brl   :echo
:outdone = *

         lda   gotN
         jsr   prDEC
         lda   #msgOF
         jsr   say

*---------- Test 2: answer the Mac

         lda   #msgIN
         jsr   say
         lda   myLO
         sta   ipLO
         lda   myHI
         sta   ipHI
         jsr   prIP
         lda   #msgIN2
         jsr   say
         jsr   ticks
         sta   t0
         sta   tDOT

:listen  ldx   #TCPIPPoll
         jsl   TOOLBOX
         sep   #$20                 ; any key ends it early
         ldal  $E0C000
         bmi   :key
         rep   #$20
         jsr   ticks
         pha
         sec
         sbc   tDOT
         cmp   #60
         bcc   :nodot
         pla
         pha
         sta   tDOT
         lda   #"."
         jsr   putc
:nodot   pla
         sec
         sbc   t0
         cmp   #LISTENTX
         bcc   :listen
         bra   :heard
:key     stal  $E0C010
         rep   #$20
:heard   jsr   crout

         lda   ipid                 ; give the ipid back
         pha
         ldx   #TCPIPLogout
         jsl   TOOLBOX

*---------- Leave Marinetti as we found it

unwind   lda   weConnected
         beq   :nodisc
         pea   $0000                ; forceFlag
         pea   $0000                ; displayPtr
         pea   $0000
         ldx   #TCPIPDisconnect
         jsl   TOOLBOX
:nodisc  lda   weStarted
         beq   finish
         ldx   #TCPIPShutDown
         jsl   TOOLBOX

finish   lda   #msgDONE
         jsr   say
         jsr   waitKEY
         jsr   toolsDOWN
         jsl   GSOS
         dw    $2029                ; class 1 Quit
         adrl  quitPARM
         brk   $00                  ; Quit does not come back

quitPARM dw    2
         adrl  $00000000
         dw    $0000

*---------- The tick count, low word: enough for intervals under 18 minutes

ticks    pea   $0000
         pea   $0000
         ldx   #GetTick
         jsl   TOOLBOX
         pla
         ply                        ; the high word is not needed
         rts

*---------- An address in network order: first octet in the lowest byte

prIP     lda   ipLO
         and   #$00FF
         jsr   prDEC
         lda   #"."
         jsr   putc
         lda   ipLO
         xba
         and   #$00FF
         jsr   prDEC
         lda   #"."
         jsr   putc
         lda   ipHI
         and   #$00FF
         jsr   prDEC
         lda   #"."
         jsr   putc
         lda   ipHI
         xba
         and   #$00FF
         jmp   prDEC

*---------- A word in decimal, 0-65535, no leading zeros

prNUM    ldx   #$0000               ; digit count on the stack
:div     sta   dTMP                 ; divide by ten, remainder to the stack
         lda   #$0000
         ldy   #16
:bit     asl   dTMP
         rol
         cmp   #10
         bcc   :low
         sbc   #10
         inc   dTMP
:low     dey
         bne   :bit
         pha
         inx
         lda   dTMP
         bne   :div
:out     pla
         clc
         adc   #$0030
         phx
         jsr   putc
         plx
         dex
         bne   :out
         rts

toolsUP  ldx   #TLStartUp
         jsl   TOOLBOX
         pea   $0000
         ldx   #MMStartUp
         jsl   TOOLBOX
         pla
         sta   userID
*   TextStartUp takes no parameters.  Pushing a userID leaves a word on the
*   stack, and this routine's rts then pulls it as a return address - landing
*   at $000001 when that word reads zero.  The shipped BlueSCSI application
*   starts MTStartUp first and calls TextStartUp with nothing pushed.

         ldx   #MTStartUp
         jsl   TOOLBOX
         ldx   #TextStartUp
         jsl   TOOLBOX

*   Starting the Text tools is not enough: until the globals and devices are
*   set, WriteCString dispatches through a device that is not there, which is
*   how the machine ended up executing in emulation mode at $2002.  This
*   sequence is transcribed instruction for instruction from the shipped
*   BlueSCSI application.

         pea   $00FF                ; input globals
         pea   $0080
         ldx   #SetInGlobals
         jsl   TOOLBOX
         pea   $00FF                ; output globals
         pea   $0080
         ldx   #SetOutGlobals
         jsl   TOOLBOX
         pea   $00FF                ; error globals
         pea   $0080
         ldx   #SetErrGlobals
         jsl   TOOLBOX

         pea   $0000                ; device 3 = the text screen
         pea   $0000
         pea   $0003
         ldx   #SetInputDevice
         jsl   TOOLBOX
         pea   $0000
         pea   $0000
         pea   $0003
         ldx   #SetOutputDevice
         jsl   TOOLBOX
         pea   $0000
         pea   $0000
         pea   $0003
         ldx   #SetErrorDevice
         jsl   TOOLBOX

         pea   $0000                ; init input, output and error devices
         ldx   #InitTextDev
         jsl   TOOLBOX
         pea   $0001
         ldx   #InitTextDev
         jsl   TOOLBOX
         pea   $0002
         ldx   #InitTextDev
         jsl   TOOLBOX
         rts

toolsDOWN ldx  #TextShutDown     ; no parameters, like its startup
         jsl   TOOLBOX
         lda   userID
         pha
         ldx   #MMShutDown
         jsl   TOOLBOX
         ldx   #TLShutDown
         jsl   TOOLBOX
         rts

*---------- Report a tool call result: carry and error code

shoERR   bcs   :bad
         pha
         lda   #msgOK
         jsr   say
         pla
         rts
:bad     pha
         lda   #msgERR
         jsr   say
         pla
         pha
         jsr   hexWORD
         jsr   crout
         pla
         rts

shoOK    lda   #msgOK
         jmp   say

*---------- Wait for a key, straight off the hardware

waitKEY  sep   #$20
:loop    ldal  $E0C000
         bpl   :loop
         stal  $E0C010
         rep   #$20
         rts

*---------- Output

say      tay
         lda   myBank
         pha
         tya
         pha
         ldx   #WriteCString
         jsl   TOOLBOX
         rts

putc     and   #$00FF
         ora   #$0080
         pha
         ldx   #WriteChar
         jsl   TOOLBOX
         rts

crout    lda   #$000D
         bra   putc

hexWORD  pha
         xba
         jsr   hexBYTE
         pla
hexBYTE  pha
         lsr
         lsr
         lsr
         lsr
         jsr   hexNIB
         pla
hexNIB   and   #$000F
         cmp   #$000A
         bcc   :digit
         clc
         adc   #$0007
:digit   clc
         adc   #$0030
         jmp   putc

*--- A byte in decimal, for the IP address

prDEC    and   #$00FF
         sta   dTMP
         ldx   #$0000
:hund    cmp   #100
         bcc   :tens
         sec
         sbc   #100
         inx
         bra   :hund
:tens    pha
         txa
         beq   :skiph
         clc
         adc   #$0030
         jsr   putc
:skiph   pla
         ldx   #$0000
:ten     cmp   #10
         bcc   :ones
         sec
         sbc   #10
         inx
         bra   :ten
:ones    pha
         txa
         clc
         adc   #$0030
         jsr   putc
         pla
         clc
         adc   #$0030
         jmp   putc

*---------- Storage

myBank   ds    2
userID   ds    2
ipLO     ds    2
ipHI     ds    2
myLO     ds    2
myHI     ds    2
gwLO     ds    2
gwHI     ds    2
dTMP     ds    2
ipid     ds    2
seq      ds    2
gotN     ds    2
t0       ds    2
tDOT     ds    2
weStarted ds   2
weConnected ds 2

msgTITLE asc   'PING BUILD 2 - GATEWAY FROM CONFIG'
         hex   0D0D00
msgLOAD  asc   'MARINETTI           '
         hex   00
msgSTART asc   'TCPIPSTARTUP        '
         hex   00
msgCONN  asc   'TCPIPCONNECT        '
         hex   00
msgMYIP  asc   'MY IP ADDRESS       '
         hex   00
msgLOGIN asc   'TCPIPLOGIN ERROR $'
         hex   00
msgOUT   asc   0D'ECHO TO '
         hex   00
msgGW    asc   ' (THE GATEWAY)'
         hex   0D00
msgSEQ   asc   '  SEQ '
         hex   00
msgSPC   asc   '  '
         hex   00
msgSERR  asc   'SEND ERROR $'
         hex   00
msgREPLY asc   'REPLY IN '
         hex   00
msgTICKS asc   ' TICKS'
         hex   0D00
msgTIMEOUT asc 'NO REPLY'
         hex   0D00
msgOF    asc   ' OF 4 REPLIED'
         hex   0D00
msgIN    asc   0D'NOW, FROM ANOTHER COMPUTER: PING '
         hex   00
msgIN2   hex   0D
         asc   'ANSWERING FOR 30 SECONDS, ANY KEY STOPS'
         hex   0D00
msgOK    asc   'OK'
         hex   0D00
msgERR   asc   'ERROR $'
         hex   00
msgDONE  asc   'DONE - PRESS A KEY'
         hex   0D00
