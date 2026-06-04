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

_GREEN     =\x1b[32m
_END       =\x1b[0m

USER_PROGRAM_SCRIPT = ../tools/user_program.py
NAME = "my_program"

.PHONY : all
all: libs_asterisc examples user_programs complete_msg

.PHONY: libs_asterisc
libs_asterisc:
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: examples
examples:
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: user_programs
user_programs:
	@+$(MAKE) -C $@ --no-print-directory

.PHONY: user
user: user_programs

.PHONY: new
new:
	@python3 $(USER_PROGRAM_SCRIPT) --new $(NAME)

.PHONY: delete
delete:
	@python3 $(USER_PROGRAM_SCRIPT) --del $(NAME)

.PHONY: del
del: delete

.PHONY: complete_msg
complete_msg:
	@/bin/echo -e "\n$(_GREEN)build complete!$(_END)"
