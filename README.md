# TAGGER

## Getting Started

### Prerequisites
Tagger can directly be integrated after cloning it from this repository. However, to run 
various checks on the source code, various tools are required.

- [`bender >= v0.26.1`](https://github.com/pulp-platform/bender)

### Simulation

We currently do not include any free and open-source simulation setup. However, if you have access to
[*Questa advanced simulator*](https://eda.sw.siemens.com/en-US/ic/questa/simulation/advanced-simulator/),
a simulation can be launched using:
```
sh> make scripts/compile_vsim.tcl
sh> questa-2021.3 vsim -64
vsim> source scripts/compile_vsim.tcl
vsim> source scripts/start_vsim.tcl
vsim> do scripts/waves/tagger.do
vsim> run -all
```
### Modules List

| Name                                                            | Description |
|-----------------------------------------------------------------|-------------|
| [`tb_tagger`](test/tb_tagger.sv)                                | Device under test - Top level module for simulation    |
| [`tb_tagger`](test/user_checker.sv)                             | Monitoring and comparing the tagger output against golden model |
| [`tagger`](src/tagger.sv)                                       | Tagger top level            |
| [`tagger_patid`](src/tagger_patid.sv)                           | Single address range comparator       |
| [`tagger_regs_wrap`](src/tagger_regs_wrap.sv)                   | Register wrapper to assign the signals from register side |
| [`tagger_reg_reg_pkg`](src/register/tagger_reg_reg_pkg.sv)      | Register interface package            |
| [`tagger_reg_reg_top`](src/register/tagger_reg_reg_top.sv)      | Register interface top level module            |