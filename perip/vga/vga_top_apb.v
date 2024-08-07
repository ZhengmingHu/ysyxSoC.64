module vga_top_apb(
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  output [7:0]  vga_r,
  output [7:0]  vga_g,
  output [7:0]  vga_b,
  output        vga_hsync,
  output        vga_vsync,
  output        vga_valid
);

wire vmem_wen = in_psel && in_penable && in_pwrite;
wire [23:0] vmem_waddr = {2'd0, in_paddr[23:2]};
wire [23:0] vmem_wdata = in_pwdata[23:0];
wire [23:0] vmem_rdata;
wire [ 9:0] ctrl_haddr;
wire [ 9:0] ctrl_vaddr;

reg         pready;

always @(posedge clock) begin
  if(reset)begin
    pready <= 'b0;
  end else if(in_psel & in_penable & in_pwrite & in_pready)begin
    pready <= 'b0;
  end else if(in_psel & in_penable & in_pwrite)begin
    pready <= 'b1;
  end
end

assign in_pready  = pready;

vmem u_vmem(
    .clk                                (clock                     ),
    .wen                                (vmem_wen                  ),
    .waddr                              (vmem_waddr                ),
    .wdata                              (vmem_wdata                ),
    .rhaddr                             (ctrl_haddr                ),
    .rvaddr                             (ctrl_vaddr                ),
    .rdata                              (vmem_rdata                ) 
);

vga_ctrl u_vga_ctrl(
    .pclk                               (clock                     ),
    .reset                              (reset                     ),
    .vga_data                           (vmem_rdata                ),
    .h_addr                             (ctrl_haddr                ),
    .v_addr                             (ctrl_vaddr                ),
    .hsync                              (vga_hsync                 ),
    .vsync                              (vga_vsync                 ),
    .valid                              (vga_valid                 ),
    .vga_r                              (vga_r                     ),
    .vga_g                              (vga_g                     ),
    .vga_b                              (vga_b                     ) 
);

assign in_pready = 1'b1;
assign in_pslverr = 1'b0;

endmodule
