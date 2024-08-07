module gpio_top_apb(
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

  output [15:0] gpio_out,
  input  [15:0] gpio_in,
  output [7:0]  gpio_seg_0,
  output [7:0]  gpio_seg_1,
  output [7:0]  gpio_seg_2,
  output [7:0]  gpio_seg_3,
  output [7:0]  gpio_seg_4,
  output [7:0]  gpio_seg_5,
  output [7:0]  gpio_seg_6,
  output [7:0]  gpio_seg_7
);

localparam LED    = 0,
           SW     = 4,
           SEG_LO = 8,
           SEG_HI = 12;

wire [3:0] gpio_addr = in_paddr[3:0];

reg [31:0] gpio_led_reg;
reg [31:0] gpio_sw_reg;
reg [31:0] gpio_seg_lo_reg;
reg [31:0] gpio_seg_hi_reg;
reg        pready;

//////////////////////////////////////////////////////////////////
//
// Functions
//

function automatic is_read();
  return in_psel & in_penable & ~in_pwrite;
endfunction : is_read

function automatic is_write();
  return in_psel & in_penable & in_pwrite;
endfunction : is_write

function automatic is_write_to_addr(input [3:0] addr);
  return is_write() & (gpio_addr == addr);
endfunction : is_write_to_addr

function automatic is_read_from_addr(input [3:0] addr);
  return is_read() & (gpio_addr == addr);
endfunction : is_read_from_addr

function automatic [31:0] get_write_data(input [31:0] orig_data);
  for (int n = 0; n < 32/8; n++)
    get_write_data[n*8 +: 8] = in_pstrb[n] ? in_pwdata[n*8 +: 8] : orig_data[n*8 +: 8];
endfunction

//////////////////////////////////////////////////////////////////
//
// Write
//

always @ (posedge clock)
  if (reset)
    gpio_led_reg <= 32'd0;
  else if (is_write_to_addr(LED))
    gpio_led_reg <= get_write_data(gpio_led_reg);

always @ (posedge clock)
  if (reset)
    gpio_seg_lo_reg <= 32'd0;
  else if (is_write_to_addr(SEG_LO))
    gpio_seg_lo_reg <= get_write_data(gpio_seg_lo_reg);

always @ (posedge clock)
  if (reset)
    gpio_seg_hi_reg <= 32'd0;
  else if (is_write_to_addr(SEG_HI))
    gpio_seg_hi_reg <= get_write_data(gpio_seg_hi_reg);

//////////////////////////////////////////////////////////////////
//
// Read
//

always @ (posedge clock)
  if (reset)
    gpio_sw_reg <= 32'd0;
  else if (is_read_from_addr(SW))
    gpio_sw_reg <= {16'd0, gpio_in};

//////////////////////////////////////////////////////////////////
//
// Reg
//

always @ (posedge clock) begin
  if (reset)
    pready <= 1'b0;
  else if (in_psel & in_penable & in_pready)
    pready <= 1'b0;
  else if (in_psel & in_penable)
    pready <= 1'b1;
end

//////////////////////////////////////////////////////////////////
//
// Output
//

assign in_pslverr = 1'b0;
assign in_pready = pready;

assign gpio_out   = gpio_led_reg[15:0];
assign in_prdata  = gpio_sw_reg;
assign gpio_seg_0 = gpio_seg_lo_reg[ 7: 0];
assign gpio_seg_1 = gpio_seg_lo_reg[15: 8];
assign gpio_seg_2 = gpio_seg_lo_reg[23:16];
assign gpio_seg_3 = gpio_seg_lo_reg[31:24];
assign gpio_seg_4 = gpio_seg_hi_reg[ 7: 0];
assign gpio_seg_5 = gpio_seg_hi_reg[15: 8];
assign gpio_seg_6 = gpio_seg_hi_reg[23:16];
assign gpio_seg_7 = gpio_seg_hi_reg[31:24];

endmodule
