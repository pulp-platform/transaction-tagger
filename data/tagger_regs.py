# This file is used to automatically generate `tagger_regs.hjson`

import math
import sys
# all variables below are just for verification
RegWidth    	= int(sys.argv[1]) 		# 32 Same as "RegWidth" in sv
MaxPartition   	= int(sys.argv[2]) 		# 16 Same as "MaxPartition" in sv
PatidLen 		= int(sys.argv[3]) 		# 8

num_entry_per_reg 	= math.floor(32/PatidLen) 
num_patid_reg 		= math.ceil(MaxPartition/num_entry_per_reg)
num_conf_reg 		= math.ceil(MaxPartition/16)

with open('data/tagger_regs.hjson', 'w') as f:
    f.write('// Copyright 2018-2021 ETH Zurich and University of Bologna.\n\
// Solderpad Hardware License, Version 0.51, see LICENSE for details.\n\
// SPDX-License-Identifier: SHL-0.51\n\
//\n\
// Authors: \n\
// Diyou Shen <dishen@student.ethz.ch>\n\
\n\
\n\
\n\
{\n\
    name: "tagger_reg",\n\
    clock_primary: "clk_i",\n\
    reset_primary: "rst_ni",\n\
    bus_interfaces: [{\n\
        protocol: "reg_iface",\n\
        direction: "device"\n\
    }],\n\
    regwidth: "32",\n\
    registers: [{\n\
        multireg: {\n\
            name: "PAT_COMMIT",\n\
            desc: "Partition configuration commit register",\n\
            count: "1",\n\
            cname: "TAGGER",\n\
            swaccess: "rw",\n\
            hwaccess: "hrw",\n\
            fields: [{\n\
                bits: "0",\n\
                name: "commit",\n\
                desc: "commit changes of partition configuration",\n\
                resval: "0"\n\
            }]\n\
        }},\n\
        ')
    f.write(f'''
        {{
        multireg: {{
            name: "PAT_ADDR",
            desc: "Partition address",
            count: "{MaxPartition}",
            cname: "TAGGER",
            swaccess: "rw",
            hwaccess: "hro",
            fields: [{{
                bits: "31:0",
                name: "PAT_ADDR",
                desc: "Single partition configurations: address",
                resval: "0"
            }}]
        }}}},
        {{
        multireg: {{
            name: "PATID",
            desc: "Partition ID",
            count: "{num_patid_reg}",
            cname: "TAGGER",
            swaccess: "rw",
            hwaccess: "hro",
            fields: [{{
                bits: "31:0",
                name: "PATID",
                desc: "Partition ID (PatID) for each partition, length determined by params",
                resval: "0"
            }}]
        }}}},
        {{
        multireg: {{
            name: "ADDR_CONF",
            desc: "Address encoding mode switch register",
            count: "{num_conf_reg}",
            cname: "TAGGER",
            swaccess: "rw",
            hwaccess: "hro",
            fields: [{{
                bits: "31:0",
                name: "addr_comf",
                desc: "2 bits configuration for each partition. 2'b00: OFF, 2'b01: TOR, 2'b10: NA4",
                resval: "0"
            }}]
        }}}}''')

    f.write('  ]\n}\n')
