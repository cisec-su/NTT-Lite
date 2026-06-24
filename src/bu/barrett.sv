`include "barrett.svh"

module barrett
   #(
        parameter  LOGQ     = 32,
        parameter  PIPE_Q   = 1 ,
        parameter  CORRECT  = 1 ,
        parameter  FF_IN    = 1 ,
        parameter  FF_SHF   = 1 ,
        parameter  FF_BARRETT_KR_SUM0 = 0,
        parameter  FF_BARRETT_KR_SUB0 = 0,
        parameter  FF_BARRETT_KR_MUL  = 1,
        parameter  FF_BARRETT_KR_SUM1 = 0,
        parameter  FF_BARRETT_KR_SUM2 = 1,
        parameter  FF_BARRETT_KR_SUB1 = 0,
        parameter  FF_MUL   = 1 ,
        parameter  FF_OUT   = 1
    )
    (
        input               clk ,
        input               dual,
        input  [2*LOGQ-1:0] C   ,
        output [  LOGQ-1:0] T   ,
        input  [2*LOGQ-1:0] MU  ,
        output [  LOGQ-1:0] D   ,
        input  [  LOGQ-1:0] Q
    );

///////////////////////////// input check ///////////////////////////////

if (LOGQ > 32) begin
    LOGQ_CANT_BE_GREATER_THAN_32();
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// parameters ////////////////////////////////

localparam barrett_params_t params = {LOGQ, FF_IN, FF_SHF, FF_MUL, FF_OUT,
                                      FF_BARRETT_KR_SUM0, FF_BARRETT_KR_SUB0, FF_BARRETT_KR_MUL, FF_BARRETT_KR_SUM1, FF_BARRETT_KR_SUM2, FF_BARRETT_KR_SUB1};
localparam karatsuba_64x64_dual_params_t  mac_0_params = barrett_mac_0_params(params);
localparam mac_std_dual_32x34_params_t    mac_1_params = barrett_mac_1_params(params);

localparam LOGQ0 = LOGQ >> 1;

localparam LOGMU0  = LOGQ;
localparam LOGMU = LOGMU0 << 1;

localparam LOGD  = LOGQ << 1;
localparam LOGC  = LOGQ << 1;

localparam LOGD0 = LOGD >> 1;

localparam LOGC0 = LOGC >> 1;
localparam LOGCL_0 = (LOGQ >> 1) + 1;
localparam LOGCL = LOGCL_0 << 1;

localparam LOGT0 = barrett_logt0(params);
localparam LOGT0_0 = LOGT0 >> 1;
localparam LOGT0H_0 = LOGT0_0 - (LOGQ0  << 1);
localparam LOGT0H = LOGT0H_0 << 1;

localparam LOGT0HL_0 = LOGQ0 + 1;
localparam LOGT0HL = LOGT0HL_0 << 1;

localparam LOGT1   = barrett_logt1(params);
localparam LOGT1_0 = LOGT1 >> 1;
localparam LOGT1L_0 = (LOGQ0 + 1);
localparam LOGT1L   = LOGT1L_0 << 1;


localparam LAT    = barrett_lat(params);
localparam LAT_0  = barrett_mac_0_lat(params);
localparam LAT_1  = barrett_mac_1_lat(params);

localparam CL_D   = LAT_0;
localparam Q_D    = (PIPE_Q) ? LAT_1 + LAT_0 + FF_IN : 0;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// signals ///////////////////////////////////

reg  [LOGQ*2 -1:0] C_q;
reg  [LOGMU  -1:0] MU_q;
reg  [LOGQ   -1:0] Q_q [0:Q_D-1];

wire [LOGC -1:0] C_mx;
wire [LOGQ -1:0] Q_mx   [0:1];
wire [LOGMU-1:0] MU_mx;

wire [LOGCL  -1:0] CL;
wire [LOGCL_0-1:0] CL_0;
wire [LOGCL_0-1:0] CL_1;

reg  [LOGCL-1:0] CL_q [0:CL_D-1];
wire [LOGCL-1:0] CL_mx;

wire [LOGT0 -1:0] T0;
wire [LOGT0H-1:0] T0H;
wire [LOGT0HL-1:0] T0HL;
wire [LOGT0H-1:0] D_apx;
reg  [LOGT0H-1:0] D_apx_q [0:LAT_1-1];
wire [LOGT0H-1:0] D_apx_mx;

wire [LOGT1 -1:0] T1;
wire [LOGT1L-1:0] T1L;
wire [LOGT1L-1:0] T1N;

wire [LOGQ-1:0] T5;
reg  [LOGQ-1:0] T5_q;

wire [1:0] K;
wire [LOGD-1:0] D_int;
wire [LOGQ-1:0] D_int_c;
reg  [LOGQ-1:0] D_int_q;

mode_mul_t mode_mul;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// comb. assignments //////////////////////

assign mode_mul = (dual) ? MUL_DUAL : MUL_SINGLE;

assign D_apx = T0H;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// pipeline steps  /////////////////////////////

if (FF_IN) begin
    assign C_mx = C_q;
end
else begin
    assign C_mx = C;
end

if (CL_D) begin
    assign CL_mx = CL_q[CL_D - 1];
end
else begin
    assign CL_mx = CL;
end

if (FF_IN && PIPE_Q) begin
    assign MU_mx = MU_q;
end
else begin
    assign MU_mx = MU;
end

if (Q_D) begin
    assign Q_mx[0] = Q_q[FF_IN + LAT_0 - 1];
    assign Q_mx[1] = Q_q[          Q_D - 1];
end
else begin
    assign Q_mx[0] = Q;
    assign Q_mx[1] = Q;
end

if (LAT_1) begin
    assign D_apx_mx = D_apx_q[LAT_1 - 1];
end
else begin
    assign D_apx_mx = D_apx;
end

if (FF_OUT) begin
    assign T = T5_q;
    assign D = D_int_q;
end
else begin
    assign T = T5;
    assign D = D_int_c;
end

/////////////////////////////////////////////////////////////////////////




/////////////////////////// lsb of input ////////////////////////////////

lsb_dual #(
    .LOGA0(LOGC0  ),
    .LOGC0(LOGCL_0)
) lsb_dual_inst_0 (
    .A   (C_mx ),
    .dual(dual ),
    .C   (CL   )
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// intmul //////////////////////////////////////

karatsuba_64x64_dual #(
    .FF_IN  (mac_0_params.FF_IN  ),
    .FF_SUM0(mac_0_params.FF_SUM0),
    .FF_SUB0(mac_0_params.FF_SUB0), 
    .FF_MUL (mac_0_params.FF_MUL ),
    .FF_SUM1(mac_0_params.FF_SUM1),
    .FF_SUM2(mac_0_params.FF_SUM2),
    .FF_SUB1(mac_0_params.FF_SUB1),
    .FF_OUT (mac_0_params.FF_OUT )
) intmul_karatsuba_inst_0 (
    .clk     (clk      ),
    .dual    (dual     ),
    .A       (C_mx     ),
    .B       (MU_mx    ),
    .C       (T0       )
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// shift-right and lsb /////////////////////////

msb_dual #(
    .LOGA0(LOGT0_0 ),
    .LOGC0(LOGT0H_0)
) msb_dual_inst (
    .A   (T0  ),
    .dual(dual),
    .C   (T0H )
);


lsb_dual #(
    .LOGA0(LOGT0H_0 ),
    .LOGC0(LOGT0HL_0)
) lsb_dual_inst_1 (
    .A   (T0H ),
    .dual(dual),
    .C   (T0HL)
);


/////////////////////////////////////////////////////////////////////////




/////////////////////////// mac /////////////////////////////////////////

mac_std_dual_32x34 #(
    .LOGB    (mac_1_params.LOGB   ),
    .MODE_E  (mac_1_params.MODE_E ),
    .FF_IN_A (mac_1_params.FF_IN_A),
    .FF_IN_B (mac_1_params.FF_IN_B),
    .FF_IN_E (mac_1_params.FF_IN_E),
    .FF_MUL  (mac_1_params.FF_MUL ),
    .FF_OUT  (mac_1_params.FF_OUT ),
    .OPT_HIGH(                   1)
) mac_std_inst_1 (
    .clk     (clk     ),
    .mode_mul(mode_mul),
    .en_z    (1'b0    ),
    .A       (Q_mx[0] ),
    .B       (T0HL    ),
    .E       (CL_mx   ),
    .C       (T1      )
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// lsb and negation ////////////////////////////

lsb_dual #(
    .LOGA0(LOGT1_0 ),
    .LOGC0(LOGT1L_0)
) lsb_dual_inst_2 (
    .A   (T1  ),
    .dual(dual),
    .C   (T1L )
);


addsub_dual #(
    .MODE (1      ),
    .LOGA0(LOGT1L_0),
    .LOGB0(LOGT1L_0)
) addsub_neg_inst (
    .A   (0     ),
    .B   (T1L   ),
    .dual(dual  ),
    .C   (T1N   )
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// correction //////////////////////////////////

barrett_correction #(
    .LOGQ(LOGQ)
) barrett_correction_inst (
    .dual(dual    ),
    .A   (T1N     ),
    .C   (T5      ),
    .K   (K       ),
    .Q   (Q_mx[1] )
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// correction for div res. /////////////////////

addsub_dual #(
    .MODE (0       ),
    .LOGA0(LOGT0H_0),
    .LOGB0(1       )
) addsub_corr_inst (
    .A   (D_apx_mx),
    .B   (K       ),
    .dual(dual    ),
    .C   (D_int   )
);

assign D_int_c = (dual) ? {D_int[LOGQ +: LOGQ0], D_int[0 +: LOGQ0]} : D_int[LOGQ-1:0];

/////////////////////////////////////////////////////////////////////////




/////////////////////////// sequential logic  ///////////////////////////

if (FF_IN) begin
    always @(posedge clk) begin           
        C_q <= C;
    end
end

if (CL_D) begin
    for (genvar i = 0; i < CL_D; i = i + 1) begin
        always @(posedge clk) begin
            CL_q[i] <= (i == 0) ? CL : CL_q[i - 1];
        end
    end
end

if (FF_IN && PIPE_Q) begin
    always @(posedge clk) begin           
        MU_q <= MU;
    end
end

if (Q_D) begin
    for (genvar i = 0; i < Q_D; i = i + 1) begin
        always @(posedge clk) begin
            Q_q[i] <= (i == 0) ? Q : Q_q[i - 1];
        end
    end
end

if (LAT_1) begin
    for (genvar i = 0; i < LAT_1; i = i + 1) begin
        always @(posedge clk) begin
            D_apx_q[i] <= (i == 0) ? D_apx : D_apx_q[i - 1];
        end
    end
end

if (FF_OUT) begin
    always @(posedge clk) begin
        T5_q <= T5;
        D_int_q <= D_int_c;
    end
end

/////////////////////////////////////////////////////////////////////////


endmodule