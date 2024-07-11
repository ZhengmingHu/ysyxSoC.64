module apb_delayer(
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

  output [31:0] out_paddr,
  output        out_psel,
  output        out_penable,
  output [2:0]  out_pprot,
  output        out_pwrite,
  output [31:0] out_pwdata,
  output [3:0]  out_pstrb,
  input         out_pready,
  input  [31:0] out_prdata,
  input         out_pslverr
);

// ------------------------------------------------------------
// -- Calibrating memory access latency (c = r * s * k)
// ------------------------------------------------------------
// yosys-sta core timing report: 507.418MHz
//    with device clk frequency: 100MHz
// 
// got r = core_clk_freq / device_clk_freq = 5,
// and let's assume s = 2
// ------------------------------------------------------------

localparam r = 5; 
localparam s = 2;
localparam inc = r * s;

localparam S_IDLE = 2'd0, S_TRANS = 2'd1, S_WAIT = 2'd2;

reg [1:0]  state;
reg        pready_r;
reg [31:0] prdata_r;
reg        pslverr_r;

always @ (posedge clock) begin
  if (reset)
    state <= S_IDLE;
  else begin
    case (state)
      S_IDLE  : state <= in_psel             ? S_TRANS : S_IDLE;
      S_TRANS : state <= out_pready          ? S_WAIT  : S_TRANS;
      S_WAIT  : state <= quant_counters == 0 ? (in_psel ? S_TRANS : S_IDLE) : S_WAIT;
      default : ; 
    endcase
  end
end

wire transfer = state == S_TRANS;
wire transfer2waiting = out_pready & transfer;
wire waiting = state == S_WAIT;

reg  [31:0] quant_counters;

always @ (posedge clock) begin
  if (reset)
    quant_counters <= 32'd0;
  else if (transfer2waiting) 
    quant_counters <= (quant_counters + inc) >> $clog2(s);
  else if (transfer)
    quant_counters <= quant_counters + inc;
  else if (quant_counters == 32'd0)
    quant_counters <= 32'd0;
  else if (waiting)
    quant_counters <= quant_counters - 1'b1;
end


always @ (posedge clock) begin
  if (reset) begin
    pready_r <= 1'd0;
    prdata_r <= 32'd0;
    pslverr_r <= 1'd0;
  end else if (out_pready && transfer) begin
    pready_r <= out_pready;
    prdata_r <= out_prdata;
    pslverr_r <= out_pslverr;
  end else if (transfer) begin
    pready_r <= 1'd0;
    prdata_r <= 32'd0;
    pslverr_r <= 1'd0;
  end
end

assign out_paddr   = waiting ? 32'd0 : in_paddr;
assign out_psel    = waiting ? 1'b0 : in_psel;
assign out_penable = waiting ? 1'b0 : in_penable;
assign out_pprot   = in_pprot;
assign out_pwrite  = waiting ? 1'b0 : in_pwrite;
assign out_pwdata  = waiting ? 32'b0 : in_pwdata;
assign out_pstrb   = waiting ? 4'b0 : in_pstrb;
assign in_pready   = (quant_counters == 0 && waiting) ? pready_r  : 1'd0;
assign in_prdata   = (quant_counters == 0 && waiting) ? prdata_r  : 32'd0;
assign in_pslverr  = (quant_counters == 0 && waiting) ? pslverr_r : 1'd0;

endmodule
