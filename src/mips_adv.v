`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.08.2025 17:07:31
// Design Name: 
// Module Name: mips_adv
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


module risc_adv(input clk_in, input reset, output clk_locked);
  reg [31:0]PC,IF_ID_IR,IF_ID_NPC;                         //PC and Inst. declarations
  reg [31:0]ID_EX_IR,ID_EX_NPC,ID_EX_A,ID_EX_B,ID_EX_Imm;  //Stage latches
  reg [2:0]ID_EX_type,EX_MEM_type,MEM_WB_type;             //Type of inst declarations
  reg [31:0]EX_MEM_IR,EX_MEM_ALUOut,EX_MEM_B;             // Stage-3 latch declaration           
  reg EX_MEM_Cond,HALTED;                                //Condition for selection mux
  reg [31:0]MEM_WB_IR,MEM_WB_ALUOut,MEM_WB_LMD;          //Stage=4 declarations
  reg [31:0] REG[31:0];                                  //Register
  //new declarations
  reg ID_EX_RegWrite,EX_MEM_RegWrite,MEM_WB_RegWrite; // The new RegWrite signal
  reg [4:0] ID_EX_Rd,EX_MEM_Rd,MEM_WB_Rd;   // The new destination register number
  reg [4:0] ID_EX_Rs1;                      // Source regs for instruction        
  reg [4:0] ID_EX_Rs2; 
  reg [31:0] alu_input_A;
  reg [31:0] alu_input_B;
  (* ram_style = "block" *) reg [31:0] MEM [0:1023];
  
  wire clk1;
  wire clk2;
  wire master_reset;
  assign master_reset = reset | (~clk_locked); 

      //MMCM clock 
  clk_wiz_0 clkgen (
      .clk_out1(clk1),   // 0° clock
      .clk_out2(clk2),    // 180° clock
      .reset(reset),         // your system reset
      .locked(clk_locked),   // status signal
      .clk_in1(clk_in)       // input clock (from board oscillator or external pin)
  );
  
  parameter ADD=6'b0, SUB=6'b000001, AND=6'b000010, OR=6'b000011,
            SLT=6'b000100, MUL=6'b000101, HLT=6'b111111, LW=6'b001000,
            SW=6'b001001, ADDI=6'b001010, SUBI=6'b001011, SLTI=6'b001100,
            BNEQZ=6'b001101, BEQZ=6'b001110;
  parameter RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010, STORE=3'b011,
            BRANCH=3'b100, HALT=3'b101, NOP=3'b110;
  wire taken_branch;                               //Branch signal
  wire [31:0] branch_target_address;               //Branch address
  
  assign branch_target_address = (ID_EX_NPC) + (ID_EX_Imm << 2); //Adder
  assign taken_branch = (EX_MEM_type == BRANCH) &&                        //Branching logic
                      ((EX_MEM_IR[31:26] == BEQZ && EX_MEM_Cond == 1) || 
                       (EX_MEM_IR[31:26] == BNEQZ && EX_MEM_Cond == 0));
  
  always @(posedge clk1 or posedge master_reset)      //**STAGE-1** 
    if (master_reset) 
      begin
      $display("IF stage: taken_branch=%b, EX_MEM_type=%b, EX_MEM_Cond=%b", 
               taken_branch, EX_MEM_type, EX_MEM_Cond);
      PC          <= 32'd0;
      IF_ID_IR    <= 32'h0;   
      IF_ID_NPC   <= 32'd0;
      HALTED      <= 1'b0;
    end
    else if (HALTED==0)
      begin
        
          if(taken_branch)   //newnew
          begin
            $display("BRANCH TAKEN at time %0t: PC=%h -> %h", $time, PC, EX_MEM_ALUOut);
            PC <= EX_MEM_ALUOut;              // Correct the PC to the target address.
            IF_ID_IR <= MEM[EX_MEM_ALUOut[11:2]];  //load the vlaue stored at address pointed by alu into ir.
            IF_ID_NPC <= EX_MEM_ALUOut+32'd4;  // tell pc to have a foresight of instruction.
            
          end
        else
          begin                  //default
            IF_ID_IR <= MEM[PC[11:2]];   // load value from address pointed by PC from mem to IR.
            IF_ID_NPC <= PC+32'd4;     // increment npc.
            PC <= PC +32'd4;           // increment pc.  *word addressing*
            
          end
      end

      
  always @(posedge clk2 or posedge master_reset)       //**STAGE-2**
    if (master_reset) 
      begin
      ID_EX_IR   <= 32'h0;
      ID_EX_NPC  <= 32'd0;
      ID_EX_A    <= 32'd0;
      ID_EX_B    <= 32'd0;
      ID_EX_Imm  <= 32'd0;
      ID_EX_type <= NOP; 
      end
      
    else if(taken_branch)
      begin
      ID_EX_Rd       <= 5'b0;
      ID_EX_A    <= 32'd0;
      ID_EX_B    <= 32'd0;
      ID_EX_Imm  <= 32'd0;
      ID_EX_type <= NOP; 
      ID_EX_RegWrite <= 1'b0;
      ID_EX_Rs1      <= 5'b0;
      ID_EX_Rs2      <= 5'b0;
      ID_EX_IR       <= 32'h0;
      end
    else if(HALTED==0)  
    begin
      if(IF_ID_IR[25:21]==5'b00000)         //source register =0? 
        ID_EX_A <=0;                        //pass to next stage.
      else 
        ID_EX_A <= REG[IF_ID_IR[25:21]];    //extract the value of A from actual reg.
      
      if(IF_ID_IR[20:16]==5'b00000)         //target reg = 0?
        ID_EX_B <=0;                        // pass it to next stage.
      else  
        ID_EX_B <= REG[IF_ID_IR[20:16]];    //else pass the actual value to next stage.
      //following must be done in any case
      ID_EX_Rs1 <= IF_ID_IR[25:21]; // Extract the Rs1 register number
      ID_EX_Rs2 <= IF_ID_IR[20:16]; // Extract the Rs2 register number
      ID_EX_NPC <= IF_ID_NPC;              //be smart and pass the npc value to next stage
      ID_EX_IR <= IF_ID_IR;                // same pass the IR. (kinda most useful)
      ID_EX_Imm <= {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}}; //extend the bit 16 to 32.
      
      case(IF_ID_IR[31:26])
        ADD,SUB,AND,OR,SLT,MUL: 
           begin
            ID_EX_type <= RR_ALU;     //we gotta tell what kinda instruction it is. 
            //new logic
            ID_EX_RegWrite <= 1'b1; // These instructions write to a register
            ID_EX_Rd <= IF_ID_IR[15:11]; // For R-type, Rd is here
           end
        
        ADDI,SUBI,SLTI:
           begin 
            ID_EX_type <= RM_ALU;             // it makes dumb alu look smarter
            //new logic
            ID_EX_RegWrite <= 1'b1; // These instructions write to a register
            ID_EX_Rd       <= IF_ID_IR[20:16]; // For I-type, destination is Rt
           end
        
        LW: 
          begin
            ID_EX_type <= LOAD;               
            ID_EX_RegWrite <= 1'b1; // Load writes to a register
            ID_EX_Rd       <= IF_ID_IR[20:16]; // For Load, destination is Rt  
          end
        
        SW:
           begin 
            ID_EX_type <= STORE;
            ID_EX_RegWrite <= 1'b0; // Store does NOT write to a register
            ID_EX_Rd       <= 5'b0;  // No destination, so pass 0
           end
        
        BNEQZ,BEQZ: 
           begin
            ID_EX_type <= BRANCH;
            ID_EX_RegWrite <= 1'b0; // Branch does NOT write to a register
            ID_EX_Rd       <= 5'b0;  // No destination, so pass 0
           end
        HLT: 
          begin
            ID_EX_type <= HALT;
            ID_EX_RegWrite <= 1'b0;
            ID_EX_Rd       <= 5'b0;
          end
                                          
        default:
          begin 
            ID_EX_type <= HALT;
            ID_EX_RegWrite <= 1'b0;
            ID_EX_Rd       <= 5'b0;
          end 
      endcase
       $display("ID @%0t: Instr %h, A_in=%d, B_in=%d", 
                 $time, IF_ID_IR, REG[IF_ID_IR[25:21]], REG[IF_ID_IR[20:16]]);
    end 
    
    //forwarding logic using muxes
    always @(*) begin
    // MUX for ALU Input A (Handles forwarding and original BRANCH/ALU selection)
    if (EX_MEM_RegWrite && (EX_MEM_Rd != 0) && (EX_MEM_Rd == ID_EX_Rs1)) begin
        alu_input_A = EX_MEM_ALUOut; // Forward from EX stage
      end
    else if (MEM_WB_RegWrite && (MEM_WB_Rd != 0) && (MEM_WB_Rd == ID_EX_Rs1)) begin
        alu_input_A = (MEM_WB_type == LOAD) ? MEM_WB_LMD : MEM_WB_ALUOut;    // Forward from MEM stage
        //alu_input_A = MEM_WB_ALUOut; 
      end
    /*else begin // No Hazard: Use Original MUX Logic
        if (ID_EX_type == BRANCH)
            alu_input_A = ID_EX_NPC; // Select NPC for branches
            */          
    else
      alu_input_A = ID_EX_A;   // Default is register A
     //end

    // MUX for ALU Input B (Handles forwarding and original REG/IMM selection)
    if ((ID_EX_type == RR_ALU) && EX_MEM_RegWrite && (EX_MEM_Rd != 0) && (EX_MEM_Rd == ID_EX_Rs2))
        alu_input_B = EX_MEM_ALUOut;
    else if ((ID_EX_type == RR_ALU) && MEM_WB_RegWrite && (MEM_WB_Rd != 0) && (MEM_WB_Rd == ID_EX_Rs2))
        alu_input_B = (MEM_WB_type == LOAD) ? MEM_WB_LMD : MEM_WB_ALUOut;
    else if (ID_EX_type == RR_ALU)
        alu_input_B = ID_EX_B;
    else // For RM_ALU, LOAD, STORE, BRANCH, the second operand is always the immediate
        alu_input_B = ID_EX_Imm;
  end
    
    always @(posedge clk1 or posedge master_reset)    //**STAGE-3**
      if(master_reset)
        begin
          EX_MEM_type <=NOP;
          EX_MEM_IR <= 0;
          EX_MEM_ALUOut <= 32'd0;
          EX_MEM_B      <= 32'd0;
          EX_MEM_Cond   <= 1'b0;
          EX_MEM_RegWrite <= 1'b0; 
          EX_MEM_Rd       <= 5'b0;  
        end
      else if(HALTED==0)
        begin                        // transfer of instructions onto next step.
          EX_MEM_type <= ID_EX_type;   
          EX_MEM_IR <= ID_EX_IR;
           EX_MEM_RegWrite <= ID_EX_RegWrite; // Pass RegWrite along
           EX_MEM_Rd       <= ID_EX_Rd;       // Pass Rd along
          case(ID_EX_type)
            RR_ALU:                 //If the instruction type is reg-reg then use this.
              begin
                case(ID_EX_IR[31:26])
                  ADD: EX_MEM_ALUOut <= (alu_input_A) + (alu_input_B);
                  SUB: EX_MEM_ALUOut <= (alu_input_A) - (alu_input_B);
                  MUL: EX_MEM_ALUOut <= (alu_input_A) * (alu_input_B);           
                  AND: EX_MEM_ALUOut <= (alu_input_A) & (alu_input_B);
                  OR: EX_MEM_ALUOut <= (alu_input_A) | (alu_input_B);
                  SLT: EX_MEM_ALUOut <= (alu_input_A) < (alu_input_B);
                  default: EX_MEM_ALUOut <= 32'h0;
                endcase
              end
            RM_ALU:                      //If it is reg-immediate value choose this.
              begin
                case(ID_EX_IR[31:26])
                  ADDI: EX_MEM_ALUOut <= (alu_input_A) + (alu_input_B);
                  SUBI: EX_MEM_ALUOut <= (alu_input_A) - (alu_input_B);
                  SLTI: EX_MEM_ALUOut <= (alu_input_A) < (alu_input_B);
                  default: EX_MEM_ALUOut <= 32'h0;//(alu_input_A) < (alu_input_B);
                endcase
              end
            LOAD, STORE:               //If instruction is load or store use this.
              begin
                EX_MEM_ALUOut <= (alu_input_A) + (alu_input_B);  //Calculate the memory address where to store.
                EX_MEM_B <= alu_input_B;                       //Pass the value of B.
              end
            BRANCH:                   //If the instruction is branch.
              begin
                EX_MEM_ALUOut <= branch_target_address;
                //EX_MEM_ALUOut <= (alu_input_A) + (alu_input_B);  //Calculate where to branch.
                EX_MEM_Cond <= (alu_input_A == 0);
              end
              default:
                begin
                end
          endcase
          $display("EX @%0t: Instr %h, alu_A=%d, alu_B=%d, ALUOut=%d, Cond=%b", 
                 $time, ID_EX_IR, alu_input_A, alu_input_B, EX_MEM_ALUOut, EX_MEM_Cond);
    
        end
        
    always @(posedge clk2 or posedge master_reset)    //**STAGE-4**
      
      if(master_reset)
        begin
          MEM_WB_type <=NOP;
          MEM_WB_IR <=0;
          MEM_WB_RegWrite <= 1'b0; 
          MEM_WB_Rd       <= 5'b0;  
        end
      else if(HALTED ==0)
        begin
          MEM_WB_type <= EX_MEM_type;  //Default transfer of values to next stage.
          MEM_WB_IR <= EX_MEM_IR;
          MEM_WB_RegWrite <= EX_MEM_RegWrite;
          MEM_WB_Rd       <= EX_MEM_Rd;       
          MEM_WB_ALUOut <= EX_MEM_ALUOut;
          MEM_WB_LMD <= MEM_WB_LMD;
          
          case(EX_MEM_type)
            RR_ALU,RM_ALU:                  //Chill if it is reg-reg/imm instruction work normally. 
              MEM_WB_ALUOut <= EX_MEM_ALUOut;
            LOAD:                          //Gotta transfer the data stored in the memory for extraction. 
              MEM_WB_LMD <= MEM[EX_MEM_ALUOut[11:2]];
            STORE:                        //Gotta store the value in memory pointed by alu output.
                MEM[EX_MEM_ALUOut[11:2]] <= EX_MEM_B;
          endcase
        end
        
      always @(posedge clk1 or posedge master_reset)   //**STAGE-5**
        begin
          if(master_reset) 
            begin
              MEM_WB_IR   <= 0;      // acts like NOP
              MEM_WB_type <= 0;
              MEM_WB_ALUOut <= 0;
              MEM_WB_LMD <= 0;
            end
             case(MEM_WB_type)
               RR_ALU, RM_ALU: // Combined ALU types
                  begin
                   // MODIFIED: Use MEM_WB_Rd instead of re-decoding the IR
                   if(MEM_WB_Rd != 5'd0)
                       REG[MEM_WB_Rd] <= MEM_WB_ALUOut;
                       $display("WB @%0t: Reg[%0d] <= %h (from instr %h)", 
                       $time, MEM_WB_Rd, MEM_WB_ALUOut, MEM_WB_IR);
                  end
               LOAD: 
                 begin
                   // MODIFIED: Use MEM_WB_Rd instead of re-decoding the IR
                   if (MEM_WB_Rd != 5'd0)
                   REG[MEM_WB_Rd] <= MEM_WB_LMD;
                    $display("WB @%0t: Reg[%0d] <= %h (from instr %h)", 
                    $time, MEM_WB_Rd, MEM_WB_LMD, MEM_WB_IR);
                   
                 end
               HALT: 
                 begin 
                   HALTED <= 1'b1;
                    $display("HALT encountered at time %0t (instr %h)", $time, MEM_WB_IR);
                 end
               default: 
                 begin
                 end
            endcase
          end
endmodule
