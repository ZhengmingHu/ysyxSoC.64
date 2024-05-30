module psram(
  input sck,
  input ce_n,
  inout [3:0] dio
);

  wire       reset  = ce_n;
  wire [3:0] dout_en;

  
  localparam S_CMD=3'b000, S_ADDR=3'b001, S_WAIT=3'b010, S_R_DATA=3'b011, S_W_DATA=3'b100, S_ERR=3'b101;
  localparam QSPI =1'b0  , QPI   =1'b1;

  wire [7:0]  CMD_35H = 8'h35;
  wire [7:0]  CMD_EBH = 8'heb;
  wire [7:0]  CMD_38H = 8'h38;
  
  
  reg         mode;
  reg   [2:0] state;
  reg   [7:0] counter;
  reg   [7:0] cmd;
  reg  [23:0] addr;
  reg  [31:0] read_data;
  reg  [31:0] write_data;

  wire        ren = (state ==   S_ADDR) && (counter == 8'd5);
  reg         wen;
  wire        valid = (ren && cmd == CMD_EBH) || (wen && cmd == CMD_38H);
  wire [31:0] rdata;
  wire [31:0] wdata = write_data;
  wire [31:0] raddr = {8'h80, addr[23:0]};
  wire [31:0] waddr = {8'h80, addr[23:0]};

  // psram model ////////////////////////////////////////////
  psram_cmd psram_cmd_i(
    .clock(sck),
    .valid(valid),
    .cmd(cmd),
    .raddr(raddr),
    .waddr(waddr),
    .rdata(rdata),
    .wdata(wdata) 
  );

  // mode switch ///////////////////////////////////////////
  always @ (negedge sck or posedge reset) begin
    if (mode==QPI)
      mode <= mode;
    else if (cmd == CMD_35H)
      mode <= QPI;
    else if (reset)
      mode <= QSPI;
  end

  // fsm ///////////////////////////////////////////////////
  always @ (negedge sck or posedge reset) begin
    if (reset) 
      state <= S_CMD;
    else begin
      case (state) 
        S_CMD    : state <= (counter == 8'd1) && (mode == QPI    )  ? S_ADDR   :
                            (counter == 8'd7) && (mode == QSPI   )  ? S_ADDR   : state;
        S_ADDR   : state <= (cmd == CMD_EBH ) && (counter == 8'd5)  ? S_WAIT   :
                            (cmd == CMD_38H ) && (counter == 8'd5)  ? S_W_DATA :
                            (cmd != CMD_38H ) && (cmd != CMD_EBH )  ? S_ERR    : state;
        S_W_DATA : state <= state;
        S_WAIT   : state <= (counter == 8'd5)                       ? S_R_DATA : state;
        S_R_DATA : state <= state;
        default  : begin
          state <= state;
          $fwrite(32'h80000002, "Assertion failed: Unsupported command `%xh`\n", cmd);
        end
      endcase
    end
  end

  // counter reg ////////////////////////////////////////////
  always @ (negedge sck or posedge reset) begin
    if (reset) 
      counter <= 8'd0;
    else begin
      case (state)
        S_CMD   : counter <= (counter < 8'd1) && (mode == QPI ) ? counter + 8'd1 :
                             (counter < 8'd7) && (mode == QSPI) ? counter + 8'd1 : 8'd0;
        S_ADDR  : counter <= (counter < 8'd5) ? counter + 8'd1 : 8'd0;
        S_WAIT  : counter <= (counter < 8'd5) ? counter + 8'd1 : 8'd0;
        default : counter <= counter + 8'd1;
      endcase
    end
  end

  // cmd reg ///////////////////////////////////////////////
  always @ (posedge sck or posedge reset) begin
    if (reset)
      cmd <= 8'd0;
    else if (state == S_CMD) begin
      if (mode == QSPI) 
        cmd <= {cmd[6:0], dio[0]};
      else if (mode == QPI)
        cmd <= {cmd[3:0], dio};
    end
  end
  
  // addr reg //////////////////////////////////////////////
  always @ (posedge sck or posedge reset) begin
    if (reset)
      addr <= 24'd0;
    else if (state == S_ADDR)
      addr <= {addr[19:0], dio};
    else if (state == S_W_DATA) begin
      if (counter == 0)
        addr <= addr;
      else if (~counter[0])
        addr <= addr + 1;
    end
  end

  // rdata reg /////////////////////////////////////////////
  wire [31:0] data_bswap = {rdata[7:0], rdata[15:8], rdata[23:16], rdata[31:24]};
  always @ (negedge sck or posedge reset) begin
    if (reset)
      read_data <= 32'd0;
    else if (state == S_R_DATA) begin
      read_data <= { {counter == 8'd0 ? data_bswap : read_data}[27:0], 4'b0};
    end
  end

  // wen reg ///////////////////////////////////////////////
  always @ (posedge sck or posedge reset) begin
    if (reset)
      wen <= 1'b0;
    else
      wen <= (state == S_W_DATA) && counter[0];  
  end

  // wdata reg /////////////////////////////////////////////
  always @ (posedge sck or posedge reset) begin
    if (reset) 
      write_data <= 32'd0;
    else if (state == S_W_DATA) begin
      write_data <= {24'd0, write_data[3:0], dio};
    end
  end

  wire s_r_data = state == S_R_DATA;
  assign dout_en = {4{s_r_data}};
  assign dio[0] = dout_en[0] ?  {(counter == 8'd0) ? data_bswap : read_data}[28] : 1'bz;
  assign dio[1] = dout_en[1] ?  {(counter == 8'd0) ? data_bswap : read_data}[29] : 1'bz;
  assign dio[2] = dout_en[2] ?  {(counter == 8'd0) ? data_bswap : read_data}[30] : 1'bz;
  assign dio[3] = dout_en[3] ?  {(counter == 8'd0) ? data_bswap : read_data}[31]: 1'bz;

endmodule

import "DPI-C" function void psram_write(input int addr, input int data);
import "DPI-C" function void psram_read(input int addr, output int data);

module psram_cmd (
  input             clock,
  input             valid,
  input       [7:0] cmd,
  input      [31:0] raddr,
  input      [31:0] waddr,
  output reg [31:0] rdata,
  input reg [31:0] wdata
);

always@(negedge clock) begin
    if (valid)
      if (cmd == 8'heb) psram_read(raddr, rdata);
      else if (cmd == 8'h38) begin psram_write(waddr, wdata); end
      else begin
        $fwrite(32'h80000002, "Assertion failed: Unsupport command `%xh`\n", cmd);
        //$fatal;
      end
  end

endmodule