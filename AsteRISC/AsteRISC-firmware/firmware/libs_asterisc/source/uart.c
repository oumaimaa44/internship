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

#include "../include/uart.h"

void _putchar(char c) {
  uart0_putchar(c);
}

int uart0_putchar(int c) {
  while (uart0_status_bits->tx_full) {}
  *uart0_data_tx = c;
  return c;
}

int uart0_puts(const char *s) {
  int i = 0;
  while (s[i] != '\0') {
    uart0_putchar(s[i]);
    i++;
  } 
  return i;
}

char uart0_getchar() {
  while (uart0_status_bits->rx_empty) {}
  return uart0_data_rx_bits->value;
}

char *uart0_gets(char *s) {
  int ch;
  char *p = s;
  while ((ch = uart0_getchar()) != '\n') {
    *s = (char) ch;
    s++;
  }
  *s = '\0';
  return p;
}
