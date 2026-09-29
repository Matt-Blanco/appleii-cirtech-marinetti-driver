*
* LINKTEST - install check and repair for BSLink
*
* A file copied into System:TCPIP often arrives as type NON with auxtype
* $0000, because the transfer kept the data and dropped the file's identity.
* Marinetti never looks inside such a file, so the module never appears in
* the link layer list.
*
* This program:
*
*   1. GetFileInfo on *:System:TCPIP:BSLink - what type is it really?
*   2. If it is wrong, SetFileInfo stamps $BC / $4083 back on
*   3. TCPIPGetModuleNames - what does Marinetti list now?
*
* Step 3 is the one that keeps earning its keep.  Marinetti loads every
* module in the folder, calls LinkModuleInfo on each, and returns the list.
* If BSLink appears there but not in the control panel popup, the module is
* loading fine and the popup is objecting to something else - most likely
* liMethodID, which is supposed to be registered with Marinetti's author.
*
* Tool call numbers were read out of the shipped BlueSCSI application rather
* than recalled, so they match working code.
*
* GS/OS S16.  Launch it from the Finder.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         mx    %00
         rel
         lst   off

*---------- Tools

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

TCPIPStartUp = $0236
TCPIPShutDown = $0336
TCPIPGetModuleNames = $4C36

MARINETTI =    $36                  ; the TCP/IP tool set number

*---------- What a link layer module must look like

LLTYPE   =     $00BC
LLAUXLO  =     $4083
LLAUXHI  =     $0000

*---------- Direct page

listPTR  =     $10
count    =     $14
nameLEN  =     $16

*===========================================================================

main     phk
         plb
         sep   #$20                 ; remember our bank for string pushes
         phk
         pla
         sta   myBank
         rep   #$20
         stz   myBank+1

         jsr   toolsUP

         lda   #msgTITLE
         jsr   say

         jsr   dirLIST
         jsr   fileCHECK
         jsr   moduleLIST

         lda   #msgDONE
         jsr   say
         jsr   waitKEY
         jsr   toolsDOWN

         jsl   GSOS                 ; Quit
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

         pea   $0000                ; MMStartUp returns our UserID
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

*===========================================================================
* 0. What is actually in System:TCPIP
*===========================================================================
*
* Marinetti scans the whole folder, so the file's name does not matter - but
* its file type and auxtype do.  Listing every entry with its type settles
* both questions at once: is our module there at all, and did the copy keep
* $BC / $4083.

dirLIST  lda   #msgDIR
         jsr   say

         jsl   GSOS                 ; Open the directory
         dw    $2010
         adrl  opPARMS
         bcc   :opened

         pha
         lda   #msgERR
         jsr   say
         pla
         jsr   hexWORD
         jmp   crout

:opened  lda   opREF
         sta   deREF
         sta   clREF

:next    jsl   GSOS                 ; GetDirEntry, sequentially
         dw    $001C
         adrl  dePARMS
         bcs   :done

         sep   #$20                 ; the name, as a GS/OS result buffer
         ldy   #$0000
:nloop   cpy   deNAME+2
         bcs   :padded
         lda   deNAME+4,y
         ora   #$80
         jsr   putc
         iny
         bra   :nloop
:padded  cpy   #$0010               ; pad the column out to 16
         bcs   :types
         lda   #" "
         jsr   putc
         iny
         bra   :padded
:types   rep   #$20

         lda   deTYPE
         jsr   hexWORD
         lda   #" "
         jsr   putc
         lda   deAUX+2
         jsr   hexWORD
         lda   deAUX
         jsr   hexWORD
         jsr   crout
         bra   :next

:done    jsl   GSOS                 ; Close
         dw    $2014
         adrl  clPARMS
         jmp   crout

*===========================================================================
* 1. The file, and its identity
*===========================================================================

fileCHECK lda  #msgFILE
         jsr   say

         jsr   getINFO
         bcc   :got

         pha
         lda   #msgERR
         jsr   say
         pla
         jsr   hexWORD
         jsr   crout
         lda   #msgWHERE
         jmp   say

:got     jsr   showINFO
         jsr   isRIGHT
         bcs   :stamp

         lda   #msgGOODF
         jmp   say

*--- wrong identity: put it back

:stamp   lda   #msgBADF
         jsr   say

         lda   fiACCESS             ; keep the access byte we found
         sta   siACCESS
         lda   #LLTYPE
         sta   siTYPE
         lda   #LLAUXLO
         sta   siAUX
         lda   #LLAUXHI
         sta   siAUX+2

         jsl   GSOS                 ; SetFileInfo
         dw    $0005
         adrl  siPARMS
         bcc   :again

         pha
         lda   #msgSETERR
         jsr   say
         pla
         jsr   hexWORD
         jmp   crout

:again   jsr   getINFO              ; prove it took
         bcs   :fail
         jsr   showINFO
         jsr   isRIGHT
         bcs   :fail
         lda   #msgFIXED
         jmp   say
:fail    lda   #msgSTILL
         jmp   say

*--- GetFileInfo into the block below

getINFO  jsl   GSOS
         dw    $0006
         adrl  fiPARMS
         rts

*--- print what we found

showINFO lda   #msgTYPE
         jsr   say
         lda   fiTYPE
         jsr   hexWORD
         lda   #msgAUX
         jsr   say
         lda   fiAUX+2
         jsr   hexWORD
         lda   fiAUX
         jsr   hexWORD
         jmp   crout

*--- carry clear when the identity is what Marinetti needs

isRIGHT  lda   fiTYPE
         cmp   #LLTYPE
         bne   :no
         lda   fiAUX
         cmp   #LLAUXLO
         bne   :no
         lda   fiAUX+2
         cmp   #LLAUXHI
         bne   :no
         clc
         rts
:no      sec
         rts

*===========================================================================
* 2. What Marinetti lists
*===========================================================================

moduleLIST lda #msgLIST
         jsr   say

         lda   #MARINETTI           ; LoadOneTool(toolNum, minVersion):
         pha                        ; two words, no result space
         pea   $0300
         ldx   #LoadOneTool
         jsl   TOOLBOX
         bcc   :loaded

         lda   #msgNOTCP
         jmp   say

:loaded  ldx   #TCPIPStartUp
         jsl   TOOLBOX

         pea   $0000                ; space for the list pointer
         pea   $0000
         ldx   #TCPIPGetModuleNames
         jsl   TOOLBOX
         pla
         sta   listPTR
         pla
         sta   listPTR+2

         lda   listPTR
         ora   listPTR+2
         bne   :walk
         lda   #msgNOLIST
         jmp   say

:walk    stz   count

:entry   lda   [listPTR]            ; a nil method ID ends the list
         beq   :done

         jsr   hexWORD              ; method ID, then the name
         lda   #" "
         jsr   putc
         lda   #" "
         jsr   putc

         ldy   #$0002
         lda   [listPTR],y
         and   #$00FF
         sta   nameLEN
         beq   :next
         ldy   #$0003

:name    lda   [listPTR],y
         and   #$00FF
         phy
         jsr   putc
         ply
         iny
         cpy   nameLEN
         bcc   :name
         beq   :name

:next    jsr   crout
         inc   count

         lda   listPTR              ; records are 64 bytes
         clc
         adc   #$0040
         sta   listPTR
         lda   listPTR+2
         adc   #$0000
         sta   listPTR+2
         bra   :entry

:done    lda   #msgCOUNT
         jsr   say
         lda   count
         jsr   hexWORD
         jsr   crout

         ldx   #TCPIPShutDown
         jsl   TOOLBOX
         rts

*===========================================================================
* Output
*===========================================================================

*--- the C string whose address is in A, in our bank

waitKEY  sep   #$20                 ; straight off the keyboard hardware
:loop    ldal  $E0C000
         bpl   :loop
         stal  $E0C010
         rep   #$20
         rts

say      tay
         lda   myBank
         pha
         tya
         pha
         ldx   #WriteCString
         jsl   TOOLBOX
         rts

putc     and   #$00FF
         ora   #$0080               ; the text tools want high ASCII
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

*===========================================================================
* Data
*===========================================================================

*--- GetFileInfo, class 1: pathname, access, fileType, auxType, storageType

fiPARMS  dw    5
         adrl  thePATH
fiACCESS dw    0
fiTYPE   dw    0
fiAUX    adrl  0
         dw    0

*--- SetFileInfo, class 1: pathname, access, fileType, auxType

siPARMS  dw    4
         adrl  thePATH
siACCESS dw    0
siTYPE   dw    0
siAUX    adrl  0

*--- Open / GetDirEntry / Close parameter blocks

opPARMS  dw    2
opREF    dw    0
         adrl  dirPATH

dePARMS  dw    13
deREF    dw    0
         dw    0                    ; flags
         dw    0                    ; base: displacement is absolute
         dw    1                    ; displacement: the next entry
         adrl  deNAME
         dw    0                    ; entryNum
deTYPE   dw    0
         adrl  0                    ; eof
         adrl  0                    ; blockCount
         ds    8                    ; createDateTime
         ds    8                    ; modDateTime
         dw    0                    ; access
deAUX    adrl  0

clPARMS  dw    1
clREF    dw    0

deNAME   dw    36                   ; result buffer: size, length, characters
         dw    0
         ds    32

dirPATH  dw    dirEND-dirSTR
dirSTR   asc   '*:System:TCPIP'
dirEND   =     *

thePATH  dw    pathEND-pathSTR
pathSTR  asc   '*:System:TCPIP:BSLink'
pathEND  =     *

myBank   ds    2
userID   ds    2

msgTITLE asc   'LINKTEST - BSLINK INSTALL CHECK',0D,0D,00
msgFILE  asc   '1. THE FILE',0D,00
msgERR   asc   '   GS/OS ERROR $',00
msgWHERE asc   '   IS IT AT *:SYSTEM:TCPIP:BSLINK ?',0D,00
msgTYPE  asc   '   FILETYPE $',00
msgAUX   asc   '   AUXTYPE $',00
msgGOODF asc   '   CORRECT ALREADY',0D,00
msgBADF  asc   '   WRONG - STAMPING $BC / $4083',0D,00
msgSETERR asc  '   SETFILEINFO FAILED $',00
msgFIXED asc   '   FIXED - REBOOT, THEN CHECK THE POPUP',0D,00
msgSTILL asc   '   STILL WRONG',0D,00

msgDIR   asc   'FILES IN SYSTEM:TCPIP'
         hex   0D00
msgLIST  asc   0D,'2. MODULES MARINETTI CAN SEE',0D,00
msgNOTCP asc   '   MARINETTI WILL NOT LOAD',0D,00
msgNOLIST asc  '   NO LIST RETURNED',0D,00
msgCOUNT asc   '   MODULES FOUND: $',00
msgDONE  asc   0D,'DONE',0D,00
