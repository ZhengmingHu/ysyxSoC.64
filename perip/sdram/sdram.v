module sdram (
  input        clk,    
  input        cke,
  input        cs ,
  input        ras,
  input        cas,
  input        we ,
  input [13:0] a  ,
  input [ 1:0] ba ,
  input [ 3:0] dqm,
  inout [31:0] dq 
  
);

localparam CMD_ACTIVE        = 4'b0011;
localparam CMD_LOAD_MODE     = 4'b0000;
localparam BANK_0            = 2'd0;
localparam BANK_1            = 2'd1;
localparam BANK_2            = 2'd2;
localparam BANK_3            = 2'd3;

wire cs_rank_0;
wire cs_rank_1;

wire ck = cke ? clk : 1'b0;

reg [13:0] active_row_bank_0_q;
reg [13:0] active_row_bank_1_q;
reg [13:0] active_row_bank_2_q;
reg [13:0] active_row_bank_3_q;

wire[13:0] active_row_bank_0;
wire[13:0] active_row_bank_1;
wire[13:0] active_row_bank_2;
wire[13:0] active_row_bank_3;

wire [3:0] cmd = {cs, ras, cas, we};
wire       load_mode = cmd == CMD_LOAD_MODE;

always @ (posedge ck) begin
  if (cmd == CMD_ACTIVE)
    case (ba)
      BANK_0: active_row_bank_0_q <= a;
      BANK_1: active_row_bank_1_q <= a;
      BANK_2: active_row_bank_2_q <= a;
      BANK_3: active_row_bank_3_q <= a;
      default:  ;
    endcase 
end

assign active_row_bank_0 = cmd == CMD_ACTIVE ? a : active_row_bank_0_q;
assign active_row_bank_1 = cmd == CMD_ACTIVE ? a : active_row_bank_1_q;
assign active_row_bank_2 = cmd == CMD_ACTIVE ? a : active_row_bank_2_q;
assign active_row_bank_3 = cmd == CMD_ACTIVE ? a : active_row_bank_3_q;

assign cs_rank_0 =  load_mode ? 1'b1 :
                                ~active_row_bank_0[13] & ba == 2'd0 |
                                ~active_row_bank_1[13] & ba == 2'd1 |
                                ~active_row_bank_2[13] & ba == 2'd2 |
                                ~active_row_bank_3[13] & ba == 2'd3 ;

assign cs_rank_1 =  load_mode ? 1'b1 : 
                                active_row_bank_0[13] & ba == 2'd0 |
                                active_row_bank_1[13] & ba == 2'd1 |
                                active_row_bank_2[13] & ba == 2'd2 |
                                active_row_bank_3[13] & ba == 2'd3 ;
 

sdram_rank u_rank_0_0 (
  .clk       (      clk),  
  .cke       (      cke),
  .cs        (~cs_rank_0),
  .ras       (      ras),
  .cas       (      cas),
  .we        (       we),
  .a         (  a[12:0]),
  .ba        (       ba),
  .dqm       ( dqm[1:0]),
  .dq        ( dq[15:0])
); 
 
sdram_rank u_rank_0_1 (
  .clk       (      clk),  
  .cke       (      cke),
  .cs        (~cs_rank_0),
  .ras       (      ras),
  .cas       (      cas),
  .we        (       we),
  .a         (  a[12:0]),
  .ba        (       ba),
  .dqm       ( dqm[3:2]),
  .dq        (dq[31:16])
);

sdram_rank u_rank_1_0 (
  .clk       (      clk),  
  .cke       (      cke),
  .cs        (~cs_rank_1),
  .ras       (      ras),
  .cas       (      cas),
  .we        (       we),
  .a         (  a[12:0]),
  .ba        (       ba),
  .dqm       ( dqm[1:0]),
  .dq        ( dq[15:0])
);

sdram_rank u_rank_1_1 (
  .clk       (      clk),  
  .cke       (      cke),
  .cs        (~cs_rank_1),
  .ras       (      ras),
  .cas       (      cas),
  .we        (       we),
  .a         (  a[12:0]),
  .ba        (       ba),
  .dqm       ( dqm[3:2]),
  .dq        (dq[31:16])
);

endmodule

module sdram_rank(
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
localparam STATE_WRITE       = 3'd5;

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

reg [ 3:0] cmd_q;
reg [ 1:0] bank_q;
reg [12:0] active_row_bank_0_q;
reg [12:0] active_row_bank_1_q;
reg [12:0] active_row_bank_2_q;
reg [12:0] active_row_bank_3_q;

reg [12:0] col_q;

reg [ 3:0] bl_q;
reg [ 2:0] cas_q;

reg        dout_en_q;
reg [15:0] rdata0_q;
reg [15:0] rdata_q;

wire[ 3:0] len_r;
reg [ 3:0] len_q;
wire[ 2:0] delay_r;
reg [ 2:0] delay_q;

wire       cmd_access = (cmd == CMD_READ || cmd == CMD_WRITE);
wire       cmd_active = cmd == CMD_ACTIVE;
wire       cmd_read   = cmd == CMD_READ;

wire[ 1:0] bank = (cmd_access || cmd_active) ? ba : bank_q;
wire[ 8:0] col  = cmd_access ? a[8:0] : col_q[8:0];
wire[12:0] active_row_bank_0  = active_row_bank_0_q;
wire[12:0] active_row_bank_1  = active_row_bank_1_q;
wire[12:0] active_row_bank_2  = active_row_bank_2_q;
wire[12:0] active_row_bank_3  = active_row_bank_3_q;

wire       mode_reg_wen = cmd == CMD_LOAD_MODE;

wire           wen = bl_q == 1 ? cmd == CMD_WRITE : cmd == CMD_WRITE || state == STATE_WRITE;

wire       buf_ren = bl_q == 1 ? cmd == CMD_READ : cmd == CMD_READ  || state == STATE_READ_0;
wire       ram_ren = bl_q == 1 ? state == STATE_READ_0 : state == STATE_READ_1;
wire           ren = buf_ren || ram_ren;

//-----------------------------------------------------------------
//  Row Addr/Bank/Col Addr Reg
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (cmd == CMD_ACTIVE)
    case (ba)
      BANK_0: active_row_bank_0_q <= a;
      BANK_1: active_row_bank_1_q <= a;
      BANK_2: active_row_bank_2_q <= a;
      BANK_3: active_row_bank_3_q <= a;
      default:  ;
    endcase 
end

always @ (posedge ck) begin
  if (cmd == CMD_ACTIVE || cmd == CMD_READ || cmd == CMD_WRITE)
    bank_q <= ba;
end

always @ (posedge ck) begin
  if (cmd_access & bl_q > 1)
    col_q <= a + 1;
  else if (|len_r) 
    col_q <= col_q + 1;
end

//-----------------------------------------------------------------
//  Len/Delay Reg
//-----------------------------------------------------------------
assign len_r   = (  cmd_access) ? bl_q - 4'd1  :
                 (  len_q == 0) ? 4'd0         : 
                 (delay_r == 0) ? len_q - 4'd1 : len_q;
assign delay_r = (    cmd_read) ? cas_q - 3'd1 :                  
                 (delay_q == 0) ? 3'd0         : delay_q - 3'd1;

always @ (posedge ck) begin
  len_q <= len_r;
  delay_q <= delay_r;
end

//-----------------------------------------------------------------
//  State Machine
//-----------------------------------------------------------------
wire j_load_mode  =  cmd == CMD_LOAD_MODE;
wire j_active     =  cmd == CMD_ACTIVE; 
wire j_read_0     =  cmd == CMD_READ;
wire j_read_1     =  state == STATE_READ_0 & len_r == 0;
wire j_write      =  cmd == CMD_WRITE;
wire j_idle       =  (state == STATE_WRITE & len_r == 0) || (state == STATE_READ_1 & len_q == 0);

always @ (posedge ck) begin
  state <= j_load_mode ? STATE_LOAD_MODE :
           j_active    ? STATE_ACTIVE    :
           j_read_0    ? STATE_READ_0    :
           j_read_1    ? STATE_READ_1    :
           j_write     ? STATE_WRITE     :
           j_idle      ? STATE_IDLE      : state;
end

//-----------------------------------------------------------------
//  Mode Reg
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (mode_reg_wen) begin
    bl_q <= 1 << a[2:0]; 
    cas_q <= a[6:4];
  end
end

//-----------------------------------------------------------------
//  Write
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (wen & ~dqm[1]) begin
    case (bank)
      BANK_0: sdram_bank_0[active_row_bank_0][col][15:8] <= dq[15:8];
      BANK_1: sdram_bank_1[active_row_bank_1][col][15:8] <= dq[15:8];
      BANK_2: sdram_bank_2[active_row_bank_2][col][15:8] <= dq[15:8];
      BANK_3: sdram_bank_3[active_row_bank_3][col][15:8] <= dq[15:8];
      default:  ;
    endcase
  end
end

always @ (posedge ck) begin
  if (wen & ~dqm[0]) begin
    case (bank)
      BANK_0: sdram_bank_0[active_row_bank_0][col][ 7:0] <= dq[ 7:0];
      BANK_1: sdram_bank_1[active_row_bank_1][col][ 7:0] <= dq[ 7:0];
      BANK_2: sdram_bank_2[active_row_bank_2][col][ 7:0] <= dq[ 7:0];
      BANK_3: sdram_bank_3[active_row_bank_3][col][ 7:0] <= dq[ 7:0];
      default:  ;
    endcase
  end
end
 
//-----------------------------------------------------------------
//  read
//-----------------------------------------------------------------
always @ (posedge ck) begin
  if (buf_ren) begin
    case (bank)
      BANK_0: rdata0_q <= sdram_bank_0[active_row_bank_0][col];
      BANK_1: rdata0_q <= sdram_bank_1[active_row_bank_1][col];
      BANK_2: rdata0_q <= sdram_bank_2[active_row_bank_2][col];
      BANK_3: rdata0_q <= sdram_bank_3[active_row_bank_3][col];
      default: ;
    endcase
  end
end

// always @ * begin
//   if (cmd == CMD_ACTIVE && ba==2'b10 && row==2) begin
//     $display("sdram active:%x",sdram_bank_2[row][60]);
//     $display("");
//   end
// end

// reg [15:0] row_buf [511:0];
// reg [15:0] sdram_buf;

// always @ (posedge ck) begin
//   row_buf <= row_buffer_bank_2;
// end

// always @ (posedge ck) begin
//   sdram_buf <= sdram_bank_1[1][343];
// end

// always @ * begin
//   if (sdram_bank_1[1][343] != sdram_buf) begin
//     $display("write");
//     $display("near pc:%x", dbg_addr);
//     $display("sdram:%x", {sdram_bank_1[1][343], sdram_bank_1[1][342]});
//     $display($time);
//     $display("");
//   end
// end

// always @ * begin
//   if (row_buffer_bank_2[60]==16'h5608 && row_buf[60]!=16'h5608) begin
//     $display("shit write 5608");
//     $display("near pc:%x", dbg_addr);
//     $display("sdram:%x", sdram_bank_2[2][60]);
//     $display("");
//   end
// end


// always @ * begin
//   if ((col == 9'h156 || col == 9'h157) && ba==2'b01 && ren && bank==2'b01 && row==1) begin
//     $display("read:%x", dq);
//     $display("col:%x", col);
//     $display("sdram:%x",sdram_bank_2[row][col]);
//     $display("");
//   end
// end

// always @ * begin
//   if ((col == 9'h156 || col == 9'h157) && wen && bank==2'b01 && row==1) begin
//     $display("write:%x", dq);
//     $display("col:%x", col);
//     $display("sdram:%x",sdram_bank_1[1][col]);
//     $display("");
//   end
// end

always @ (posedge ck) begin
  if (ren)
    rdata_q <= rdata0_q;
end

always @ (posedge ck)
  dout_en_q <= ren;

assign dq = dout_en_q ? rdata_q : 16'dz;

endmodule