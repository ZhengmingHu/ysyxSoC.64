module sdram(
  input        clk,
  input        cke,
  input        cs,
  input        ras,
  input        cas,
  input        we,
  input [12:0] a,
  input [ 1:0] ba,
  input [ 1:0] dqm,
  inout [15:0] dq
);

localparam CMD_W             = 4;
localparam CMD_NOP           = 4'b0111;
localparam CMD_ACTIVE        = 4'b0011;
localparam CMD_READ          = 4'b0101;
localparam CMD_WRITE         = 4'b0100;
localparam CMD_TERMINATE     = 4'b0110;
localparam CMD_PRECHARGE     = 4'b0010;
localparam CMD_REFRESH       = 4'b0001;
localparam CMD_LOAD_MODE     = 4'b0000;

localparam STATE_IDLE        = 3'd0;
localparam STATE_LOAD_MODE   = 3'd1;
localparam STATE_ACTIVE      = 3'd2;
localparam STATE_READ_0      = 3'd3;
localparam STATE_READ_1      = 3'd4;
localparam STATE_WRITE_BUF   = 3'd5;
localparam STATE_WRITE_RAM   = 3'd6;

localparam BANK_0            = 2'd0;
localparam BANK_1            = 2'd1;
localparam BANK_2            = 2'd2;
localparam BANK_3            = 2'd3;

wire ck = cke ? clk : 1'b0;
wire [3:0] cmd = {cs, ras, cas, we};

reg [ 2:0] state;

reg [15:0] sdram_bank_0 [8191:0][511:0];
reg [15:0] sdram_bank_1 [8191:0][511:0];
reg [15:0] sdram_bank_2 [8191:0][511:0];
reg [15:0] sdram_bank_3 [8191:0][511:0];

reg [15:0] row_buffer           [511:0];

reg [ 3:0] cmd_q;
reg [ 1:0] bank_q;
reg [12:0] row_q;
reg [12:0] col_q;

reg [12:0] mode_q;

reg [15:0] rdata0_q;
reg [15:0] rdata_q;

wire[ 1:0] delay_r;
reg [ 1:0] delay_q;

wire       cmd_access = (cmd == CMD_READ || cmd == CMD_WRITE);

wire[ 1:0] bank = bank_q;
wire[12:0] row  = row_q;
wire[ 8:0] col  = cmd_access ? a[8:0] : col_q[8:0];

wire       buf_wen = cmd == CMD_WRITE || state == STATE_WRITE_BUF;
wire       ram_wen = state == STATE_WRITE_RAM;
wire           wen = buf_wen || ram_wen;

wire       buf_ren = cmd == CMD_READ  || state == STATE_READ_0;
wire       ram_ren = state == STATE_READ_1;
wire           ren = buf_ren || ram_ren;

//-----------------------------------------------------------------
//  Row Buffer Reg
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (cmd == CMD_ACTIVE) begin
    case (ba)
      BANK_0: row_buffer <= sdram_bank_0[a][511:0];
      BANK_1: row_buffer <= sdram_bank_1[a][511:0];
      BANK_2: row_buffer <= sdram_bank_2[a][511:0];
      BANK_3: row_buffer <= sdram_bank_3[a][511:0];
      default:  ;

    endcase
  end
end

//-----------------------------------------------------------------
//  Row Addr/Bank/Col Addr Reg
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (cmd == CMD_ACTIVE) 
    row_q <= a;
end

always @ (posedge ck) begin
  if (cmd == CMD_ACTIVE)
    bank_q <= ba;
end

always @ (posedge ck) begin
  if (cmd_access)
    col_q <= a + 1;
  else if (|delay_r) 
    col_q <= col_q + 1;
end

//-----------------------------------------------------------------
//  Delay Reg
//-----------------------------------------------------------------
assign delay_r = (  cmd_access) ? 2'd1 :                  // FIX ME: fit mode reg
                 (delay_q == 0) ? 2'd0 : delay_q - 2'd1;
always @ (posedge ck) begin
  delay_q <= delay_r;
end

//-----------------------------------------------------------------
//  State Machine
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (cmd == CMD_ACTIVE)
    state <= STATE_ACTIVE;
  else if (cmd == CMD_READ)
    state <= STATE_READ_0;
  else if (state == STATE_READ_0 & delay_r == 0)
    state <= STATE_READ_1;
  else if (cmd == CMD_WRITE)
    state <= STATE_WRITE_BUF;
  else if (state == STATE_WRITE_BUF & delay_r == 0)
    state <= STATE_WRITE_RAM;
  else if ((state == STATE_WRITE_RAM & delay_q == 0) || (state == STATE_READ_1 & delay_q == 0))
    state <= STATE_IDLE;
end

//-----------------------------------------------------------------
//  Write
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (buf_wen & ~dqm[1])
    row_buffer[col][15:8] <= dq[15:8];
  if (buf_wen & ~dqm[0])
    row_buffer[col][ 7:0] <= dq[ 7:0];
end

always @ (posedge ck) begin
  if (ram_wen) begin
    case (bank_q)
      BANK_0: sdram_bank_0[row][511:0] <= row_buffer[511:0];
      BANK_1: sdram_bank_1[row][511:0] <= row_buffer[511:0];
      BANK_2: sdram_bank_2[row][511:0] <= row_buffer[511:0];
      BANK_3: sdram_bank_3[row][511:0] <= row_buffer[511:0];
      default:  ;
    endcase
  end
end
 
//-----------------------------------------------------------------
//  read
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (buf_ren) 
    rdata0_q <= row_buffer[col];
end

always @ (posedge ck) begin
  if (ren)
    rdata_q <= rdata0_q;
end

assign dq = wen ? 16'dz : rdata_q;

endmodule
