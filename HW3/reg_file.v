module reg_file #(parameter DWIDTH = 32)
(
    input                 clk,      // system clock
    input                 rst,      // system reset

    input  [4 : 0]        rs1_id,   // register ID of data #1
    input  [4 : 0]        rs2_id,   // register ID of data #2 (if any)

    input                 we,       // if (we) R[rdst_id] <= rdst
    input  [4 : 0]        rdst_id,  // destination register ID
    input  signed [DWIDTH-1 : 0] rdst,     // input to destination register

    output reg signed [DWIDTH-1 : 0] rs1,      // register operand #1
    output reg signed [DWIDTH-1 : 0] rs2       // register operand #2 (if any)
);

reg signed[DWIDTH-1:0] R[0:31];

assign rs1 = (rs1_id == 5'b00000) ? 32'h0 : R[rs1_id]; // If rs1_id is 0, assign 0 to rs1
assign rs2 = (rs2_id == 5'b00000) ? 32'h0 : R[rs2_id]; // If rs2_id is 0, assign 0 to rs2

// Sequential logic for register updates
always @(posedge clk) begin
    // reset register
    if(rst)begin
        for (int i = 0; i < 32; i = i + 1) begin
            R[i] <= 32'h0; // Initialize all registers to zero
        end
    end
    // Write to register if we is enabled
    else if(we) begin
        R[rdst_id] <= rdst; // Write data to destination register
        //$display("%d: %d", rdst_id, rdst);
    end
end

endmodule
