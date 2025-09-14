`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.08.2025 11:50:01
// Design Name: 
// Module Name: risc_adv_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module risc_adv_tb;
  reg clk_in, reset;
  wire clk_locked;

  integer k;

  // Instantiate top module
  mips_adv uut (
    .clk_in(clk_in),
    .reset(reset),
    .clk_locked(clk_locked)
  );

  // Clock generation: 10ns period (100MHz input)
  initial begin
    clk_in = 0;
    forever #5 clk_in = ~clk_in;
  end

  // Stimulus
  initial begin
    reset = 1;
    #20;            // keep reset active for a while
    reset = 0;
  end

  // Initialize CPU memory & registers after reset
  initial begin
    wait(clk_locked == 1);   // wait for MMCM lock
    wait(reset == 0);

    // Initialize registers
    for(k=0; k<32; k=k+1)
      uut.REG[k] = 0;

    // Load program 1 into instruction memory
    uut.MEM[0] = 32'h2801000a; // ADDI R1, R0, 10
    uut.MEM[1] = 32'h28020014; // ADDI R2, R0, 20
    uut.MEM[2] = 32'h28030019; // ADDI R3, R0, 25
    uut.MEM[3] = 32'h00222000; // ADD R4, R1, R2
    uut.MEM[4] = 32'h00832800; // ADD R5, R4, R3
    uut.MEM[5] = 32'hfc000000; // HLT

    // Let simulation run until the processor halts
    wait(uut.HALTED == 1);
    @(posedge uut.clk1); // Settle

    // Dump results for Test 1
    $display("\n---- Register Dump (NORMAL TEST) ----");
    for(k=1; k<6; k=k+1) // Display R1 through R5
        $display("R%0d = %0d", k, uut.REG[k]);
    
    $display("\n--- Preparing for HAZARD TEST ---");
    #20;

    // --- TEST 2: HAZARD & BRANCH TEST ---
    // Reset the processor to start the next test
    reset = 1;
    #20;
    reset = 0;
    wait(reset == 0);

    $display("--- Loading and Running HAZARD TEST Program ---");
    
    // Re-initialize registers
    for(k=0; k<32; k=k+1)
      uut.REG[k] = 0;

    // Load the second program into memory (overwriting the first)
    uut.MEM[0] = 32'h280A0005; // ADDI R10, R0, 5
    uut.MEM[1] = 32'h280B0000; // ADDI R11, R0, 0
    uut.MEM[2] = 32'h296B0002; // ADDI R11, R11, 2
    uut.MEM[3] = 32'h294AFFFF; // ADDI R10, R10, -1
    uut.MEM[4] = 32'h3540FFFD; // BNEQZ R10, Loop (to addr 2)
    uut.MEM[5] = 32'hFC000000; // HLT
    wait(uut.HALTED == 1);
    
    $display("\n---- Register Dump (HAZARD TEST) ----");
    $display("R10 (Counter) = %0d", uut.REG[10]);
    $display("R11 (Accumulator) = %0d", uut.REG[11]);

    $finish;
  end

endmodule
