`include "mac_std_dual_32x34.svh"

module modmul
    #(
        parameter LOGQ    = 32
    )
    (
        input                clk ,
        input   mode_mul_t   mode,
        input  [LOGQ -1  :0] Q   ,
        input  [LOGQ +1  :0] MU  ,
        input  [LOGLOGQ-1:0] logq,        
        input  [LOGQ -1  :0] A   ,
        input  [LOGQ -1  :0] B   ,
        output [LOGQ -1  :0] C
    );

///////////////////////////// input check ///////////////////////////////

generate
    if (LOGQ > 32) begin
        LOGQ_CANT_BE_GREATER_THAN_32();
    end
endgenerate
    
/////////////////////////////////////////////////////////////////////////


localparam K     = 2*LOGQ;
localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));


wire [K-1:0] C_;
wire dual;

assign dual = (mode == MUL_SINGLE) ? 1'b0 : 1'b1;

mac_std_dual_32x34 #(
    .LOGB   (LOGQ  ),
    .MODE_E (DIS_E ),
    .FF_IN_A(1     ),
    .FF_IN_B(1     ),
    .FF_IN_E(1     ),
    .FF_OUT (1     ),
    .FF_MUL (1     )
) im_nstd (
    .clk     (clk ),
    .mode_mul(mode),
    .A       (A   ),
    .B       (B   ),
    .C       (C_  )
);


barrett #(
    .LOGQ    (LOGQ),
    .LOGQH   (LOGQ),
    .PIPE_Q  (0   ),
    .CORRECT (1   ),
    .FF_IN   (0   ),
    .FF_SHF  (0   ),
    .FF_MUL  (1   ),
    .FF_NEG  (0   ),
    .FF_CORR (0   ),
    .FF_OUT  (1   )
) barrett_inst (
    .clk (clk ),
    .dual(dual),
    .C   (C_  ),
    .T   (C   ),
    .B   (logq),
    .MU  (MU  ),
    .qH  (Q   )
);


endmodule




