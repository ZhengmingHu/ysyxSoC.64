module vmem (
    input         clk,
    input         wen,
    input  [23:0] waddr,
    input  [23:0] wdata,
    input  [ 9:0] rhaddr,
    input  [ 9:0] rvaddr,
    output [23:0] rdata
);

reg  [23:0] vga_mem [524287:0];

wire [18:0] raddr = {9'd0, rhaddr} + {rvaddr, 9'd0} + {2'd0, rvaddr, 7'd0};
wire [23:0] vga_data;

always @ (posedge clk) begin
    if (wen)
        vga_mem[waddr[18:0]] <= wdata; 
end

assign vga_data = vga_mem[raddr];
assign rdata = (wen & (waddr[18:0] == raddr)) ? wdata : vga_data;

endmodule