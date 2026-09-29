* Expansion linker file for the Marinetti link layer
*
* Marinetti link layer modules are OMF files of type $BC, auxtype $4083,
* installed into *:System:TCPIP (Programmers' Guide, page 131).

	DSK	BSLink
	TYP	$BC
	AUX	$4083

* Assemble files

	ASM	bslink.s
	KND	$1000
	SNA	BSLink

* KIND $1000 = Code, NoSpecial.  Every link layer Marinetti ships is built
* this way; PPP's OMF header reads "KIND $1000 Code - NoSpecial".  Without
* that attribute the System Loader may place the segment in special memory -
* banks $00, $01, $E0, $E1 - which is where the toolbox, GS/OS buffers and
* the display live.  A 4.5K module landing there wedges the machine.

* END
