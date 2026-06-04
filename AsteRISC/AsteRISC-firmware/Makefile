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

_BOLD      =\x1b[1m
_BLUE      =\x1b[34m
_WHITE     =\x1b[37m
_YELLOW    =\x1b[33m
_GREEN     =\x1b[32m
_END       =\x1b[0m

.PHONY : all
all: motd firmware

.PHONY: firmware
firmware:
	@+$(MAKE) -C firmware $@ --no-print-directory

.PHONY: new
new:
	@+$(MAKE) -C firmware $@ --no-print-directory

.PHONY: delete
delete:
	@+$(MAKE) -C firmware $@ --no-print-directory

.PHONY: del
del: delete

.PHONY: motd
motd:
	@/bin/echo -e "$(_BLUE)$(_WHITE)5555555$(_YELLOW)555555555555$(_WHITE)$(_BLUE)  $(_YELLOW)            _____ _______ ______ _____  _____  _____  _____ "
	@/bin/echo -e "$(_BLUE)$(_WHITE)555555555$(_YELLOW)5555555555$(_WHITE)$(_BLUE)  $(_YELLOW)     /\    / ____|__   __|  ____|  __ \|_   _|/ ____|/ ____|"
	@/bin/echo -e "$(_BLUE)5555555$(_WHITE)555$(_YELLOW)555555555$(_WHITE)$(_BLUE)  $(_YELLOW)    /  \  | (___    | |  | |__  | |__) | | | | (___ | |     "
	@/bin/echo -e "$(_BLUE)5555555$(_WHITE)555$(_YELLOW)55555555$(_WHITE)5$(_BLUE)  $(_YELLOW)   / /\ \  \___ \   | |  |  __| |  _  /  | |  \___ \| |     "
	@/bin/echo -e "$(_BLUE)555555$(_WHITE)555$(_YELLOW)55555555$(_WHITE)55$(_BLUE)  $(_YELLOW)  / ____ \ ____) |  | |  | |____| | \ \ _| |_ ____) | |____ "
	@/bin/echo -e "$(_BLUE)5$(_WHITE)5555555$(_YELLOW)55555555$(_WHITE)555$(_BLUE)  $(_YELLOW) /_/    \_\_____/   |_|  |______|_|  \_\_____|_____/ \_____|"
	@/bin/echo -e "$(_BLUE)55$(_WHITE)5555$(_YELLOW)55555555$(_WHITE)5555$(_BLUE)5"
	@/bin/echo -e "$(_BLUE)5555$(_WHITE)5555$(_YELLOW)55555$(_WHITE)5555$(_BLUE)55                   $(_BOLD)A Silicon-Proven SoC based on $(_END)"
	@/bin/echo -e "$(_BLUE)55555$(_WHITE)5555$(_YELLOW)55$(_WHITE)5555$(_BLUE)5555                 $(_BOLD)a flexible RISC-V Processor Core$(_END)"
	@/bin/echo -e "$(_BLUE)5555555$(_WHITE)5555$(_YELLOW)$(_WHITE)555$(_BLUE)55555"
