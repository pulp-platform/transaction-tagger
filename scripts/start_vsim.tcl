# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Thomas Benz <tbenz@iis.ee.ethz.ch>

vsim -t 1ps -voptargs="+acc +cover" tb_tagger -coverage -logfile logs/tagger.vsim.log -wlf logs/tagger.wlf

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
log -r /*
