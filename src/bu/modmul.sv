`include "mac_std_dual_32x34.svh"

module modmul
    #(
        parameter LOGQ    = 32
    )
    (
        input                clk ,
        input   mode_mul_t   mode,
        input  [LOGQ   -1:0] Q   ,
        input  [LOGT   -1:0] MU  ,
        input  [LOGQ   -1:0] A   ,
        input  [LOGQ   -1:0] E   ,
        input  [LOGQ   -1:0] B   ,
        output [LOGT   -1:0] T   ,        
        output [LOGT   -1:0] D   ,
        output [LOGQ   -1:0] C
    );

///////////////////////////// input check ///////////////////////////////

generate
    if (LOGQ > 32) begin
        LOGQ_CANT_BE_GREATER_THAN_32();
    end
endgenerate
    
/////////////////////////////////////////////////////////////////////////




///////////////////////////// parameters ////////////////////////////////

localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));
localparam LOGT    = LOGQ << 1;

/////////////////////////////////////////////////////////////////////////


wire dual;

assign dual = (mode == MUL_SINGLE) ? 1'b0 : 1'b1;

mac_std_dual_32x34 #(
    .LOGB   (LOGQ  ),
    .MODE_E (ADD_E ),
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
    .E       (E   ),
    .C       (T   )
);


barrett #(
    .LOGQ  (LOGQ),
    .PIPE_Q(0   ),
    .FF_IN (0   ),
    .FF_SHF(0   ),
    .FF_MUL(1   ),
    .FF_OUT(1   )
) barrett_inst (
    .clk (clk ),
    .dual(dual),
    .C   (T   ),
    .T   (C   ),
    .D   (D   ),
    .MU  (MU  ),
    .Q   (Q   )
);


endmodule




