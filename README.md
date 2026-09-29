# Cirtech SCSI — custom driver work

Driving the Cirtech SCSI Interface directly, so an Apple IIgs can talk to
non-block SCSI devices — specifically the BlueSCSI DaynaPORT processor device.

## Why this exists

The GS/OS SCSI drivers in `../scsi2` (`SCSIProc.Driver`, `SCSICOMM.Driver`) reach
the bus through Apple's `SCSI.Manager`, which only drives Apple's own SCSI cards.
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
disk/    FD40_512 probe.po - bootable ProDOS 8 disk with all three
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

## What we know

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

## Roadmap

**Milestone 1 — prove the register map. DONE 2026-09-22.** `src/probe.s`. Finds
the card, reports FAST or SAFE, selects the target. Selection of ID 3 returned
bus status `$68`: BSY, REQ, phase 2, command out.

**Milestone 2 — arbitrary CDB. DONE 2026-09-22.** `src/inquiry.s`. Command out,
data in, status and message in. INQUIRY returned 36 bytes: device type `$03`
processor, vendor `Dayna`, product `SCSI/Link`, status `$00`, message `$00`.

**Milestone 3 — the BlueSCSI toolbox and the network. DONE 2026-09-23.** An ARP
request went out and its reply came back, read off the DaynaPORT byte for byte.
Every SCSI phase is exercised: command out, data in, data out, status, message
in. See "Hardware results" in `docs/hardware.md`.

Lesson worth keeping: test against an access point you control. A managed
network that drops frames from an unleased source address looks exactly like
broken code, and cost us several rounds.

**Milestone 3 (detail) — the BlueSCSI toolbox.** The transport now lives in
`src/scsicore.s` as a `PUT` include: a program fills `cdb`/`cdbLEN`, and
`outBUF`/`outLEN` for a data-out command, then calls `runSCSI`. Results come back
in `buf`/`datIDX`, `status` and `message`.

- `src/toolbox.s` — metadata `$D9` sub-command `$01`. **DONE 2026-09-22:** API
  version 0, capabilities `$07` (large transfers, large send, working dir). A
  10-byte CDB, after INQUIRY proved a 6-byte one.
- `src/wifi.s` — Receive Diagnostic `$1C` sub-command `$04`, Wi-Fi info.
  **DONE 2026-09-23:** 76 bytes, SSID `sandbox370` at offset 2, in the
  scan-result entry format behind a two-byte header.
- `src/netrecv.s` — the real DaynaPORT sequence: enable `$0E`, wait, statistics
  `$09` for the MAC, then read `$08` repeatedly. A first version that just sent
  `$08` returned nothing but zeros, because the interface was never enabled and
  byte 5 of the read CDB was `00` instead of `C0`. **Ready to test.**
- Next: Send `$0A`, the first command needing a **data-out** phase. The core
  handles that phase but has not exercised it yet.

`../scsi2/bluescsi.s` has all of these as GS/OS DControl and DStatus calls. The
CDBs carry over unchanged; only the transport differs.

**Milestone 4 — the Marinetti link layer. DISPATCHER PROVEN 2026-09-24.**
`link/modtest.s` assembles the module into a ProDOS 8 binary and calls it with
the documented register convention, so it can be tested without GS/OS - which
matters, because a module that hangs takes the boot with it and has to be
deleted from outside (`tools/prodos_rm.py`).

`LinkInterfaceV` and `LinkModuleInfo`, the two calls Marinetti makes while
building its list, now run and return cleanly, with a correct 29-byte info
block: method ID, a 21-byte name field, rVersion longword and flags.

The module reports `conTest` ($0005), the ID the Programmers' Guide reserves
for development. A public release needs its own ID from Marinetti's author.

Five bugs were found getting there, every one a register-width or stack
arithmetic error that assembled without complaint:

1. `phb` left the caller's data bank byte above the return address
2. `jsr (dispatch,x)` put its own return address on top of the parameters
3. handlers assembled 8-bit because the assembler's width tracking arrives in
   source order, and `exitLINK` ends 8-bit - `lda #$0001` became `A9 01`
4. `netENABLE` inherited 8-bit from the routine above it, and its flag store
   was 16-bit, running into the next CDB
5. `exitLINK` saved the flags *after* narrowing the accumulator, so every call
   returned with the caller's register widths changed

Assembling with `lst on` and auditing the listing is what found 3, 4 and 5.
The checks worth repeating after any change: every immediate's emitted size
matches its operand, every width-sensitive routine prologue matches its
callers, no 16-bit store lands in a byte field, and `php` precedes any width
change on an exit path.

**Milestone 4 (original note) — the Marinetti link layer.** `link/`
holds `BSLink`, an OMF module of type `$BC` auxtype `$4083`, which is what
Marinetti loads from `*:System:TCPIP` (Programmers' Guide, page 131).

```
link/bslink.s       the twelve interface calls and the dispatcher
link/scsi16.s       the proven transport, ported to 65816
link/arp.s          ethernet framing, ARP, and a four entry cache
link/make_bslink.s  linker file: TYP $BC, AUX $4083
```

Marinetti deals only in IP, so everything below it belongs to the module:
ethernet framing, and ARP both ways — answering requests for our address and
resolving the address we are sending to. Addressing is static for now, read
from the connect data; DHCP would have to run down here too.

Build and install:

```
merlin32 . link/make_bslink.s
```

then copy `BSLink` (it is on the transfer disk as `BSLINK`) into
`*:System:TCPIP` on the GS/OS boot volume, and pick it in the TCP/IP control
panel.

`src/installer/install.s` does the copy on the IIgs. It is `INSTALL.SYSTEM` on
the transfer disk: launch it from the Finder, or from BASIC.SYSTEM with
`-INSTALL.SYSTEM` once the prefix is `/PROBE`. ProDOS 8 can't tell which volume
GS/OS booted from, so it offers each online volume with a `SYSTEM/TCPIP`
directory and asks before replacing an existing `BSLINK`. If the copy fails, it
deletes the partial file. To rebuild it and put it on the disk:

```
merlin32 . src/installer/install.s
python3 tools/prodos_rm.py "disk/FD60_512 probe.po" /INSTALL.SYSTEM
python3 tools/prodos_add.py "disk/FD60_512 probe.po" \
        src/installer/InstallSystem INSTALL.SYSTEM 0xFF 0x2000
```

Marinetti loads every `$BC`/`$4083` file in `TCPIP`, so remove any test builds
(`BSLINKT13` and the like) from there by hand.

`disk/BlueSCSILink.po` is the disk to give other people. It is a bootable 800K
ProDOS volume, `/BLUESCSILINK`, and holds only what installation needs:

```
PRODOS          ProDOS 8 v1.7, taken from the Cirtech disk with its boot blocks
INSTALL.SYSTEM  the installer, first .SYSTEM file, so booting the disk runs it
BSLINK          link/BSLink
README          src/installer/README.txt, a TXT file that opens in Teach
```

Rebuild it after changing any of those files:

```
python3 tools/prodos_new.py disk/BlueSCSILink.po BLUESCSILINK 1600 \
        --boot "disk/FD60_512 probe.po"
python3 tools/prodos_add.py disk/BlueSCSILink.po \
        src/installer/InstallSystem INSTALL.SYSTEM 0xFF 0x2000
python3 tools/prodos_add.py disk/BlueSCSILink.po link/BSLink BSLINK 0xBC 0x4083
python3 tools/prodos_add.py disk/BlueSCSILink.po \
        src/installer/README.txt README 0x04 0x0000 --text
```

`prodos_new.py` overwrites the image, so the four commands always rebuild it
from scratch. `--text` changes the README's line feeds to the carriage returns
that ProDOS text files use.

`LinkConfigure` currently just fills in defaults matching the Mac
Internet Sharing setup the transport was proven against: 192.168.2.99,
255.255.255.0, gateway 192.168.2.1.

Two things to expect on first run: the module has never executed on a IIgs, and
the transfer loop is byte-at-a-time, which was enough for ARP but will be the
first thing to strain under real traffic.

**Milestone 5 — package it further.** Either a GS/OS driver (file type `$BB`, aux `$01xx`,
structure in the SCSI-2 ERS under "Physical Structure of an SCSI Driver") that
presents the device the way `SCSIProc.Driver` would, or go straight to a Marinetti
link layer that owns the card directly. The driver route is more work but means
existing software keeps working.

## Building

The sources are Merlin syntax, plain 6502, ProDOS 8, origin `$2000`. `probe.s` is
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

## Putting it on a disk

`_FileInformation.txt` is metadata for Cadius. It never goes onto the image — it
only tells Cadius which ProDOS type and aux type to stamp on the file it copies.
`tools/prodos_add.py` takes those on the command line instead, so neither Cadius
nor AppleCommander is needed:

```
cp ~/Downloads/Cirtech\ SCSI/Cirtech\ SCSI\ 800k.PO "disk/FD40_512 probe.po"
python3 tools/prodos_add.py "disk/FD40_512 probe.po" \
        src/compiled/ProbeCompiled PROBE 0x06 0x2000
```

`disk/FD40_512 probe.po` is that image, already built: the Cirtech utility disk
(ProDOS 8 and BASIC.SYSTEM) with `PROBE` added as BIN, aux `$2000`. Its volume is
renamed to `/PROBE` so it can't clash with the original `/SC`.

The filename is the BlueSCSI convention: `FD` floppy, SCSI ID `4`, LUN `0`, 512
byte blocks. IDs 3, 5 and 6 are in use, so 4 is free.

To run it:

1. Put the BlueSCSI in USB mass storage mode and copy `FD40_512 probe.po` to the
   root of the SD card. Back the card up while you're there.
2. Boot the IIgs and get to a ProDOS 8 BASIC prompt. From GS/OS, launch
   `BASIC.SYSTEM` from the Finder; the copy on `/PROBE` will do.
3. At the `]` prompt:

```
]PREFIX /PROBE
]BRUN PROBE
```

The Cirtech ROM boots whichever device has the highest SCSI ID, currently ID 6.
To make this disk boot directly instead, give it the highest ID and move the
current boot image below it.

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
- `../scsi2/manuals/SCSI-2 Driver ERS v202608.pdf` — GS/OS driver structure, and
  every CDB the BlueSCSI toolbox uses.
- `../scsi2/bluescsi.s` — working command sequences, as GS/OS calls.
- `../scsi2/other/dayna/SLINKCMD.txt` — the DaynaPort SCSI/Link command set. The
  authority for `$08`, `$09`, `$0A`, `$0C` and `$0E`.
- BlueSCSI toolbox docs: https://github.com/BlueSCSI/BlueSCSI-v2/wiki/Toolbox-Developer-Docs
