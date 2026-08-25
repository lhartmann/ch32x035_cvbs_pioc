#  CVBS/NTSC output using PIOC

PIOC runs all the sync signals and interrupts host when data is needed, and when entering vblank. Resolution is 256x192.
PIOC code also holds 256 8x8 glyphs for font/tile data, which would result in 32x24 characters.

On interrupt, PIOC code sets SFR_CTRL_RD to the scanline it is about to render. Host must fill PIOC SFR_DATA_R0 to R31 with 32 bytes of image data, and SFR_CTRL_WR is used for mode selection.

If SFR_CTRL_WR bit 7 is cleared then data is parsed as "text mode", i.e., tile indices that will be looked up into the font/glyph table. PIOC code will render the 8 scanlines, and interrupt as soon as it is ready for the next line of data.
If SFR_CTRL_WR bit 6 is set, then interrupt is requested a the end of each scanline (not after full glyph is drawn). This does not stop PIOC rendering, just let's the host know.
Additionally, SFR_CTRL_WR bit 2:0 may be set to a specific glyph line to start render on.

If SFR_CTRL_WR bit 7 is set then data is parsed as "bitmap mode", i.e., raw pixels to display. An interrupt will be triggered as soon as it is ready for the next line of data.

Rendering may be mix-and-matched by host code, so you get text and bitmap regions on the same screen. Full-text requires 32*24 = 768 bytes for tilemap, while full-bitmap takes 256*192/8 = 6144 bytes for framebuffer.

```
git clone --recursive https://github.com/lhartmann/ch32x035_cvbs_pioc
cd ch32x035_cvbs_pioc
make -C fonts
make
```

PIOC uses the programming pins as IO, so no SWD debgging is possible. To program, trigger the ch32x035 bootloader during make, and connect to UART at 3Mb/s for reading printfs.

SWDIO pin is used as SYNC, with a 1kR series resistor. SWDCK pin is used as LUMA, with a 470R series resistor.

```
                   1kR
SWDIO (SYNC) ----/\/\/\----+---- Video (RCA center pin)
                  470R     |
SWDCK (LUMA) ----/\/\/\----+
GND   -------------------------- GND   (RCA outter ring)
``` 
