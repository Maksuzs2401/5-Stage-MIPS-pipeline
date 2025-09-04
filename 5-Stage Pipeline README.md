5-Stage Pipelined RISC-V Style Processor
Overview
This project is a complete 5-stage pipelined processor, designed and implemented in Verilog. It is based on a classic RISC architecture (like MIPS or RISC-V) and includes advanced hardware features to handle both data and control hazards, ensuring correct and efficient execution of sequential programs and loops.

This processor was designed as an advanced computer architecture project to demonstrate a practical understanding of pipelining, hazard detection, and performance optimization.

Key Features
Classic 5-Stage Pipeline: Implements the standard Fetch, Decode, Execute, Memory, and Write-Back stages.

Data Hazard Resolution: A complete data forwarding unit resolves Read-After-Write (RAW) hazards without stalling the pipeline. It can forward results from the EX/MEM and MEM/WB stages back to the EX stage.

Problem
While I have tried to implement control hazard unit. I have used a dedicated adder for calculating branch address using assign statement. The flushing takes place in stage-2. But I am not getting the correct output. 



File Structure
.
├── src/
│   └── risc_adv.v       # The main Verilog source for the processor core.
└── sim/
    └── risc_adv_tb.v    # The testbench file used for simulation.

How to Run the Simulation
This project can be simulated using any standard Verilog simulator (like Xilinx Vivado's XSim, ModelSim/QuestaSim, or Icarus Verilog).

Compile the Verilog Files:
The clk_wiz_0 module is a Xilinx IP core. For simulation, you can either generate it in Vivado or replace it with a simple clock divider if using other tools.

From a TCL console in your simulation environment:

# For Vivado's XSim
xvlog path/to/src/risc_adv.v
xvlog path/to/sim/risc_adv_tb.v
xelab risc_adv_tb -snapshot risc_adv_sim

Run the Simulation:

# For Vivado's XSim
xsim risc_adv_sim -runall

Verification Strategy:
The provided testbench (risc_adv_tb.v) automatically runs two test programs to verify the key features:

Data Forwarding Test: A sequential program with back-to-back ADD instructions that create data dependencies. The test passes if the final register values are correct, proving the forwarding unit is working.

Expected Output: R4 = 30, R5 = 55

Control Hazard Test: A program with a for loop that runs 5 times. This tests the branch_taken signal and the pipeline flush mechanism. The test passes if the final counter and accumulator values are correct. However, my test fails and I am getting output R10 = 0 and R11 = 18.

Expected Output: R10 = 0, R11 = 10

Actual Output: R10 = 0, R11 = 18. 

