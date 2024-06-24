module decode #(parameter DWIDTH = 32)
(
    input [DWIDTH-1:0]  instr,   // Input instruction.

    output reg [2 : 0]        jump_type,
    output reg [DWIDTH-1 : 0] jump_addr, // the address will jump to
    output reg              we_regfile,  // Write enable for the register file.
    output reg              we_dmem,      // Write enable for the data memory.
    output reg [3 : 0]      op,      // Operation code for the ALU.
    output reg [1 : 0]      ssel,    // Select the signal for either the immediate value or rs2.

    output reg signed [DWIDTH-1:0] imm,     // The immediate value (if used).
    output reg [4 : 0]      rs1_id,  // register ID for rs.
    output reg [4 : 0]      rs2_id,  // register ID for rt (if used).
    output reg [4 : 0]      rdst_id // register ID for rd or rt (if used).
    //output reg              hazard_info
);

/***************************************************************************************
    ---------------------------------------------------------------------------------
    | R_type |    |   opcode   |   rs   |   rt   |   rd   |   shamt   |    funct    |
    ---------------------------------------------------------------------------------
    | I_type |    |   opcode   |   rs   |   rt   |             immediate            |
    ---------------------------------------------------------------------------------
    | J_type |    |   opcode   |                     address                        |
    ---------------------------------------------------------------------------------
                   31        26 25    21 20    16 15    11 10        6 5           0
 ***************************************************************************************/

    localparam [3:0] OP_AND = 4'b0000,
                     OP_OR  = 4'b0001,
                     OP_ADD = 4'b0010,
                     OP_SUB = 4'b0110,
                     OP_NOR = 4'b1100,
                     OP_SLT = 4'b0111,
                     OP_JR = 4'b1000,
                     OP_NOT_DEFINED = 4'b1111;

     // Instruction field extraction
    wire [5:0] op_code = instr[31:26];
    wire [4:0] rs = instr[25:21];
    wire [4:0] rt = instr[20:16];
    wire [4:0] rd = instr[15:11];
    wire [4:0] shamt = instr[10:6];
    wire [5:0] funct = instr[5:0];
    wire [15:0] imm_val = instr[15:0];
    wire [25:0] jump_addr_val = instr[25:0];

    // Instruction decoding
    always @(*) begin

    //$display("");
    //$display("instr: 0x%08x", instr);
        case (op_code)
            6'b000000: begin // If op_code is 000000, then it will be R-type
                case(funct)
                    6'b100000:begin
                        op = OP_ADD;
                        ssel = 2'b00; // Use rs2
                        rs1_id = rs;
                        jump_type = 3'b000; // Not a jump instruction
                        jump_addr = 32'b0; // Not used
                    end

                    6'b100100:begin
                        op = OP_AND;
                        ssel = 2'b00; // Use rs2
                        rs1_id = rs;
                        jump_type = 3'b000; // Not a jump instruction
                        jump_addr = 32'b0; // Not used
                    end

                    6'b100111:begin
                        op = OP_NOR;
                        ssel = 2'b00; // Use rs2
                        rs1_id = rs;
                        jump_type = 3'b000; // Not a jump instruction
                        jump_addr = 32'b0; // Not used
                    end

                    6'b100101:begin
                        op = OP_OR;
                        ssel = 2'b00; // Use rs2
                        rs1_id = rs;
                        jump_type = 3'b000; // Not a jump instruction
                        jump_addr = 32'b0; // Not used
                    end

                    6'b101010:begin
                        op = OP_SLT;
                        ssel = 2'b00; // Use rs2
                        rs1_id = rs;
                        jump_type = 3'b000; // Not a jump instruction
                        jump_addr = 32'b0; // Not used
                    end

                    6'b100010:begin
                        op = OP_SUB;
                        ssel = 2'b00; // Use rs2
                        rs1_id = rs;
                        jump_type = 3'b000; // Not a jump instruction
                        jump_addr = 32'b0; // Not used
                    end

                    6'b001000:begin
                        op = OP_JR;
                        ssel = 2'b10; // Use rs2
                        rs1_id = 31;
                        jump_type = 3'b011; 
                        jump_addr[27:0] = jump_addr_val << 2;
                        //$display("JR");
                    end

                    default: begin
                        op = OP_NOT_DEFINED;
                        rs1_id = rs;
                        ssel = 2'b11;
                        jump_type = 3'b000; // Not a jump instruction
                        jump_addr = 32'b0; // Not used
                    end
                endcase
                imm = {{16{imm_val[15]}}, imm_val}; 
                rs2_id = rt;
                rdst_id = rd;
                we_regfile = 1'b1; // writing to the register file
                we_dmem = 1'b0; // Not writing to the data memory
                //hazard_info = 1'b1; // Hazard info signal set
            end

            6'b001000: begin // If op_code is 001000, then it will be addi in I-type
                op = OP_ADD;
                jump_type = 3'b000; // Not a jump instruction
                jump_addr = 32'b0; // Not used
                ssel = 2'b01; // Use immediate
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = 5'b0;
                rdst_id = rt;
                we_regfile = 1'b1; // writing to the register file
                we_dmem = 1'b0; // Not writing to the data memory
                //hazard_info = 1'b0; // No hazard for this instruction
            end

            6'b001010: begin // If op_code is 001010, then it will be slti in I-type
                op = OP_SLT;
                jump_type = 3'b000; // Not a jump instruction
                jump_addr = 32'b0; // Not used
                ssel = 2'b01; // Use immediate
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = 5'b0;
                rdst_id = rt;
                we_regfile = 1'b1; // writing to the register file
                we_dmem = 1'b0; // Not writing to the data memory
                //hazard_info = 1'b0; // No hazard for this instruction
            end

            6'b100011: begin // If op_code is 100011, then it will be lw in I-type
                op = OP_ADD; 
                jump_type = 3'b000; // Not a jump instruction
                jump_addr = 32'b0; // Not used
                ssel = 2'b01; // Use immediate
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = rt; // Not used
                rdst_id = rt;
                we_regfile = 1'b1; // Not writing to the register file
                we_dmem = 1'b0; // Not writing to the data memory
                //hazard_info = 1'b1; // Hazard info signal set
            end

            6'b101011: begin // If op_code is 101011, then it will be sw in I-type
                op = OP_ADD; 
                jump_type = 3'b000; // Not a jump instruction
                jump_addr = 32'b0; // Not used
                ssel = 2'b01; // Use immediate
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = rt; 
                rdst_id = rt;
                we_regfile = 1'b0; // Not writing to the register file
                we_dmem = 1'b1; // Writing to the data memory
                //hazard_info = 1'b1; // Hazard info signal set
            end

            6'b000100: begin // If op_code is 000100, then it will be beq in I-type
                op = OP_SUB; 
                jump_type = 3'b001; // jump instruction
                jump_addr = 32'b0; // Not used
                ssel = 2'b00; // Use immediate
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = rt;
                rdst_id = 5'b0; // Not used
                we_regfile = 1'b0; // Not writing to the register file
                we_dmem = 1'b0; // Not writing to the data memory
                //hazard_info = 1'b1; // Hazard info signal set
            end

            6'b000011: begin // If op_code is 000011, then it will be jal in J-type
                op = OP_ADD; 
                jump_type = 3'b010; // JAL instruction
                jump_addr[27:0] = jump_addr_val << 2; // Jump address (sign-extended and shifted left by 2 bits)
                ssel = 2'b10; 
                imm = {{12{instr[31]}}, instr[31:0], 2'b0}; // Zero-extend immediate and shift left by 2 bits
                rs1_id = 5'b0; // Not used
                rs2_id = 5'b0; // Not used
                rdst_id = 31; 
                we_regfile = 1'b1; // writing to the register file
                we_dmem = 1'b0; // Not writing to the data memory
                //hazard_info = 1'b1; // Hazard info signal set
            end

            6'b000010: begin // If op_code is 000010, then it will be j in J-type
                op = OP_NOT_DEFINED; // Not specified, using ADD
                jump_type = 3'b010; // J instruction
                jump_addr[27:0] = jump_addr_val << 2; // Jump address (sign-extended and shifted left by 2 bits)
                ssel = 2'b11; // Use immediate
                imm = {{12{instr[31]}}, jump_addr_val, 2'b0}; // Zero-extend immediate and shift left by 2 bits
                rs1_id = 5'b0; // Not used
                rs2_id = 5'b0; // Not used
                rdst_id = 5'b0; // Not used
                we_regfile = 1'b0; // Not writing to the register file
                we_dmem = 1'b0; // Not writing to the data memory
                //hazard_info = 1'b1; // Hazard info signal set
            end

            default: begin
                op = OP_NOT_DEFINED;
                jump_type = 3'b000; // Not a jump instruction
                jump_addr = 32'b0; // Not used
                ssel = 2'b11;
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = 5'b0;
                rdst_id = rt;
                we_regfile = 1'b0; // Not writing to the register file
                we_dmem = 1'b0; // Not writing to the data memory
                //hazard_info = 1'b0; // No hazard for this instruction
            end
        endcase
        //$display("reg_file: %d", we_regfile);
    end
endmodule
