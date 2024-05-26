`include "spi_defines.v"

module spi_xip #(
  parameter flash_addr_start = 32'h30000000,
  parameter flash_addr_mask  = 32'hf0000000,
  parameter read_cmd         = 32'h03000000,
  parameter spi_ss_num       = 8
) (
    input         clock,
    input         reset,
   
    // from spi_top_apb /////////////
    input  [31:0] in_paddr,
    input         in_psel,
    input         in_penable,
    input         in_pwrite,
    input  [31:0] in_pwdata,
    input  [3:0]  in_pstrb,

    // from spi_top /////////////////
    input         in_pready,
    input  [31:0] in_prdata,
    input         in_pslverr,

    // to spi_top ///////////////////
    output [31:0] out_paddr,
    output        out_psel,
    output        out_penable,
    output        out_pwrite,
    output [31:0] out_pwdata,
    output [ 3:0] out_pstrb,
 
    // to spi_tob_apb ///////////////
    output        out_pready,
    output [31:0] out_prdata,
    output        out_pslverr
);

// parameter definition /////////////////////////////////////////
localparam TX0_ADDR     = 32'h10001000;
localparam TX1_ADDR     = 32'h10001004;
localparam RX0_ADDR     = 32'h10001000;
localparam RX1_ADDR     = 32'h10001004; 
localparam CTRL_ADDR    = 32'h10001010;
localparam DEVIDER_ADDR = 32'h10001014; 
localparam SS_ADDR      = 32'h10001018;
     
localparam S_IDLE     = 0 , S_TX_0    = 1 , S_TX_1      = 2, S_DEVIDER    = 3, S_SS_SET     = 4;
localparam S_CTRL_CFG = 5 , S_CTRL_GO = 6 , S_CTRL_POLL = 7, S_CTRL_CLEAR = 8, S_SS_CLEAR   = 9;
localparam S_RX_0     = 10, S_RX_1    = 11;

// control //////////////////////////////////////////////////////
wire xip_mode = (in_paddr & flash_addr_mask) == flash_addr_start; 
wire p_hs     = out_penable & out_psel & in_pready;

wire go       = in_prdata[`SPI_CTRL_GO];

// rdata_gen signalk ////////////////////////////////////////////
reg  [31:0] rx_0_rdata;
wire [63:0] rx_rdata_ext;
wire [31:0] rx_rdata; 

// critical signal //////////////////////////////////////////////
wire [31:0] xip_paddr;
wire        xip_psel;
wire        xip_penable;
wire        xip_pwrite;
wire [31:0] xip_pwdata;
wire [ 3:0] xip_pstrb;
wire        xip_pready;
wire [31:0] xip_prdata;

// fsm //////////////////////////////////////////////////////////
reg [ 3: 0] state;
wire s_idle      = state == S_IDLE      , s_tx_0      = state == S_TX_0        , s_tx_1       = state == S_TX_1;   
wire s_devider   = state == S_DEVIDER   , s_ss_set    = state == S_SS_SET      , s_ctrl_cfg   = state == S_CTRL_CFG;
wire s_ctrl_go   = state == S_CTRL_GO   , s_ctrl_poll = state == S_CTRL_POLL   , s_ctrl_clear = state == S_CTRL_CLEAR;
wire s_ss_clear  = state == S_SS_CLEAR  , s_rx_0      = state == S_RX_0        , s_rx_1       = state == S_RX_1;

always @ (posedge clock or posedge reset) begin
    if (reset)
        state <= S_IDLE;
    else begin
        case (state)
            S_IDLE       : state <= (xip_mode & in_psel & in_penable) ? S_TX_0 : S_IDLE;
            S_TX_0       : state <= (p_hs)       ? S_TX_1       : S_TX_0;
            S_TX_1       : state <= (p_hs)       ? S_DEVIDER    : S_TX_1;
            S_DEVIDER    : state <= (p_hs)       ? S_SS_SET     : S_DEVIDER;
            S_SS_SET     : state <= (p_hs)       ? S_CTRL_CFG   : S_SS_SET;
            S_CTRL_CFG   : state <= (p_hs)       ? S_CTRL_GO    : S_CTRL_CFG;
            S_CTRL_GO    : state <= (p_hs)       ? S_CTRL_POLL  : S_CTRL_GO;
            S_CTRL_POLL  : state <= (p_hs & ~go) ? S_SS_CLEAR   : S_CTRL_POLL;
            S_CTRL_CLEAR : state <= (p_hs)       ? S_SS_CLEAR   : S_CTRL_CLEAR;
            S_SS_CLEAR   : state <= (p_hs)       ? S_RX_0       : S_SS_CLEAR;
            S_RX_0       : state <= (p_hs)       ? S_RX_1       : S_RX_0;
            S_RX_1       : state <= (p_hs)       ? S_IDLE       : S_RX_1;
        endcase
    end
end

// xip rdata generate

always @ (posedge clock or posedge reset) begin
    if (reset) 
        rx_0_rdata <= 0;
    else if (s_rx_0 & p_hs)
        rx_0_rdata <= in_prdata;
end

assign rx_rdata_ext = ({in_prdata, 32'h0} | {32'h0, rx_0_rdata}) >> 1;
assign rx_rdata     = ((rx_rdata_ext[31:0] >> 24) & 32'hff      ) |
                      ((rx_rdata_ext[31:0] << 8 ) & 32'hff0000  ) |
                      ((rx_rdata_ext[31:0] >> 8 ) & 32'hff00    ) |
                      ((rx_rdata_ext[31:0] << 24) & 32'hff000000);



// signal select ///////////////////////////////////////////////
assign xip_psel    = s_idle       ? 1'b0 : 1'b1;
assign xip_penable = s_idle       ? 1'b0 : 1'b1;

assign xip_paddr   = s_idle       ? 32'h0       :
                     s_tx_0       ? TX0_ADDR    :
                     s_tx_1       ? TX1_ADDR    :
                     s_devider    ? DEVIDER_ADDR:
                     s_ss_set     ? SS_ADDR     :
                     s_ctrl_cfg   ? CTRL_ADDR   :
                     s_ctrl_go    ? CTRL_ADDR   :
                     s_ctrl_poll  ? CTRL_ADDR   :
                     s_ctrl_clear ? CTRL_ADDR   :
                     s_ss_clear   ? SS_ADDR     :
                     s_rx_0       ? RX0_ADDR    :
                     s_rx_1       ? RX1_ADDR    : 32'h0;


assign xip_pwrite  = s_idle       ? 1'b0        : 
                     s_tx_0       ? 1'b1        :
                     s_tx_1       ? 1'b1        :
                     s_devider    ? 1'b1        :
                     s_ss_set     ? 1'b1        :
                     s_ctrl_cfg   ? 1'b1        : 
                     s_ctrl_go    ? 1'b1        :
                     s_ctrl_poll  ? 1'b0        :
                     s_ctrl_clear ? 1'b1        :
                     s_ss_clear   ? 1'b1        :
                     s_rx_0       ? 1'b0        :
                     s_rx_1       ? 1'b0        : 1'b0;

assign xip_pwdata  = s_idle       ? 32'b0       :
                     s_tx_0       ? 32'h0       :   
                     s_tx_1       ? read_cmd | {8'b0, in_paddr[23:0]} :
                     s_devider    ? 32'h1       :   // TOO SMALL
                     s_ss_set     ? 32'h1       :
                     s_ctrl_cfg   ? 32'h240     : 
                     s_ctrl_go    ? 32'h340     :
                     s_ctrl_poll  ? 32'h0       :
                     s_ctrl_clear ? 32'h0       :
                     s_ss_clear   ? 32'h0       :
                     s_rx_0       ? 32'h0       :
                     s_rx_1       ? 32'h0       : 32'h0;

assign xip_pstrb   = s_idle       ? 4'b0        :
                     s_tx_0       ? 4'hf        :
                     s_tx_1       ? 4'hf        :
                     s_devider    ? 4'hf        :
                     s_ss_set     ? 4'hf        :
                     s_ctrl_cfg   ? 4'hf        :
                     s_ctrl_go    ? 4'hf        :
                     s_ctrl_poll  ? 4'h0        :
                     s_ctrl_clear ? 4'hf        :
                     s_ss_clear   ? 4'hf        :
                     s_rx_0       ? 4'h0        :
                     s_rx_1       ? 4'h0        : 4'h0;

assign xip_pready  = s_rx_1 & in_pready         ;
assign xip_prdata  = rx_rdata                   ;


assign out_paddr    = xip_mode ? xip_paddr   :  in_paddr  ;    
assign out_psel     = xip_mode ? xip_psel    :  in_psel   ;    
assign out_penable  = xip_mode ? xip_penable :  in_penable;
assign out_pwrite   = xip_mode ? xip_pwrite  :  in_pwrite ;
assign out_pwdata   = xip_mode ? xip_pwdata  :  in_pwdata ;
assign out_pstrb    = xip_mode ? xip_pstrb   :  in_pstrb  ;  

assign out_pready   = xip_mode ? xip_pready  :  in_pready ;
assign out_prdata   = xip_mode ? {{32{s_rx_1}}} & xip_prdata : in_prdata;
assign out_pslverr = 1'b0;

endmodule