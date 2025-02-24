`include "modsub.svh"

module modsub
    #(
        parameter LOGQ       = 64,
        parameter LOGQH      = 47,
        parameter LOGQH_DUAL = 15,
        parameter EN_DUAL    = 1 , 
        parameter FF_IN      = 0 ,
        parameter FF_SUB     = 0 ,
        parameter FF_OUT     = 0
    )
    (
        input                 clk ,
        input  [LOGQ    -1:0] A   ,
        input  [LOGQ    -1:0] B   ,
        input  [LOGQH   -1:0] qH  ,
        input                 dual,
        output [LOGQ    -1:0] C
    );

///////////////////////////// input checks //////////////////////////////

generate
    if (LOGQH_DUAL > LOGQH) begin
        LOGQH_DUAL_CANT_BE_GREATER_THAN_LOGQH();        
    end
    if (EN_DUAL && ((LOGQ % 2) != 0)) begin
        LOGQ_MUST_BE_EVEN_FOR_DUAL_MODE();
    end
endgenerate

/////////////////////////////////////////////////////////////////////////

///////////////////////////// parameters ////////////////////////////////

localparam W = LOGQ - LOGQH;
localparam modsub_params_t params = {LOGQ, LOGQH, FF_IN, FF_SUB, FF_OUT};
localparam LAT = modsub_lat(params);
localparam LOGQ0 = LOGQ >> 1;
localparam W_DUAL = LOGQ0 - LOGQH_DUAL;

/////////////////////////////////////////////////////////////////////////

///////////////////////// Signals Declaration ///////////////////////////

reg  [LOGQ-1:0] A_q;
wire [LOGQ-1:0] A_mx;

reg  [LOGQ-1:0] B_q;
wire [LOGQ-1:0] B_mx;

reg  [LOGQ-1:0] qH_q;
wire [LOGQ-1:0] qH_mx;

wire [LOGQ0:0] R0;
reg  [LOGQ0:0] R0_q;
wire [LOGQ0:0] R0_mx;
wire [LOGQ0:0] R1;
reg  [LOGQ0:0] R1_q;
wire [LOGQ0:0] R1_mx;

wire [LOGQ0:0] Rq0;
reg  [LOGQ0:0] Rq0_q;
wire [LOGQ0:0] Rq0_mx;
wire [LOGQ0:0] Rq1;
reg  [LOGQ0:0] Rq1_q;
wire [LOGQ0:0] Rq1_mx;

wire [LOGQ -1:0] S;
reg  [LOGQ -1:0] S_q;
wire [LOGQ0-1:0] S0;
wire [LOGQ0-1:0] S1;

wire [LOGQ:0] q;

generate
    if (EN_DUAL) begin : DUAL
        wire [LOGQ0:0] q;
    end
endgenerate

/////////////////////////////////////////////////////////////////////////

///////////////////////////// Pipeline Steps ////////////////////////////

assign A_mx  = (FF_IN) ? A_q  : A;
assign B_mx  = (FF_IN) ? B_q  : B;
assign qH_mx = (FF_IN) ? qH_q : qH;

assign R0_mx   = (FF_SUB) ? R0_q   : R0;
assign R1_mx   = (FF_SUB) ? R1_q   : R1;
assign Rq0_mx  = (FF_SUB) ? Rq0_q  : Rq0;
assign Rq1_mx  = (FF_SUB) ? Rq1_q  : Rq1;

assign C = (FF_OUT) ? S_q : S;

/////////////////////////////////////////////////////////////////////////

///////////////////////////// Assignments ///////////////////////////////

assign q = (LOGQ > LOGQH) ? {1'b0, qH_mx, {(W - 1){1'b0}}, 1'b1} : {1'b0, qH_mx};
generate
    if (EN_DUAL) begin
        assign DUAL.q = (LOGQ0 > LOGQH_DUAL) ? {1'b0, qH_mx[LOGQH_DUAL-1:0], {(W_DUAL - 1){1'b0}}, 1'b1} : {1'b0, qH_mx[LOGQH_DUAL-1:0]};
    end
endgenerate

assign R0 = A_mx[LOGQ0-1:    0] - B_mx[LOGQ0-1:    0];
assign R1 = A_mx[LOGQ -1:LOGQ0] - B_mx[LOGQ -1:LOGQ0] - ((!EN_DUAL || !dual) ? {1'b0, R0[LOGQ0]} : 0);

assign Rq0 = (EN_DUAL && dual) ? (R0 + DUAL.q) : (R0[LOGQ0-1:0] + q[LOGQ0-1:0]);
assign Rq1 = (EN_DUAL && dual) ? (R1 + DUAL.q) : (R1 + (q >> LOGQ0) + Rq0[LOGQ0]);

assign S0 = ((EN_DUAL &&  dual && (R0_mx[LOGQ0] == 1)) || 
            ( EN_DUAL && !dual &&  R1_mx[LOGQ0] == 1)  || 
            (!EN_DUAL &&           R1_mx[LOGQ0] == 1)) ? Rq0_mx[LOGQ0-1:0] : R0_mx[LOGQ0-1:0];
assign S1 = (R1_mx[LOGQ0] == 1) ? Rq1_mx[LOGQ0-1:0] : R1_mx[LOGQ0-1:0];
assign S  = {S1, S0};

/////////////////////////////////////////////////////////////////////////

/////////////////////////// Sequential Logic ////////////////////////////

generate
    if (FF_IN) begin
        always @(posedge clk) begin
            A_q  <= A;
            B_q  <= B;
            qH_q <= qH;
        end
    end
endgenerate

generate
    if (FF_SUB) begin
        always @(posedge clk) begin
            R0_q <= R0;
            R1_q <= R1;
            Rq0_q <= Rq0;
            Rq1_q <= Rq1;
        end
    end 
endgenerate

generate
    if (FF_OUT) begin
        always @(posedge clk) begin
            S_q <= S;
        end
    end
endgenerate

endmodule
