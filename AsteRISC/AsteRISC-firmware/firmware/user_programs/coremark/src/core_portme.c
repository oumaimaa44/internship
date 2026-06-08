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

Original Author: Shay Gal-on
*/

/* Modified for the NEORV32 Processor - 2025, Stephan Nolting */

#include "coremark.h"
#include "core_portme.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

int default_num_contexts = MULTITHREAD;

/* TIMING with rdcycle */
#define CLOCK_HZ 100000000UL
static CORE_TICKS start_cycle;
static CORE_TICKS stop_cycle;

static CORE_TICKS start_instret;
static CORE_TICKS stop_instret;



static CORE_TICKS read_cycle(void)
{
  CORE_TICKS value;
  asm volatile ("rdcycle %0" : "=r"(value));
  return value;
}



static CORE_TICKS read_instret(void)
{
  CORE_TICKS value;
  asm volatile ("rdinstret %0" : "=r"(value));
  return value;
}


void start_time(void)
{
  start_cycle = read_cycle();
  start_instret = read_instret();
}



void stop_time(void)
{
  stop_cycle = read_cycle();
  stop_instret = read_instret();
}



CORE_TICKS get_time(void)
{
  return stop_cycle - start_cycle;
}



secs_ret time_in_secs(CORE_TICKS ticks)
{
  return ticks / CLOCK_HZ;
}
/* Function : portable_init
 * Target specific initialization code
 * Test for some common mistakes.
 */
void portable_init(core_portable *p, int *argc, char *argv[]) {
  ee_printf("ENTER portable_init\n");
  ee_printf("A\n");
  ee_printf("TEST d=%d\n", 123);
  ee_printf("B\n");

  //asm volatile ("ebreak");
  (void)argc;
  (void)argv;
  ee_printf("Compiling for %d Hz, This can take a while : \n", CLOCK_HZ);
  p->portable_id = 1;
}


/* Function : portable_fini
 * Target specific final code
 */
void portable_fini(core_portable *p) {

  CORE_TICKS cycles = stop_cycle - start_cycle;
  CORE_TICKS instr  = stop_instret - start_instret;

  ee_printf("\nAsteRISC Hardware Counters\n");
  ee_printf(" > Active clock cycles  : %u\n", (unsigned int)cycles);
  ee_printf(" > Retired instructions : %u\n", (unsigned int)instr);

  if (instr != 0) {
    unsigned int cpi_x1000 = (1000 * cycles) / instr;
    ee_printf(" > CPI                  : %u.%03u\n",
              cpi_x1000 / 1000,
              cpi_x1000 % 1000);
  }

    p->portable_id = 0;
    ee_printf("\nCoreMark finished\n");
    asm volatile ("ebreak");

}

#if MULTITHREAD != 1
#error "This simple PicoRV32 port supports only MULTITHREAD = 1"
#endif




