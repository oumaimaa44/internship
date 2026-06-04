
#include <asterisc.h>
#include <debug.h>
#include <gpio.h>
#include <uart.h>
#include <uart_extensions.h> 

#include "my_defines.h"

void init() {
    // pinMode sets the pin mode (INPUT, OUTPUT, INPUT_PULLUP, INPUT_PULLDOWN, HARDWARE_FUNCTION)
    pinMode(SWLED_GPIO, OUTPUT);
    pinMode(SWITCH_GPIO, INPUT);

    // with HARDWARE_FUNCTION, pinMode connects the UART peripheral to the GPIO pins
    pinMode(UART_TX_GPIO, HARDWARE_FUNCTION);
    pinMode(UART_RX_GPIO, HARDWARE_FUNCTION);

    // uart config:
    uart0_config_bits->baudrate = GET_BAUDRATE_DIV(UART_BAUDRATE, TARGET_FREQUENCY); // set baudrate divisor
    uart0_config_bits->tx_en = 1; // enable TX
}

// This is the "main" function of your program.
int _entry() {

    init();

    // debug_printf oututs the string to the simulation console/log
    debug_printf(AWESOME_MESSAGE);

    // uart0_printf outputs the string to the UART0 serial port
    uart0_printf(AWESOME_MESSAGE);

    while (1) {
        unsigned char switch0 = digitalRead(SWITCH_GPIO); // read switch state
        digitalWrite(SWLED_GPIO, switch0); // write switch state to LED
    }
    
    return 0;
}
