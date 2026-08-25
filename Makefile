all : flash

TARGET:=cvbs_main
TARGET_EXT:=cpp
TARGET_MCU:=CH32X035
LINKER_SCRIPT:=cvbs_x035_pioc.ld
EXTRA_ELF_DEPENDENCIES+=xcgh_incrementer.pioc.h
EXTRA_ELF_DEPENDENCIES+=cvbs_text_32x24.pioc.h
EXTRA_ELF_DEPENDENCIES+=blink.pioc.h
EXTRA_ELF_DEPENDENCIES+=dvd.xbm
EXTRA_ELF_DEPENDENCIES+=timer_ntsc.asm
EXTRA_ELF_DEPENDENCIES+=ass.xbm
CFLAGS+=-Isupport/u8g2/csrc/
ADDITIONAL_C_FILES+=$(wildcard support/u8g2/csrc/*.c)

include support/ch32fun/ch32fun/ch32fun.mk

flash : cv_flash
clean : cv_clean
	rm -f *.pioc.bin *.pioc.h

%.pioc.bin: %.pioc.asm
	support/PYPIOC/pypioc.py assemble $< $@

%.pioc.h: %.pioc.bin
	xxd -i $< > $@

%.xbm: %.png
	convert $< -colorspace Gray -dither FloydSteinberg -remap pattern:gray50 $@
	sed -i 's/static char /static const uint8_t /' $@
