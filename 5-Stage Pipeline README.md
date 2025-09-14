# Project: An Experimental 5-Stage MIPS Pipeline

This repository documents my exploration into building a 5-stage pipelined MIPS processor in Verilog. The primary goal was to implement a classic five-stage pipeline (IF, ID, EX, MEM, WB) and tackle the associated data and control hazards.

However, this project also served as a personal deep-dive into a non-conventional clocking methodology: **a dual-phase, non-overlapping clocking scheme**.



## Core Architecture

The processor is based on a standard 5-stage design:
1.  **IF (Instruction Fetch):** Fetches the instruction from memory based on the Program Counter (PC).
2.  **ID (Instruction Decode):** Decodes the instruction, reads operands from the register file, and calculates immediate values.
3.  **EX (Execute):** Performs the ALU operation or calculates the memory address for loads/stores.
4.  **MEM (Memory Access):** Reads from or writes to the data memory.
5.  **WB (Write Back):** Writes the result back into the register file.

The design includes a forwarding unit to handle most data hazards (RAW hazards) by routing results from the EX and MEM stages back to the ALU inputs.

## The Dual-Phase Clocking Experiment

### The Hypothesis

Instead of clocking all pipeline registers on a single clock edge, I wanted to investigate a dual-phase approach. The idea was to use an MMCM to generate two clocks from a single source: `clk1` at 0° and `clk2` at 180°.

The pipeline stages were then clocked on a positive alternating phases:
- **IF Stage Registers:** Clocked on `clk1`
- **ID Stage Registers:** Clocked on `clk2`
- **EX Stage Registers:** Clocked on `clk1`
- **MEM Stage Registers:** Clocked on `clk2`
- **WB Stage Logic:** Occurs on `clk1`

My initial theory was that this could potentially spread out the logic evaluation across the full clock period, mimicking a latch-based pipeline design. In theory, this might help ease timing constraints by giving each stage a full half-cycle for its logic to settle before being captured by the next stage's registers.

### Initial Success and The Inevitable Challenge

For simple, linear instruction streams (like a series of ALU operations), this approach appeared to work. Data flowed cleanly forward through the pipeline from a `clk1` domain to a `clk2` domain and back. The implementation of the data forwarding unit, while slightly more complex due to the different clock phases, was also manageable.

The experiment hit a wall when I began implementing the **control hazard unit**.

## The Failure Point: Branch Logic

The core challenge of a control hazard is that a branch decision, which is typically made in the EX stage, must affect the Program Counter back in the IF stage.

**Here’s where the dual-phase clocking scheme broke down:**

1.  A branch instruction (`BEQZ`, `BNEQZ`) is evaluated in the **EX stage**, which is driven by `clk1`.
2.  The outcome of the branch (the condition `EX_MEM_Cond` and the target address `EX_MEM_ALUOut`) is latched into the **EX/MEM pipeline register** on the `posedge clk2`.
3.  This branch decision (`taken_branch`) must now travel **backwards** from the EX/MEM register to the logic controlling the PC in the **IF stage**.
4.  The PC and the IF/ID register are updated on the `posedge clk1`.

This created a critical feedback path that was nearly impossible to manage. The branch decision, finalized on a `clk2` edge, had to propagate back and be ready to influence a mux that was being evaluated for the *very next* `clk1` edge. This cross-phase, multi-cycle feedback path introduced severe timing complexities that standard synthesis tools are not well-equipped to handle without extremely careful (and complex) manual constraints. The result was unpredictable behavior and a fundamentally broken control flow.

## Conclusion and Current Status

My pursuit of a dual-phase clocking scheme was an incredibly valuable learning experience. It demonstrated that while data flows forward nicely in such a design, the backward-traveling nature of hazard control signals creates critical timing paths that make the architecture impractical for a simple FPGA implementation.

**The code in this repository is left in its experimental state.** It contains the non-functional control hazard logic built upon the dual-phase clocking foundation. It serves as a testament to this exploration.

The clear path forward is to refactor the entire design to use a **single synchronous clock** for all pipeline stages. This is the industry-standard approach precisely because it simplifies the timing analysis of these complex feedback paths required for hazard resolution, allowing for a robust and predictable design.
