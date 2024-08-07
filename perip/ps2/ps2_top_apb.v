module ps2_top_apb(
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

  input         ps2_clk,
  input         ps2_data
);

wire ren = in_psel & in_penable & ~in_pwrite;

wire not_empty;
wire [7:0] data;

reg        pready;

always @(posedge clock) begin
  if(reset)begin
    pready <= 'b0;
  end else if(in_psel & in_penable & in_pready)begin
    pready <= 'b0;
  end else if(in_psel & in_penable)begin
    pready <= 'b1;
  end
end

ps2_keyboard u_keybrd(
  .clk       (clock),
  .clrn      (!reset),
  .ps2_clk   (ps2_clk),
  .ps2_data  (ps2_data),
  .nextdata_n(!ren),
  .data      (data),
  .ready     (not_empty)
);

assign in_pslverr = 1'b0;
assign in_prdata = not_empty ? {24'd0, data} : 32'd0;
assign in_pready = pready;

endmodule
