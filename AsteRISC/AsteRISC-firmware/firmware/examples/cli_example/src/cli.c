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

#include "cli.h" 

void cli_execute() {
  char input_buffer[MAX_INPUT_CHARACTERS];
  unsigned short cursor_pos = 0;
  char c;

  my_puts(PROMPT_COLOR);
  my_puts(PROMPT_MSG);
  my_puts(_END);

  while ((c = my_getchar()) != INPUT_KEY_ENTER) {
    if (cursor_pos < MAX_INPUT_CHARACTERS - 1) {
      if (c == INPUT_KEY_BACKSPACE || c == INPUT_KEY_DELETE) {
        if (cursor_pos > 0) {
          my_putchar(c);
          cursor_pos--;
        }
      } else {
        my_putchar(c);
        input_buffer[cursor_pos] = c;
        cursor_pos++;
      }
    }
  }

  my_puts(OUTPUT_NEWLINE);

  if (cursor_pos == 0) {
    return;
  }

  input_buffer[cursor_pos] = '\0';

  char* command = my_strtok(input_buffer, COMMAND_SEPARATOR);
  char* arg = my_strtok(NULL, "");

  unsigned char command_found = 0;
  for (unsigned char i = 0 ; i < COMMAND_COUNT ; i++) {
    if (my_strcmp(command, commands[i].name) == 0) {
      (commands[i].implementation)(arg);
      command_found = 1;
      break;
    }
  }
  if (!command_found) {
    my_puts(ERROR_COLOR);
    my_puts(UNKNOWN_MSG);
    my_puts(_END);
  }
  my_puts(OUTPUT_NEWLINE);
}