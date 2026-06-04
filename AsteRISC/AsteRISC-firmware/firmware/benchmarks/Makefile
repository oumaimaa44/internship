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
all: libs_asterisc coremark dhrystone_benchmark dhrystone_benchmark_m

.PHONY: libs_asterisc
libs_asterisc:
	@+$(MAKE) -C ../$@ --no-print-directory

.PHONY: coremark
coremark:
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: dhrystone_benchmark
dhrystone_benchmark:
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: dhrystone_benchmark_m
dhrystone_benchmark_m: 
	@+$(MAKE) -C $@ --no-print-directory
