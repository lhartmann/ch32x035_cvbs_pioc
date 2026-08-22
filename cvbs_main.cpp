#include "ch32fun.h"
#include "PIOC_SFR.h"
#include <stdio.h>
#include "xcgh_incrementer.pioc.h"
#include "cvbs_text_32x24.pioc.h"
#include "blink.pioc.h"

extern union PIOC_SRAM_u {
	uint8_t  u8 [4096];
	uint16_t u16[2048];
	uint32_t u32[1024];
} PIOC_SRAM;

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

	// memfill(PIOC_SRAM.u8 + len, 4096 - len); // pad with NOP
	memset(PIOC_SRAM.u8 + len, 0x55, 4096 - len); // pad with NOP

	memdump(PIOC_SRAM.u8, 4096);

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

	uint32_t mask = 0;
	uint32_t val  = 0;
#define val_for_pin(pin, val) (((val) & 0xFu) << ((pin)%8*4))
#define mask_for_pin(pin) val_for_pin(pin, 0xFu)

	GPIOC->CFGXR.PIN18 = GPIO_CFGxR_OUT_50Mhz_AF_PP;
	GPIOC->CFGXR.PIN19 = GPIO_CFGxR_OUT_50Mhz_AF_PP;

	uint8_t *sram = (uint8_t *)PIOC_SRAM_BASE;
	memtest(sram, 4096);

//	pioc_load(xcgh_incrementer_pioc_bin, sizeof(xcgh_incrementer_pioc_bin));
	pioc_load(cvbs_text_32x24_pioc_bin, sizeof(cvbs_text_32x24_pioc_bin));
//	pioc_load(blink_pioc_bin, sizeof(blink_pioc_bin));

	PIOC->D32_DATA_REG0_3   = 0x43424140U;
	PIOC->D32_DATA_REG4_7   = 0x47464544U;
	PIOC->D32_DATA_REG8_11  = 0x4b4a4948U;
	PIOC->D32_DATA_REG12_15 = 0x4f4e4d4cU;
	PIOC->D32_DATA_REG16_19 = 0x53525150U;
	PIOC->D32_DATA_REG20_23 = 0x57565554U;
	PIOC->D32_DATA_REG24_27 = 0x5b5a5958U;
	PIOC->D32_DATA_REG28_31 = 0x5f5e5d5cU;

	while(1)
	{
		GPIOC->BSXR = 1 << 2 | 1 << 19;
		printf("SYS_CFG[%02X]  EXCH[%02X]  RD[%02X]  CFG[%02X]  IO[%02X]  TIMER0[INT=%02X, CNT=%02X, CTL=%02X]\n",
			PIOC->D8_SYS_CFG,
			PIOC->D8_DATA_EXCH,
			PIOC->D8_CTRL_RD,
			PIOC->D8_SYS_CFG,
			PIOC->D8_PORT_IO,
			PIOC->D8_TMR0_INIT,
			PIOC->D8_TMR0_COUNT,
			PIOC->D8_TMR0_CTRL
		);

		if (PIOC->D8_DATA_EXCH & 1)
			GPIOB->BSHR = 1 << 12;
		else
			GPIOB->BCR  = 1 << 12;

		GPIOC->BSXR = 1 << 18 | 1  << 3;;
		Delay_Ms( 250 );
	}
}
