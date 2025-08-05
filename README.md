# Transaction Tagger

This module allows you to tag AXI read/write transactions according to
configurable address ranges. Whenever a transaction falls within one of the
configured address ranges a corresponding tag (which is just a number) is
inserted into the transaction as part of the AXI user signal.

## Prerequisites
Tagger can directly be integrated after cloning it from this repository. However, to run 
various checks on the source code, various tools are required.

- [`bender >= v0.26.1`](https://github.com/pulp-platform/bender)

## Simulation

You need questasim to run simulations.

Run the following commands:

```
sh> make scripts/compile_vsim.tcl
sh> questa-2021.3 vsim -64
vsim> source scripts/compile_vsim.tcl
vsim> source scripts/start_vsim.tcl
vsim> do scripts/waves/tagger.do
vsim> run -all
```

## Modules

| Name                                                            | Description |
|-----------------------------------------------------------------|-------------|
| [`tb_tagger`](test/tb_tagger.sv)                                | Device under test - Top level module for simulation    |
| [`tb_tagger`](test/user_checker.sv)                             | Monitoring and comparing the tagger output against golden model |
| [`tagger`](src/tagger.sv)                                       | Tagger top level            |
| [`tagger_patid`](src/tagger_patid.sv)                           | Single address range comparator       |
| [`tagger_regs_wrap`](src/tagger_regs_wrap.sv)                   | Register wrapper to assign the signals from register side |
| [`tagger_reg_reg_pkg`](src/register/tagger_reg_reg_pkg.sv)      | Register interface package            |
| [`tagger_reg_reg_top`](src/register/tagger_reg_reg_top.sv)      | Register interface top level module            |

## Registers

All registers in `tagger` are implemented as 32-bit registers, using `regtool.py` tool.

| Name                       | Bitfield    | Description  |
|----------------------------|-------------|--------------|
| `pat_commit`               | \[0:0\]     | Device under test - Top level module for simulation    |
| `pat_addr[i]`              | \[31:0\]    | The address and/or size settings for each partition, the total number `k` of registers equals to `MAXPARTITION`. The address is assumed to have the least two bits removed because of the register mapping. An example use can be found in the `test/tb_tagger.sv`    |
| `patid[j]`                 | \[31:0\]    | The `PATID` for each partition. The length of each `patid` entry, `PATID_LEN` equals to `AXI_USER_ID_MSB-AXI_USER_ID_LSB+1`. The number of registers 'j' equals to `ceil(MAXPARTITION/PATID_LEN)]`. |
| `addr_conf[k]`             | \[31:0\]    | Configure the modes for partitions. Each partition will occupy 2 bits from LSB: `00-OFF`,`01-TOR`, `10-NA4`.`11-NAPOT`. The number of register `k` equals to `ceil(MAXPARTITION/16)`. |
