module ps2_keyboard(clk,clrn,ps2_clk,ps2_data,data,
                    ready,nextdata_n);
    input clk,clrn,ps2_clk,ps2_data;
    input nextdata_n;
    output [7:0] data;
    output ready;
    // internal signal, for test
    reg [9:0] buffer;        // ps2_data bits
    reg [7:0] fifo[7:0];     // data fifo
    reg [3:0] w_ptr,r_ptr;   // fifo write and read pointers
    reg [3:0] count;  // count ps2_data bits
    // detect falling edge of ps2_clk
    reg [2:0] ps2_clk_sync;
    wire [2:0] w_addr = w_ptr[2:0];
    wire [2:0] r_addr = r_ptr[2:0];

    wire empty, full;

    always @(posedge clk) begin
        ps2_clk_sync <=  {ps2_clk_sync[1:0],ps2_clk};
    end

    wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];

    always @(posedge clk) begin
        if (clrn == 0) begin // reset
            count <= 0; w_ptr <= 0; r_ptr <= 0;
        end
        else begin
            if ( ready ) begin // read to output next data
                if(nextdata_n == 1'b0) //read next data
                begin
                    r_ptr <= r_ptr + 3'b1;
                end
            end
            if (sampling) begin
              if (count == 4'd10) begin
                if ((buffer[0] == 0) &&  // start bit
                    (ps2_data)       &&  // stop bit
                    (^buffer[9:1])) begin      // odd  parity
                    fifo[w_addr] <= buffer[8:1];  // kbd scan code
                    w_ptr <= w_ptr+3'b1;
                end
                count <= 0;     // for next
              end else begin
                buffer[count] <= ps2_data;  // store ps2_data
                count <= count + 3'b1;
              end
            end
        end
    end
    assign data = fifo[r_addr]; //always set output data
    assign empty = (w_ptr == r_ptr);
    assign full  = (w_ptr[3] != r_ptr[3]) & (w_addr == r_addr);
    assign ready = !empty;

endmodule
