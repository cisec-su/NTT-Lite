`include "mac_std_dual_32x34.svh"

module modmul
    #(
        parameter int unsigned LOGQ            = 32,
        parameter int unsigned FF_INTMUL_MUL   = 1 ,
        parameter int unsigned FF_MODRED_MUL   = 1 ,
        parameter int unsigned FF_BARRETT_KR_SUM0 = 0 ,
        parameter int unsigned FF_BARRETT_KR_SUB0 = 0 ,
        parameter int unsigned FF_BARRETT_KR_MUL  = 1 ,
        parameter int unsigned FF_BARRETT_KR_SUM1 = 0 ,
        parameter int unsigned FF_BARRETT_KR_SUM2 = 1 ,
        parameter int unsigned FF_BARRETT_KR_SUB1 = 0 ,
        parameter int unsigned FF_BARRETT_NEG     = 0
    )
    (
        input                  clk ,
        input   mode_mul_t     mode,
        input                  en_z,
        input  [ LOGQ    -1:0] Q   ,
        input  [(LOGQ<<1)-1:0] MU  ,
        input  [ LOGQ    -1:0] A   ,
        input  [ LOGQ    -1:0] E   ,
        input  [(LOGQ>>1)-1:0] Z   ,
        input  [ LOGQ    -1:0] B   ,
        output [(LOGQ<<1)-1:0] T   ,        
        output [(LOGQ<<1)-1:0] D   ,
        output [ LOGQ    -1:0] C   ,
        output [ LOGQ    -1:0] F
    );

///////////////////////////// input check ///////////////////////////////

generate
    if (LOGQ > 32) begin
        LOGQ_CANT_BE_GREATER_THAN_32();
    end
endgenerate
    
/////////////////////////////////////////////////////////////////////////




wire dual;

assign dual = (mode == MUL_SINGLE) ? 1'b0 : 1'b1;

mac_std_dual_32x34 #(
    .LOGB   (LOGQ         ),
    .MODE_E (ADD_E        ),
    .FF_IN_A(1            ),
    .FF_IN_B(1            ),
    .FF_IN_E(1            ),
    .FF_IN_Z(1            ),
    .FF_MUL (FF_INTMUL_MUL),
    .FF_OUT (1            )
) im_nstd (
    .clk     (clk ),
    .mode_mul(mode),
    .en_z    (en_z),
    .A       (A   ),
    .B       (B   ),
    .Z       (Z   ),
    .E       (E   ),
    .C       (T   ),
    .F       (F   )
);


barrett #(
    .LOGQ  (LOGQ         ),
    .PIPE_Q(0            ),
    .FF_IN (0            ),
    .FF_SHF(0            ),
    .FF_KR_SUM0(FF_BARRETT_KR_SUM0),
    .FF_KR_SUB0(FF_BARRETT_KR_SUB0),
    .FF_KR_MUL (FF_BARRETT_KR_MUL ),
    .FF_KR_SUM1(FF_BARRETT_KR_SUM1),
    .FF_KR_SUM2(FF_BARRETT_KR_SUM2),
    .FF_KR_SUB1(FF_BARRETT_KR_SUB1),
    .FF_NEG    (FF_BARRETT_NEG    ),
    .FF_MUL(FF_MODRED_MUL),
    .FF_OUT(1            )
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




