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
    wire [DWIDTH-1:0] imem_rdata;
    // decode
    wire [2:0] jump_type;
    wire [DWIDTH-1:0] jump_addr;
    reg  we_regfile;
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
    
    // IF/ID pipeline register
    reg [DWIDTH-1:0] if_id_instr;
    reg [DWIDTH-1:0] if_id_pc;

    // ID/EX pipeline register
    reg [DWIDTH-1:0] id_ex_addr;
    reg [DWIDTH-1:0] id_ex_pc;
    reg [0:0] id_ex_we_regfile;
    reg [0:0] id_ex_we_dmem;
    reg signed [DWIDTH-1:0] id_ex_imm;
    reg [4:0] id_ex_rs1_id;
    reg [4:0] id_ex_rs2_id;
    reg [4:0] id_ex_rdst_id;
    reg [3:0] id_ex_op;
    reg [1:0] id_ex_ssel;
    reg [5:0] id_ex_op_code;
    reg [2:0] id_ex_jump_type;
    reg signed [DWIDTH-1 : 0] id_ex_reg_rs1;
    reg signed [DWIDTH-1 : 0] id_ex_reg_rs2; 

    // EX/MEM pipeline register
    reg [DWIDTH-1:0] ex_mem_pc;
    reg [4:0] ex_mem_rdst_id;
    reg [5:0] ex_mem_op_code;
    reg [0:0] ex_mem_we_regfile;
    reg [0:0] ex_mem_we_dmem;
    reg signed [DWIDTH-1 : 0] ex_mem_rd;
    reg signed [DWIDTH-1 : 0] ex_mem_rs2;

    // MEM/WB pipeline register
    reg [0:0] mem_wb_we_regfile;
    reg [0:0] mem_wb_we_dmem;
    reg [DWIDTH-1:0] mem_wb_pc;
    reg signed [DWIDTH-1:0] mem_wb_rdata_or_rd;
    reg [4:0] mem_wb_rdst_id;
    

    imem imem_inst(
        .addr(pc),
        .rdata(imem_rdata)
    );

    decode decode_inst (
        // input
        .instr(if_id_instr),

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

        .we(mem_wb_we_regfile),
        .hazard_stall(hazard_stall),
        .rdst_id(mem_wb_rdst_id),
        .rdst(mem_wb_rdata_or_rd),

        // output 
        .rs1(rs1), // rs
        .rs2(rs2_reg_file_out)  // rt
    );

    alu alu_inst (
        // input
        .op(id_ex_op),
        .rs1(id_ex_reg_rs1),
        .rs2(rs2_alu_in),

        // output
        .rd(rd),
        .zero(zero),
        .overflow(overflow)
    );

    // Dmem
    dmem dmem_inst (
        .clk(clk),
        .addr(ex_mem_rd),
        .we(ex_mem_we_dmem),
        .wdata(ex_mem_rs2),
        .rdata(rdata)
    );


    // Hazard Control
    wire hazard_stall;
    wire hazard_flush;

    // Simple hazard control logic for data hazards (stall)
    assign hazard_stall = ((ex_mem_rdst_id != 0 && (ex_mem_rdst_id == id_ex_rs1_id || ex_mem_rdst_id == id_ex_rs2_id || ex_mem_rdst_id == id_ex_rdst_id)) 
    || (mem_wb_rdst_id != 0 && (mem_wb_rdst_id == id_ex_rs1_id || mem_wb_rdst_id == id_ex_rs2_id || mem_wb_rdst_id == id_ex_rdst_id)));
    
    // Branch hazard detection (flush)
    assign hazard_flush = (id_ex_jump_type != J_TYPE_NOP);  // Added hazard flush logic

    // IF/ID pipeline register update
    always @(posedge clk or posedge rst) begin
        if (rst || hazard_stall || hazard_flush) begin
            if_id_instr <= 0;
            if_id_pc <= 0;
        end else begin   
            if_id_instr <= imem_rdata;
            if_id_pc <= pc;
        end
        //$display("pc:", pc);
        //$display("rdata:", imem_rdata);
        //$display("if_id_instr:", if_id_instr);
    end

    // ID/EX pipeline register update
    always @(posedge clk or posedge rst) begin
        if (rst || hazard_stall || hazard_flush) begin
            id_ex_addr <= 0;
            id_ex_pc <= 0;
            id_ex_imm <= 0;
            id_ex_op <= 0;
            id_ex_rs1_id <= 0;
            id_ex_rs2_id <= 0;
            id_ex_rdst_id <= 0;
            id_ex_reg_rs1 <= 0;
            id_ex_reg_rs2 <= 0;
            id_ex_ssel <= 2'b11;
            id_ex_op_code <= 0;
            id_ex_we_regfile <= 0;
            id_ex_we_dmem <= 0;
            id_ex_jump_type <= 0;
        end else begin
            id_ex_addr <= jump_addr;
            id_ex_pc <= if_id_pc;
            id_ex_imm <= imm;
            id_ex_op <= op;
            id_ex_rs1_id <= rs1_id;
            id_ex_rs2_id <= rs2_id;
            id_ex_rdst_id <= rdst_id;
            id_ex_reg_rs1 <= rs1;
            id_ex_reg_rs2 <= rs2_reg_file_out;
            id_ex_ssel <= ssel;
            id_ex_op_code <= if_id_instr[31:26];
            id_ex_we_regfile <= we_regfile;
            id_ex_we_dmem <= we_dmem;
            id_ex_jump_type <= jump_type;
        end
        //$display("id_ex_pc:", id_ex_pc);
        //$display("rs1_id:", rs1_id);
        //$display("id_ex_rs1_id:", id_ex_rs1_id);
        //$display("id_ex_rs2_id:", id_ex_rs2_id);
        //$display("id_ex_reg_rs1:", id_ex_reg_rs1);
        //$display("hazard_stall: ", hazard_stall);
        //$display("we_dmem: ", we_dmem);
        //$display("id_ex_we_dmem: ", id_ex_we_dmem);
        //$display("id_ex_jump_type: ", id_ex_jump_type);
    end

    // EX/MEM pipeline register update
    always @(posedge clk or posedge rst) begin
        if (rst || hazard_stall) begin
            ex_mem_pc <= 0;
            ex_mem_rdst_id <= 0;
            ex_mem_we_regfile <= 0;
            ex_mem_we_dmem <= 0;
            ex_mem_rd <= 0;
            ex_mem_op_code <= 0;
            ex_mem_rs2 <= 0;
        end else begin
            ex_mem_pc <= id_ex_pc;
            ex_mem_rdst_id <= id_ex_rdst_id;
            ex_mem_we_regfile <= id_ex_we_regfile;
            ex_mem_we_dmem <= id_ex_we_dmem;
            ex_mem_rd <= rd;
            ex_mem_op_code <= id_ex_op_code;
            ex_mem_rs2 <= id_ex_reg_rs2;
        end
        //$display("ex_mem_pc:", ex_mem_pc);
        //$display("ex_mem_rdst_id:", ex_mem_rdst_id);
        //$display("ex_mem_rs2:", ex_mem_rs2);
        //$display("ex_mem_we_dmem:", ex_mem_we_dmem);
    end

    // MEM/WB pipeline register update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_wb_pc <= 0;
            mem_wb_rdst_id <= 0;
            mem_wb_rdata_or_rd <= 0;
            mem_wb_we_regfile <= 0;
            mem_wb_we_dmem <= 0;
        end else begin
            mem_wb_pc <= ex_mem_pc;
            mem_wb_rdst_id <= ex_mem_rdst_id;
            case(ex_mem_op_code)
                6'b100011: begin
                    mem_wb_rdata_or_rd <= rdata;
                    //$display("rdst1: %d", rdst);
                end
                default: begin
                    mem_wb_rdata_or_rd <= ex_mem_rd;
                end
            endcase
            mem_wb_we_regfile <= ex_mem_we_regfile;
        end
        //$display("mem_wb_pc: ", mem_wb_pc);
        //$display("mem_wb_rdst_id:", mem_wb_rdst_id);
        //$display("mem_wb_rdata_or_rd:", mem_wb_rdata_or_rd);
        //$display("rdst_id: %d", rdst_id);
        //$display("rdst: %d", mem_wb_rdata_or_rd);
    end

    always @(*)begin
        case(id_ex_ssel)
            2'b00: begin 
                rs2_alu_in = id_ex_reg_rs2; 
                //$display("rs2_alu_in: %d", rs2_alu_in);
                end
            2'b01: begin 
                rs2_alu_in = id_ex_imm; 
                //$display("rs2_alu_in: %d", rs2_alu_in);
            end
            2'b10: begin
                rs2_alu_in = id_ex_pc + 4;
                //$display("rs2_alu_in: %d", rs2_alu_in);
            end
            default:;
        endcase

        /*case(imem_rdata[31:26])
            6'b100011: begin
                rdst <= rdata;
                //$display("rdst1: %d", rdst);
            end
            default: begin
                rdst <= rd;
                //$display("rdst2: %d", rdst);
            end
        endcase*/
        //$display("rs1_id: %d, rs2_id: %d, rdst_id: %d, imm: %d, we_dmem: %d, we_reg: %d, rdst: %d, ssel:%d", rs1_id, rs2_id, rdst_id, imm, we_dmem, we_regfile, rdst, ssel);
    end

    always @(posedge clk or posedge rst) begin
        //$display("fuck: %d", imem_rdata);
        if (rst) begin
            pc <= 0;
        end
        else if(hazard_stall)
            pc <= ex_mem_pc+4;
        else begin
            case(id_ex_jump_type)
                J_TYPE_NOP: begin
                    if(!hazard_stall)
                        pc <= pc + 4; // For no operation, increment PC by 4
                end
                J_TYPE_BEQ: begin
                    if (id_ex_reg_rs1 == id_ex_reg_rs2)
                        pc <= id_ex_pc+4+(id_ex_imm<<2); // Branch if rs1 == rs2
                    else
                        pc <= id_ex_pc + 4;
                end
                J_TYPE_JAL: begin
                    pc <= id_ex_pc+4; 
                    pc[27:0] <= id_ex_addr;
                end
                J_TYPE_J: begin
                    pc <= id_ex_pc+4;
                    pc[27:0] <= id_ex_addr;
                end
                J_TYPE_JR: begin
                    pc <= id_ex_reg_rs1;
                end
                default:;
            endcase
        end 
    end
    
endmodule
