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

#ifndef _CONFIG_H_
#define _CONFIG_H_ 

#define _END                "\x1b[0m"
#define _BOLD               "\x1b[1m"
#define _ITALIC             "\x1b[3m"
#define _RED                "\x1b[31m"
#define _GREEN              "\x1b[32m"
#define _YELLOW             "\x1b[33m"
#define _BLUE               "\x1b[34m"
#define _CYAN               "\x1b[36m"
#define _WHITE              "\x1b[37m"

#define INPUT_KEY_CTRL_C    0x03
#define INPUT_KEY_BACKSPACE 0x08
#define INPUT_KEY_TAB       0x09
#define INPUT_KEY_ENTER     0x0D
#define INPUT_KEY_ESCAPE    0x1B
#define INPUT_KEY_DELETE    0x7F

#define OUTPUT_NEWLINE      "\r\n"


#define PROMPT_MSG          "[asterisc]$ "
#define UNKNOWN_MSG         "Unknown command. Type \"help\" for help."

#define PROMPT_COLOR        _CYAN
#define ERROR_COLOR         _RED

#define COMMAND_SEPARATOR   " "

#define MAX_INPUT_CHARACTERS 128

#endif // _CONFIG_H_