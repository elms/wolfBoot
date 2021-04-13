#include <stdint.h>

#define DEBUG_UART

#ifdef DEBUG_UART

#define CCSRBAR 0xFE000000
#define UART0_OFFSET 0x11C500
#define UART0_BASE  (CCSRBAR + UART0_OFFSET)

#define SYS_CLK 100000000

static inline uint8_t in_8(const volatile unsigned char *addr)
{
	uint8_t ret;

	__asm__ __volatile__(
		"sync; lbz%U1%X1 %0,%1;\n"
		"twi 0,%0,0;\n"
		"isync" : "=r" (ret) : "m" (*addr));
	return ret;
}

static inline void out_8(volatile unsigned char *addr, uint8_t val)
{
	__asm__ __volatile__("sync;\n"
			     "stb%U0%X0 %1,%0;\n"
			     : "=m" (*addr)
			     : "r" (val));
}

static void uart_init(void) {
    /* calc divisor */
    //clock_div, baud, base_clk  163 115200 300000000
    uint32_t div = 163; //(SYS_CLK / 2) / (16 * 115200);
    register volatile uint8_t* uart = (uint8_t*)UART0_BASE;

    while (!(in_8(uart + 5) & 0x40))
       ;

    /* set ier, fcr, mcr */
    out_8(uart + 1, 0);
    out_8(uart + 4, 3);
    out_8(uart + 2, 7);

    /* enable buad rate access (DLAB=1) - divisor latch access bit*/
    out_8(uart + 3, 0x83);
    /* set divisor */
    out_8(uart + 0, div & 0xff);
    out_8(uart + 1, (div>>8) & 0xff);
    /* disable rate access (DLAB=0) */
    out_8(uart + 3, 0x03);
}

static void uart_write(const char* buf, uint32_t sz)
{
    volatile uint8_t* uart = (uint8_t*)UART0_BASE;
    uint32_t pos = 0;
    while (sz-- > 0) {
        while (!(in_8(uart + 5) & 0x20))
		;
        out_8(uart + 0, buf[pos++]);
    }
}
#endif /* DEBUG_UART */


void main(void) {
    int i = 0;
    int j = 0;
    int k = 0;
    uart_write("wolfBoot\n", 9);

    /* Wait for reboot */
    while(1) {
        for (j=0; j<100000; j++)
            ;
        i++;
        uart_write("0x", 2);
        k = i;
        while (k>0) {
            uart_write(k%10 + '0', 1);
            k /= 10;
        }
    }
}
