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


#ifndef _GPIO_LIB_H_
#define _GPIO_LIB_H_ 

#include "asterisc.h" 

#define LOW  0
#define HIGH 1

enum pinmode_e {
   INPUT,
   OUTPUT,
   INPUT_PULLUP,
   INPUT_PULLDOWN,
   HARDWARE_FUNCTION
};

void pinMode(unsigned long pin, enum pinmode_e mode);
void digitalWrite(unsigned long pin, unsigned char value);
unsigned char digitalRead(unsigned long pin);

#endif // _GPIO_LIB_H_