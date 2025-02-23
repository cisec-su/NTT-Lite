module modmul
    #(
        parameter LOGQ    = 64,
        parameter LOGQH   = 48,
        parameter MUL_OP  = 16
    )
    (
        input              clk ,
        input  [LOGQH-1:0] qH  ,
        input  [LOGQW-1:0] qW  ,
        input  [LOGQ -1:0] A   ,
        input  [LOGQ -1:0] B   ,
        output [LOGQ -1:0] C
    );

localparam K     = 2*LOGQ;
localparam W     = LOGQ - LOGQH;
localparam QW    = $rtoi($ceil(LOGQ / W));
localparam LOGQW = $rtoi($ceil($clog2(QW + 1)));


wire [K-1:0] C_;


mac_std #(
        .LOGA   (LOGQ  ),       
        .LOGB   (LOGQ  ),
        .MODE_E (0     ),
        .DSP_A_U(MUL_OP),
        .DSP_B_U(MUL_OP),
        .USE_CSA(1     ),
        .FF_CSA (1     ),
        .FF_IN_A(1     ),
        .FF_IN_B(1     ),
        .FF_IN_E(1     ),
        .FF_OUT (1     ),
        .FF_MUL (1     )
    )
im_nstd
    (
        .clk(clk),
        .A  (A  ),
        .B  (B  ),
        .C  (C_ )
    );


wlm #(
        .LOGQ   (LOGQ   ),
        .LOGQH  (LOGQH  ),
        .DSP_A_U(MUL_OP ),
        .DSP_B_U(MUL_OP ),
        .CORRECT(1      ),
        .FF_IN  (0      ),
        .FF_SUM (0      ),
        .FF_SUB (0      ),
        .FF_MUL (1      ),
        .FF_OUT (1      )
    ) 
wlm_inst 
    (
        .clk(clk),
        .qH (qH ),
        .qW (qW ),
        .C  (C_ ),
        .T  (C  )
    );


endmodule




