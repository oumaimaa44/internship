#**********************************************************************#
#                               AsteRISC                               #
#**********************************************************************#
#
# Copyright (C) 2022 Jonathan Saussereau
#
# This file is part of AsteRISC.
# AsteRISC is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# AsteRISC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with AsteRISC. If not, see <https://www.gnu.org/licenses/>.
#

.PHONY : all
all: pwm_example uart_example cli_example

.PHONY: libs_asterisc
libs_asterisc: 
	@+$(MAKE) -C ../$@ --no-print-directory

.PHONY: cpu_example
cpu_example: libs_asterisc
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: mega_example
mega_example: libs_asterisc
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: pwm_example
pwm_example: libs_asterisc
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: uart_example
uart_example: libs_asterisc
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: timer_example
timer_example: libs_asterisc
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: cli_example
cli_example: libs_asterisc
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: mul_example
mul_example: libs_asterisc
	@+$(MAKE) -C $@ --no-print-directory
