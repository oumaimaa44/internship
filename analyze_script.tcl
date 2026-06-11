# ********************************************************************** #
#                                Odatix                                  #
# ********************************************************************** #
#
# Copyright (C) 2022 Jonathan Saussereau
#
# This file is part of Odatix.
# Odatix is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Odatix is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Odatix. If not, see <https://www.gnu.org/licenses/>.
#

if {[catch {

    source /net/users/oelmouden/internship/cva6/work/fmax_synthesis/vivado/xc7a100t-csg324-1/CVA6/cvxif/scripts/settings.tcl

    set signature "<grey>\[analyze_script.tcl\]<end>"

    ######################################
    # Read source files
    ######################################

    set rtl_path [file normalize $rtl_path]

    set verilog_error 0
    set sverilog_error 0

    set repo_dir ""
    if {[info exists env(CVA6_REPO_DIR)]} {
        set repo_dir $env(CVA6_REPO_DIR)
    }
    set cva6_token "\${CVA6_REPO_DIR}"

    # Determine source root and collect include directories
    set include_dirs {}
    set source_root $rtl_path
    
    set flist_file ""
    if {[file exists "$rtl_path/Flist.ariane"]} {
        set flist_file "$rtl_path/Flist.ariane"
    } elseif {[file exists "$rtl_path/Flist.cva6"]} {
        set flist_file "$rtl_path/Flist.cva6"
    } elseif {[file exists "$rtl_path/flist.ariane"]} {
        set flist_file "$rtl_path/flist.ariane"
    } elseif {[file exists "$rtl_path/flist.cva6"]} {
        set flist_file "$rtl_path/flist.cva6"
    }

    # Parse Flist to discover source_root and collect includes first
    if {$flist_file != ""} {
        # Recursive function to parse Flist and nested -F files
        proc parse_flist {flist_path source_root repo_dir cva6_token} {
            set all_lines {}
            
            if {![file exists $flist_path]} {
                return $all_lines
            }
            
            set fd [open $flist_path]
            set lines [split [read $fd] "\n"]
            close $fd
            
            foreach line $lines {
                set line [string trim $line]
                if {$line == "" || [regexp {^//} $line]} continue
                
                # Handle -F directive for nested Flists
                if {[string match "-F*" $line]} {
                    set nested_flist [string range $line 2 end]
                    set nested_flist [string trim $nested_flist]
                    
                    # Expand environment variables in nested flist path
                    set nested_flist [expand_env_vars $nested_flist $repo_dir]
                    
                    # Make path absolute relative to source_root if not already
                    if {![file pathtype $nested_flist] eq "absolute"} {
                        set nested_flist [file normalize [file join $source_root $nested_flist]]
                    }
                    
                    # Recursively parse nested flist
                    set nested_lines [parse_flist $nested_flist $source_root $repo_dir $cva6_token]
                    foreach nl $nested_lines {
                        lappend all_lines $nl
                    }
                } else {
                    lappend all_lines $line
                }
            }
            
            return $all_lines
        }
        
        # Helper function to expand environment variables
        proc expand_env_vars {str repo_dir} {
            # Replace ${VARIABLE} with environment variable value
            set pattern {\\$\{([A-Za-z_][A-Za-z0-9_]*)\}}
            set result $str
            while {[regexp $pattern $result match varname]} {
                if {[info exists ::env($varname)]} {
                    set result [regsub $pattern $result [set ::env($varname)] result]
                } elseif {$varname eq "CVA6_REPO_DIR" && $repo_dir ne ""} {
                    set result [regsub $pattern $result $repo_dir result]
                } else {
                    # If variable not found, try common defaults
                    if {$varname eq "HPDCACHE_DIR"} {
                        # Default: assume hpdcache is in vendor
                        set result [regsub $pattern $result "$repo_dir/vendor/pulp-platform/hpdcache" result]
                    } else {
                        break
                    }
                }
            }
            return $result
        }
        
        set fd [open $flist_file]
        set flist_lines [split [read $fd] "\n"]
        close $fd
        
        # Parse Flist including nested -F directives
        set lines [parse_flist $flist_file $source_root $repo_dir $cva6_token]
        
        set first_source_line ""
        foreach line $lines {
            set line [string trim $line]
            if {$line == "" || [regexp {^(//|\+incdir\+|-F)} $line]} continue
            set first_source_line $line
            break
        }
        
        if {$first_source_line != ""} {
            set curr $rtl_path
            while {1} {
                set test_line $first_source_line
                if {$repo_dir == "" && [string first $cva6_token $test_line] != -1} {
                    set test_line [string map [list $cva6_token $curr] $test_line]
                }
                set candidate [file normalize [file join $curr $test_line]]
                if {[file exists $candidate]} {
                    set source_root $curr
                    break
                }
                set parent [file dirname $curr]
                if {$parent eq $curr} {
                    break
                }
                set curr $parent
            }
        }
        
        # Extract all include directories from parsed Flist
        foreach line $lines {
            set line [string trim $line]
            if {$line == "" || [regexp {^(//|-F)} $line]} continue
            if {[string match "+incdir+*" $line]} {
                set dir [string range $line 8 end]
                if {$dir != ""} {
                    if {$repo_dir != ""} {
                        set dir [string map [list $cva6_token $repo_dir] $dir]
                    } elseif {[string first $cva6_token $dir] != -1} {
                        set dir [string map [list $cva6_token $source_root] $dir]
                    }
                    # Expand any remaining environment variables
                    set dir [expand_env_vars $dir $repo_dir]
                    set dir [file normalize [file join $source_root $dir]]
                    if {[file isdirectory $dir]} {
                        lappend include_dirs $dir
                    }
                }
            }
        }
    }
    
    # Add fallback hardcoded include paths relative to source_root
    set incdir_paths [list \
        [file join $source_root include] \
        [file join $source_root cvfpu src common_cells include] \
        [file join $source_root cache_subsystem hpdcache rtl include] \
    ]
    foreach incdir $incdir_paths {
        if {[file isdirectory $incdir]} {
            lappend include_dirs $incdir
        }
    }
    
    set include_dirs [lsort -unique $include_dirs]
    if {[llength $include_dirs] > 0} {
        set_property include_dirs $include_dirs [current_fileset]
    }

    # read verilog source files
    if {$flist_file != ""} {
        set source_files {}
        foreach line $lines {
            set line [string trim $line]
            if {$line == "" || [regexp {^(//|\+incdir\+|-F)} $line]} continue
            
            # Expand environment variables
            set line [expand_env_vars $line $repo_dir]
            
            if {$repo_dir != ""} {
                set line [string map [list $cva6_token $repo_dir] $line]
            } elseif {[string first $cva6_token $line] != -1} {
                set line [string map [list $cva6_token $source_root] $line]
            }
            
            set file_path [file normalize [file join $source_root $line]]
            if {[file exists $file_path]} {
                lappend source_files $file_path
            }
        }
        
        if {[llength $source_files] != 0} {
            if {[catch {read_verilog -sv $source_files} errmsg]} {
                puts "$signature <bold><red>error: failed reading verilog source files from $flist_file<end>"
                puts "$signature tool says -> $errmsg"
                set verilog_error 1
            }
        } else {
            puts "$signature <bold><red>error: no source files found in $flist_file<end>"
            set verilog_error 1
        }
    } else {
    set verilog_filenames [get_files_recursive $rtl_path {*.v *.sv *.svh}]
    puts "$signature <cyan>Verilog/SystemVerilog files:<end>"
    foreach file $verilog_filenames {
        puts "  - $file"
    }
    if {[catch {read_verilog -sv $verilog_filenames} errmsg]} {
        if {$verilog_filenames == ""} {
            puts "$signature <cyan>note: no verilog file in source directory<end>"
        } else {
            puts "$signature <bold><red>error: failed reading verilog source files<end>"
            puts "$signature tool says -> $errmsg"
        }
        set verilog_error 1
    }
    }
   
    

    # read vhdl source files
    set vhdl_filenames [get_files_recursive $rtl_path {*.vhd *.vhdl}]
    puts "$signature <cyan>VHDL files:<end>"
    foreach file $vhdl_filenames {
        puts "  - $file"
    }
    if {[catch {read_vhdl $vhdl_filenames} errmsg]} {
        if {$vhdl_filenames == ""} {
            puts "$signature <cyan>note: no vhdl file in source directory<end>"
        } else {
            puts "$signature <bold><red>error: failed reading vhdl source files<end>"
            puts "$signature tool says -> $errmsg"
        }
        if {$verilog_error == 1} {
            puts "$signature <red>error: failed reading both verilog and vhdl source files, exiting"
            exit -1
        }
    }

} ]} {
    puts "$signature <bold><red>error: unhandled tcl error, exiting<end>"
    puts "$signature <cyan>note: if you did not edit the tcl script, this should not append, please report this with the information bellow<end>"
    puts "$signature <cyan>tcl error detail:<red>"
    puts "$errorInfo"
    puts "<cyan>^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^<end>"
    exit -1
}
