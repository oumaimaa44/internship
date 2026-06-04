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

import re
import os
import sys
import argparse

from utils import copytree, replace_in_file, append_to_line_starting_with

tools_path = os.path.dirname(os.path.abspath(__file__))
template_dir = os.path.join(tools_path, "templates", "user_program_template")
user_programs_dir = os.path.join(tools_path, "..", "firmware", "user_programs")
makefile_rule_template = os.path.join(tools_path, "templates", "new_program_makefile_rule.mk")
makefile_all_rule_pattern = "all:"
makefile_filename = "Makefile"

######################################
# Parse Arguments
######################################

def add_arguments(parser):
    parser.add_argument("-n", "--new", default=None, help="create program by name")
    parser.add_argument("-d", "--delete", "--del", default=None, help="delete program by name")


def parse_arguments():
    parser = argparse.ArgumentParser(description="Add a new or delete user programs")
    add_arguments(parser)
    return parser.parse_args()

def treat_name(name: str) -> str:
    # Sanitize name
    name = re.sub(r'\W|^(?=\d)', '_', name)
    
    if not name:
        print("Error: Invalid program name.")
        sys.exit(1)
    return name

######################################
# New Program
######################################

def copy_template_to_user_programs(output_dir: str):
    if not os.path.exists(template_dir):
        print(f"Error: Template directory not found: {template_dir}")
        sys.exit(1)
        return
    
    if os.path.exists(output_dir):
        print(f"Error: Directory already exists: {output_dir}")
        sys.exit(1)
        return
        
    copytree(template_dir, output_dir)
    
def add_new_rule_to_makefile(makefile_path: str, template_path: str, name: str):
    if not os.path.exists(makefile_path):
        print(f"Error: Makefile not found: {makefile_path}")
        sys.exit(1)
    
    if not os.path.exists(template_path):
        print(f"Error: Template Makefile rule not found: {template_path}")
        sys.exit(1)
        return
    
    with open(template_path, 'r') as template_file:
        template_content = template_file.read()
    
    new_rule = template_content.replace("${RULE_NAME}", name)
    
    with open(makefile_path, 'a') as makefile:
        makefile.write("\n")
        makefile.write(new_rule)

######################################
# Delete Program
######################################

def remove_user_program_dir(output_dir: str):
    if os.path.exists(output_dir):
        import shutil
        shutil.rmtree(output_dir)
    else:
        print(f"Directory not found (nothing to delete): {output_dir}")

def remove_rule_from_makefile(makefile_path: str, name: str):
    if not os.path.exists(makefile_path):
        print(f"Error: Makefile not found: {makefile_path}")
        return

    with open(makefile_path, 'r') as f:
        lines = f.readlines()

    # Remove rule block for the program
    new_lines = []
    in_rule = False
    previous_line = None
    for line in lines:
        if line.strip().startswith(f".PHONY: {name}"):
            in_rule = True
        elif in_rule and (line.strip() == "" or not (line.startswith("\t") or line.startswith(f"{name}:"))):
            in_rule = False
        elif not in_rule and previous_line is not None:
            new_lines.append(previous_line)
        previous_line = line
    
    if not in_rule and previous_line is not None:
        new_lines.append(previous_line)

    with open(makefile_path, 'w') as f:
        f.writelines(new_lines)

def remove_from_all_rule(makefile_path: str, name: str):
    if not os.path.exists(makefile_path):
        print(f"Error: Makefile not found: {makefile_path}")
        return

    with open(makefile_path, 'r') as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        if line.startswith(makefile_all_rule_pattern):
            parts = line.split()
            parts = [p for p in parts if p != name]
            lines[i] = " ".join(parts) + "\n"
            break

    with open(makefile_path, 'w') as f:
        f.writelines(lines)


######################################
# Main
######################################

def main(args):
    if args.new and args.delete:
        print("Error: Use either -n/--new or -d/--delete, not both.")
        sys.exit(1)

    main_makefile_path = os.path.realpath(os.path.join(user_programs_dir, makefile_filename))

    if args.new:
        name = treat_name(args.new)
        output_dir = os.path.realpath(os.path.join(user_programs_dir, name))

        # Create new user program from template
        copy_template_to_user_programs(output_dir)

        # Edit program makefile
        makefile_path = os.path.join(output_dir, makefile_filename)
        replace_in_file(makefile_path, "${TARGET_NAME}", name)

        # Edit user_programs Makefile
        add_new_rule_to_makefile(main_makefile_path, makefile_rule_template, name)

        # Add to makefile all rule
        append_to_line_starting_with(main_makefile_path, makefile_all_rule_pattern, f" {name}")

        print(f"User program '{name}' added successfully.")
        print(f"You can edit the source files in '{output_dir}/src'")
        print(f"Run 'make firmware' to build it.")

    elif args.delete:
        name = args.delete
        output_dir = os.path.realpath(os.path.join(user_programs_dir, name))

        # Remove user program directory
        remove_user_program_dir(output_dir)

        # Remove rule from user_programs Makefile
        remove_rule_from_makefile(main_makefile_path, name)

        # Remove program from all rule
        remove_from_all_rule(main_makefile_path, name)

        print(f"User program '{name}' deleted successfully.")

    else:
        print("Error: Use -n/--new or -d/--delete.")
        sys.exit(1)


if __name__ == "__main__":
    args = parse_arguments()
    main(args)
