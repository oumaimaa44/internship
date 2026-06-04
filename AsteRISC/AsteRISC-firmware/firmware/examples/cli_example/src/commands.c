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

#include "commands.h"

command_t commands[COMMAND_COUNT] = {
  {
    .name = "cute", 
    .args = "", 
    .description = "display a cute kitten",
    .implementation = &cute
  },
  {
    .name = "echo", 
    .args = "<string>", 
    .description = "display a line of text",
    .implementation = &echo
  },
  {
    .name = "help", 
    .args = "", 
    .description = "list all available commands",
    .implementation = &help
  },
  {
    .name = "read", 
    .args = "<address>", 
    .description = "read data from memory",
    .implementation = &read_data
  },
  {
    .name = "write", 
    .args = "<address> <value>",
    .description = "write data to memory",
    .implementation = &write_data
  }
};

void help(char* args) {
  for (unsigned char i = 0 ; i < COMMAND_COUNT ; i++) {
    my_puts(_BOLD);
    my_puts(commands[i].name);
    my_puts(_ITALIC);
    my_puts(" ");
    my_puts(commands[i].args);
    my_puts(_END);
    my_puts(OUTPUT_NEWLINE);
    my_puts("\t");
    my_puts(commands[i].description);
    if (i < COMMAND_COUNT - 1) {
      my_puts(OUTPUT_NEWLINE);
      my_puts(OUTPUT_NEWLINE);
    }
  }
}

void read_data(char* args) {
  char* address = my_strtok(args, COMMAND_SEPARATOR);
  unsigned long address_value = strtoul(address, NULL, 0);

  volatile unsigned long *pointer = (unsigned long *)(address_value);
  print_dec_hex_bin(*pointer);
}

void write_data(char* args) {
  char* address = my_strtok(args, COMMAND_SEPARATOR);
  unsigned long address_value = strtoul(address, NULL, 0);

  char* data = my_strtok(NULL, COMMAND_SEPARATOR);
  unsigned long data_value = strtoul(data, NULL, 0);

  volatile unsigned long *pointer = (unsigned long *)(address_value);
  *pointer = data_value;
  print_dec_hex_bin(*pointer);
}

void echo(char* args) {
  my_puts(args);
}

void cute(char* args) {
  my_puts(" ,_     _\r\n");
  my_puts(" |\\\\_,-~/\r\n");
  my_puts(" / _  _ |    ,--.\r\n");
  my_puts("(  @  @ )   / ,-'\r\n");
  my_puts(" \\  _T_/-._( (\r\n");
  my_puts(" /         `. \\\r\n");
  my_puts("|         _  \\ |\r\n");
  my_puts(" \\ \\ ,  /      |\r\n");
  my_puts("  || |-_\\__   /\r\n");
  my_puts(" ((_/`(____,-'\r\n");
}

void print_dec_hex_bin(unsigned long data) {
  char data_string[33];
  itoa(data, data_string, 10);
  my_puts(data_string);
  my_puts(OUTPUT_NEWLINE);
  my_puts("0x");
  itoa(data, data_string, 16);
  my_puts(data_string);
  my_puts(OUTPUT_NEWLINE);
  my_puts("0b");
  itoa(data, data_string, 2);
  my_puts(data_string);
}