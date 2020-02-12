###############################################################################
# Copyright 2020 Igor Semenov and LaCASA@UAH
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
###############################################################################/

SOPC_FILE="./Quartus/nios_multicore.sopcinfo"
ECLIPSE_DIR="./Eclipse"
SRC_DIR="$ECLIPSE_DIR/src"
PRJ_NAME="MatrixMult"

# Generates board support packages and projects for N cores
generate_bsp () {
    # Number of cores in the system
    core_count=$1
    
    printf "********** Generating board support packages for $core_count cores **********\n"
    
    # For each core
    for ((core=0;core<core_count;core++)); do
        core_name="c$core"
        printf "\n\n********** BSP for core $core_name **********\n\n";
        bsp_dir="$ECLIPSE_DIR/${PRJ_NAME}_${core_name}_bsp"
        app_dir="$ECLIPSE_DIR/${PRJ_NAME}_${core_name}" 

        # Set BSP parameters
        args=()
        args+=("--cpu-name ${core_name}_nios2")
        args+=("--set hal.max_file_descriptors 10")
        args+=("--set hal.enable_small_c_library true")
        args+=("--set hal.sys_clk_timer none")
        args+=("--set hal.timestamp_timer none")
        args+=("--set hal.enable_exit false")
        args+=("--set hal.enable_c_plus_plus false")
        args+=("--set hal.enable_lightweight_device_driver_api true")
        args+=("--set hal.enable_clean_exit false")
        args+=("--set hal.enable_sim_optimize false")
        args+=("--set hal.enable_reduced_device_drivers true")
        args+=("--set hal.make.bsp_cflags_optimization -O3")
        args+=("--set hal.make.bsp_cflags_user_flags -fdata-sections -ffunction-sections")
        args+=("--default_sections_mapping ${core_name}_ram")
        args+=("--cmd add_section_mapping .text ${core_name}_rom")
        args+=("--cmd add_section_mapping .shared shared_mem")
        args=$(IFS=" " ; echo "${args[*]}")
        
        # Generate board support package
        rm -rf "$bsp_dir"
        nios2-bsp hal "$bsp_dir" "$SOPC_FILE" $args

        printf "\n\n********** Application for core $core_name **********\n\n";

        # Set project parameters
        args=()
        args+=("--bsp-dir $bsp_dir")
        args+=("--app-dir $app_dir")
        args+=("--src-dir $SRC_DIR")
        args+=("--set APP_CFLAGS_USER_FLAGS")
        args+=("-DCORE_ID=$core")
        args+=("-DCORE_COUNT=$core_count")
        args=$(IFS=" " ; echo "${args[*]}")

        # Generate projects
        rm -rf "$app_dir"
        nios2-app-generate-makefile $args
    done
}

# Compiles projects for N cores
make_projects () {
    # Number of cores in the system
    core_count=$1
    printf "********** Compiling projects for $core_count cores **********\n"
    
    # For each project
    for ((core=0;core<core_count;core++)); do
        core_name="c$core"
        printf "\n\n********** Compiling for core $core_name **********\n\n";
        app_dir="$ECLIPSE_DIR/${PRJ_NAME}_${core_name}"
        
        # Make current project
        (cd $app_dir && make)
    done
}

# Loads executable files to N processors
load_elfs () {
    # Number of cores in the system
    core_count=$1
    
    printf "**********Loading ELFs to $core_count cores **********\n"
    
    # For each Nios II
    for ((core=core_count-1;core>=0;core--)); do
        core_name="c$core"
        printf "\n\n********** Loading code to $core_name **********\n\n";
        app_dir="$ECLIPSE_DIR/${PRJ_NAME}_${core_name}"
        
        # Load executable to the current Nios
        nios2-download --instance $core -g "$app_dir/main.elf"
    done
    
    printf "\n\n********** Openning terminal for core c0 **********\n\n";
    
    # Open terminal for the main core
    nios2-terminal --instance 0
}

# Select command to execute
case "$1" in
    generate-bsp)
        generate_bsp $2
        ;;
     
    make-projects)
        make_projects $2
        ;;
     
    load-elfs)
        load_elfs $2
        ;;
     
    *)
        echo $"Usage: $0 {generate-bsp|make-projects|load-elfs} core_count"
esac
