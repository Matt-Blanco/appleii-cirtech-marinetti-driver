# Cirtech SCSI / Marinetti Link Layer 

The following repository drives the Cirtech SCSI Interface directly, so an Apple IIgs can talk to
non-block SCSI devices — specifically the BlueSCSI DaynaPORT processor device. The custom Link Layer allows third-party SCSI cards (like the 1988 UK Cirtech SCSI Card) to manage a network connection between [BlueSCSI](https://bluescsi.com) and [Marinetti](https://www.apple2.org/marinetti/).

## Why make a driver for a 40yr old computer?

I wanted to explore vintage computers and take a step back in time. My experience has primarily been in front-end development, but the history of interfaces is incredibly rich. I chose to walk down the software stack to get as low-level as possible, and to see what it would be like to resurrect a dormant computer.

## Why a Custom Driver is Needed

Existing drivers to use the BlueSCSI with an Apple II expect SCSI cards manufactured by Apple and not third-party SCSI cards. For anyone with a third-party SCSI card, you can now expand the capabilities of an Apple II.

Existing GS/OS drivers reach through the bus, which only drives Apple's own SCSI cards.
On a Cirtech card they load, find no devices and go quiet.

The Cirtech ROM itself is no help either. Its published interfaces are the ProDOS
Block Device Protocol and a SmartPort emulation — STATUS, READ BLOCK, WRITE BLOCK,
FORMAT, INIT. All block-only, with no way to issue an arbitrary CDB. The BlueSCSI
toolbox needs Inquiry `$12`, Send `$0A`, Receive `$08`, Receive Diagnostic `$1C`
and `$D0`-`$DA`, none of which can be expressed through SmartPort.

The card's hardware has no such limit. It is a discrete SCSI implementation whose
registers can drive any phase sequence. So: program the registers ourselves.

## What's here

```
rom/     the 8 KB EPROM dump (2764)
tools/   rommap.py     - ROM layout, region extraction
         dis6502.py    - 6502 disassembler
         prodos_add.py - put a file on a ProDOS disk image
         prodos_new.py - create an empty, optionally bootable, ProDOS image
docs/    hardware.md   - register map, sequences, hardware results
         *.asm         - disassembly of the slot pages and expansion ROM
src/     scsicore.s    - the working transport, PUT into the programs below
         probe.s       - milestone 1: find the card, select a target
         inquiry.s     - milestone 2: a full INQUIRY command
         toolbox.s     - milestone 3a: BlueSCSI metadata $D9/$01
disk/    BlueSCSILink.po   - bootable ProDOS 8 disk with all three
         FD60_512 probe.po - Test disk containing all iterations of the custom link layer.
```

Regenerate the disassembly with:

```
python3 tools/rommap.py rom/cirtech_scsi_2764.bin
python3 tools/dis6502.py rom/cirtech_scsi_2764.bin 0x700 0x100 0xC700 > docs/slot7_fast.asm
python3 tools/dis6502.py rom/cirtech_scsi_2764.bin 0x800 0x800 0xC800 > docs/expansion_fast.asm
```

Linear disassembly of the expansion ROM drifts out of alignment across data
tables. When a routine looks like nonsense, disassemble from its entry point:

```
python3 tools/dis6502.py rom/cirtech_scsi_2764.bin 0xAFB 0x105 0xCAFB
```

## About the Hardware

Full detail in `docs/hardware.md`. In short:

- The card is found by ID bytes `$Cs01`=`$20`, `$Cs03`=`$00`, `$Cs05`=`$03`,
  `$CsFB`=`$02`. `$Cs07` is `$00` for FAST mode, `$3C` for SAFE.
- Registers live at `$C080 + $10 * slot`. `+0` data port (both directions), `+1`
  control on write and status on read (ACK is bit 4, data drive is bit 0), `+2`
  transfer engine, `+3` expected phase, `+4` bus status (BSY `$40`, REQ `$20`,
  phase `$1C`), `+5` card status, `+6` final byte, `+7` strobe, `+8` inverted
  readback, `+C` block FIFO.
- Selection, the phase dispatcher and the byte handshake are decoded from the ROM
  at `$CB96`, `$CC63` and `$CEA8`.
- **Verified on hardware.** A full INQUIRY to the DaynaPORT at ID 3 returned
  `Dayna` / `SCSI/Link` with status GOOD.

## Building

The sources are [Merlin](https://brutaldeluxe.fr/products/crossdevtools/merlin/) syntax, plain 6502, ProDOS 8, origin `$2000`. `probe.s` is
self-contained; `inquiry.s` and `toolbox.s` end with `PUT scsicore`.

```
merlin32 . src/toolbox.s
```

- On the Mac: [Merlin32](https://www.brutaldeluxe.fr/products/crossdevtools/merlin/),
  then move the binary onto a disk image.
- On the IIgs: Merlin 8/16 directly.

BRUN it from a ProDOS 8 prompt.

Merlin32 writes `src/compiled/_FileInformation.txt` with `AuxType(0000)`. ProDOS
uses the aux type as a BIN file's load address, so it must say `AuxType(2000)` to
match the `org`, otherwise BRUN loads the code at `$0000` and the machine hangs.
Merlin32 rewrites that file on every assembly, so check it before building a disk
image (Cadius reads it when it copies the file in).

## Requirements

- An Apple IIgs
- GS/OS
  - System 6.0.1 or System 6.0.4 
- BlueSCSI V2
  - With a network card file labelled as `NE3.hda`
  - `bluescsi.ini` with WiFi configured
  ```
  [SCSI]
  WiFiSSID=[Your WiFi Name]
  WiFiPassword=[Your Wifi Password]
  Debug=0
  EnableToolbox=1	; Enabled
  [SCSI2]
  Vendor=Dayna
  Product=SCSI/Link
  ```
- A Cirtech SCSI Card
  - Placed in expandable card Slot 7

## Installation

Place the `BlueSCSILink.po` or `BlueSCSILink.2mg` file onto your Apple II disk and run the `INSTALLER.SYS` file to copy the `BSLINK` Marinetti Link Layer into the `SYSTEM:TCPIP` folder of your GS/OS boot drive. For more manual installation follow the below steps:

To install the link layer without the installer, `/src/compiled/BSLink` should be moved onto a ProDOS disk using CiderPress or DiskJockey under the `SYSTEM:TCPIP` folder.

A connection can also be tested with the `PING` application. After the network has been configured in the TCP/IP Control Panel, the application can be run to test a connection between a modern computer and the Apple IIgs. 

## Safety

These programs drive the SCSI bus without going through the ROM. A mistake can
wedge the bus or, in the worst case, disturb a transfer in flight.

None of them do disk I/O of their own, so running them from a SCSI volume is safe
as long as nothing else is writing. Back up the SD card first, run them as the
first thing after a boot, and reboot afterwards. Every exit path releases the bus
and then resets it with the card's own SmartPort INIT call.

## References

- `~/Downloads/Cirtech SCSI/Cirtech SCSI User's Manual.pdf` — chapter 6 has the ID
  bytes, FAST/SAFE modes, the ProDOS block protocol and the SmartPort call format.
- [`github.com/antoinevignau/source/tree/main/scsi2`](github.com/antoinevignau/source/tree/main/scsi2) — GS/OS driver structure, and
  every CDB the BlueSCSI toolbox uses, working command sequences, as GS/OS calls,  the DaynaPort SCSI/Link command set. The authority for `$08`, `$09`, `$0A`, `$0C` and `$0E`.
- BlueSCSI toolbox docs: https://github.com/BlueSCSI/BlueSCSI-v2/wiki/Toolbox-Developer-Docs

## Acknowledgements

The following work would not have been possible without the existing Apple II development community. Thank you to:

- <em>Thomas Shreeve</em> for providing the Cirtech SCSI card and responding to all of my questions
- <em>[Brutal Delux Software](https://brutaldeluxe.fr/)</em> for developing the initial drivers for the BlueSCSI and Apple IIgs
- <em>[AppleFritter](https://www.applefritter.com/forum/84)</em> the forum used to find answers to obscure questions
- <em>[Speccie's Software Archive](https://speccie.uk/software/)</em> for providing software tools to compile assembly and the starter disk containing a Marinetti installation 
- <em>[Nikolai Kozak](https://nkozak.com/about)</em> for introducing me to the BlueSCSI
- <em>[Zachary Blanco](https://blanco.io)</em> for finding an Apple II at a garage sale in ~2010
