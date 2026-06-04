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

#include "../include/gpio.h" 

void pinMode(unsigned long pin, enum pinmode_e mode) {
  unsigned long mask = (1 << pin);
  *gpio_output_en   = (mode == OUTPUT)            ? *gpio_output_en   | mask : *gpio_output_en   & ~mask;
  *gpio_pullup_en   = (mode == INPUT_PULLUP)      ? *gpio_pullup_en   | mask : *gpio_pullup_en   & ~mask;
  *gpio_pulldown_en = (mode == INPUT_PULLDOWN)    ? *gpio_pulldown_en | mask : *gpio_pulldown_en & ~mask;
  *iof_sel          = (mode == HARDWARE_FUNCTION) ? *iof_sel          | mask : *iof_sel          & ~mask;
}

unsigned char digitalRead(unsigned long pin) {
  return (*gpio_read_value & (1 << pin)) >> pin;
}

void digitalWrite(unsigned long pin, unsigned char value) {
  *gpio_write_value = (value == LOW) ? *gpio_write_value & ~(1 << pin) : *gpio_write_value | (1 << pin);
}

