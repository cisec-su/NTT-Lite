module butterfly
   #(
        parameter LOGQ   = 64,
        parameter LOGQH  = 48,
        parameter MUL_OP = 16,
        parameter L      = 13
    )
    (
        input              clk,
        input  [LOGQ -1:0] A  ,
        input  [LOGQ -1:0] B  ,
        input  [LOGQ -1:0] PSI,
        input  [LOGQ -1:0] q  ,
        input  [LOGQW-1:0] qW ,
        output [LOGQ -1:0] E  ,
        output [LOGQ -1:0] O  ,
        output [LOGQ -1:0] M
    );

localparam W     = LOGQ - LOGQH;
localparam QW    = $rtoi($ceil(LOGQ / W));
localparam LOGQW = $rtoi($ceil($clog2(QW + 1)));
localparam MODMUL_CC = 11;

reg  [LOGQH-1:0] q_int;
wire [LOGQH-1:0] qH;
wire [LOGQ -1:0] A_shift;
wire [LOGQ -1:0] MM;

assign qH = q[LOGQ-1 -: LOGQH];

shiftreg #(
    .SHIFT(L            ),
    .DATA (LOGQ         )
) sre10(
    .clk     (clk    ),
    .rst     (1'b0   ),
    .data_in (A      ),
    .data_out(A_shift)
);


modmul #(
    .LOGQ   (LOGQ   ),
    .LOGQH  (LOGQH  ),
    .MUL_OP (MUL_OP )
) mm0 (
    .clk(clk),
    .qH (qH ),
    .qW (qW ),
    .A  (B  ),
    .B  (PSI),
    .C  (MM )
);


modadd  #(
    .LOGQ (LOGQ ),
    .LOGQH(LOGQH)
) ma (
    .A (A_shift),
    .B (MM     ),
    .qH(q_int  ),
    .C (E      )  
);


modsub #(
    .LOGQ (LOGQ ),
    .LOGQH(LOGQH)
) ms (
    .A (A_shift),
    .B (MM     ),
    .qH(q_int  ),
    .C (O      )
);

assign M = MM;

always @(posedge clk ) begin
    q_int <= qH;
end


endmodule




