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

# Edit riscv_env to set your RISCV toolchain path
source "$(dirname "$0")/../riscv_env"

OBJCOPY=$RISCV_BIN/$RISCV_TT-objcopy
OBJDUMP=$RISCV_BIN/$RISCV_TT-objdump
OBJSIZE=$RISCV_BIN/$RISCV_TT-size


if [ ! -f "$1" ]
then
   echo "Error: Missing or bad filename"
   exit
fi

if [ ! command -v python3 &> /dev/null ]
then
    echo "Error: Python3 is required"
    exit
fi

$OBJCOPY $1 /dev/null --dump-section .data=data.section.dump --dump-section .text=text.section.dump

if [ ! -f text.section.dump ]
then
   echo "Error: Unable to dump sections"
   exit 
fi

cat text.section.dump | od -An -w4 -v -tx4 | cut -c 2- > $1_imem.hex

if [ ! -f data.section.dump ]
then
   echo "Warning: empty data dump"
   echo "" > $1_dmem.hex
else
   cat data.section.dump | od -An -w4 -v -tx4 | cut -c 2- > $1_dmem.hex
fi

#$OBJDUMP -x $1 
$OBJDUMP -d $1 | sed '/[^\t]*\t[^\t]*\t/!d' | cut -f 3,4 | sed 's/ .*$//' > $1.asm

# dump binary to risc-v assembly, also : 
# - remove empty lines
# - remove header (2 first lines after removing blank lines)
# - replace tabs with spaces
# - strip multiple spaces to one
# - remove all ':'
$OBJDUMP -dS $1 | sed '/^$/d' | sed '1,2d' | sed 's/\t/ /g' | tr -s ' ' | tr -d ':' > $1.txt

power2() { python3 -c "print(1 if $1 == 0 else 2 ** ( $1 - 1 ).bit_length(), end='')"; }

$OBJSIZE $1

echo -n "CPU prerequisites: imem >= "
TEXT_SIZE=$($OBJSIZE $1 -A | grep .text | awk '{print $2;}')
IMEM_MIN=$(($TEXT_SIZE/4))
power2 $IMEM_MIN

if [ ! -f data.section.dump ]
then
    echo ""
else
    echo -n "x32, dmem >= "
    DATA_SIZE=$($OBJSIZE $1 -A | grep .data | awk '{print $2;}')
    DMEM_MIN=$(($DATA_SIZE/4))
    power2 $DMEM_MIN
    echo "x32"
    rm data.section.dump
fi

rm text.section.dump

