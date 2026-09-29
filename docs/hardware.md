# Cirtech SCSI Interface — hardware notes

Everything here was derived from the 8 KB EPROM dump (`rom/cirtech_scsi_2764.bin`)
and the *Cirtech SCSI Interface User's Manual* (1989, part 890206/104).

Each claim is tagged:

- **[ROM]** — read directly out of the disassembly. Solid.
- **[MANUAL]** — stated in the user's manual. Solid.
- **[INFERRED]** — my reading of what the code is doing. Needs checking on real hardware.

## Card identification [MANUAL] [ROM]

A slot holds a Cirtech SCSI Interface when:

| Address  | Value | Meaning            |
|----------|-------|--------------------|
| `$Cs01`  | `$20` | ID byte 1          |
| `$Cs03`  | `$00` | ID byte 2          |
| `$Cs05`  | `$03` | ID byte 3          |
| `$CsFB`  | `$02` | ID byte 4          |
| `$Cs07`  | `$00` | FAST mode          |
| `$Cs07`  | `$3C` | SAFE mode          |

`$CsFF` = `$12`, so the ProDOS block entry point is `$Cs12` and the SmartPort
entry point is `$Cs15` (manual, figure 5: the caller adds 3).

`$CsFE` = `$3F` — the ProDOS status byte: removable, interruptible, read, write,
format, status supported.

## ROM layout [ROM]

The 2764 holds two 4 KB banks, picked by the Autostart Selector:

```
$0000-$0FFF  FAST bank        $1000-$1FFF  SAFE bank
  +$000  copyright banner
  +$100  slot 1 page  -> $C100
   ...   one pre-built page per slot, slot addresses patched in
  +$700  slot 7 page  -> $C700
  +$800  expansion ROM -> $C800-$CFFF (shared by all slots)
```

The per-slot pages exist because the byte-transfer loops are written with
absolute addressing (`LDA $C0FC` in the slot 7 copy), which is what makes FAST
mode fast. The expansion ROM is slot-independent and reaches the card through
`$BFF3,Y`, where `Y` comes from screen hole `$0778`.

## Register map [INFERRED]

Base = `$C080 + $10 * slot`, so `$C0F0` for slot 7. In the expansion ROM the
same registers appear as `$BFF3,Y` (base+0) through `$BFFB,Y` (base+8), with
`Y = $FD` for slot 7.

| Offset | Access | Purpose |
|--------|--------|---------|
| `+$0`  | write  | Data-out latch. Written **inverted** (`EOR #$FF`), OR'd with the initiator ID bit during selection. |
| `+$1`  | r/w    | **Write: bus drive / control.** Observed values `$00`, `$04`, `$05`, `$0C`. `$0C` before asserting the data bus, `$05` during selection, `$04` while waiting for BSY, `$00` once selected. **Read: card handshake status** — bit 6 = ready, bit 5 = error. Confirmed on hardware 2026-09-22: the first wait of the selection sequence polls this register, not `+$4`. |
| `+$2`  | write  | Transfer engine control. `$01` arms it, `$04` stops or idles it, `$06` sets up a data-out block. |
| `+$3`  | write  | Expected-phase latch. The ROM writes the bus phase bits shifted right by one, so the hardware can run a block transfer in that phase. |
| `+$4`  | read   | SCSI bus status. Bit 6 = BSY (tested by `ASL` then `BMI`), bit 5 = REQ (`AND #$20`), bits 4-2 = phase (`AND #$1C`), giving MSG/C-D/I-O. |
| `+$5`  | read   | Card/transfer status. Bit 6 = byte ready (`ROL` then `BPL`), bit 5 = phase change or error (`AND #$20`), bit 4 = selection timeout (`AND #$10`). |
| `+$6`  | read   | Final byte of a transfer. Read after writing `$04` to `+$2`. |
| `+$7`  | read   | Strobe. The value is discarded; reading it appears to acknowledge or advance the engine. |
| `+$8`  | read   | Data-in latch, also inverted. Selection verifies the bus by comparing `+$8` against what it drove. |
| `+$C`  | r/w    | Block data FIFO port. This is the one the unrolled loops hammer. |

`+$9`, `+$A`, `+$B`, `+$D`, `+$E`, `+$F` are untouched by the ROM.

## FAST vs SAFE [ROM] [MANUAL]

Both modes use the same registers; only the polling differs.

**FAST** (`slot7_fast.asm`, `$C769`): poll `+$5` bit 6 once, then read four bytes
per iteration from `+$C` with no further checks. The manual warns the device must
stay under 10 µs per byte.

**SAFE** (`slot7_safe.asm`, `$C769`): poll `+$5` bit 6 before every single byte.
The manual gives 21 µs per byte as the resulting rate.

Both finish a block the same way: write `$04` to `+$2`, then read the last byte
from `+$6`.

Read and write share this shape. The write path (`$C7A7` FAST) first writes
`$06` to `+$2`, `$01` to `+$1` and `$01` to `+$5`, then streams out through `+$C`.

The buffer pointer is ProDOS's `$44/$45` throughout, and blocks are always 512
bytes, done as two 256-byte passes.

## Selection sequence [INFERRED]

From `$CB96`-`$CC5B` in `expansion_fast.asm`. Steps 0-2 were corrected after the
first hardware run; see "Hardware results" below.

0. Write `$00` to `+$1`, `+$2`, `+$3` and `+$4`, then read `+$7`. Read `+$4`: it
   must be `$00`, meaning the bus is idle. If not, the ROM settles and retries.
1. Read `+$8`, complement it, write to `+$0`. Write `$01` to `+$2`. This arms the
   transfer engine.
2. Poll `+$1` until bit 6 is **set**, with `AND #$10` on `+$5` as the escape.
   Then check `+$1` bit 5: set means the card is reporting an error.
3. Write `$0C` to `+$1`.
4. Read `+$8`, complement, `ORA` the initiator ID mask from zero page `$43`, and
   write the result to `+$0`. That puts both IDs on the data bus, which is what
   SCSI selection requires.
5. Write `$00` to `+$2` and `+$4`, then `$05` to `+$1` — this asserts SEL.
6. Wait for BSY on `+$4` bit 6, with a timeout of `$69` × 256 passes. On timeout,
   drive `$00` to `+$0` and `$04` to `+$1`, then return ProDOS error `$28`
   (device not connected).
7. Once the target asserts BSY: write `$04` to `+$2`, read `+$7`, write `$00`
   to `+$1`. Selection is complete.

## Phase dispatch [INFERRED]

From `$CC63`:

```
    poll +$5 until bit 2 set (transfer ready) or error
    read +$4, AND #$20  -> wait for REQ
    read +$4, AND #$1C  -> phase bits, LSR, TAX
    LSR again, write to +$3           ; tell the engine which phase
    read +$7                          ; strobe
    X = $0E -> MESSAGE IN   ($CE6C)
    X = $0C -> MESSAGE OUT  ($CEA1, sends $07, message reject)
    X = $06 -> STATUS       ($CEA7, byte kept in $4A masked with $1E)
    X = $04 -> COMMAND OUT
    X = $02 -> DATA IN      via the slot page loops
    X = $00 -> DATA OUT
```

X is twice the SCSI phase number (MSG, C/D, I/O as bits 2, 1, 0), so the
dispatcher's constants map onto the standard phases directly.

### Single-byte handshake [ROM]

`$CEA1` sends (A is written to `+$0` first, carry set); `$CEA7` receives (carry
clear). Both then run the same handshake at `$CEA8`:

```
    wait until +$4 & $20          ; REQ asserted
      abort if +$5 & $10          ; card gave up
    if sending: +$1 |= $01        ; enable the data drive
    byte = +$0                    ; the data register, true polarity
    +$1 |= $10                    ; ACK on
    wait until +$4 & $20 == 0     ; REQ released
    +$1 &= $EF                    ; ACK off
```

So `+$0` is the data port in both directions, and `+$8` is only an inverted
readback used to sanity check the bus during selection. `+$1` carries ACK in bit
4 and the data-drive enable in bit 0; the phase loop writes `+$1` = `$00` at the
top of every pass to clear both.

### Bus reset [ROM]

`$CE8C`: write `$80` to `+$1`, spin about four times, write `$00` back.

The zero page it uses matches ProDOS: `$42` command, `$43` unit or ID mask,
`$44/$45` buffer, `$46/$47` block number, `$4A` returned status, `$4D` retry
counter.

Error codes returned in `Y` at the common exit `$CB0C` are ProDOS ones: `$27`
I/O error, `$28` no device, `$2B` write protected.

## What this means for the driver

The card is a discrete SCSI implementation with no command-set restrictions of
its own. The ROM only ever *uses* it for block commands, but the registers can
drive any phase sequence, so a driver that programs them directly can issue an
arbitrary CDB — Inquiry `$12`, Send `$0A`, Receive `$08`, Receive Diagnostic
`$1C`, and the BlueSCSI toolbox commands `$D0`-`$DA`.

Nothing in the ROM needs to be called, and nothing in the ROM gets in the way.

## Hardware results

**2026-09-22, first probe run.** Slot 7, SAFE mode, idle bus reading
`+$4` = `$00`, `+$5` = `$08`.

Confirmed:

- Detection by ID bytes works, and the card is in **SAFE** mode. The ROM bank in
  use is therefore the `$1000` one, and per-byte handshaking is on.
- An idle bus reads `+$4` = `$00`, which matches the ROM's own idle test at
  `$CB96` and makes `+$4` bit 6 = BSY plausible.
- `+$5` = `$08` on an idle bus. Bit 3 is set with nothing happening, so it is not
  an activity flag. Unidentified.

**2026-09-22, INQUIRY against ID 3.** Full command cycle succeeded: command
out, data in (36 bytes), status `$00` GOOD, message `$00` command complete.

```
03 00 01 01 1F 00 00 18  "Dayna   " "SCSI/Link       "
```

Device type `$03` (processor), ANSI SCSI-1, response format 1, 31 additional
bytes, sync and linked commands supported. Vendor and product are exactly the
strings `../../scsi2/README.md` step 3 says to check for.

That settles the register map end to end. The card issues arbitrary CDBs.

**2026-09-22, BlueSCSI toolbox metadata `$D9`/`$01` against ID 3.** Status `$00`,
8 bytes in: `00 07 00 00 00 00 00 00`. API version 0, capability flags `$07`, so
large transfers, large send and set-working-directory are all supported. This is
step 4 of the Marinetti recipe in `../../scsi2/README.md`, satisfied.

It also proves a 10-byte CDB works, after INQUIRY proved a 6-byte one.

**2026-09-23, Wi-Fi info `$1C`/`$04` against ID 3.** Status `$00`, 76 bytes in.
The sub-command *is* implemented, though `bluescsi.s` never calls it.

```
offset 0-1    00 41         header
offset 2-65   "sandbox370"  SSID, 64-byte field, null padded
offset 66-71  00 x6         BSSID, empty in this response
offset 72     C4            -60 as a signed byte: RSSI in dBm?
offset 73     06            Wi-Fi channel?
offset 74-75  00 00
```

76 = 2 + 74, and `bluescsi.s` has `SIZE_SSID = 74 ; 64 + 6 + 1 + 1 + 1 + 1` with
scan results read starting at offset 2 (`lda #2 : sta offsetNETWORK`). So the
info response is one access-point entry in the scan-result format behind a
two-byte header. The split into 64 + 6 + 1 + 1 + 1 + 1 is documented; naming the
last four bytes RSSI and channel is inference from their values.

Header byte 1 = `$41` is unexplained.

**2026-09-23, working ethernet.** With a Mac running Internet Sharing as the
access point, `MACAP` sent an ARP request and read back the reply:

```
header  00 40 00 00 00 00        length $40 = 64, flags: last packet
dst     00 80 19 17 1E 95        us
src     52 A6 D8 6B CE 64        the Mac
type    08 06                    ARP
        00 01 08 00 06 04        ethernet / IPv4
op      00 02                    reply
sha/spa 52 A6 D8 6B CE 64  C0 A8 02 01    the Mac, 192.168.2.1
tha/tpa 00 80 19 17 1E 95  C0 A8 02 63    us, 192.168.2.99
        ... padding ...  11 22 95 DC      CRC
```

64 = a 60 byte frame plus the 4 CRC bytes, exactly as `SLINKCMD.txt` describes,
and 70 bytes in total once the 6 byte header is counted. Transmit and receive
both work, and the whole path is proven: IIgs, Cirtech registers, SCSI phases,
DaynaPORT command set, radio, and back.

The earlier silence was never the code. `sandbox370` drops frames whose source
address it never leased, most likely dynamic ARP inspection or client
isolation. The same program on an unmanaged access point works first time.

Corrected:

- The probe's first wait polled `+$4` for BSY to fall. That was wrong on both
  counts: the ROM polls **`+$1`**, and it waits for bit 6 to be **set**, not
  clear. `+$1` is read/write, which the earlier register map missed. The failure
  was "BUS NEVER WENT FREE" despite `+$4` reading `$00` a moment earlier — the
  probe's own write of `$01` to `+$2` is what changed `+$4`.

### Link layer: the "self-overwriting" module (MODTEST builds 7–10)

Across four builds MODTEST crashed inside `LinkConnect` (`$000C`) with a BRK
partway through `arpSTORE`, with `$A0` bytes in memory and `Y=$A0A0`. Build 9
copied the module aside and compared it after every call. The comparison showed
the module intact through `$000A` and the copy itself wiped, which pointed at
`$000A`.

The cause was the harness, not the module. MODTEST pushed every word parameter
before every long parameter. `LinkSendDatagram` takes the pointer first and the
length on top, so the module read the **address** of MODTEST's scratch buffer
(about `$2349`, or 9 KB) as the length and `$00:0000` as the pointer. It then
copied 9 KB of bank 0 into `frameBUF+14`. That ran 1,500 bytes to the end of
`readBUF` and then went on over the ARP code, with bytes that came from the
text screen at `$0400`. That is where the `$A0`s came from. `LinkConnect`
crashed only because it was the next call to run ARP code.

The four-entry ARP cache removed in build 6 was blamed for this same symptom
and was probably innocent.

Fixed in MODTEST build 11 / BSLINKT10:

- Each test entry says whether a word or a long goes on top, what value the
  word carries, and what pointer the longs carry. `$000A` now sends a real
  20-byte IPv4 header with length 20. `$000C` gets a nil handle, so it uses the
  default configuration.
- `LinkSendDatagram` rejects a length of 0 or anything above MTU with `$3617`.
- `netREAD` ignores a wire length above 1,518 (frame plus CRC).
- `netWRITE` pads frames to the 60-byte ethernet minimum. MACAP always sent 60.
  The link layer's 42-byte ARP had never been tried on hardware.
- Merlin32 turned `lda $0000,x` into direct-page `B5 00` in four places in
  `arp.s`, so ARP address compares read the direct page. These now use `|$0000,x`.
- The watcher's page bounds and skip ranges now come from labels. They were
  hand-typed before, and went stale with every edit.

### Link layer: `$B648` from TCPIPConnect (BSLINKT11)

MODTEST build 11 returned cleanly. Its log shows `LinkConnect` sending a
60-byte ARP for 192.168.2.1 and getting a 70-byte reply on the first read, so
the whole module path resolves the gateway on hardware. The canary stayed `80`
through every stage.

LINKCONN still got `$B648`. Marinetti's source (`I.INIT.S`, TCPIPConnect)
pushes 22 bytes, with conHandle on top, and reads our result from `A`
(`STA 5,S` / `_DisposeHandle` / `PLA`). A non-zero result sends it to
`DUMPLINKLAYER`, and `STRIPTOOLEXIT` then ORs the result with `$3600`.

Cause: `exitLINK` restored the caller's data bank with `plb` and **then** read
`pSAVE` and `errSAVE` with absolute loads, which read Marinetti's bank at our
offsets. Every call handed back a garbage result and garbage flags. MODTEST ran
everything in bank 0, so it never showed. `LinkConnect` is the only call that
Marinetti judges by `A`.

Fixed:

- `exitLINK` loads everything before `plb` and carries the result across in Y.
- MODTEST (build 12) calls with data bank `$01` and prints each call's `A` and
  carry.
- `routeMAC` ended with `plp`, which threw away `arpRESOLVE`'s carry, so an
  unresolved address read as success.
- `arpSTORE` compared replies with `wantIP`, the datagram's destination,
  instead of the address being resolved. A gateway reply for an off-subnet
  send, or for LinkConnect, was dropped. The new `askIP` and `macIP` fields
  track the address being asked for and the address `dstMAC` belongs to.
- LINKCONN and LINKTEST called Quit as `$0029` (class 0) with a class-1
  parameter block. That's the crash at `11/8A84` after "PRESS A KEY". They now
  use `$2029`.

### Link layer: connected (BSLINKT11), then byte order (BSLINKT12)

With BSLINKT11, LINKCONN connected, and so did the TCP/IP control panel, with
no freeze. That's the first working Marinetti connection through the Cirtech
card.

A ping from the Mac to 192.168.2.99 still timed out. The Mac's ARP table had
the right MAC (`00:80:19:17:1e:95` on `bridge100`). The cause was the address
byte order. Marinetti keeps IP addresses in network order: `I.IP.S` compares
`ip_dst` word by word with `MYIPADDRESS`, and tests loopback as `CMP #$007F`.
The module was storing `lvIPaddress` byte-swapped, so Marinetti believed its
address was 99.2.168.192 and dropped every packet sent to 192.168.2.99.
LINKCONN's printout had the matching mistake, so the two cancelled on screen.
Both are fixed.

New test program `PING` (S16): it sends four ICMP echoes to 192.168.2.1 with
tick timings, then polls for 30 seconds so the Mac can ping 192.168.2.99.
Marinetti answers echo requests itself, but only when something calls
`TCPIPPoll`. Its RunQ task does that every 0.5 s, and only while a desktop
event loop is running.

### First two-way IP traffic, and where the loss is (PING, BSLINKT12)

The Mac's `ping 192.168.2.99` got about 20% replies. That's the first IP
traffic in both directions. In `ping_lastlog.txt`:

- 6 frames of 98 bytes were read (the Mac's echo requests), and **all 6 were
  answered** with a 98-byte write. Once a frame reaches the DaynaPORT queue,
  the link layer and Marinetti handle it correctly.
- The IIgs's own 8 echo requests (60-byte writes) all went out, and no reply
  ever came back.
- 6,264 empty reads, all with checksum 0. So there was no dropped-packet
  state: most Mac→IIgs frames never reached the firmware's queue at all.
- The Mac's firewall stealth mode is off. `netstat -s -p icmp` showed the Mac
  had answered every echo request it received (34 at the time).

The firmware's receive path (`BlueSCSI_platform_network.cpp`,
`cyw43_cb_process_ethernet` → `scsiNetworkEnqueue`) filters nothing except
when the interface is disabled, and it was enabled for the whole session. The
firmware never calls `cyw43_wifi_pm`, so the Pico W runs the driver default,
`CYW43_PERFORMANCE_PM`: PM2 power save, asleep 200 ms after activity, with a
listen interval of 10 beacons. Unicast frames from a macOS Internet Sharing
access point to a dozing radio are the prime suspect. The one ARP reply,
which arrived 20 ms after a transmit while the radio was awake, fits that.

Two contributing loads on the Pico: debug logging writes the SD log in every
command's status phase, and the traced link layer issues 5 SCSI commands per
Marinetti poll. `BSLINKS12` is the same module built with `TRACEON 0`.

Firmware fix, not applied: `cirtech/firmware/bluescsi-wifi-no-powersave.patch`
(`cyw43_wifi_pm(&cyw43_state, CYW43_NONE_PM)` after
`cyw43_arch_enable_sta_mode()`).

### Packet capture: the loss is over the air (`ping.pcap`)

`sudo tcpdump -i pktap,bridge100,ap1 -k -w ping.pcap icmp or arp` during PING
and a 10-packet `ping` from the Mac:

| Mac → IIgs traffic | handed to `ap1` | reached the IIgs |
|---|---|---|
| echo replies to the IIgs (svc BE, 42 bytes) | 4 of 4, 0.1 ms after each request | 0 |
| Mac's own echo requests (svc CTL, 98 bytes) | 10 of 10 | 3 (answered 104–187 ms after sending) |

Every frame is addressed to `00:80:19:17:1e:95` and handed to the Wi-Fi
driver immediately. The IIgs answered every ping that reached it. So the
Mac, the link layer and Marinetti are all correct, and frames are lost between
the macOS access point and the Pico W.

The delivered pings arrived 100–190 ms late, which looks like delivery
held for a dozing station until its beacon wake-up. The class split (CTL about
30%, BE 0 of 16 across runs) would fit WMM power-save delivery varying by
access category, but that's unproven. TCP is BE, so it can't work until this
is fixed. Next step: `bluescsi-wifi-no-powersave.patch`, or a different access
point.

### Configure dialog (BSLINKS13 / BSLINKT13)

`LinkConfigure` now opens a dialog (`link/config.s`) with IP address, subnet
mask and gateway fields, so changing networks no longer needs a rebuild. It
follows Marinetti's own flow (`CDev/C.INIT.S` CONFIGURE):

1. `TCPIPGetConnectData` gets the handle.
2. `TCPIPEditLinkConfig` calls us.
3. `TCPIPSetConnectData` saves the handle.

We write readCONFIG's layout into the handle: version 1, then IP address,
mask and gateway as network-order longs. `LinkConnect` reads it back.

The window is built from in-memory templates, following Direct Connect's
`DC.CONFIG.S`, so it needs no resource fork. Tool numbers were checked
against ORCA/C's headers. All 22 template pointers carry 24-bit (RELOC3)
relocations in the OMF.

DNS isn't in the dialog because the control panel's Setup window already
has two DNS fields.

Text that doesn't parse becomes 0.0.0.0 (`TCPIPConvertIPToHex` always
reports success), so Save beeps and stays open. MODTEST no longer calls
`$0016`, because it opens a desktop window.

PING (build 2) now pings the gateway saved by the dialog, falling back to
192.168.2.1.

### Working: iPhone Personal Hotspot (BSLINKS13, PING build 2)

The BlueSCSI joined the iPhone's hotspot, and the address was set in the new
Configure dialog: 172.20.10.14 / 255.255.255.240 / gateway 172.20.10.1.

- PING from the IIgs: **4 of 4 replied**.
- The Mac, tethered to the same iPhone, pinging the IIgs: **about 10% loss**
  (it was about 80% through Mac Internet Sharing).

So the heavy loss was the Mac's Internet Sharing access point, not the link
layer, Marinetti or the transport. The residual 10% is unexplained. It could
be Pico W power save (the firmware patch is still available) or the first
ping waiting on ARP.

The Configure dialog worked on hardware at its first run.

## DaynaPORT command set [MANUAL]

`../../scsi2/other/dayna/SLINKCMD.txt` — "DaynaPort SCSI/Link: SCSI Command Set",
Roger Burrows, rev 1.20 — is the authority, and it is already in this repo.

```
03  Request Sense       03 00 00 00 00 00      always 9 bytes back
08  Read                08 00 00 LL LL XX      XX must be C0 or 80
09  Retrieve Statistics 09 00 00 00 12 00      18 bytes: MAC, then 3 counters
0A  Write               0A 00 00 LL LL XX      XX = 00 raw, 80 = length-prefixed
0C  Set Interface Mode  0C 00 00 00 FF 80      FF = 04 allows broadcast
0C  Set MAC Address     0C 00 00 00 FF 40      data out, 6 bytes
0E  Enable/disable      0E 00 00 00 00 80/00   80 enables, 00 disables
12  Inquiry             12 00 00 00 LL 00
```

Two requirements a driver cannot skip:

1. **The interface must be enabled** with `0E ... 80` before any packet arrives,
   and the spec says to leave it alone for about half a second afterwards.
2. **Byte 5 of the read CDB must be `C0` or `80`.** The ERS calls bits 7-6
   vendor unique; on a DaynaPORT they are mandatory. A read with `00` there
   returns nothing useful.

Read response: `LL LL NN NN NN NN <packet> CC CC CC CC`, where `LLLL` is the
packet length including the 4 CRC bytes, and `NNNNNNNN` is `00000000` for the
last packet, `00000010` when more are waiting, `FFFFFFFF` when a packet was
dropped (length then reads `4000`, and only a disable/enable clears it).
`LLLL` = `0000` means nothing is waiting.

Write with `XX` = `80` takes `PP PP 00 00 <packet> 00 00 00 00`, where `PPPP` is
the real packet length and `LLLL` in the CDB is that length plus 8.

## Still unknown

- Exact bit meanings of `+$1`. `$04`, `$05` and `$0C` are used; the rest is guesswork.
- Whether `+$3` must be written before every phase or only before a block.
- How message-out and ATN are asserted, if at all. The ROM never sends a message out.
- Whether the FIFO at `+$C` can do non-512-byte transfers, which the network
  commands need. `+$6` reading the final byte hints the engine has a counter.

These are the questions milestone 1 in the README is meant to answer.
