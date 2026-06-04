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


#ifndef _UART_LIB_H_
#define _UART_LIB_H_ 

#include "asterisc.h" 
#include <stddef.h>
#include <stdlib.h>
#include <stdarg.h>

#define GET_BAUDRATE_DIV(GBD_BAUDRATE, GBD_FREQUENCY) ((GBD_FREQUENCY) / (1 + (GBD_BAUDRATE)))

// Usual Baudrates (All supported at 100 MHz):
#define BAUD_2400    2400  
#define BAUD_4800    4800  
#define BAUD_9600    9600  
#define BAUD_19200   19200 
#define BAUD_38400   38400 
#define BAUD_57600   57600 
#define BAUD_115200  115200
#define BAUD_230400  230400
#define BAUD_460800  460800
#define BAUD_570600  570600
#define BAUD_921600  921600
#define BAUD_1000000 1000000
#define BAUD_2000000 2000000

void _putchar(char c);

int uart0_putchar(int c);

char uart0_getchar();

int uart0_puts(const char *s);

#endif // _UART_LIB_H_