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

    source scripts/settings.tcl
    set signature "<grey>\[analyze_script.tcl\]<end>"

    set rtl_path [file normalize $rtl_path]
    set target_cfg "cv32a6_imac_sv32"
    #set target_cfg "cv64a6_imafdc_sv39"
    puts "$signature <cyan>rtl_path:<end> $rtl_path"

    # Avoid Vivado automatic reordering as much as possible
    catch {set_property source_mgmt_mode None [current_project]}

    # ------------------------------------------------------------
    # Small helper functions
    # ------------------------------------------------------------

    proc add_unique {varname value} {
        upvar 1 $varname lst
        if {$value ne "" && [lsearch -exact $lst $value] < 0} {
            lappend lst $value
        }
    }

    proc find_repo_root {rtl_path} {
        foreach start [list [pwd] $rtl_path [file dirname $rtl_path]] {
            set cur [file normalize $start]

            while {1} {
                if {[file exists [file join $cur "core" "Flist.cva6"]] &&
                    [file exists [file join $cur "core" "include" "ariane_pkg.sv"]]} {
                    return $cur
                }

                set parent [file dirname $cur]
                if {$parent eq $cur} {
                    break
                }
                set cur $parent
            }
        }

        error "Could not find CVA6 repo root"
    }

    proc expand_vars {txt repo_root target_cfg} {
        set hpdcache_dir [file join $repo_root "core" "cache_subsystem" "hpdcache"]

        return [string map [list \
            "\${CVA6_REPO_DIR}" $repo_root \
            "\$CVA6_REPO_DIR"   $repo_root \
            "\${TARGET_CFG}"    $target_cfg \
            "\$TARGET_CFG"      $target_cfg \
            "\${HPDCACHE_DIR}"  $hpdcache_dir \
            "\$HPDCACHE_DIR"    $hpdcache_dir \
        ] $txt]
    }

    proc resolve_path {raw repo_root rtl_path target_cfg} {
        set p [expand_vars $raw $repo_root $target_cfg]

        # Prefer Odatix copied RTL for files inside core/
        set repo_core [file normalize [file join $repo_root "core"]]

        if {[string first $repo_core $p] == 0} {
            set rel [string range $p [expr {[string length $repo_core] + 1}] end]
            set candidate [file normalize [file join $rtl_path $rel]]

            if {[file exists $candidate]} {
                return $candidate
            }
        }

        if {[string match "core/*" $p]} {
            set rel [string range $p 5 end]
            set candidate [file normalize [file join $rtl_path $rel]]

            if {[file exists $candidate]} {
                return $candidate
            }

            return [file normalize [file join $repo_root $p]]
        }

        if {[file pathtype $p] ne "absolute"} {
            return [file normalize [file join $repo_root $p]]
        }

        return [file normalize $p]
    }

    proc find_by_name {files basename} {
        foreach f $files {
            if {[file tail $f] eq $basename} {
                return $f
            }
        }
        return ""
    }

    # ------------------------------------------------------------
    # Locate repo and Flist.cva6
    # ------------------------------------------------------------

    set repo_root [find_repo_root $rtl_path]
    puts "$signature <cyan>repo_root:<end> $repo_root"

    set flist_file [file join $repo_root "core" "Flist.cva6"]

    if {![file exists $flist_file]} {
        puts "$signature <bold><red>error: Flist.cva6 not found:<end> $flist_file"
        exit -1
    }

    puts "$signature <cyan>using file list:<end> $flist_file"

    # ------------------------------------------------------------
    # Create Vivado-safe unread stub
    # ------------------------------------------------------------
    # The original unread.sv is empty. Vivado can keep it as a black box
    # during opt_design, so we create a tiny non-empty module.

    set unread_stub [file join $rtl_path "odatix_unread_stub.sv"]
    set fh [open $unread_stub w]
    puts $fh {(* KEEP_HIERARCHY = "yes", DONT_TOUCH = "yes" *)}
    puts $fh {module unread (input logic d_i);}
    puts $fh {  (* KEEP = "TRUE", DONT_TOUCH = "TRUE" *) wire sink;}
    puts $fh {  (* DONT_TOUCH = "TRUE" *) LUT1 #(.INIT(2'b10)) i_keep (.I0(d_i), .O(sink));}
    puts $fh {endmodule}
    close $fh

    puts "$signature <cyan>reading unread stub early:<end> $unread_stub"
    read_verilog -sv $unread_stub

    # ------------------------------------------------------------
    # Parse Flist.cva6
    # ------------------------------------------------------------

    set include_dirs {}
    set source_files {}

    set fh [open $flist_file r]
    set lines [split [read $fh] "\n"]
    close $fh

    foreach raw_line $lines {
        set line [string trim $raw_line]

        if {$line eq ""} {
            continue
        }

        if {[regexp {^\s*//} $line]} {
            continue
        }

        if {[regexp {^\s*#} $line]} {
            continue
        }

        # Skip nested HPDcache flist
        if {[string match "-F*" $line]} {
            puts "$signature <yellow>skipping nested flist:<end> $line"
            continue
        }

        # Include directory
        if {[string match "+incdir+*" $line]} {
            set d [string range $line 8 end]
            set d [resolve_path $d $repo_root $rtl_path $target_cfg]

            if {[file isdirectory $d]} {
                add_unique include_dirs $d
            }

            continue
        }

        set f [resolve_path $line $repo_root $rtl_path $target_cfg]
        set lf [string tolower $f]
        set base [file tail $f]

        # Skip HPDcache when using normal WB/WT cache config
        if {[string first "hpdcache" $lf] >= 0} {
            puts "$signature <yellow>skipping HPDcache source:<end> $f"
            continue
        }

        # Skip headers as sources
        if {[regexp {(\.svh|\.vh)$} $lf]} {
            if {[file exists $f]} {
                add_unique include_dirs [file dirname $f]
            }
            continue
        }

        # Skip old wrappers
        if {$base eq "ariane_soc_wrapper.sv" ||
            $base eq "ariane__soc_wrapper.sv" ||
            $base eq "ariane_verilog_wrap.sv"} {
            puts "$signature <yellow>skipping old wrapper:<end> $f"
            continue
        }

        # Skip behavioral tracer
        if {[string match "*instr_tracer.sv" $lf]} {
            puts "$signature <yellow>skipping tracer:<end> $f"
            continue
        }

        # Skip non-synth SRAM wrapper.
        # We will add tc_sram_fpga_wrapper.sv instead.
        if {$base eq "tc_sram_wrapper.sv"} {
            puts "$signature <yellow>skipping non-synth SRAM wrapper:<end> $f"
            continue
        }

        # Skip original empty unread.sv.
        # We use odatix_unread_stub.sv instead.
        if {$base eq "unread.sv"} {
            puts "$signature <yellow>skipping original unread:<end> $f"
            continue
        }

        if {[file exists $f]} {
            add_unique source_files $f
        } else {
            puts "$signature <yellow>warning: source not found:<end> $f"
        }
    }

    # ------------------------------------------------------------
    # Force required FPGA SRAM files and unread stub
    # ------------------------------------------------------------

    foreach f [list \
        [file join $repo_root "vendor" "pulp-platform" "fpga-support" "rtl" "SyncSpRamBeNx64.sv"] \
        [file join $repo_root "common" "local" "util" "tc_sram_fpga_wrapper.sv"] \
        $unread_stub \
    ] {
        if {[file exists $f]} {
            add_unique source_files [file normalize $f]
        } else {
            puts "$signature <yellow>warning: mandatory file not found:<end> $f"
        }
    }

    # ------------------------------------------------------------
    # Extra include dirs
    # ------------------------------------------------------------

    foreach d [list \
        [file join $rtl_path "include"] \
        [file join $rtl_path "cache_subsystem"] \
        [file join $rtl_path "cvfpu" "src" "common_cells" "include"] \
        [file join $repo_root "vendor" "pulp-platform" "common_cells" "include"] \
        [file join $repo_root "vendor" "pulp-platform" "common_cells" "src"] \
        [file join $repo_root "vendor" "pulp-platform" "axi" "include"] \
        [file join $repo_root "corev_apu" "register_interface" "include"] \
        [file join $repo_root "common" "local" "util"] \
    ] {
        if {[file isdirectory $d]} {
            add_unique include_dirs [file normalize $d]
        }
    }

    set include_dirs [lsort -unique $include_dirs]

    puts "$signature <cyan>include dirs:<end>"
    foreach d $include_dirs {
        puts "  - $d"
    }

    if {[llength $include_dirs] > 0} {
        set_property include_dirs $include_dirs [current_fileset]
    }

    # ------------------------------------------------------------
    # Split packages and RTL
    # ------------------------------------------------------------

    set package_files {}
    set rtl_files {}

    foreach f $source_files {
        set base [file tail $f]

        if {[regexp {_pkg\.sv$} $base] ||
            $base eq "fpnew_pkg.sv" ||
            $base eq "cf_math_pkg.sv"} {
            add_unique package_files $f
        } else {
            add_unique rtl_files $f
        }
    }

    # ------------------------------------------------------------
    # Package order
    # ------------------------------------------------------------

    set package_order [list \
        "cf_math_pkg.sv" \
        "fpnew_pkg.sv" \
        "config_pkg.sv" \
        "${target_cfg}_config_pkg.sv" \
        "riscv_pkg.sv" \
        "axi_pkg.sv" \
        "ariane_pkg.sv" \
        "wt_cache_pkg.sv" \
        "std_cache_pkg.sv" \
        "instr_tracer_pkg.sv" \
        "build_config_pkg.sv" \
        "aes_pkg.sv" \
        "triggers_pkg.sv" \
        "cvxif_instr_pkg.sv" \
    ]

    set ordered_packages {}

    foreach pkg $package_order {
        set f [find_by_name $package_files $pkg]

        if {$f ne ""} {
            add_unique ordered_packages $f
        }
    }

    foreach f $package_files {
        add_unique ordered_packages $f
    }

    set package_files $ordered_packages

    # ------------------------------------------------------------
    # Keep wrapper last
    # ------------------------------------------------------------

    set wrapper_file [find_by_name $rtl_files "cva6_soc_wrapper.sv"]

    if {$wrapper_file eq ""} {
        puts "$signature <bold><red>error: cva6_soc_wrapper.sv not found<end>"
        exit -1
    }

    set ordered_rtl {}

    foreach f $rtl_files {
        if {$f ne $wrapper_file} {
            add_unique ordered_rtl $f
        }
    }

    add_unique ordered_rtl $wrapper_file
    set rtl_files $ordered_rtl

    # ------------------------------------------------------------
    # Check important packages
    # ------------------------------------------------------------

    foreach pkg [list \
        "config_pkg.sv" \
        "${target_cfg}_config_pkg.sv" \
        "riscv_pkg.sv" \
        "axi_pkg.sv" \
        "ariane_pkg.sv" \
    ] {
        set f [find_by_name $package_files $pkg]

        if {$f eq ""} {
            puts "$signature <bold><red>error: required package missing:<end> $pkg"
            exit -1
        }

        puts "$signature <cyan>required package found:<end> $f"
    }

    # ------------------------------------------------------------
    # Read files
    # ------------------------------------------------------------

    puts "$signature <cyan>reading packages first<end>"

    foreach f $package_files {
        puts "$signature <cyan>pkg:<end> $f"
        read_verilog -sv $f
    }

    puts "$signature <cyan>reading RTL after packages<end>"

    foreach f $rtl_files {
        puts "$signature <cyan>rtl:<end> $f"
        read_verilog -sv $f
    }

    # Help Vivado keep package files before RTL
    foreach pkg [lreverse $package_order] {
        set f [find_by_name $package_files $pkg]

        if {$f ne ""} {
            set gf [get_files -quiet [file normalize $f]]

            if {[llength $gf] > 0} {
                catch {reorder_files -fileset [current_fileset] -front $gf}
            }
        }
    }

    set gw [get_files -quiet [file normalize $wrapper_file]]

    if {[llength $gw] > 0} {
        catch {reorder_files -fileset [current_fileset] -back $gw}
    }

    catch {
        report_compile_order \
            -fileset [current_fileset] \
            -sources \
            -used_in synthesis \
            -file compile_order_after_analyze.rpt
    }

} errmsg]} {
    puts "<grey>\[analyze_script.tcl\]<end> <bold><red>error: analyze failed<end>"
    puts "<grey>\[analyze_script.tcl\]<end> tool says -> $errmsg"
    puts "$errorInfo"
    exit -1
}
