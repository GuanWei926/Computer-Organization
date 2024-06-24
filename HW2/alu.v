module alu #(parameter DWIDTH = 32)
(
  input  [3:0]        op,    // Operation to perform.
  input  signed [DWIDTH-1:0] rs1,   // Input data #1.
  input  signed [DWIDTH-1:0] rs2,   // Input data #2.
  output reg signed [DWIDTH-1:0] rd, // Result of computation.
  output reg zero,            // zero = 1 if rd is 0, 0 otherwise.
  output reg overflow         // overflow = 1 if overflow happens.
);

always @(*) begin 
    case(op)
        4'b0000 : begin
                    rd = rs1 & rs2;   // and
                    zero = (rd==0) ? 1'b1 : 1'b0;
                end
        4'b0001 : begin
                    rd = rs1 | rs2;   // or
                    zero = (rd==0) ? 1'b1 : 1'b0;
                end 
        4'b0010 : begin
                    rd = rs1 + rs2;   // add
                    zero = (rd==0) ? 1'b1 : 1'b0;
                end
        4'b0110 : begin 
                    rd = rs1 - rs2;   // subtract
                    zero = (rd==0) ? 1'b1 : 1'b0;
                end
        4'b1100 : begin 
                    rd = ~(rs1 | rs2);    // nor
                    zero = (rd==0) ? 1'b1 : 1'b0;
                end
        4'b0111 : begin 
                    rd = (rs1 < rs2) ? 32'h1 : 32'h0;  // slt(set less than)
                    zero = (rd==0) ? 1'b1 : 1'b0;
                end
        default : begin 
                    rd = 32'0;
                    zero = 0;
                    overflow = 0;
                end        
    endcase
    
    if(op==4'b0010 && rs1[DWIDTH-1] == rs2[DWIDTH-1] && rd[DWIDTH-1] != rs1[DWIDTH-1])
        overflow = 1;
    else if(op==4'b0110 && rs1[DWIDTH-1] != rs2[DWIDTH-1] && rd[DWIDTH-1] != rs1[DWIDTH-1])
        overflow = 1;
    else
        overflow = 0;
end

endmodule
