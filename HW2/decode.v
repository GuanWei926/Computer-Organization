module decode #(parameter DWIDTH = 32)
(
    input [DWIDTH-1:0]  instr,   // Input instruction.

    output reg [3 : 0]      op,      // Operation code for the ALU.
    output reg              ssel,    // Select the signal for either the immediate value or rs2.

    output reg [DWIDTH-1:0] imm,     // The immediate value (if used).
    output reg [4 : 0]      rs1_id,  // register ID for rs.
    output reg [4 : 0]      rs2_id,  // register ID for rt (if used).
    output reg [4 : 0]      rdst_id // register ID for rd or rt (if used).
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
                     OP_NOT_DEFINED = 4'b1111;

     // Instruction field extraction
    wire [5:0] op_code = instr[31:26];
    wire [4:0] rs = instr[25:21];
    wire [4:0] rt = instr[20:16];
    wire [4:0] rd = instr[15:11];
    wire [4:0] shamt = instr[10:6];
    wire [5:0] funct = instr[5:0];
    wire [15:0] imm_val = instr[15:0];

    // Instruction decoding
    always @(*) begin
        case (op_code)
            6'b000000: begin // If op_code is 000000, then it will be R-type
                case(funct)
                    6'b100000:begin
                        op = OP_ADD;
                    end

                    6'b100100:begin
                        op = OP_AND;
                    end

                    6'b100111:begin
                        op = OP_NOR;
                    end

                    6'b100101:begin
                        op = OP_OR;
                    end

                    6'b101010:begin
                        op = OP_SLT;
                    end

                    6'b100010:begin
                        op = OP_SUB;
                    end

                    default: begin
                        op = OP_NOT_DEFINED;
                    end
                endcase
                ssel = 1'b1; // Use rs2
                imm = {{16{imm_val[15]}}, imm_val}; 
                rs1_id = rs;
                rs2_id = rt;
                rdst_id = rd;
            end

            6'b001000: begin // If op_code is 001000, then it will be addi in I-type
                op = OP_ADD;
                ssel = 1'b0; // Use immediate
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = 5'b0;
                rdst_id = rt;
            end

            6'b001010: begin // If op_code is 001000, then it will be slti in I-type
                op = OP_SLT;
                ssel = 1'b0; // Use immediate
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = 5'b0;
                rdst_id = rt;
            end

            default: begin
                op = OP_NOT_DEFINED;
                ssel = 1'b0;
                imm = {{16{imm_val[15]}}, imm_val}; // Sign-extend immediate
                rs1_id = rs;
                rs2_id = 5'b0;
                rdst_id = rt;
            end
        endcase
    end
endmodule
