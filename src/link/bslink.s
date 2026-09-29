*
* BSLINK - a Marinetti link layer for the BlueSCSI DaynaPORT
*          reached through a Cirtech SCSI Interface
*
* (c) 2026 - built on the transport proven in ../src
*
* Marinetti loads link layer modules from *:System:TCPIP.  They are OMF files
* of type $BC, auxtype $4083 (Marinetti 2.0 Programmers' Guide, page 131).
* The load point is the dispatcher, called in native mode with:
*
*     A    the module's direct page, or $0000 if none
*     X    the call number
*     Y    Marinetti's UserID - every allocation must use it, not ours
*     DP   Marinetti's direct page; $E0-$FF are ours and survive calls
*     S    the RTL address, then the parameters
*
* On exit A holds a terr_* error ANDed with terrmask, carry flags the error,
* DBK and DP are restored, and the parameters are off the stack.
*
* What this module owns
* ---------------------
* Marinetti passes IP datagrams and expects IP datagrams back.  Ethernet sits
* in between, so everything below IP is ours:
*
*   - the Cirtech register-level SCSI transport      (scsi16.s)
*   - the DaynaPORT command set                      (scsi16.s)
*   - ethernet framing and ARP                       (arp.s)
*
* ARP matters because Marinetti knows nothing about hardware addresses.  We
* answer requests for our own address and resolve the address of whatever we
* are sending to, caching what we learn.
*
* Addressing is static: address, netmask and gateway come from the connect
* data that LinkConfigure's dialog stores (config.s), or built-in defaults.  DHCP would also have to run
* down here, below Marinetti, and is left for later.
*
* STATUS: written against the documented interface and on top of a transport
* proven on hardware, but this module has not yet been run on a IIgs.  Expect
* to iterate, exactly as the milestones in ../README.md did.
*

         mx    %00
         rel
         lst   off

         PUT   module
         PUT   scsi16
         PUT   arp
         PUT   config
