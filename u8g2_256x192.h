#include "u8g2.h"

#define FB_WIDTH  256
#define FB_HEIGHT 192
#define FB_SIZE   ((FB_WIDTH * FB_HEIGHT) / 8) // 6,144 bytes

u8g2_t u8g2;
static const u8x8_display_info_t vx82_display_info = {
    /* chip_enable_level = */ 0,
    /* chip_disable_level = */ 1,

    /* post_chip_enable_wait_ns = */ 0,
    /* pre_chip_disable_wait_ns = */ 0,
    /* reset_pulse_width_ms = */ 0,
    /* post_reset_wait_ms = */ 0,
    /* sda_setup_time_ns = */ 0,
    /* sck_pulse_width_ns = */ 0,	/* half of cycle time (100ns according to datasheet), AVR: below 70: 8 MHz, >= 70 --> 4MHz clock */
    /* sck_clock_hz = */ 4000000UL,	/* since Arduino 1.6.0, the SPI bus speed in Hz. Should be  1000000000/sck_pulse_width_ns */
    /* spi_mode = */ 0,		/* active high, rising edge */
    /* i2c_bus_clock_100kHz = */ 4,
    /* data_setup_time_ns = */ 0,
    /* write_pulse_width_ns = */ 0,
    /* tile_width = */ 256/8,		/* 8x8 */
    /* tile_hight = */ 192/8,
    /* default_x_offset = */ 0,
    /* flipmode_x_offset = */ 0,
    /* pixel_width = */ 256,
    /* pixel_height = */ 192
};

// Does nothing, return success
uint8_t u8x8_nop_cb(U8X8_UNUSED u8x8_t *u8x8, U8X8_UNUSED uint8_t msg, U8X8_UNUSED uint8_t arg_int, U8X8_UNUSED void *arg_ptr)  {
    return 1;
}

void init_u8g2(uint8_t  *framebuffer) {
    u8g2_SetupDisplay(&u8g2, u8x8_nop_cb, u8x8_nop_cb, u8x8_nop_cb, u8x8_nop_cb);
    u8g2.u8x8.display_info = &vx82_display_info;
    u8g2_SetupBuffer(&u8g2, framebuffer, 192/8, u8g2_ll_hvline_horizontal_right_lsb, &u8g2_cb_r0);

    u8g2_InitDisplay(&u8g2);
    u8g2_SetPowerSave(&u8g2, 0);
    u8g2_ClearBuffer(&u8g2);
}

