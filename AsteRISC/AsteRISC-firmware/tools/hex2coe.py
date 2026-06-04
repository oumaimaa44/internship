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

import os
import sys
import re
import render_to_file
from datetime import datetime

element_pattern = re.compile("(.*?)\n", re.DOTALL)

template = "../../tools/templates/memory_template.coe"

header = "hex2coe.py: "

class bcolors:
    FAIL = '\033[91m'
    ENDC = '\033[0m'

def get_memory_def(file):
    if not os.path.exists(file):
        print(f"{header}{bcolors.FAIL}File not found: {file}{bcolors.ENDC}")
        sys.exit(1)
    
    with open(file) as file:
        file_content = file.read()
        init = False
        out = ""
        for element in re.finditer(element_pattern, file_content):
            if not init: 
                init = True
            else:
                out += ", "
            out += element.group(1).strip()
    return out

def write(template, output_folder, output_file, filename, content):
    if not os.path.exists(template):
        print(f"{header}{bcolors.FAIL}Template not found: {template}{bcolors.ENDC}")
        return
    
    date = datetime.now().strftime("%Y/%m/%d, %H:%M:%S")

    subs = {
        "${SOURCE}"    : filename,
        "${DATE}"      : date,
        "${FILENAME}"  : output_file,
        "${CONTENT}"   : content
    }
    render_to_file.render_to_file(template, output_folder + output_file, subs)

if __name__ == "__main__":
    if len(sys.argv) >= 2:
        try:
            input = sys.argv[1]
            path = os.path.dirname(input)
            cur_dir = os.path.basename(os.getcwd())

            if input == cur_dir or input == '.':
                path = '.'
                full_path = os.path.join(path, "bin/")
                template = os.path.join("..", template)
                filename = cur_dir
            elif not os.path.exists(input):
                print(f"{header}{bcolors.FAIL}Target not found: {input}{bcolors.ENDC}")
                sys.exit(1)
            else:
                filename = os.path.basename(input)
                full_path = os.path.join(path, filename, "bin/")
            
            imem_file = os.path.join(full_path, filename + "_imem.hex")
            dmem_file = os.path.join(full_path, filename + "_dmem.hex")
            imem_content = get_memory_def(imem_file)
            dmem_content = get_memory_def(dmem_file)

            write(template, full_path, filename + "_imem.coe", filename, imem_content)
            write(template, full_path, filename + "_dmem.coe", filename, dmem_content)

        except Exception as e:
            print(f"{header}{bcolors.FAIL}An error occurred: {e}{bcolors.ENDC}")
    else:
        print(f"{header}{bcolors.FAIL}No argument found. Please select a target{bcolors.ENDC}")
