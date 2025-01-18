

module modadd
    #(
        parameter LOGQ   = 64,
        parameter LOGQH  = 48
    )
    (
        input            clk,
        input [LOGQ-1:0] A  ,
        input [LOGQ-1:0] B  ,
        input [LOGQH-1:0] qH ,
        output[LOGQ-1:0] C
    );

localparam W = LOGQ - LOGQH;

wire [LOGQ:0] R;
wire [LOGQ:0] Rq;

assign R = A + B;
assign Rq= R - {1'b0,qH,{W-1{1'b0}},1'b1};
assign C = (Rq[LOGQ] == 0) ? Rq[LOGQ-1:0] : R[LOGQ-1:0];

endmodule
