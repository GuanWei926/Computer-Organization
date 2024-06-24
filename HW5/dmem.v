module dmem (
    input           clk,
    input  [ 7 : 0] addr,  // byte address
    input           we,    // write-enable
    input  signed [31 : 0] wdata, // write data
    output signed [31 : 0] rdata  // read data
);

    reg signed [31 : 0] RAM [63 : 0];

    integer idx;

    initial begin
        for (idx = 0; idx < 64; idx = idx+1) RAM[idx] = 32'h0;
    end

    // Read operation
    assign rdata = RAM[addr[7:2]];

    // Write operation
    always @(posedge clk) begin
        if (we) begin 
            RAM[addr[7:2]] <= wdata;
            //$display("addr:%b", addr);
            //$display("%d: %d", addr, wdata);
        end
    end

endmodule