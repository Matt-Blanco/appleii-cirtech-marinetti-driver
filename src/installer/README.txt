BlueSCSI Link for Marinetti
===========================

BSLink is a Marinetti link layer. It
puts an Apple IIgs on the network
through a BlueSCSI v2 with Wi-Fi,
attached to a Cirtech SCSI Interface
card.

This is an early release.


What you need
-------------
- Apple IIgs with GS/OS System 6
- Marinetti 3.0, already installed
- Cirtech SCSI Interface card, in any
  slot
- BlueSCSI v2 with Wi-Fi. Its network
  device must be at SCSI ID 3, and
  WiFiSSID and WiFiPassword must be
  set in bluescsi.ini.


Installing
----------
1. Start GS/OS as usual.
2. Open this disk and double-click
   INSTALL.SYSTEM.
3. It asks about each volume that has
   a System:TCPIP folder. Answer Y for
   the volume GS/OS starts from.
4. When it says INSTALLED, press a key
   and restart.

If BSLINK is already installed, the
installer asks before replacing it.

You can also start the Apple IIgs from
this disk. The installer then runs by
itself, but it can only see volumes
that ProDOS 8 can see.


Setting up
----------
1. Open the TCP/IP control panel.
2. Choose BlueSCSI DaynaPORT as the
   link layer.
3. Use Configure to enter an IP
   address, subnet mask and gateway.
   There is no DHCP yet, so choose an
   address your router will not give
   to another device.
4. Set the DNS servers in TCP/IP
   Setup.
5. Connect.


Removing it
-----------
Delete BSLINK from System:TCPIP and
restart.

If GS/OS stops while starting up after
you install BSLink, start from another
disk and delete System:TCPIP:BSLINK
from your startup volume.

Marinetti loads every link layer in
System:TCPIP. Remove any older BSLink
test copies from that folder.
