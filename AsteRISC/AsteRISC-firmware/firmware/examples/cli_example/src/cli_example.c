/**********************************************************************\
*                               AsteRISC                               *
************************************************************************
*
* Copyright (C) 2022 Jonathan Saussereau
*
* This file is part of AsteRISC.
* AsteRISC is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
* 
* AsteRISC is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with AsteRISC. If not, see <https://www.gnu.org/licenses/>.
*
*/

#include <asterisc.h>
#include <gpio.h>
#include <uart.h> 
#include <uart_extensions.h> 

#include "cli.h"

#define UART_TX_GPIO 19
#define UART_RX_GPIO 18

#define SWITCH_GPIO 15

#define SWLED_GPIO  7
#define TMLED_GPIO  6

#define TARGET_FREQUENCY 40000000
#define UART_BAUDRATE    BAUD_115200



void init() {
  //gpio config:
  pinMode(TMLED_GPIO, OUTPUT);
  digitalWrite(TMLED_GPIO, HIGH);

  pinMode(SWLED_GPIO, OUTPUT);
  pinMode(SWITCH_GPIO, INPUT);

  pinMode(UART_TX_GPIO, HARDWARE_FUNCTION);
  pinMode(UART_RX_GPIO, HARDWARE_FUNCTION);
  
  // uart config:
  uart0_config_bits->baudrate = GET_BAUDRATE_DIV(UART_BAUDRATE, TARGET_FREQUENCY);
  uart0_config_bits->tx_en = 1;
  uart0_config_bits->rx_en = 1;
}

void motd();

int _entry() {

  init();

  // print hello
  uart0_puts(_BOLD);
  uart0_puts("*****************\r\n");
  uart0_puts("* Hello, world! *\r\n");
  uart0_puts("*****************\r\n");
  uart0_puts(_END);
  uart0_puts("\r\n");

  while(1) {
    cli_execute();
  }

  // write switch state on the LED
  unsigned char switch0 = digitalRead(SWITCH_GPIO);
  digitalWrite(SWLED_GPIO, switch0);  

  return 0;
}