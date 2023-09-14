# Copyright 2023 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Diyou Shen 	<dishen@student.ethz.ch>

BENDER ?= bender
PYTHON ?= python3

REGGEN_PATH  = $(shell $(BENDER) path register_interface)/vendor/lowrisc_opentitan/util/regtool.py
REGGEN	     = $(PYTHON) $(REGGEN_PATH)

REGWIDTH        	= 32
MAXPARTITION 		= 8
PATID_LEN 			= 4
TAGGER_REGS_PATH   	= data/tagger_regs.py

# --------------
# help
# --------------

help:
	@echo ""
	@echo "----------------"
	@echo "Tagger Makefile"
	@echo "----------------"
	@echo ""
	@echo "-------------"
	@echo "Constants"
	@echo "-------------"
	@echo "REGWIDTH:                          memory-mapped register width, default to 32 bits"
	@echo ""
	@echo "MAXPARTITION:                      max number of partitions supported, default to 8"
	@echo ""
	@echo "PATID_LEN:                         number of bits of patid, default to 4 bits"
	@echo ""
	@echo "-------------"
	@echo "Commands"
	@echo "-------------"
	@echo "regs:                              generates the RegBus compatible register file"
	@echo ""
	@echo "sim_clean:                         cleans generated files"
	@echo ""
	@echo "scripts/compile_vsim.tcl:          generates files for Questasim simulation"
	@echo ""
	@echo "bender_gen_src:                    generates filelist of src files"
	@echo ""


# --------------
# Qustasim
# --------------
.PHONY: sim_clean

VLOG_ARGS += -suppress vlog-2583 -suppress vlog-13314 -suppress vlog-13233 -timescale \"1 ns / 1 ps\"

define generate_vsim
	echo 'set ROOT [file normalize [file dirname [info script]]/$3]' > $1
	$(BENDER) script vsim --vlog-arg="$(VLOG_ARGS)" $2 | grep -v "set ROOT" >> $1
	echo >> $1
endef

scripts/compile_vsim.tcl: Bender.yml
	$(call generate_vsim, $@, -t rtl -t test,..)

sim_clean:
	rm -rf scripts/compile_vsim.tcl
	rm -rf work
	rm -f  transcript
	rm -f  wlf*
	rm -f  *.wlf
	rm -f  *.vstf
	rm -f  modelsim.ini
	rm -f  logs/*.wlf
	rm -f  logs/*.vsim.log

# --------------
# Registers
# --------------

regs:partition_config
	$(REGGEN) -r --outdir src/ data/tagger_regs.hjson
	$(REGGEN) --cdefines --outfile include/tagger_regs.h data/tagger_regs.hjson


# Partitioning Regs Width Gen
partition_config:
	$(PYTHON) $(TAGGER_REGS_PATH) $(REGWIDTH) $(MAXPARTITION) $(PATID_LEN)

# --------------
# Bender
# --------------

bender_gen_src:
	$(BENDER) script flist --relative-path --exclude axi --exclude common_cells --exclude register_interface > src.list
