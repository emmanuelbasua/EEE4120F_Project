 EEE4120F Project – CRU Co-Processor for StarCore-1

## Overview

This repository contains the complete implementation, verification, and documentation of the **Coordinate Rotation Unit (CRU)** — a CORDIC-based trigonometric co-processor designed for the **StarCore-1 16-bit RISC processor**.

The project was developed for the EEE4120F High Performance Embedded Systems course at the University of Cape Town.

The CRU accelerates sine and cosine computations required for quaternion-based attitude determination on the OrbitEdge-1 CubeSat platform by integrating a hardware CORDIC engine into the reserved opcode `1010` slot of the StarCore-1 ISA.

Key features include:

- 16-bit fixed-point Q1.15 datapath
- Rotation-mode CORDIC implementation
- 16 iterative shift-add stages
- 16-entry arctangent ROM
- 3-state Moore FSM controller
- Bounded latency of 18 clock cycles
- No hardware multipliers
- Full verification against IEEE-754 Python golden model
- Approximate 6× trigonometric acceleration
- Approximate 3.2× overall workload speedup (Amdahl analysis)


## Verification Results

The CRU was verified using:

- Directed angle test vectors
- Self-checking Verilog testbenches
- Python IEEE-754 golden reference model
- Latency assertions
- Fixed-point error analysis

All 16 directed test vectors passed successfully.

---

## Technologies Used

- Verilog HDL
- Icarus Verilog (`iverilog`)
- Python
- Fixed-point arithmetic
- FPGA-oriented hardware design
- CORDIC algorithms

---

## Authors

- Emmanuel Basua
- Adedamola Yusuff
- Sanjan Naidoo

---

## References

1. J. E. Volder, *The CORDIC Trigonometric Computing Technique*, 1959.
2. M. D. Hill and M. R. Marty, *Amdahl’s Law in the Multicore Era*, 2008.
3. R. Andraka, *A Survey of CORDIC Algorithms for FPGA Based Computers*, 1998.
