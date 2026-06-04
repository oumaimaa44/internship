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


#ifndef _7SEG_LIB_H_
#define _7SEG_LIB_H_ 

#include "asterisc.h"
#include "gpio.h" 

/* 
seven segment display format: [A B C D E F G P]
   -------                   MSB             LSB
   |  A  |
 F |     | B
   -------
   |  G  |
 E |     | C
   -------
      D
*/

typedef union {
  struct {
    unsigned char point                   : 1;
    unsigned char seg_G                   : 1;
    unsigned char seg_F                   : 1;
    unsigned char seg_E                   : 1;
    unsigned char seg_D                   : 1;
    unsigned char seg_C                   : 1;
    unsigned char seg_B                   : 1;
    unsigned char seg_A                   : 1;
  };
  struct {
    unsigned char value                   : 8;
  };
} seven_segment_t;

seven_segment_t get_7seg_value(unsigned char input);

#endif // _7SEG_LIB_H_