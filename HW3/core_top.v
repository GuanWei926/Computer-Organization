module core_top #(
    parameter DWIDTH = 32
)(
    input                 clk,
    input                 rst
);

    // Jump type
    localparam [2:0] J_TYPE_NOP = 3'b000,
                     J_TYPE_BEQ = 3'b001,
                     J_TYPE_JAL = 3'b010,
                     J_TYPE_JR  = 3'b011,
                     J_TYPE_J   = 3'b100; 

    // imem
    reg  [DWIDTH-1:0] pc; //Program Counter signals
    wire signed[DWIDTH-1:0] imem_rdata;
    // decode
    wire [2:0] jump_type;
    wire [DWIDTH-1:0] jump_addr;
    wire we_regfile;
    wire we_dmem;
    wire [3:0]        op;
    wire [1:0]        ssel;
    wire signed[DWIDTH-1:0] imm;
    wire [4:0]        rs1_id;
    wire [4:0]        rs2_id;
    wire [4:0]        rdst_id;
    // regfile
    wire signed[DWIDTH-1:0] rs2_reg_file_out;
    // alu
    wire signed [DWIDTH-1:0] rd;
    wire signed [DWIDTH-1:0] rs1;
    wire              zero;
    wire              overflow;
    // dmem
    reg signed [DWIDTH-1:0] rdst;
    wire signed[DWIDTH-1:0] rdata;
    
    reg signed[DWIDTH-1 : 0] rs2_alu_in;

    imem imem_inst(
        .addr(pc),
        .rdata(imem_rdata)
    );

    decode decode_inst (
        // input
        .instr(imem_rdata),

        // output  
        .jump_type(jump_type),
        .jump_addr(jump_addr),
        .we_regfile(we_regfile),
        .we_dmem(we_dmem),

        .op(op),
        .ssel(ssel),
        .imm(imm),
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .rdst_id(rdst_id)
    );

    reg_file reg_file_inst (
        // input
        .clk(clk),
        .rst(rst),

        .rs1_id(rs1_id),
        .rs2_id(rs2_id),

        .we(we_regfile),
        .rdst_id(rdst_id),
        .rdst(rdst),

        // output 
        .rs1(rs1), // rs
        .rs2(rs2_reg_file_out)  // rt
    );

    alu alu_inst (
        // input
        .op(op),
        .rs1(rs1),
        .rs2(rs2_alu_in),

        // output
        .rd(rd),
        .zero(zero),
        .overflow(overflow)
    );

    // Dmem
    dmem dmem_inst (
        .clk(clk),
        .addr(rd),
        .we(we_dmem),
        .wdata(rs2_reg_file_out),
        .rdata(rdata)
    );

    always @(*)begin
        case(ssel)
            2'b00: begin 
                rs2_alu_in = rs2_reg_file_out; 
                //$display("rs2_alu_in: %d", rs2_alu_in);
                end
            2'b01: begin 
                rs2_alu_in = imm; 
                //$display("rs2_alu_in: %d", rs2_alu_in);
            end
            2'b10: begin
                rs2_alu_in = pc + 4;
                //$display("ssel:10");
            end
            default:;
        endcase

        case(imem_rdata[31:26])
            6'b100011: begin
                rdst <= rdata;
                //$display("rdst1: %d", rdst);
            end
            default: begin
                rdst <= rd;
                //$display("rdst2: %d", rdst);
            end
        endcase
        //rs2_alu_in = rs2_reg_file_out;
        //$display("rs1_id: %d, rs2_id: %d, rdst_id: %d, imm: %d, we_dmem: %d, we_reg: %d, rdst: %d, ssel:%d", rs1_id, rs2_id, rdst_id, imm, we_dmem, we_regfile, rdst, ssel);
    end

    always @(posedge clk) begin
        //$display("fuck: %d", imem_rdata);
        if (rst) begin
            pc <= 0;
        end
        else begin
            case(jump_type)
                J_TYPE_NOP: pc <= pc + 4; // For no operation, increment PC by 4
                J_TYPE_BEQ: begin
                    if (zero)
                        pc <= pc+4+(imm<<2); // Branch if rs1 == rs2
                    else
                        pc <= pc + 4;
                end
                J_TYPE_JAL: begin
                    pc <= pc+4; 
                    pc[27:0] <= jump_addr;
                end
                J_TYPE_J: begin
                    pc <= pc+4; 
                    pc[27:0] <= jump_addr;
                end
                J_TYPE_JR: begin
                    pc <= rs1;
                    //$display("rs1: ", rs1);
                end
                default:;
            endcase
        end 
    end
    
endmodule
