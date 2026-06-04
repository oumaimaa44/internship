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
import fnmatch
import shutil

def replace_in_file(file_path: str, key: str, value: str):
    """
    Replace all occurrences of key with value in the specified file.    
    """
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        return
    
    with open(file_path, 'r') as file:
        content = file.read()
    
    # Replace placeholder with actual value
    content = content.replace(key, value)
    
    with open(file_path, 'w') as file:
        file.write(content)

def append_to_line_starting_with(file_path: str, line_start: str, text_to_append: str):
    """
    Append text_to_append to the end of the line starting with line_start in the specified file.
    """
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        return
    
    with open(file_path, 'r') as file:
        lines = file.readlines()
    
    with open(file_path, 'w') as file:
        for line in lines:
            if line.startswith(line_start):
                line = line.rstrip() + text_to_append + "\n"
            file.write(line)
    
def copytree(src, dst, dirs_exist_ok=False, whitelist=None, blacklist=None, **kwargs):
  """
  Custom copytree to copy directories with support for dirs_exist_ok, whitelist, and blacklist.

  Args:
    src (str): Source directory.
    dst (str): Destination directory.
    dirs_exist_ok (bool): Whether to allow overwriting the destination directory.
    whitelist (list, optional): List of patterns to include (relative to `src`).
    blacklist (list, optional): List of patterns to exclude (relative to `src`).
    **kwargs: Additional arguments passed to shutil.copy2.
  """
  def is_pattern_matched(path, patterns):
    """
    Check if the path matches any pattern in the list.
    Args:
      path (str): The path to check (relative to `src`).
      patterns (list): List of patterns to match against.
    Returns:
      bool: True if any pattern matches, False otherwise.
    """
    for pattern in patterns:
      if fnmatch.fnmatch(path, pattern):
        return True
      if os.path.realpath(pattern) == os.path.realpath(path):
        return True
      if os.path.dirname(os.path.realpath(path)).startswith(os.path.realpath(pattern)):
        return True
    return False

  def should_copy_file(rel_path):
    """
    Determine if a file should be copied based on whitelist and blacklist.
    Args:
      rel_path (str): Relative path to check.
    Returns:
      bool: True if the file should be copied, False otherwise.
    """
    # If whitelist exists, only copy paths matching the whitelist
    if whitelist and not is_pattern_matched(rel_path, whitelist) and not os.path.isdir(rel_path):
      return False
    # Exclude paths matching the blacklist
    if blacklist and is_pattern_matched(rel_path, blacklist):
      return False
    # Default: copy the path
    return True

  def should_explore_dir(rel_path):
    """
    Determine if a directory should be explored based on the blacklist.
    The whitelist does not apply to directories for exploration.
    Args:
      rel_path (str): Relative path to check.
    Returns:
      bool: True if the directory should be explored, False otherwise.
    """
    # Exclude directories matching the blacklist
    if blacklist and is_pattern_matched(rel_path, blacklist):
      return False
    # Default: explore the directory
    return True

  # Normalize paths
  src = os.path.realpath(src)
  dst = os.path.realpath(dst)

  # Ensure destination exists
  if os.path.exists(dst):
    if not dirs_exist_ok:
      raise FileExistsError(f"Destination directory {dst} exists and dirs_exist_ok is False.")
  else:
    os.makedirs(dst)

  for root, dirs, files in os.walk(src):
    # Calculate the relative path from src
    rel_root = os.path.relpath(root, src)

    # Remove directories that should not be explored
    dirs[:] = [d for d in dirs if should_explore_dir(os.path.join(rel_root, d))]

    # Process files
    for file in files:
      src_file = os.path.join(root, file)
      rel_file = os.path.join(rel_root, file)  # Relative path for whitelist/blacklist checks
      dst_file = os.path.join(dst, rel_file)
      
      if should_copy_file(rel_file):  # Pass relative path to should_copy_file
        os.makedirs(os.path.dirname(dst_file), exist_ok=True)
        shutil.copy2(src_file, dst_file, **kwargs)
