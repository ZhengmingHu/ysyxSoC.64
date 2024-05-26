// define this macro to enable fast behavior simulation
// for flash by skipping SPI transfers
//`define FAST_FLASH

module spi_top_apb #(
  parameter flash_addr_start = 32'h30000000,
  parameter flash_addr_end   = 32'h3fffffff,
  parameter spi_ss_num       = 8
) (
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

  output                  spi_sck,
  output [spi_ss_num-1:0] spi_ss,
  output                  spi_mosi,
  input                   spi_miso,
  output                  spi_irq_out
);

`ifdef FAST_FLASH

wire [31:0] data;
parameter invalid_cmd = 8'h0;
flash_cmd flash_cmd_i(
  .clock(clock),
  .valid(in_psel && !in_penable),
  .cmd(in_pwrite ? invalid_cmd : 8'h03),
  .addr({8'b0, in_paddr[23:2], 2'b0}),
  .data(data)
);
assign spi_sck    = 1'b0;
assign spi_ss     = 8'b0;
assign spi_mosi   = 1'b1;
assign spi_irq_out= 1'b0;
assign in_pslverr = 1'b0;
assign in_pready  = in_penable && in_psel && !in_pwrite;
assign in_prdata  = data[31:0];

`else


// xip output to spi master ////////////////////////////
wire  [ 31: 0] xip_paddr;
wire           xip_psel;
wire           xip_penable;
wire           xip_pwrite;
wire  [ 31: 0] xip_pwdata;
wire  [  3: 0] xip_pstrb;

// xip input from spi master //////////////////////////
wire           xip_pready;
wire  [ 31: 0] xip_prdata;
wire           xip_pslverr;

spi_xip u0_spi_xip (
    .clock                              (clock                     ),
    .reset                              (reset                     ),
  
    .in_paddr                           (in_paddr                  ),
    .in_psel                            (in_psel                   ),
    .in_penable                         (in_penable                ),
    .in_pwrite                          (in_pwrite                 ),
    .in_pwdata                          (in_pwdata                 ),
    .in_pstrb                           (in_pstrb                  ),
  
    .in_pready                          (xip_pready                ),
    .in_prdata                          (xip_prdata                ),
    .in_pslverr                         (xip_pslverr               ),
  
    .out_paddr                          (xip_paddr                 ),
    .out_psel                           (xip_psel                  ),
    .out_penable                        (xip_penable               ),
    .out_pwrite                         (xip_pwrite                ),
    .out_pwdata                         (xip_pwdata                ),
    .out_pstrb                          (xip_pstrb                 ),
  
    .out_pready                         (in_pready                 ),
    .out_prdata                         (in_prdata                 ),
    .out_pslverr                        (in_pslverr                ) 
);

spi_top u0_spi_top (
  .wb_clk_i(clock),
  .wb_rst_i(reset),
  .wb_adr_i(xip_paddr[4:0]),
  .wb_dat_i(xip_pwdata),
  .wb_dat_o(xip_prdata),
  .wb_sel_i(xip_pstrb),
  .wb_we_i (xip_pwrite),
  .wb_stb_i(xip_psel),
  .wb_cyc_i(xip_penable),
  .wb_ack_o(xip_pready),
  .wb_err_o(xip_pslverr),
  .wb_int_o(spi_irq_out),

  .ss_pad_o(spi_ss),
  .sclk_pad_o(spi_sck),
  .mosi_pad_o(spi_mosi),
  .miso_pad_i(spi_miso)
);

`endif // FAST_FLASH

endmodule
