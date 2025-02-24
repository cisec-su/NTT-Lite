module modmul
    #(
        parameter LOGQ    = 32,
        parameter MUL_OP  = 16
    )
    (
        input                clk ,
        input  [LOGQ -1  :0] Q   ,
        input  [LOGQ     :0] MU  ,
        input  [LOGLOGQ-1:0] logq,        
        input  [LOGQ -1  :0] A   ,
        input  [LOGQ -1  :0] B   ,
        output [LOGQ -1  :0] C
    );

localparam K     = 2*LOGQ;
localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));


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
) im_nstd (
    .clk(clk),
    .A  (A  ),
    .B  (B  ),
    .C  (C_ )
);


barrett #(
    .LOGQ    (LOGQ   ),
    .LOGQH   (LOGQ   ),
    .DSP_A_U (MUL_OP ),
    .DSP_B_U (MUL_OP ),
    .PIPE_Q  (0      ),
    .CORRECT (1      ),
    .FF_IN   (0      ),
    .FF_SHF  (0      ),
    .FF_MUL  (1      ),
    .USE_CSA (1      ),
    .FF_CSA  (1      ),
    .FF_NEG  (0      ),
    .FF_CORR (0      ),
    .FF_OUT  (1      )
) barrett_inst (
    .clk(clk ),
    .C  (C_  ),
    .T  (C   ),
    .B  (logq),
    .MU (MU  ),
    .qH (Q   )
);


endmodule




