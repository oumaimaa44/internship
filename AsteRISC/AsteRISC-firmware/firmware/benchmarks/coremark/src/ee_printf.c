// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#include <stdarg.h>
#include <stdint.h>

static void ee_putchar(int c) {
  *((volatile int*)0x0A000000) = c;
}

static void ee_puts(char *p) {
  while (*p)
  *((volatile int*)0x0A000000) = *(p++);
}

char* ee_convert(unsigned long num, int base) { 
  static char Representation[]= "0123456789ABCDEF";
  static char buffer[50]; 
  char *ptr; 

  ptr = &buffer[49]; 
  *ptr = '\0'; 

  do { 
    *--ptr = Representation[num%base]; 
    num /= base; 
  } while (num != 0); 

  return(ptr); 
}

void ee_printf(char* format, ...) { 
  unsigned long i = 0; 
  unsigned long uval; 
  signed long sval; 
  char *str; 

  va_list arg; 
  va_start(arg, format); 

  while (format[i] != '\0') {
    if (format[i] != '%') { 
      ee_putchar(format[i]);
      i++;
    } else {
      while (format[i] != '\0') {
        i++;
        if (format[i] == 'c') { 
          uval = va_arg(arg, unsigned long);
          ee_putchar(sval);
          break;
        } else if (format[i] == 'd') { 
          sval = va_arg(arg, signed long);
          if (sval < 0) {
            sval = -sval;
            ee_putchar('-');
          }
          ee_puts(ee_convert(sval, 10));
          break;
        } else if (format[i] == 'u') { 
          uval = va_arg(arg, unsigned long);
          ee_puts(ee_convert(uval, 10));
          break;
        } else if (format[i] == 'o') { 
          uval = va_arg(arg, unsigned long);
          ee_puts(ee_convert(uval, 8));
          break;
        } else if (format[i] == 's') { 
          str = va_arg(arg, signed char *);
          ee_puts(str);
          break;
        } else if (format[i] == 'x') { 
          uval = va_arg(arg, unsigned long);
          ee_puts(ee_convert(uval, 16));
          break;
        }
      }
      i++;
    }
  }

  va_end(arg); 
}
