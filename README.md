# TAGGER

## Getting Started

### Prerequisites
Tagger can directly be integrated after cloning it from this repository. However, to run 
various checks on the source code, various tools are required.

- [`bender >= v0.26.1`](https://github.com/pulp-platform/bender)
- `Python3 >= 3.8` including some the libraries listed in [`requirements.txt`](requirements.txt)

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