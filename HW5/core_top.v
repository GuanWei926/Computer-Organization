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

    // BHT entry definition
    typedef struct packed{
        reg valid;
        reg [1:0] taken;
        reg [DWIDTH-1:0] target_pc;
        reg [DWIDTH-1:0] branch_pc;
    } bht_entry_t;

    // BHT memory
    bht_entry_t bht_mem [63:0];

    integer idx;
    initial begin
        for (idx = 0; idx < 64; idx = idx+1) begin
            bht_mem[idx].valid = 1'b0;
            bht_mem[idx].taken = 2'b01;
            bht_mem[idx].target_pc = 32'b0;
        end
    end

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
    reg signed[DWIDTH-1 : 0] rs2_alu_in;
    reg signed[DWIDTH-1 : 0] rs1_alu_in;
    wire              zero;
    wire              overflow;
    // dmem
    reg signed [DWIDTH-1:0] rdst;
    wire signed[DWIDTH-1:0] rdata;
    
    
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
    reg [0:0] ex_mem_zero;
    reg [2:0] ex_mem_jump_type;
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
        .rs1(rs1_alu_in),
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
    wire special_hazard;
    reg[0:0] beq_flush;
    wire lw_use_stall;
    wire sw_use_stall;

    // Simple hazard control logic for data hazards (stall)
    assign hazard_stall = ((ex_mem_rdst_id != 0 && (ex_mem_rdst_id == id_ex_rs1_id || ex_mem_rdst_id == id_ex_rs2_id || ex_mem_rdst_id == id_ex_rdst_id)) 
    || (mem_wb_rdst_id != 0 && (mem_wb_rdst_id == id_ex_rs1_id || mem_wb_rdst_id == id_ex_rs2_id || mem_wb_rdst_id == id_ex_rdst_id)));


    assign special_hazard = (mem_wb_rdst_id != 0 && (mem_wb_rdst_id == if_id_instr[25:21] || mem_wb_rdst_id == if_id_instr[20:16]));
    
    reg [5:0] id_ex_idx = (id_ex_pc/4) % 64;
    /*assign beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((id_ex_reg_rs1 == id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
    ||(id_ex_reg_rs1 != id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));*/
    
    // Branch hazard detection (flush)
    assign hazard_flush = (id_ex_jump_type != J_TYPE_NOP && id_ex_jump_type != J_TYPE_BEQ);  // Added hazard flush logic

    // Load-use hazard detection
    assign lw_use_stall = (id_ex_op_code == 6'b100011) && 
                          ((id_ex_rdst_id == rs1_id) || (id_ex_rdst_id == rs2_id));

    // Store-use hazard detection
    assign sw_use_stall = (if_id_instr[31:26]==6'b101011) && 
                          (id_ex_rdst_id == rs2_id);


    // Forwarding Unit
    reg [1:0] forwardA, forwardB;

    always @(*) begin
        // Forwarding for rs1
        if (ex_mem_we_regfile && (ex_mem_rdst_id != 0) && (ex_mem_rdst_id == id_ex_rs1_id))
            forwardA = 2'b10;
        else if (mem_wb_we_regfile && (mem_wb_rdst_id != 0) && (mem_wb_rdst_id == id_ex_rs1_id))
            forwardA = 2'b01;
        /*else if (mem_wb_we_regfile && (mem_wb_rdst_id != 0) && (mem_wb_rdst_id == id_ex_rdst_id)) begin
            forwardA = 2'b11;
        end*/
        else
            forwardA = 2'b00;

        // Forwarding for rs2
        if (ex_mem_we_regfile && (ex_mem_rdst_id != 0) && (ex_mem_rdst_id == id_ex_rs2_id))
            forwardB = 2'b10;
        else if (mem_wb_we_regfile && (mem_wb_rdst_id != 0) && (mem_wb_rdst_id == id_ex_rs2_id))
            forwardB = 2'b01;
        else
            forwardB = 2'b00;
    end

    // IF/ID pipeline register update
    always @(posedge clk or posedge rst) begin
        if (rst || lw_use_stall || sw_use_stall || hazard_flush || beq_flush) begin
            if_id_instr <= 0;
            if_id_pc <= 0;
        end else if(special_hazard)begin
            if_id_instr <= if_id_instr;
            if_id_pc <= if_id_pc;
        end else if(!lw_use_stall && !sw_use_stall) begin   
            if_id_instr <= imem_rdata;
            if_id_pc <= pc;
        end
        //$display("pc:", pc);
        //$display("if_id_pc:", if_id_pc);
        // $display("rdata:", imem_rdata);
        //$display("if_id_instr:", if_id_instr);
        // $display("lw_use_stall:", lw_use_stall);
    end

    // ID/EX pipeline register update
    always @(posedge clk or posedge rst) begin
        if (rst || hazard_flush || beq_flush) begin
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
        end else if (!lw_use_stall && !sw_use_stall) begin
            id_ex_addr <= jump_addr;
            id_ex_pc <= if_id_pc;
            id_ex_imm <= imm;
            id_ex_op <= op;
            id_ex_rs1_id <= rs1_id;
            id_ex_rs2_id <= rs2_id;
            id_ex_rdst_id <= rdst_id;
            id_ex_reg_rs1 <= rs1;
            if (if_id_instr[31:26]==6'b101011) begin
                if((ex_mem_rdst_id != 0 && ex_mem_rdst_id == rs2_id ))
                    id_ex_reg_rs2 <= ex_mem_rd;
                else if((ex_mem_rdst_id != 0 && mem_wb_rdst_id == rs2_id ))
                    id_ex_reg_rs2 <= mem_wb_rdata_or_rd;
                else
                    id_ex_reg_rs2 <= rs2_reg_file_out;
            end
            else
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
        // $display("id_ex_rs2_id:", id_ex_rs2_id);
        //$display("rs2_id", rs2_id);
        //$display("id_ex_reg_rs1:", id_ex_reg_rs1);
        //$display("hazard_stall: ", hazard_stall);
        //$display("we_dmem: ", we_dmem);
        //$display("id_ex_we_dmem: ", id_ex_we_dmem);
        //$display("id_ex_jump_type: ", id_ex_jump_type);
        //$display("id_ex_reg_rs2:", id_ex_reg_rs2);
        //$display("bht_mem[id_ex_idx]:", bht_mem[id_ex_idx].taken);
    end

    // EX/MEM pipeline register update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_mem_pc <= 0;
            ex_mem_rdst_id <= 0;
            ex_mem_we_regfile <= 0;
            ex_mem_we_dmem <= 0;
            ex_mem_rd <= 0;
            ex_mem_op_code <= 0;
            ex_mem_rs2 <= 0;
            ex_mem_jump_type <= 0;
            ex_mem_zero <= 0;
        end else begin
            ex_mem_pc <= id_ex_pc;
            ex_mem_rdst_id <= id_ex_rdst_id;
            ex_mem_we_regfile <= id_ex_we_regfile;
            ex_mem_we_dmem <= id_ex_we_dmem;
            ex_mem_rd <= rd;
            ex_mem_op_code <= id_ex_op_code;
            ex_mem_rs2 <= id_ex_reg_rs2;
            ex_mem_jump_type <= id_ex_jump_type;
            ex_mem_zero <= zero;
        end
        //$display("ex_mem_pc:", ex_mem_pc);
        //$display("ex_mem_jump_type:", ex_mem_jump_type);
        //$display("ex_mem_rdst_id:", ex_mem_rdst_id);
        //$display("ex_mem_rs2:", ex_mem_rs2);
        //$display("ex_mem_rd:", ex_mem_rd);
        //$display("ex_mem_zero:", ex_mem_zero);
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
        // $display("rdst: %d", mem_wb_rdata_or_rd);
    end

    always @(posedge clk)begin
        if(forwardA == 2'b00)begin
            if(forwardB == 2'b00)begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((id_ex_reg_rs1 == id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                 ||(id_ex_reg_rs1 != id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end else if(forwardB == 2'b01) begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((id_ex_reg_rs1 == ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                ||(id_ex_reg_rs1 != ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end else if(forwardB == 2'b10)begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((id_ex_reg_rs1 == mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                ||(id_ex_reg_rs1 != mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end
        end
        else if(forwardA == 2'b01)begin
            if(forwardB == 2'b00)begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((ex_mem_rd == id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                 ||(ex_mem_rd != id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end else if(forwardB == 2'b01) begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((ex_mem_rd == ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                ||(ex_mem_rd != ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end else if(forwardB == 2'b10)begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((ex_mem_rd == mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                ||(ex_mem_rd != mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end
        end
        else if(forwardA == 2'b01)begin
            if(forwardB == 2'b00)begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((mem_wb_rdata_or_rd == id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                 ||(mem_wb_rdata_or_rd != id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end else if(forwardB == 2'b01) begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((mem_wb_rdata_or_rd == ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                ||(mem_wb_rdata_or_rd != ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end else if(forwardB == 2'b10)begin
                beq_flush = (id_ex_jump_type == J_TYPE_BEQ) && ((mem_wb_rdata_or_rd == mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))
                ||(mem_wb_rdata_or_rd != mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10)));
            end
        end
    end

    always @(*)begin
        case(id_ex_ssel)
            2'b00: begin 
                rs2_alu_in = (forwardB == 2'b00) ? id_ex_reg_rs2 : 
                             (forwardB == 2'b10) ? ex_mem_rd : 
                             (forwardB == 2'b01) ? mem_wb_rdata_or_rd : id_ex_reg_rs2; 
                //$display("forwardB: %d", forwardB);
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
        //$display("rs2_alu_in: ", rs2_alu_in);
    end

    always @(*) begin
        rs1_alu_in = (forwardA == 2'b00) ? id_ex_reg_rs1 : 
                     (forwardA == 2'b10) ? ex_mem_rd : 
                     (forwardA == 2'b11) ? ex_mem_rd : 
                     (forwardA == 2'b01) ? mem_wb_rdata_or_rd : id_ex_reg_rs1;
        //$display("rs1_alu_in: ", rs1_alu_in);
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 0;
        end
        else if(lw_use_stall) begin
            //$display("=====================================================123");
            pc <= id_ex_pc+4;
        end
        else if(sw_use_stall)begin
            pc <= id_ex_pc+4;
        end
        else if(special_hazard)
            pc <= if_id_pc+4;
        else begin
            case(id_ex_jump_type)
                J_TYPE_NOP: begin
                    /*if(!lw_use_stall && !sw_use_stall)
                        pc <= pc + 4;*/

                    reg [5:0] idx = (pc/4) % 64;
                    if(bht_mem[idx].valid == 1'b0) begin
                        pc <= pc+4;
                    end
                    else begin
                        if(bht_mem[idx].taken == 2'b11 || bht_mem[idx].taken == 2'b10) begin
                            pc <= bht_mem[idx].target_pc;
                        end
                        else begin
                            pc <= pc+4;
                        end
                    end 
                end
                J_TYPE_BEQ: begin
                    reg [DWIDTH-1:0] a;
                    reg [DWIDTH-1:0] b;
                    if (bht_mem[id_ex_idx].valid == 1'b0) begin
                        bht_mem[id_ex_idx].valid = 1'b1;
                        bht_mem[id_ex_idx].taken = 2'b01;
                        bht_mem[id_ex_idx].branch_pc = id_ex_pc;
                        bht_mem[id_ex_idx].target_pc = id_ex_pc+4+(id_ex_imm<<2);
                    end

                    if(forwardA == 2'b00)begin
                        if(forwardB == 2'b00)begin
                            if (id_ex_reg_rs1 == id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (id_ex_reg_rs1 != id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end else if(forwardB == 2'b01) begin
                            if (id_ex_reg_rs1 == ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (id_ex_reg_rs1 != ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end else if(forwardB == 2'b10)begin
                            if (id_ex_reg_rs1 == mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (id_ex_reg_rs1 != mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end
                    end
                    else if(forwardA == 2'b01)begin
                        if(forwardB == 2'b00)begin
                           if (ex_mem_rd == id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (ex_mem_rd != id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end else if(forwardB == 2'b01) begin
                            if (ex_mem_rd == ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (ex_mem_rd != ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end else if(forwardB == 2'b10)begin
                            if (ex_mem_rd == mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (ex_mem_rd != mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end
                    end
                    else if(forwardA == 2'b01)begin
                        if(forwardB == 2'b00)begin
                            if (mem_wb_rdata_or_rd == id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (mem_wb_rdata_or_rd != id_ex_reg_rs2 && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end else if(forwardB == 2'b01) begin
                            if (mem_wb_rdata_or_rd == ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (mem_wb_rdata_or_rd != ex_mem_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end else if(forwardB == 2'b10)begin
                            if (mem_wb_rdata_or_rd == mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                                pc <= id_ex_pc+4+(id_ex_imm<<2);
                            end
                            else if (mem_wb_rdata_or_rd != mem_wb_rdata_or_rd && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                                pc <= id_ex_pc+4;
                                //$display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
                            end
                        end
                    end

                    /*if (a == b && (bht_mem[id_ex_idx].taken==2'b01 || bht_mem[id_ex_idx].taken==2'b00))begin
                        //$display("=====================================================");
                        pc <= id_ex_pc+4+(id_ex_imm<<2);
                        //bht_mem[id_ex_idx].taken <= (bht_mem[id_ex_idx].taken==2'b00)?2'b01:2'b10;
                    end
                    else if (a != b && (bht_mem[id_ex_idx].taken==2'b11 || bht_mem[id_ex_idx].taken==2'b10))begin
                        pc <= id_ex_pc+4;
                        $display("ヾ(＠⌒ー⌒＠)ノヾ(＠⌒ー⌒＠)ノヾ(＠⌒ー⌒＠)ノヾ(＠⌒ー⌒＠)ノヾ(＠⌒ー⌒＠)ノヾ(＠⌒ー⌒＠)ノ");
                        //bht_mem[id_ex_idx].taken <= (bht_mem[id_ex_idx].taken==2'b11)?2'b10:2'b01;
                    end*/    
                    else begin                
                        reg [5:0] idx = (pc/4) % 64;
                        if(bht_mem[idx].valid == 1'b0)
                            pc <= pc+4;
                        else begin
                            if(bht_mem[idx].taken == 2'b11 || bht_mem[idx].taken == 2'b10) begin
                                pc <= bht_mem[idx].target_pc;
                            end
                            else begin
                                pc <= pc+4;
                            end
                        end 
                    end
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

    always @(posedge clk)begin
        reg [5:0]ex_mem_idx = (ex_mem_pc/4)%64;
        if(ex_mem_jump_type == J_TYPE_BEQ) begin
            if(ex_mem_zero && (bht_mem[ex_mem_idx].taken==2'b00 || bht_mem[ex_mem_idx].taken==2'b01))begin
                bht_mem[ex_mem_idx].taken = (bht_mem[ex_mem_idx].taken==2'b00)?2'b01 : 2'b10;
            end
            else if(!ex_mem_zero && (bht_mem[ex_mem_idx].taken==2'b11 || bht_mem[ex_mem_idx].taken==2'b10))
                bht_mem[ex_mem_idx].taken = (bht_mem[ex_mem_idx].taken==2'b11)?2'b10 : 2'b01;
        end
        //$display("bht_mem[ex_mem_idx]:", bht_mem[ex_mem_idx].taken);
    end


endmodule
