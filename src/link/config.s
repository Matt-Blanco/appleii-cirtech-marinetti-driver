         mx    %00                 ; 16-bit A and index, like the rest of
*                                   the module

*
* CONFIG - LinkConfigure: a dialog for address, subnet mask and gateway
*
* The TCP/IP control panel's Configure button ends up here.  Its CONFIGURE
* routine (Marinetti CDev/C.INIT.S) does:
*
*     TCPIPGetConnectData      the handle Marinetti keeps for this module
*     TCPIPEditLinkConfig      starts the desktop tools, loads us, calls us
*     TCPIPSetConnectData      saves whatever we left in that handle
*
* and LinkConnect is later handed the same handle, which readCONFIG reads.
* So all this has to do is show the three values, and on Save write them into
* the handle in readCONFIG's layout:
*
*     +0  word  version, $0001
*     +2  long  IP address       network order
*     +6  long  subnet mask
*     +10 long  gateway
*
* DNS is not here: the control panel's own Setup window has two DNS fields
* and saves them with TCPIPSetDNS.
*
* Modelled on Direct Connect's configuration window (LinkLayers/DC/
* DC.CONFIG.S), which builds its window from templates in memory - no
* resource fork, which Merlin32 could not build anyway.  Tool numbers and
* parameter orders are from ORCA/C's window.h, control.h, memory.h and
* misctool.h, and Marinetti's I.CALLS.S.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

CFGVER   =     $0001                ; readCONFIG accepts this version
CFGLEN   =     14

GetPort  =     $1C04
SetPort  =     $1B04
InitCursor =   $CA04
NewWindow2 =   $610E
CloseWindow =  $0B0E
DoModalWindow = $640E
SetLETextByID = $3A10
GetLETextByID = $3B10
SetHandleSize = $1902
SysBeep  =     $2C03
TCPIPConvertIPToHex = $0D36
TCPIPConvertIPToASCII = $0E36

ctlIP    =     $2004                ; control IDs, as DC numbers its own
ctlMASK  =     $2006
ctlGATE  =     $2008
ctlCANX  =     $2009
ctlSAVE  =     $200A

*---------- $0016 LinkConfigure
*
* disconnectHandle at 1,s, connectHandle at 5,s.  We keep nothing in the
* disconnect handle.

         mx    %00                 ; entered 16-bit, whatever precedes
doConfigure lda 5,s                 ; connectHandle
         sta   cfgH
         lda   7,s
         sta   cfgH+2

         lda   cfgH                 ; start from what is saved, or the
         sta   ptr1                 ; defaults if nothing valid is
         lda   cfgH+2
         sta   ptr1+2
         jsr   readCONFIG

         pea   $0000                ; GetPort(): the port to give back
         pea   $0000
         ldx   #GetPort
         jsl   TOOLBOX
         pla
         sta   oldPORT
         pla
         sta   oldPORT+2

         pea   $0000                ; NewWindow2(): space for the WindowPtr
         pea   $0000
         pea   $0000                ; titlePtr: none
         pea   $0000
         pea   $0000                ; refCon
         pea   $0000
         pea   $0000                ; contentDrawPtr: the controls draw
         pea   $0000
         pea   $0000                ; defProcPtr: standard window
         pea   $0000
         pea   $0000                ; paramTableDesc: a pointer
         lda   myBank               ; paramTableRef: our template
         pha
         pea   cfgWIND
         pea   $800E                ; rWindParam1
         ldx   #NewWindow2
         jsl   TOOLBOX
         pla
         sta   cfgWPTR
         pla
         sta   cfgWPTR+2
         ora   cfgWPTR              ; no window, nothing to show
         bne   :shown
         brl   :out

:shown   lda   cfgWPTR+2            ; draw into it
         pha
         lda   cfgWPTR
         pha
         ldx   #SetPort
         jsl   TOOLBOX

         ldx   #ctlIP               ; the three values as dotted quads
         ldy   #myIP
         jsr   putIP
         ldx   #ctlMASK
         ldy   #myMASK
         jsr   putIP
         ldx   #ctlGATE
         ldy   #gateIP
         jsr   putIP

*--- until Save or Cancel.  DoModalWindow handles typing, Tab between the
*    fields, Return for Save and Escape for Cancel.

:loop    pea   $0000                ; space for the item hit
         pea   $0000
         lda   myBank               ; eventRecPtr
         pha
         pea   cfgEVENT
         pea   $0000                ; updateProc
         pea   $0000
         pea   $0000                ; eventHook
         pea   $0000
         pea   $0000                ; beepProc
         pea   $0000
         pea   $4008                ; flags, as DC uses them
         ldx   #DoModalWindow
         jsl   TOOLBOX
         pla                        ; the control ID that was hit
         ply                        ; its high word is always zero here
         cmp   #ctlCANX
         beq   :close
         cmp   #ctlSAVE
         bne   :loop

*--- Save: all three must parse, or nothing is stored

         ldx   #ctlIP
         ldy   #newIP
         jsr   getIP
         beq   :bad
         ldx   #ctlMASK
         ldy   #newMASK
         jsr   getIP
         beq   :bad
         ldx   #ctlGATE
         ldy   #newGATE
         jsr   getIP
         beq   :bad
         jsr   storeCFG
         bra   :close

:bad     ldx   #SysBeep             ; 0.0.0.0 or unreadable: stay open
         jsl   TOOLBOX
         bra   :loop

:close   lda   cfgWPTR+2
         pha
         lda   cfgWPTR
         pha
         ldx   #CloseWindow
         jsl   TOOLBOX
         lda   oldPORT+2
         pha
         lda   oldPORT
         pha
         ldx   #SetPort
         jsl   TOOLBOX
         ldx   #InitCursor
         jsl   TOOLBOX

:out     DROP  8
         lda   #terrOK
         clc
         jmp   exitLINK

*---------- Show the address at Y in the line edit control X

putIP    phx                        ; the control, for SetLETextByID
         pea   $0000                ; ConvertIPToASCII(): space for strlen
         lda   |$0002,y             ; ipaddress, a long: high word first
         pha
         lda   |$0000,y
         pha
         lda   myBank               ; ddpstring
         pha
         pea   cfgTEXT
         pea   $0000                ; flags
         ldx   #TCPIPConvertIPToASCII
         jsl   TOOLBOX
         pla                        ; strlen: not needed
         plx

         lda   cfgWPTR+2            ; SetLETextByID(windPtr, ctlID, text)
         pha
         lda   cfgWPTR
         pha
         pea   $0000
         phx
         lda   myBank
         pha
         pea   cfgTEXT
         ldx   #SetLETextByID
         jsl   TOOLBOX
         rts

*---------- Read line edit control X into the address at Y
*
* Returns Z set when the result is 0.0.0.0, which is also what
* TCPIPConvertIPToHex gives back for text it cannot read: it always reports
* success (I.CALLS.S).

getIP    phy                        ; where the result goes
         lda   cfgWPTR+2            ; GetLETextByID(windPtr, ctlID, text)
         pha
         lda   cfgWPTR
         pha
         pea   $0000
         phx
         lda   myBank
         pha
         pea   cfgTEXT
         ldx   #GetLETextByID
         jsl   TOOLBOX

         lda   myBank               ; ConvertIPToHex(cvtRecPtr, ddipstring)
         pha
         pea   cfgCVT
         lda   myBank
         pha
         pea   cfgTEXT
         ldx   #TCPIPConvertIPToHex
         jsl   TOOLBOX

         ply
         lda   cfgCVT               ; network order, as readCONFIG wants it
         sta   |$0000,y
         lda   cfgCVT+2
         sta   |$0002,y
         ora   cfgCVT
         rts

*---------- Write the new values into the connect handle, and use them now

storeCFG pea   $0000                ; SetHandleSize(newSize, handle)
         pea   CFGLEN
         lda   cfgH+2
         pha
         lda   cfgH
         pha
         ldx   #SetHandleSize
         jsl   TOOLBOX
         bcs   :fail                ; Marinetti keeps what it had

         lda   cfgH                 ; the handle may have moved: dereference
         sta   ptr1                 ; it only now
         lda   cfgH+2
         sta   ptr1+2
         lda   [ptr1]
         sta   ptr2
         ldy   #$0002
         lda   [ptr1],y
         sta   ptr2+2

         lda   #CFGVER
         sta   [ptr2]
         ldy   #$0002
         lda   newIP
         sta   [ptr2],y
         ldy   #$0004
         lda   newIP+2
         sta   [ptr2],y
         ldy   #$0006
         lda   newMASK
         sta   [ptr2],y
         ldy   #$0008
         lda   newMASK+2
         sta   [ptr2],y
         ldy   #$000A
         lda   newGATE
         sta   [ptr2],y
         ldy   #$000C
         lda   newGATE+2
         sta   [ptr2],y

         lda   newIP                ; and use them without waiting for
         sta   myIP                 ; the next connect to read them back
         lda   newIP+2
         sta   myIP+2
         lda   newMASK
         sta   myMASK
         lda   newMASK+2
         sta   myMASK+2
         lda   newGATE
         sta   gateIP
         lda   newGATE+2
         sta   gateIP+2
:fail    rts

*===========================================================================
* The window, built from templates as Direct Connect builds its own
*===========================================================================

*   Window template: DC's, with our size.  96 x 314 in 640 mode, centred on
*   a 200 x 640 screen.

cfgWIND  da    $50                  ; template size
         da    $20A0                ; frame bits
         adrl  0                    ; no title
         adrl  0                    ; refCon
         da    0,0,0,0              ; zoom rectangle
         adrl  cfgCOLOR             ; colour table
         da    0,0                  ; origin y/x
         da    0,0                  ; data height/width
         da    0,0                  ; max height/width
         da    0,0                  ; scroll vert/horiz
         da    0,0                  ; page vert/horiz
         adrl  0                    ; info refCon
         da    0                    ; info height
         adrl  0                    ; frame defProc
         adrl  0                    ; info defProc
         adrl  0                    ; content defProc
         da    52,163,148,477       ; position: top, left, bottom, right
         adrl  -1                   ; in front
         adrl  cfgCTLS              ; controls
         da    3                    ; a pointer to a list of pointers

cfgCOLOR da    $0000                ; frame
         da    $0F0F                ; title
         da    $0000                ; title bar
         da    $F0FF                ; grow
         da    $00F0                ; info

cfgCTLS  adrl  ctTITLE
         adrl  ctLIP
         adrl  ctEIP
         adrl  ctLMASK
         adrl  ctEMASK
         adrl  ctLGATE
         adrl  ctEGATE
         adrl  ctNOTE
         adrl  ctCANX
         adrl  ctSAVE
         adrl  0

*--- static text: pCount, ID, rect, $81000000, flag, moreFlags, refCon,
*    text, length, justification - DC's LOCALIPctl

ctTITLE  da    9
         adrl  $2001
         da    5,12,14,300
         adrl  $81000000
         da    $0000
         da    $1000
         adrl  0
         adrl  txTITLE
         da    txTITLEn
         da    0

ctLIP    da    9
         adrl  $2003
         da    24,12,34,118
         adrl  $81000000
         da    $0000
         da    $1000
         adrl  0
         adrl  txIP
         da    txIPn
         da    0

ctLMASK  da    9
         adrl  $2005
         da    40,12,50,118
         adrl  $81000000
         da    $0000
         da    $1000
         adrl  0
         adrl  txMASK
         da    txMASKn
         da    0

ctLGATE  da    9
         adrl  $2007
         da    56,12,66,118
         adrl  $81000000
         da    $0000
         da    $1000
         adrl  0
         adrl  txGATE
         da    txGATEn
         da    0

ctNOTE   da    9
         adrl  $200B
         da    71,12,80,300
         adrl  $81000000
         da    $0000
         da    $1000
         adrl  0
         adrl  txNOTE
         da    txNOTEn
         da    0

*--- line edit: pCount, ID, rect, $83000000, flag, moreFlags, refCon,
*    maximum length, default text - DC's EDITctl

ctEIP    da    8
         adrl  ctlIP
         da    22,124,35,250
         adrl  $83000000
         da    $0000
         da    $7000
         adrl  0
         da    15
         adrl  txBLANK

ctEMASK  da    8
         adrl  ctlMASK
         da    38,124,51,250
         adrl  $83000000
         da    $0000
         da    $7000
         adrl  0
         da    15
         adrl  txBLANK

ctEGATE  da    8
         adrl  ctlGATE
         da    54,124,67,250
         adrl  $83000000
         da    $0000
         da    $7000
         adrl  0
         da    15
         adrl  txBLANK

*--- buttons: DC's CANXctl and SAVEctl, Escape and Return

ctCANX   da    9
         adrl  ctlCANX
         da    82,34,95,124
         adrl  $80000000
         da    $0000
         da    $3000
         adrl  0
         adrl  txCANX
         adrl  0
         hex   1B1B
         da    $0000,$0000

ctSAVE   da    9
         adrl  ctlSAVE
         da    82,188,95,280
         adrl  $80000000
         da    $0001                ; the default button
         da    $1000
         adrl  0
         adrl  txSAVE
         adrl  0
         hex   0D0D00000000

txTITLE  asc   'BlueSCSI DaynaPORT'
txTITLEn =     *-txTITLE
txIP     asc   'IP address:'
txIPn    =     *-txIP
txMASK   asc   'Subnet mask:'
txMASKn  =     *-txMASK
txGATE   asc   'Gateway:'
txGATEn  =     *-txGATE
txNOTE   asc   'DNS servers are set in TCP/IP Setup.'
txNOTEn  =     *-txNOTE
txBLANK  str   ' '
txCANX   str   'Cancel'
txSAVE   str   'Save'

*---------- Storage

cfgH     ds    4                    ; the connect handle
oldPORT  ds    4
cfgWPTR  ds    4
newIP    ds    4
newMASK  ds    4
newGATE  ds    4
cfgCVT   ds    6                    ; ConvertIPToHex: address, then port
cfgTEXT  ds    16                   ; a pstring of up to 15 characters
cfgEVENT ds    $2E                  ; DC's TASKRECORD size
