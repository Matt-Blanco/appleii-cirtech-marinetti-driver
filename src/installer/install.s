*
* BSLINK INSTALLER
*
* Copies the Marinetti link layer BSLINK from the folder this program runs
* from into SYSTEM/TCPIP on the GS/OS boot volume - the folder Marinetti
* reads as *:System:TCPIP (Programmers' Guide, page 131).
*
* ProDOS 8 cannot tell which volume GS/OS booted from, so every online
* volume with a SYSTEM/TCPIP directory is offered in turn, and nothing is
* written until one is accepted.  A BSLINK already there is replaced only
* after a second yes.
*
* If the copy fails part way the new file is deleted again: a truncated link
* layer in TCPIP would take the next boot down with it.
*
* The copy is created as type $BC, auxtype $4083, the two things Marinetti
* checks when it builds its list of link layers.
*
* ProDOS 8, Merlin, SYS file.  Launch it from the GS/OS Finder, or from
* BASIC.SYSTEM with -INSTALL.SYSTEM once PREFIX is set to its disk.
*
* (c) 2026 - written for the BlueSCSI processor-device work
*

         org   $2000
         typ   $FF
         lst   off
         DSK   InstallSystem

*---------- ProDOS

MLI      =     $BF00

mQUIT    =     $65
mCREATE  =     $C0
mDESTROY =     $C1
mGETINFO =     $C4
mONLINE  =     $C5
mOPEN    =     $C8
mREAD    =     $CA
mWRITE   =     $CB
mCLOSE   =     $CC
mGETEOF  =     $D1

errNOFIL =     $46                  ; file not found
errEOF   =     $4C                  ; end of file

*---------- Monitor

INIT     =     $FB2F
HOME     =     $FC58
RDKEY    =     $FD0C
CROUT    =     $FD8E
PRBYTE   =     $FDDA
COUT     =     $FDED
SETKBD   =     $FE89
SETVID   =     $FE93

*---------- Zero page scratch

mptr     =     $08

*---------- Buffers, clear of this program and of ProDOS

iobufS   =     $6000                ; 1K, page aligned, for the source
iobufD   =     $6400                ; 1K, page aligned, for the copy
onbuf    =     $6800                ; 256 bytes of ON_LINE records
data     =     $7000                ; copy buffer, $7000-$8FFF
CHUNK    =     $2000

*---------- Link layer identity

LTYPE    =     $BC
LAUX     =     $4083

*---------- Entry

start    cld
         sta   $C00C                ; 40 columns, whatever launched us
         sta   $C000
         sta   $C00E
         jsr   SETVID
         jsr   SETKBD
         jsr   INIT
         jsr   HOME

         lda   #$00
         sta   refS
         sta   refD
         sta   made
         sta   seen

         lda   #<msgTITLE
         ldy   #>msgTITLE
         jsr   puts

*--- the source: BSLINK, in the current prefix

         lda   #<srcNAME
         ldy   #>srcNAME
         jsr   getINFO
         bcc   :have
         pha
         lda   #<msgNOSRC
         ldy   #>msgNOSRC
         jsr   puts
         pla
         jsr   prERR
         jmp   quit

:have    lda   iTYPE
         cmp   #LTYPE
         bne   :notll
         lda   iAUX
         cmp   #<LAUX
         bne   :notll
         lda   iAUX+1
         cmp   #>LAUX
         beq   :vols
:notll   lda   #<msgNOTLL
         ldy   #>msgNOTLL
         jsr   puts
         jmp   quit

*--- every online volume

:vols    jsr   MLI
         dfb   mONLINE
         da    pONLINE
         bcc   :scan
         jsr   prERR
         jmp   quit

:scan    lda   #$00
         sta   vIDX
:vol     ldx   vIDX
         lda   onbuf,x
         beq   :end                 ; a zero byte ends the list
         and   #$0F
         beq   :next                ; an error record, no volume there

         jsr   mkDIR
         lda   #<dPATH
         ldy   #>dPATH
         jsr   getINFO
         bcs   :next
         lda   iSTOR
         cmp   #$0D                 ; a directory, not the SYSTEM file a
         bne   :next                ; BASIC disk carries

         inc   seen
         lda   #<msgASK
         ldy   #>msgASK
         jsr   puts
         jsr   putPATH
         lda   #<msgYN
         ldy   #>msgYN
         jsr   puts
         jsr   askYN
         bcc   install

:next    lda   vIDX
         clc
         adc   #16
         sta   vIDX
         bne   :vol

:end     lda   seen
         bne   :nope
         lda   #<msgNOTCP
         ldy   #>msgNOTCP
         jsr   puts
         jmp   quit
:nope    lda   #<msgNONE
         ldy   #>msgNONE
         jsr   puts
         jmp   quit

*---------- Install into the directory in dPATH

install  jsr   addFILE

*--- already there?

         lda   #<dPATH
         ldy   #>dPATH
         jsr   getINFO
         bcc   :exists
         cmp   #errNOFIL
         beq   :create
         jmp   fail

:exists  lda   #<msgREPL
         ldy   #>msgREPL
         jsr   puts
         jsr   askYN
         bcc   :del
         lda   #<msgNONE
         ldy   #>msgNONE
         jsr   puts
         jmp   quit

:del     jsr   MLI
         dfb   mDESTROY
         da    pDEST
         bcc   :create
         jmp   fail

*--- create, then open both

:create  jsr   MLI
         dfb   mCREATE
         da    pCREATE
         bcc   :made
         jmp   fail
:made    inc   made

         lda   #<msgCOPY
         ldy   #>msgCOPY
         jsr   puts

         jsr   MLI
         dfb   mOPEN
         da    pOPENS
         bcc   :opens
         jmp   fail
:opens   lda   oREFS
         sta   refS
         sta   rREF

         jsr   MLI
         dfb   mOPEN
         da    pOPEND
         bcc   :opend
         jmp   fail
:opend   lda   oREFD
         sta   refD
         sta   wREF

*--- a chunk at a time until the source runs out

:copy    jsr   MLI
         dfb   mREAD
         da    pREAD
         bcc   :write
         cmp   #errEOF
         beq   :check
         jmp   fail

:write   lda   rTRANS
         sta   wREQ
         lda   rTRANS+1
         sta   wREQ+1
         jsr   MLI
         dfb   mWRITE
         da    pWRITE
         bcc   :copy
         jmp   fail

*--- the copy must be as long as the original

:check   lda   refS
         jsr   getEOF
         bcc   :srceof
         jmp   fail
:srceof  ldx   #2
:keep    lda   eMARK,x
         sta   srcEOF,x
         dex
         bpl   :keep

         lda   refD
         jsr   getEOF
         bcc   :dsteof
         jmp   fail
:dsteof  ldx   #2
:cmp     lda   eMARK,x
         cmp   srcEOF,x
         bne   :short
         dex
         bpl   :cmp

*--- close; closing the copy flushes its last block, so check it

         lda   refS
         jsr   closeREF
         lda   #$00
         sta   refS
         lda   refD
         ldx   #$00
         stx   refD
         jsr   closeREF
         bcc   :done
         jmp   fail

:short   lda   #<msgSHORT
         ldy   #>msgSHORT
         jsr   puts
         jmp   cleanup

:done    lda   #<msgDONE
         ldy   #>msgDONE
         jsr   puts
         jsr   putPATH
         jsr   CROUT
         lda   #<msgNEXT
         ldy   #>msgNEXT
         jsr   puts
         jmp   quit

*---------- Failure: report, close, and take the partial copy away

fail     jsr   prERR

cleanup  jsr   closeALL
         lda   made
         beq   quit
         jsr   MLI
         dfb   mDESTROY
         da    pDEST
         bcs   :left
         lda   #<msgRMV
         ldy   #>msgRMV
         jsr   puts
         jmp   quit

:left    jsr   prERR
         lda   #<msgLEFT
         ldy   #>msgLEFT
         jsr   puts
         jsr   putPATH
         jsr   CROUT

*---------- Wait for a key, then back to whatever launched us

quit     lda   #<msgKEY
         ldy   #>msgKEY
         jsr   puts
         jsr   RDKEY
         jsr   MLI
         dfb   mQUIT
         da    pQUIT
         brk   $00                  ; QUIT does not return

*---------- dPATH = /VOLUME/SYSTEM/TCPIP, from the ON_LINE record at X

mkDIR    lda   onbuf,x
         and   #$0F
         sta   cnt
         lda   #'/'
         sta   dPATH+1
         ldy   #1
:name    lda   onbuf+1,x
         sta   dPATH+1,y
         inx
         iny
         dec   cnt
         bne   :name
         ldx   #0
:sys     lda   sufDIR,x
         sta   dPATH+1,y
         inx
         iny
         cpx   #sufDIRL
         bne   :sys
         sty   dPATH
         rts

*---------- Append /BSLINK to dPATH

addFILE  ldy   dPATH
         ldx   #0
:loop    lda   sufFILE,x
         sta   dPATH+1,y
         inx
         iny
         cpx   #sufFILEL
         bne   :loop
         sty   dPATH
         rts

*---------- GET_FILE_INFO on the pathname at A/Y

getINFO  sta   iPATH
         sty   iPATH+1
         jsr   MLI
         dfb   mGETINFO
         da    pINFO
         rts

*---------- GET_EOF on the reference number in A, into eMARK

getEOF   sta   eREF
         jsr   MLI
         dfb   mGETEOF
         da    pEOF
         rts

*---------- CLOSE the reference number in A, if there is one

closeREF cmp   #$00
         beq   :none
         sta   cREF
         jsr   MLI
         dfb   mCLOSE
         da    pCLOSE
         rts
:none    clc
         rts

closeALL lda   refS
         jsr   closeREF
         lda   #$00
         sta   refS
         lda   refD
         jsr   closeREF
         lda   #$00
         sta   refD
         rts

*---------- Y or N from the keyboard: carry clear for yes

askYN    jsr   RDKEY
         and   #$DF                 ; fold lower case
         cmp   #"Y"
         beq   :yes
         cmp   #"N"
         beq   :no
         cmp   #$9B                 ; escape counts as no
         bne   askYN
:no      lda   #<msgNO
         ldy   #>msgNO
         jsr   puts
         sec
         rts
:yes     lda   #<msgYES
         ldy   #>msgYES
         jsr   puts
         clc
         rts

*---------- Print the ProDOS error in A

prERR    pha
         lda   #<msgERR
         ldy   #>msgERR
         jsr   puts
         pla
         jsr   PRBYTE
         jmp   CROUT

*---------- Print dPATH

putPATH  ldx   #0
:loop    cpx   dPATH
         beq   :done
         lda   dPATH+1,x
         ora   #$80
         jsr   COUT
         inx
         bne   :loop
:done    rts

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

*---------- MLI parameter blocks

pONLINE  dfb   2
         dfb   0                    ; unit 0: every volume
         da    onbuf

pINFO    dfb   $0A
iPATH    da    0
iACCESS  ds    1
iTYPE    ds    1
iAUX     ds    2
iSTOR    ds    1
         ds    10                   ; blocks used, dates and times

pCREATE  dfb   7
         da    dPATH
         dfb   $E3                  ; destroy, rename, write, read
         dfb   LTYPE
         da    LAUX
         dfb   $01                  ; standard file
         da    0                    ; date and time 0: now
         da    0

pDEST    dfb   1
         da    dPATH

pOPENS   dfb   3
         da    srcNAME
         da    iobufS
oREFS    ds    1

pOPEND   dfb   3
         da    dPATH
         da    iobufD
oREFD    ds    1

pREAD    dfb   4
rREF     ds    1
         da    data
         da    CHUNK
rTRANS   ds    2

pWRITE   dfb   4
wREF     ds    1
         da    data
wREQ     ds    2
         ds    2                    ; transfer count

pEOF     dfb   2
eREF     ds    1
eMARK    ds    3

pCLOSE   dfb   1
cREF     ds    1

pQUIT    dfb   4
         dfb   0
         da    0
         dfb   0
         da    0

*---------- Pathnames (low ASCII, as ProDOS wants them)

srcNAME  str   'BSLINK'
sufDIR   asc   '/SYSTEM/TCPIP'
sufDIRL  =     *-sufDIR
sufFILE  asc   '/BSLINK'
sufFILEL =     *-sufFILE

*---------- Variables

refS     ds    1
refD     ds    1
made     ds    1
seen     ds    1
vIDX     ds    1
cnt      ds    1
srcEOF   ds    3
dPATH    ds    65

*---------- Messages (high ASCII for COUT)

msgTITLE asc   "BSLINK INSTALLER"
         hex   8D8D
         asc   "COPIES THE BLUESCSI LINK LAYER INTO"
         hex   8D
         asc   "SYSTEM/TCPIP ON THE GS/OS BOOT VOLUME."
         hex   8D8D00
msgNOSRC asc   "BSLINK MUST BE BESIDE THIS PROGRAM."
         hex   8D00
msgNOTLL asc   "BSLINK IS NOT A LINK LAYER ($BC/$4083)"
         hex   8D00
msgASK   asc   "INSTALL TO "
         hex   00
msgYN    asc   "? (Y/N) "
         hex   00
msgYES   asc   "YES"
         hex   8D00
msgNO    asc   "NO"
         hex   8D00
msgNOTCP asc   "NO VOLUME HAS A SYSTEM/TCPIP FOLDER."
         hex   8D
         asc   "INSTALL MARINETTI FIRST."
         hex   8D00
msgNONE  asc   "NOTHING INSTALLED."
         hex   8D00
msgREPL  asc   "ALREADY INSTALLED. REPLACE IT? (Y/N) "
         hex   00
msgCOPY  asc   "COPYING..."
         hex   8D00
msgSHORT asc   "THE COPY IS SHORTER THAN THE ORIGINAL."
         hex   8D00
msgDONE  asc   "INSTALLED "
         hex   00
msgNEXT  asc   "RESTART GS/OS, THEN CHOOSE IT IN THE"
         hex   8D
         asc   "TCP/IP CONTROL PANEL."
         hex   8D00
msgRMV   asc   "PARTIAL COPY REMOVED."
         hex   8D00
msgLEFT  asc   "COULD NOT REMOVE THE PARTIAL COPY."
         hex   8D
         asc   "DELETE IT BEFORE RESTARTING:"
         hex   8D00
msgERR   asc   "PRODOS ERROR $"
         hex   00
msgKEY   hex   8D
         asc   "PRESS A KEY TO QUIT."
         hex   00
