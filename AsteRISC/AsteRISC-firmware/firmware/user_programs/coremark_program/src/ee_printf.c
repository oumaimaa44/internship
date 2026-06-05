// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#include <stdarg.h>
#include <stdint.h>
#include <uart.h>

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
      uart0_putchar(format[i]);
      i++;
    } else {
      while (format[i] != '\0') {
        i++;
        if (format[i] == 'c') { 
          uval = va_arg(arg, unsigned long);
          uart0_putchar((char)uval);
          break;
        } else if (format[i] == 'd') { 
          sval = va_arg(arg, signed long);
          if (sval < 0) {
            sval = -sval;
            uart0_putchar('-');
          }
          uart0_puts(ee_convert(sval, 10));
          break;
        } else if (format[i] == 'u') { 
          uval = va_arg(arg, unsigned long);
          uart0_puts(ee_convert(uval, 10));
          break;
        } else if (format[i] == 'o') { 
          uval = va_arg(arg, unsigned long);
          uart0_puts(ee_convert(uval, 8));
          break;
        } else if (format[i] == 's') { 
          str = va_arg(arg, char *);
          uart0_puts(str);
          break;
        } else if (format[i] == 'x') { 
          uval = va_arg(arg, unsigned long);
          uart0_puts(ee_convert(uval, 16));
          break;
        } else if (format[i] == '%') {
          uart0_putchar('%');
          break;
        }
      }
      i++;
    }
  }

  va_end(arg); 
}

      }
      i++;
    }
  }

  va_end(arg); 
}
