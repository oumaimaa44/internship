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

int _entry() {

  // Set GPIO 0 to 3 as ouputs
  //*iof_sel = 0xf;
  pinMode(0, HARDWARE_FUNCTION);
  pinMode(1, HARDWARE_FUNCTION);
  pinMode(2, HARDWARE_FUNCTION);
  pinMode(3, HARDWARE_FUNCTION);

  // Config reg
  pwm0_config_bits->scale               = 12;
  pwm0_config_bits->sticky              = 0;
  pwm0_config_bits->deglitch            = 1;
  pwm0_config_bits->compare2_complement = 1;
  pwm0_config_bits->zero_cmp            = 1;
  pwm0_config_bits->en_always           = 1;

  // Compare regs
  *pwm0_compare0 = 200;
  *pwm0_compare1 = 100;
  *pwm0_compare2 = *pwm0_compare1;
  *pwm0_compare3 = 150;

  while(1) {
    asm("nop");
  }

  return 0;
}