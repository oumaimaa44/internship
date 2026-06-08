/*
Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/* Modified for the AsteRISC Processor  */


#include "coremark.h"
#include <stdarg.h>

#define ZEROPAD   (1 << 0)
#define SIGN      (1 << 1)
#define PLUS      (1 << 2)
#define SPACE     (1 << 3)
#define LEFT      (1 << 4)
#define HEX_PREP  (1 << 5)
#define UPPERCASE (1 << 6)

#define is_digit(c) ((c) >= '0' && (c) <= '9')

static const char digits[]       = "0123456789abcdefghijklmnopqrstuvwxyz";
static const char upper_digits[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

static ee_size_t
local_strnlen(const char *s, ee_size_t count)
{
    const char *sc = s;
    while (*sc != '\0' && count--)
        sc++;
    return (ee_size_t)(sc - s);
}

static int
skip_atoi(const char **s)
{
    int i = 0;
    while (is_digit(**s))
        i = i * 10 + *((*s)++) - '0';
    return i;
}

/* Software unsigned divide/modulo, so the formatter works on RV32I without M div/rem. */
static unsigned long
udivmod_ul(unsigned long n, unsigned long d, unsigned long *rem)
{
    unsigned long q = 0;
    unsigned long r = 0;
    int bit;

    if (d == 0) {
        *rem = 0;
        return 0;
    }

    for (bit = 31; bit >= 0; bit--) {
        r = (r << 1) | ((n >> bit) & 1UL);
        if (r >= d) {
            r -= d;
            q |= (1UL << bit);
        }
    }

    *rem = r;
    return q;
}

static char *
number(char *str, long num, int base, int size, int precision, int type)
{
    char c, sign, tmp[66];
    const char *dig = digits;
    int i;
    unsigned long unum;

    if (type & UPPERCASE)
        dig = upper_digits;
    if (type & LEFT)
        type &= ~ZEROPAD;
    if (base < 2 || base > 36)
        return str;

    c = (type & ZEROPAD) ? '0' : ' ';
    sign = 0;

    if (type & SIGN) {
        if (num < 0) {
            sign = '-';
            /* Avoid undefined overflow for LONG_MIN on normal hosts. RV32 bare-metal is fine too. */
            unum = (unsigned long)(-(num + 1)) + 1UL;
            size--;
        } else {
            unum = (unsigned long)num;
            if (type & PLUS) {
                sign = '+';
                size--;
            } else if (type & SPACE) {
                sign = ' ';
                size--;
            }
        }
    } else {
        unum = (unsigned long)num;
    }

    if (type & HEX_PREP) {
        if (base == 16)
            size -= 2;
        else if (base == 8)
            size--;
    }

    i = 0;
    if (unum == 0) {
        tmp[i++] = '0';
    } else {
        while (unum != 0) {
            unsigned long rem;
            unum = udivmod_ul(unum, (unsigned long)base, &rem);
            tmp[i++] = dig[rem];
        }
    }

    if (i > precision)
        precision = i;
    size -= precision;

    if (!(type & (ZEROPAD | LEFT)))
        while (size-- > 0)
            *str++ = ' ';
    if (sign)
        *str++ = sign;

    if (type & HEX_PREP) {
        if (base == 8) {
            *str++ = '0';
        } else if (base == 16) {
            *str++ = '0';
            *str++ = (type & UPPERCASE) ? 'X' : 'x';
        }
    }

    if (!(type & LEFT))
        while (size-- > 0)
            *str++ = c;
    while (i < precision--)
        *str++ = '0';
    while (i-- > 0)
        *str++ = tmp[i];
    while (size-- > 0)
        *str++ = ' ';

    return str;
}

#if HAS_FLOAT
/* Keep the original CoreMark float helpers in another file/version if you need HAS_FLOAT=1.
 * For first working AsteRISC benchmark, set HAS_FLOAT to 0 in core_portme.h. */
#endif

static int
ee_vsprintf(char *buf, const char *fmt, va_list args)
{
    int len;
    int i, base;
    char *str;
    char *s;

    int flags;
    int field_width;
    int precision;
    int qualifier;

    for (str = buf; *fmt; fmt++) {
        if (*fmt != '%') {
            *str++ = *fmt;
            continue;
        }

        flags = 0;
repeat:
        fmt++;
        switch (*fmt) {
            case '-': flags |= LEFT;     goto repeat;
            case '+': flags |= PLUS;     goto repeat;
            case ' ': flags |= SPACE;    goto repeat;
            case '#': flags |= HEX_PREP; goto repeat;
            case '0': flags |= ZEROPAD;  goto repeat;
        }

        field_width = -1;
        if (is_digit(*fmt)) {
            field_width = skip_atoi(&fmt);
        } else if (*fmt == '*') {
            fmt++;
            field_width = va_arg(args, int);
            if (field_width < 0) {
                field_width = -field_width;
                flags |= LEFT;
            }
        }

        precision = -1;
        if (*fmt == '.') {
            fmt++;
            if (is_digit(*fmt))
                precision = skip_atoi(&fmt);
            else if (*fmt == '*') {
                fmt++;
                precision = va_arg(args, int);
            }
            if (precision < 0)
                precision = 0;
        }

        qualifier = -1;
        if (*fmt == 'l' || *fmt == 'L') {
            qualifier = *fmt;
            fmt++;
        }

        base = 10;

        switch (*fmt) {
            case 'c':
                if (!(flags & LEFT))
                    while (--field_width > 0)
                        *str++ = ' ';
                *str++ = (unsigned char)va_arg(args, int);
                while (--field_width > 0)
                    *str++ = ' ';
                continue;

            case 's':
                s = va_arg(args, char *);
                if (!s)
                    s = "<NULL>";
                len = (int)local_strnlen(s, precision < 0 ? 0x7fffffff : (ee_size_t)precision);
                if (!(flags & LEFT))
                    while (len < field_width--)
                        *str++ = ' ';
                for (i = 0; i < len; ++i)
                    *str++ = *s++;
                while (len < field_width--)
                    *str++ = ' ';
                continue;

            case 'p':
                if (field_width == -1) {
                    field_width = 2 * (int)sizeof(void *);
                    flags |= ZEROPAD;
                }
                str = number(str, (long)(unsigned long)va_arg(args, void *),
                             16, field_width, precision, flags);
                continue;

            case 'o':
                base = 8;
                break;

            case 'X':
                flags |= UPPERCASE;
                /* fall through */
            case 'x':
                base = 16;
                break;

            case 'd':
            case 'i':
                flags |= SIGN;
                /* fall through */
            case 'u':
                break;

#if HAS_FLOAT
            case 'f':
                /* Not implemented in this minimal no-div version. */
                s = "<float>";
                while (*s)
                    *str++ = *s++;
                continue;
#endif

            case '%':
                *str++ = '%';
                continue;

            default:
                if (*fmt != '%')
                    *str++ = '%';
                if (*fmt)
                    *str++ = *fmt;
                else
                    --fmt;
                continue;
        }

        {
            long lnum;

            if (qualifier == 'l') {
                if (flags & SIGN)
                    lnum = va_arg(args, long);
                else
                    lnum = (long)va_arg(args, unsigned long);
            } else {
                if (flags & SIGN)
                    lnum = (long)va_arg(args, int);
                else
                    lnum = (long)va_arg(args, unsigned int);
            }

            str = number(str, lnum, base, field_width, precision, flags);
        }
    }

    *str = '\0';
    return (int)(str - buf);
}

void
uart_send_char(char c)
{
    volatile unsigned int *out = (volatile unsigned int *)0x0A000000u;
    *out = (unsigned int)c;
}

int
ee_printf(const char *fmt, ...)
{
    char buf[512];
    char *p;
    va_list args;
    int n = 0;

    va_start(args, fmt);
    ee_vsprintf(buf, fmt, args);
    va_end(args);

    p = buf;
    while (*p) {
        uart_send_char(*p++);
        n++;
    }

    return n;
}