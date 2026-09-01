#include "ch32fun.h"
#include "PIOC_SFR.h"
#include <stdio.h>
#include <stdlib.h>
#include "cvbs_text_32x24.pioc.h"
#include "blink.pioc.h"
#include "u8g2_256x192.h"
#include "dvd.xbm"
#include "ass.xbm"

extern union PIOC_SRAM_u {
	uint8_t  u8 [4096];
	uint16_t u16[2048];
	uint32_t u32[1024];
} PIOC_SRAM;

union vram_u {
	uint8_t  u8 [256*192/8];
	uint16_t u16[256*192/16];
	uint32_t u32[256*192/32];
	uint8_t  txt[24][32];
} vram;
void setpixel(uint32_t x, uint32_t y) {
	uint8_t *p = vram.u8 + y*32 + x/8;
	uint8_t m = 1 << (7 - x%8);
	*p |= m;
}
void resetpixel(uint32_t x, uint32_t y) {
	uint8_t *p =  vram.u8 + y*32 + x/8;
	uint8_t m = 1 << (7 - x%8);
	*p &= ~m;
}

uint32_t memtest_seed_next(uint32_t seed) {
	constexpr uint32_t poly = 0xA0000001U;
	return (seed / 2) ^ (seed % 2 * poly);
}

void memfill(void *start, size_t len, uint32_t seed=0xFFFFFFFFU) {
	uint8_t *p = (uint8_t *)start;
	while (len--) {
		seed = memtest_seed_next(seed);

		*p++ = uint8_t(seed);
	}
}

void memset_u16(void *start, uint16_t val, size_t count) {
	uint16_t *p = (uint16_t *)start;

	while (count--)
		*p++ = val;
}

void *memcheck(void *start, size_t len, uint32_t seed=0xFFFFFFFFU) {
	uint8_t *p = (uint8_t *)start;
	while (len--) {
		seed = memtest_seed_next(seed);

		if (*p != uint8_t(seed)) return p;

		p++;
	}

	return 0;
}

bool memtest(void *start, size_t len, uint32_t seed=0xFFFFFFFFU) {
	printf("memtest 0x%08X, size 0x%08X...\n", start, len);
	// Fill
	printf("  fill...\n");
	memfill(start, len, seed);

	// Check
	printf("  check...\n");
	void *p = memcheck(start, len);
	if (p) {
		printf("  Fail at 0x%08X\n", p);
	} else {
		printf("  Success.\n");
	}

	return !p;
}

void memdump(void *start, size_t len) {
	uint8_t *p = (uint8_t *)start;
	int k = 15;

	printf("          +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F");

	while (len--) {
		if (++k == 16) {
			printf("\n%08x ", p);
			k = 0;
		}

		printf(" %02X", *p++);
	}
	printf("\n");
}

static void pioc_load(const uint8_t *data, int len)
{
	PIOC->D8_SYS_CFG = RB_MST_RESET; // Reset
	PIOC->D8_SYS_CFG = RB_MST_RESET; // Buy some time
	PIOC->D8_SYS_CFG = RB_MST_RESET; // Buy some time
	PIOC->D8_SYS_CFG = 0; // Just disable PIOC

	memcpy(PIOC_SRAM.u8, data, len); // Load code
	memset(PIOC_SRAM.u8 + len, 0x00, 4096 - len); // pad with NOP

	PIOC->D8_SYS_CFG = RB_MST_IO_EN1 | RB_MST_IO_EN0;
	PIOC->D8_SYS_CFG = RB_MST_IO_EN1 | RB_MST_IO_EN0 | RB_MST_CLK_GATE;
}

void SetupUART4() {
	// Use UART4 because of pin maps.
	// TX is PB0.
	// RX ix PB1

	RCC->APB1PCENR |= RCC_APB1Periph_USART4;
	RCC->APB2PCENR |= RCC_APB2Periph_GPIOB;
	GPIOB->CFGLR.PIN1 = GPIO_CFGxR_IN_FLOAT;
	GPIOB->CFGLR.PIN0 = GPIO_CFGxR_OUT_2Mhz_AF_PP;

	// USART4->STATR = ; // status flags
	// USART4->DATAR = ; // Data Register
	constexpr uint32_t baud = 3000000;
	USART4->BRR   =  (48000000 + baud/2) / baud;
	USART4->CTLR1 = USART_CTLR1_UE | USART_CTLR1_TE;
	// USART4->CTLR2 = ; // Mostly necessary for LIN or synchronous mode
	// USART4->CTLR3 = ; // mostly for DMA and line-control
	// USART4->GPR   = ; // mostly for smartcard and infrared
}

int putchar(int c) {
	int retries = 10000;

	if (c == '\n') {
		while (!(USART4->STATR & USART_STATR_TXE)) if (!retries--) return 1;
		USART4->DATAR = '\r';
	}

	while (!(USART4->STATR & USART_STATR_TXE)) if (!retries--) return 1;
	USART4->DATAR = c;
	return 0;
}

int _write(int fd, const char *buf, int size) {
	while (size--) putchar(*buf++);
	return 0;
}

enum class DemoModes_e {
	scrollingText,
	staticText,
	chess,
	bouncyDot,
	bouncyDvd,
	ass,
	randomLines,
	end,
	begin = scrollingText,
} demoMode = DemoModes_e::begin;

DemoModes_e &operator++(DemoModes_e &dm) {
	int k = int(dm) + 1;
	dm = DemoModes_e(k);
	if (dm == DemoModes_e::end)
		dm = DemoModes_e::begin;
	return dm;
}

extern "C" void PIOC_IRQHandler() __attribute__((interrupt));
uint32_t PIOC_IRQHandler_counter = 0;
uint32_t frame_counter = 0;
void PIOC_IRQHandler() {
	++PIOC_IRQHandler_counter;
	if (PIOC->D8_SYS_CFG & RB_DATA_SW_MR) {
		uint8_t scanline = PIOC->D8_CTRL_RD;

		if (scanline == 0xFF) {
			if (++frame_counter % 256 == 0) {
				memset(vram.u8, 0, sizeof(vram));
				if (++demoMode == DemoModes_e::end) {
					demoMode = DemoModes_e::begin;
				}
			}
		}

		if (demoMode == DemoModes_e::scrollingText || demoMode == DemoModes_e::staticText) {
			// Text demos, still or fast scrolling text
			if (scanline == 0xff)
				for (size_t i=0; i<32*24; i++)
					vram.u8[i] = i + frame_counter * (demoMode == DemoModes_e::scrollingText);

			if (scanline % 8 == 0) {
				uint32_t *p = vram.u32 + scanline/8 * (32 / sizeof(uint32_t));
				PIOC->D32_DATA_REG0_3   = p[0];
				PIOC->D32_DATA_REG4_7   = p[1];
				PIOC->D32_DATA_REG8_11  = p[2];
				PIOC->D32_DATA_REG12_15 = p[3];
				PIOC->D32_DATA_REG16_19 = p[4];
				PIOC->D32_DATA_REG20_23 = p[5];
				PIOC->D32_DATA_REG24_27 = p[6];
				PIOC->D32_DATA_REG28_31 = p[7];
				PIOC->D8_CTRL_WR = 0x00; // Display text from line 0, do not interrupt until 8th scanline.
			}
		} else if (demoMode == DemoModes_e::chess) {
			// Graphics demo 1: procedural bitmap
			uint32_t val = 0xF0F0F0F0;
			if (scanline / 4 % 2 == 0)
				val = ~val;
			PIOC->D32_DATA_REG0_3   = val;
			PIOC->D32_DATA_REG4_7   = val;
			PIOC->D32_DATA_REG8_11  = val;
			PIOC->D32_DATA_REG12_15 = val;
			PIOC->D32_DATA_REG16_19 = val;
			PIOC->D32_DATA_REG20_23 = val;
			PIOC->D32_DATA_REG24_27 = val;
			PIOC->D32_DATA_REG28_31 = val;
			PIOC->D8_CTRL_WR = 0x80; // Display graphics, interrupt after scanline.
		} else {
			// Graphics modes have vbuffer fllled on main
			uint32_t *p = vram.u32 + scanline*8;
			PIOC->D32_DATA_REG0_3   = p[0];
			PIOC->D32_DATA_REG4_7   = p[1];
			PIOC->D32_DATA_REG8_11  = p[2];
			PIOC->D32_DATA_REG12_15 = p[3];
			PIOC->D32_DATA_REG16_19 = p[4];
			PIOC->D32_DATA_REG20_23 = p[5];
			PIOC->D32_DATA_REG24_27 = p[6];
			PIOC->D32_DATA_REG28_31 = p[7];
			PIOC->D8_CTRL_WR = 0x80; // Display text from line 0, do not interrupt until 8th scanline.
		}
	}
	PIOC->D8_CTRL_RD = 0; // dummy write clear IRQ
}

uint32_t vsync_was = frame_counter;
void vsync() {
	while (vsync_was == frame_counter)
		asm volatile("" ::: "memory");
	vsync_was = frame_counter;
}

uint32_t my_random() {
	static uint32_t seed = 0x12345678;
	for (int i=0; i<32; ++i)
		seed = memtest_seed_next(seed);
	return seed ^ (seed >> 16);
}

int main()
{
	SystemInit();
	RCC->CFGR0 = 0;

	SetupUART4();
	printf("\n\n\n\nHello world!\n");

	funGpioInitAll(); // Enable GPIOs

	GPIOB->CFGHR.PIN12 = GPIO_CFGxR_OUT_10Mhz_PP;

	// Disable SWD usage of debug pins.
	AFIO->PCFR1.SW_CFG = 0b100;

	GPIOC->CFGXR.PIN18 = GPIO_CFGxR_OUT_50Mhz_AF_PP;
	GPIOC->CFGXR.PIN19 = GPIO_CFGxR_OUT_50Mhz_AF_PP;

	uint8_t *sram = (uint8_t *)PIOC_SRAM_BASE;
	memtest(sram, 4096);

	pioc_load(cvbs_text_32x24_pioc_bin, sizeof(cvbs_text_32x24_pioc_bin));
	NVIC_EnableIRQ(PIOC_IRQn);

	memset(&vram, 0, sizeof(vram));
	init_u8g2(vram.u8);

	// Dump bootloader for analysis
	printf("Bootloader area dump:");
	memdump((void*)0x1FFF0000, 3*1024 + 256);

	while(1)
	{
		vsync();
		if (1 && demoMode == DemoModes_e::bouncyDot) {
			size_t moved = 0;
			while (moved < 17) {
				auto makeden = []() -> int {
					return 0x00100000;
				};
				auto makenum = [](int den) -> int {
					int min = den *  2 / 16;
					int max = den * 14 / 16;
					return (uint64_t(my_random()) * (max-min)) >> 32 + min;
				};
				static size_t x=0;
				static int dx_num = 1;
				static int dx_den = 1;
				static int dx_acc = 0;
				dx_acc += dx_num;
				if (dx_acc > dx_den) {
					if (x == 255) {
						dx_acc = 0;
						dx_den = makeden();
						dx_num = -makenum(dx_den);
					} else {
						dx_acc -= dx_den;
						x += 1;
						moved++;
					}
				}
				if (dx_acc < -dx_den) {
					if (x == 0) {
						dx_acc = 0;
						dx_den = makeden();
						dx_num = +makenum(dx_den);
					} else {
						dx_acc += dx_den;
						x -= 1;
						moved++;
					}
				}

				static size_t y=0;
				static int dy_num = 1;
				static int dy_den = 1;
				static int dy_acc = 0;
				dy_acc += dy_num;
				if (dy_acc > dy_den) {
					if (y == 191) {
						dy_acc = 0;
						dy_den = makeden();
						dy_num = -makenum(dy_den);
					} else {
						dy_acc -= dy_den;
						y += 1;
						moved++;
					}
				}
				if (dy_acc < -dy_den) {
					if (y == 0) {
						dy_acc = 0;
						dy_den = makeden();
						dy_num = +makenum(dy_den);
					} else {
						dy_acc += dy_den;
						y -= 1;
						moved++;
					}
				}

				setpixel(x,y);
			}
			continue;
		}
		if (1 && demoMode == DemoModes_e::bouncyDvd) {
			static size_t x=0, y=0;
			static bool dx=true, dy = true;

			if (dx) {
				if (x == 255 - dvd_width)
					dx = false;
				else
					x += 1;
			} else {
				if (x == 0)
					dx = true;
				else
					x -= 1;
			}

			if (dy) {
				if (y == 191 - dvd_height)
					dy = false;
				else
					y += 1;
			} else {
				if (y == 0)
					dy = true;
				else
					y -= 1;
			}

			u8g2_DrawXBMP(&u8g2, x, y, dvd_width, dvd_height, dvd_bits);
			continue;
		}
		if (1 && demoMode == DemoModes_e::ass) {
			u8g2_DrawXBMP(&u8g2, 0, 0, ass_width, ass_height, ass_bits);

			while (demoMode == DemoModes_e::ass)
				asm volatile("" ::: "memory");

			continue;
		}
		if (1 && demoMode == DemoModes_e::randomLines) {
			int x0 = my_random() % 256;
			int x1 = my_random() % 256;
			int y0 = my_random() % 192;
			int y1 = my_random() % 192;
			u8g2_DrawLine(&u8g2, x0, y0, x1, y1);
			continue;
		}

		GPIOC->BSXR = 1 << 2 | 1 << 19;
		printf("SYS_CFG[%02X]  EXCH[%02X]  RD[%02X]  CFG[%02X]  IO[%02X]  TIMER0[INT=%02X, CNT=%02X, CTL=%02X]  PIOC_IRQ[%08lx]\n",
			PIOC->D8_SYS_CFG,
			PIOC->D8_DATA_EXCH,
			PIOC->D8_CTRL_RD,
			PIOC->D8_SYS_CFG,
			PIOC->D8_PORT_IO,
			PIOC->D8_TMR0_INIT,
			PIOC->D8_TMR0_COUNT,
			PIOC->D8_TMR0_CTRL,
			PIOC_IRQHandler_counter
		);

		if (PIOC->D8_DATA_EXCH & 1)
			GPIOB->BSHR = 1 << 12;
		else
			GPIOB->BCR  = 1 << 12;

		GPIOC->BSXR = 1 << 18 | 1  << 3;;
		Delay_Ms( 250 );
	}
}
