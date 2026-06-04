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


#ifndef _UART_EXTENSIONS_LIB_H_
#define _UART_EXTENSIONS_LIB_H_ 

#include "asterisc.h" 
#include "uart.h" 
#include <stddef.h>
#include <stdlib.h>
#include <stdarg.h>

void uart0_printf_c(char  c);

void uart0_printf_s(char *p);

void uart0_printf_x(unsigned long val, unsigned char char_count);

void uart0_printf_d(int val);

void uart0_printf(const char *format, ...);

void itoa_light(unsigned long val, char *dest);

int my_strcmp(const char *a, const char *b);

unsigned char is_delim(char c, char *delim);

char* my_strtok(char *s, char *delim);


#endif // _UART_EXTENSIONS_LIB_H_