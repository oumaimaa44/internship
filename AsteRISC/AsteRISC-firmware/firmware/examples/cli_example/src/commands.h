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

#ifndef _COMMANDS_H_
#define _COMMANDS_H_ 

#include <string.h>
#include "implem.h" 
#include "config.h" 
#include <uart.h>
#include <uart_extensions.h>

#define COMMAND_COUNT 5

typedef struct {
  char name[16];
  char args[32];
  char description[128];
  void (*implementation) (char*);
} command_t;

extern command_t commands[COMMAND_COUNT];

void print_dec_hex_bin(unsigned long data);

void help(char* args);
void read_data(char* args);
void write_data(char* args);
void echo(char* args);
void cute(char* args);

#endif // _COMMANDS_H_