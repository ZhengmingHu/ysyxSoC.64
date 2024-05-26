module bitrev (
  input  sck,
  input  ss,
  input  mosi,
  output miso
);

  wire reset = ss;

  typedef enum [1:0] { in_t, out_t } state_t;

  reg [1:0]  state;
  reg [7:0]  counter;
  reg [7:0] data;


  always@(posedge sck or posedge reset) begin
    if (reset) state <= in_t;
    else begin
      case (state)
        in_t:  state <= (counter == 8'd7 ) ? out_t : state;
        out_t: state <= state;
        default: state <= state;
      endcase
    end
  end

  always@(posedge sck or posedge reset) begin
    if (reset) counter <= 8'd0;
    else begin
      case (state)
        in_t:   counter <= (counter < 8'd7 ) ? counter + 8'd1 : 8'd0;
        default: counter <= counter + 8'd1;
      endcase
    end
  end 

  always@(posedge sck or posedge reset) begin
    if (reset) data <= 8'd0;
    else if (state == in_t)
      data <= {data[6:0], mosi};
    else if (state == out_t)
      data <= {1'b0, data[7:1]};
  end

  assign miso = ss ? 1'b1 : (state==out_t) ? data[0] : 1'b0;

endmodule
