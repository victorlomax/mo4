# Description
An emulation of the Soundpool MO4 MIDI interface for Atari ST.

The Soundpool MO4 is a 4 output MIDI interface for the Atari ST, based on a CPLD (ipLSI1016 from Lattice). However, on mine, the CPLD has apparently lost its program; the datasheet gives a retention period of 20 years, mine is over 29 years. Apparently, I'm not the only one with the same issue, but most of the MO4 owners have probably left the Atari world now. A drive called MO44.DRV is required for the interface to be detected by Cubase. Given it's structure, I think the driver was written in assembly for MC68000. Hopefully, I found a disassembled and commented listing, which helped me to understand the protocol between Cubase and the MO4 interface.

The emulation is based on 4 * ATTiny4313 microcontroller, each one devoted to an output. The choice of ATTiny4313 (or ATTiny2313) was motivated by the presence of an USART and a 20 pins package, allowing to have a full 8 bit port.

The BUSY signal is managed by a decade counter 74LS90 to speed-up the reply after a request to reset.

# Schematics
**soundpool_mo4-schematic** is based on a reverse engineering of the Soundpool MO4. **mo4emulation-schematic** is a proposed replacement.

# Sources
**simulmo4.S**: a simulation of the protocol and signals expected on the parallel port of Atari, for debugging purpose. Triggered by Timer 1, it simulates the reset_hardware function of the driver (4 pulses of /STROBE), followed by data written on the port B
![chronogram](https://github.com/victorlomax/mo4/blob/main/simulmo4.png?raw=true)
