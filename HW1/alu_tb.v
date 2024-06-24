module alu_tb (
    input clk,
    output reg finish
);
    
    localparam DWIDTH = 32;

    reg [3:0] op;
    reg [DWIDTH-1:0] rs1;
    reg [DWIDTH-1:0] rs2;

    reg [DWIDTH-1 : 0] rd, ans_rd;
    reg zero, ans_zero;
    reg overflow, ans_overflow;

    integer i = 0;
    integer pattern, temp;

    alu alu(
        .op(op),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .zero(zero),
        .overflow(overflow)
    );

    initial begin
        $display("[HW1 Testbench]");
        $display("---------------");
        pattern = $fopen("input.txt", "r");
        finish = 0;
    end

    always @(posedge clk) begin
        if ($feof(pattern)) begin
            finish = 1;
        end else begin
            temp = $fscanf(pattern, "%d\n", op);
            temp = $fscanf(pattern, "%d\n", rs1);
            temp = $fscanf(pattern, "%d\n", rs2);
            temp = $fscanf(pattern, "%d\n", ans_rd);
            temp = $fscanf(pattern, "%d\n", ans_zero);
            temp = $fscanf(pattern, "%d\n", ans_overflow);
        end
    end 

    always @(negedge clk) begin
        if ((ans_rd !== rd) || (ans_zero !== zero) || (ans_overflow !== overflow)) begin
            $display("Fail Pattern %d", i);
            $finish(); $finish();
        end else begin
            $display("Pass Pattern %d", i);
        end
        i = i + 1;
    end
    
endmodule
