*
* LINKCONN - connect through Marinetti without the control panel
*
* Every freeze so far has happened inside the TCP/IP control panel, which
* gives us nothing to read afterwards.  This drives the same tool calls the
* CDev does, in the same order, but prints each result instead:
*
*   LoadOneTool $36            is Marinetti there?
*   TCPIPStartUp        $0236
*   TCPIPStatus         $0636  is it active?
*   TCPIPSetConnectMethod $1136  select conTest ($0005), our module
*   TCPIPConnect        $1236  the call that loads and runs the link layer
*   TCPIPGetConnectStatus $0936
*   TCPIPGetMyIPAddress $0F36
*   TCPIPDisconnect     $1336
*   TCPIPShutDown       $0336
*
* Tool numbers are from the Marinetti 2.0 Programmers' Guide; the toolbox
* startup calls were read out of the shipped BlueSCSI application.
*
* If this prints an error code where the CDev freezes, that code names the
* problem.  If it freezes at the same point, the fault is in the connect
* path itself and not in the control panel.
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

*---------- Is Marinetti installed?

         lda   #msgLOAD
         jsr   say

         lda   #MARINETTI         ; toolNumber, then minVersion: two words,
         pha                        ; and no space for a result
         pea   $0300
         ldx   #LoadOneTool
         jsl   TOOLBOX
         bcc   :loaded

         jsr   shoERR
         lda   #msgNOTCP
         jsr   say
         jmp   finish

:loaded  jsr   shoOK

*---------- Start it, and ask whether it is active

         lda   #msgSTART
         jsr   say
         ldx   #TCPIPStartUp
         jsl   TOOLBOX
         jsr   shoERR

         lda   #msgSTAT
         jsr   say
         pea   $0000
         ldx   #TCPIPStatus
         jsl   TOOLBOX
         pla
         jsr   hexWORD
         jsr   crout

*---------- Select our link layer

         lda   #msgMETH
         jsr   say
         pea   conTest
         ldx   #TCPIPSetConnectMethod
         jsl   TOOLBOX
         jsr   shoERR

*---------- Connect.  This is where the control panel dies.

         lda   #msgCONN
         jsr   say

         pea   $0000                ; displayPtr = nil: no messages
         pea   $0000
         ldx   #TCPIPConnect
         jsl   TOOLBOX
         php                        ; keep the carry while we print
         sta   cResult
         jsr   crout
         lda   #msgRES
         jsr   say
         lda   cResult
         jsr   hexWORD
         jsr   crout
         plp
         bcc   :cok
         lda   #msgCARRY            ; carry set: the value above IS the error
         jsr   say
         bra   :cdone
:cok     lda   #msgNOCARRY          ; carry clear: the call reported success
         jsr   say
:cdone   jsr   waitKEY

*---------- What does it think happened?

         lda   #msgCSTAT
         jsr   say
         pea   $0000
         ldx   #TCPIPGetConnectStatus
         jsl   TOOLBOX
         pla
         jsr   hexWORD
         jsr   crout

         lda   #msgIP
         jsr   say
         pea   $0000
         pea   $0000
         ldx   #TCPIPGetMyIPAddress
         jsl   TOOLBOX
         pla
         sta   ipLO
         pla
         sta   ipHI
*   Marinetti holds addresses in network order: the first octet is the
*   lowest byte in memory, so the low byte of the low word.  This used to
*   print high byte first, which hid a byte-swapped address in the module.

         lda   ipLO
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
         jsr   prDEC
         jsr   crout

*---------- Put it back the way we found it

         lda   #msgDISC
         jsr   say
         pea   $0000                ; forceFlag: false
         pea   $0000                ; displayPtr: nil, high word
         pea   $0000                ; and its low word
         ldx   #TCPIPDisconnect
         jsl   TOOLBOX
         jsr   shoERR

         ldx   #TCPIPShutDown
         jsl   TOOLBOX

finish   lda   #msgDONE
         jsr   say
         jsr   waitKEY
         jsr   toolsDOWN
         jsl   GSOS
         dw    $2029              ; class 1 Quit: $0029 is class 0, which
*                                     read pCount 2 as a pathname pointer
         adrl  quitPARM
         brk   $00                  ; Quit does not come back

quitPARM dw    2
         adrl  $00000000
         dw    $0000

*---------- Tools

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
dTMP     ds    2
cResult  ds    2

msgTITLE asc   'LINKCONN BUILD 9 - NO CDEV'
         hex   0D0D00
msgLOAD  asc   'LOADONETOOL $36     '
         hex   00
msgSTART asc   'TCPIPSTARTUP        '
         hex   00
msgSTAT  asc   'TCPIPSTATUS         '
         hex   00
msgMETH  asc   'SETCONNECTMETHOD 5  '
         hex   00
msgCONN  asc   'TCPIPCONNECT        '
         hex   00
msgCSTAT asc   'GETCONNECTSTATUS    '
         hex   00
msgIP    asc   'MY IP ADDRESS       '
         hex   00
msgDISC  asc   'TCPIPDISCONNECT     '
         hex   00
msgOK    asc   'OK'
         hex   0D00
msgERR   asc   'ERROR $'
         hex   00
msgNOTCP asc   'MARINETTI IS NOT INSTALLED'
         hex   0D00
msgCARRY asc   '  CARRY SET - THAT VALUE IS THE ERROR'
         hex   0D00
msgNOCARRY asc '  CARRY CLEAR - CONNECT REPORTED OK'
         hex   0D00
msgRES   asc   'CONNECT RESULT: $'
         hex   00
msgDONE  asc   'DONE - PRESS A KEY'
         hex   0D00
