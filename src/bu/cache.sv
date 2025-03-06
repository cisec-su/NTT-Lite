module cache
   #(
        parameter W = 32
    )
    (
        input          clk   ,
        input          rst   ,
        output reg     full  ,
        input          wen   ,
        input          ren   ,
        input  [W-1:0] i_data,
        output [W-1:0] o_data
    );


reg [W-1:0] data_q;

assign o_data = (full) ? data_q : i_data;


always @(posedge clk) begin
    if (rst)
        data_q <= 0;
    else if (wen)
        data_q <= i_data;
end


always @(posedge clk) begin
    if (rst)
        full <= 0;
    else if (wen)
        full <= 1;
    else if (ren)
        full <= 0;
end


endmodule