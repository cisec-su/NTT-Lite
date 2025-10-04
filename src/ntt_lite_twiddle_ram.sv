module ntt_lite_twiddle_ram
   #(
        parameter LOGQ  = 32  ,
        parameter LOGN  = 8
    )
    (   input                 clk  ,

        input                 wen  ,
        input      [LOGN-1:0] waddr,
        input      [LOGQ-1:0] din  ,
        input      [LOGN-1:0] raddr,
        output reg [LOGQ-1:0] dout
      );

localparam N  = 1 << LOGN;


reg [LOGQ-1:0] bram [N-1:0];


always @(posedge clk) begin
    if(wen)
        bram[waddr] <= din;
end


always @(posedge clk) begin
    dout <= bram[raddr];
end


endmodule