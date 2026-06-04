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

#include "../include/uart_extensions.h"


static const char itoa_lookup_table[][10] = {
  "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01", // 2^0  =             1
  "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02", // 2^1  =             2
  "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04", // 2^2  =             4
  "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08", // 2^3  =             8
  "\x00\x00\x00\x00\x00\x00\x00\x00\x01\x06", // 2^4  =            16
  "\x00\x00\x00\x00\x00\x00\x00\x00\x03\x02", // 2^5  =            32
  "\x00\x00\x00\x00\x00\x00\x00\x00\x06\x04", // 2^6  =            64
  "\x00\x00\x00\x00\x00\x00\x00\x01\x02\x08", // 2^7  =           128
  "\x00\x00\x00\x00\x00\x00\x00\x02\x05\x06", // 2^8  =           256
  "\x00\x00\x00\x00\x00\x00\x00\x05\x01\x02", // 2^9  =           512
  "\x00\x00\x00\x00\x00\x00\x01\x00\x02\x04", // 2^10 =         1,024
  "\x00\x00\x00\x00\x00\x00\x02\x00\x04\x08", // 2^11 =         2,048
  "\x00\x00\x00\x00\x00\x00\x04\x00\x09\x06", // 2^12 =         4,096
  "\x00\x00\x00\x00\x00\x00\x08\x01\x09\x02", // 2^13 =         8,192
  "\x00\x00\x00\x00\x00\x01\x06\x03\x08\x04", // 2^14 =        16,384 
  "\x00\x00\x00\x00\x00\x03\x02\x07\x06\x08", // 2^15 =        32,768 
  "\x00\x00\x00\x00\x00\x06\x05\x05\x03\x06", // 2^16 =        65,536 
  "\x00\x00\x00\x00\x01\x03\x01\x00\x07\x02", // 2^17 =       131,072 
  "\x00\x00\x00\x00\x02\x06\x02\x01\x04\x04", // 2^18 =       262,144 
  "\x00\x00\x00\x00\x05\x02\x04\x02\x08\x08", // 2^19 =       524,288 
  "\x00\x00\x00\x01\x00\x04\x08\x05\x07\x06", // 2^20 =     1,048,576 
  "\x00\x00\x00\x02\x00\x09\x07\x01\x05\x02", // 2^21 =     2,097,152 
  "\x00\x00\x00\x04\x01\x09\x04\x03\x00\x04", // 2^22 =     4,194,304 
  "\x00\x00\x00\x08\x03\x08\x08\x06\x00\x08", // 2^23 =     8,388,608 
  "\x00\x00\x01\x06\x07\x07\x07\x02\x01\x06", // 2^24 =    16,777,216 
  "\x00\x00\x03\x03\x05\x05\x04\x04\x03\x02", // 2^25 =    33,554,432 
  "\x00\x00\x06\x07\x01\x00\x08\x08\x06\x04", // 2^26 =    67,108,864 
  "\x00\x01\x03\x04\x02\x01\x07\x07\x02\x08", // 2^27 =   134,217,728 
  "\x00\x02\x06\x08\x04\x03\x05\x04\x05\x06", // 2^28 =   268,435,456 
  "\x00\x05\x03\x06\x08\x07\x00\x09\x01\x02", // 2^29 =   536,870,912 
  "\x01\x00\x07\x03\x07\x04\x01\x08\x02\x04", // 2^30 = 1,073,741,824 
  "\x02\x01\x04\x07\x04\x08\x03\x06\x04\x08"  // 2^31 = 2,147,483,648 
}; // uses 320 bytes (80 32-bits words) of memory

void itoa_light(unsigned long val, char *dest) {
  char sum;
  char carry;
  char result[10] = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
  const char *lookup_value;

  for (unsigned char bit = 0 ; bit < 32 ; bit++) {
    if (val & (1 << bit)) {
      carry = 0;
      lookup_value = itoa_lookup_table[bit]; // get the decimal notation of the power of 2 corresponding to the bit position
      for (int i = 9 ; i >= 0 ; i--) {
        sum = result[i] + lookup_value[i] + carry;
        if (sum < 10) {
          carry = 0;
        } else {
          carry = 1;
          sum -= 10;
        }
        result[i] = sum;
      }
    }
  }

  int digit = 0;
  while (!result[digit] && digit < 9) {
    digit++; // ignore leading zeroes
  }
  while (digit < 10) {
    *dest++ = result[digit] + '0'; // add ASCII number offset
    digit++;
  }
  *dest++ = '\0';
}

int my_strcmp(const char *a, const char *b) {
  while (*a && *a == *b) { 
    ++a; 
    ++b; 
  }
  return (int)(unsigned char)(*a) - (int)(unsigned char)(*b);
}

unsigned char is_delim(char c, char *delim) {
  while (*delim != '\0') {
    if (c == *delim) {
      return 1;
    }
    delim++;
  }
  return 0;
}

char* my_strtok(char *s, char *delim) {
  static char *p;
  if (!s) {
    s = p;
  }
  if (!s) {
    return NULL;
  }

  while (1) {
    if (is_delim(*s, delim)) {
      s++;
      continue;
    }
    if (*s == '\0') {
      return NULL;
    }
    break;
  }

  char *ret = s;
  while (1) {
    if (*s == '\0') {
      p = s;
      return ret;
    }
    if (is_delim(*s, delim)) {
      *s = '\0';
      p = s + 1;
      return ret;
    }
    s++;
  }
}

void uart0_printf_c(char  c) {
  uart0_putchar(c);
}

void uart0_printf_s(char *p) {
  uart0_puts(p);
}

void uart0_printf_x(unsigned long val, unsigned char char_count){
  unsigned char count = 0;
  char result[9]; // for 32 bit input: 8 hex characters + '\0'
  char hex;

  // get every hex characters from lsb to msb
  while (val > 0) {
    hex = val & 0x0000000f;
    if (hex < 10) { // from '0' to '9'
      hex += '0';
    } else { // from 'a' to 'f'
      hex += 'a' - 0xa;
    }
    result[count] = hex;
    count ++;
    val >>= 4; 
  }

  // print zeroes 
  if (char_count > 0) {
    for (unsigned char i = 0 ; i < char_count - count ; i++) {
      uart0_printf_c('0');
    }
  }

  // prints hex characters in reverse order: from msb to lsb
  while (count > 0) {
    uart0_printf_c(result[count-1]);
    count--; 
  }
}

void uart0_printf_d(int val) {
  char buffer[32];
  char *p = buffer;
  if (val < 0) {
    uart0_printf_c('-');
    val = -val;
  }
  while (val || p == buffer) {
    *(p++) = '0' + val % 10;
    val = val / 10;
  }
  while (p != buffer)
    uart0_printf_c(*(--p));
}

void uart0_printf(const char *format, ...) {
  int i;
  va_list ap;

  va_start(ap, format);

  for (i = 0; format[i]; i++)
    if (format[i] == '%') {
      while (format[++i]) {
      if (format[i] == 'c') {
        uart0_printf_c(va_arg(ap,int));
        break;
      }
      if (format[i] == 's') {
        uart0_printf_s(va_arg(ap,char*));
        break;
      }
      if (format[i] == 'd') {
        uart0_printf_d(va_arg(ap,int));
        break;
      }
      if (format[i] == 'x') {
        uart0_printf_x(va_arg(ap,int), 8);
        break;
      }
      }
    } else {
      uart0_printf_c(format[i]);
    }
  va_end(ap);
}
