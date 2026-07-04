module modsub
   #(
        parameter int unsigned LOGQ   = 32,
        parameter bit          FF_IN  = 0 ,
        parameter bit          FF_OUT = 0
    )
    (
        input             clk ,
        input  [LOGQ-1:0] A   ,
        input  [LOGQ-1:0] B   ,
        input  [LOGQ-1:0] Q   ,
        input             dual,
        input             rd_en,
        output            corr0,
        output            corr1,
        output            corr,
        output [LOGQ+1:0] T   ,
        output [LOGQ-1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

wire [LOGQ-1:0] A_mx;
reg  [LOGQ-1:0] A_q ;
wire [LOGQ-1:0] B_mx;
reg  [LOGQ-1:0] B_q ;
wire [LOGQ-1:0] C_mx;
reg  [LOGQ-1:0] C_q ;

wire [LOGQ0:0] T0;
wire [LOGQ0:0] T1;

wire [LOGQ0:0] Tq0;
wire [LOGQ0:0] Tq1;

wire [LOGQ0-1:0] C0;
wire [LOGQ0-1:0] C1;

wire c;

wire corr_mx, corr0_mx, corr1_mx;
reg  corr_q, corr0_q, corr1_q;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Pipeline Steps ////////////////////////////

assign A_mx  = (FF_IN ) ? A_q : A;
assign B_mx  = (FF_IN ) ? B_q : B;
assign C     = (FF_OUT) ? C_q : C_mx;
assign corr  = (FF_OUT) ? corr_q  : corr_mx ;
assign corr0 = (FF_OUT) ? corr0_q : corr0_mx;
assign corr1 = (FF_OUT) ? corr1_q : corr1_mx;

always @(posedge clk) begin
    if (FF_IN) begin
        A_q <= A;
        B_q <= B;
    end
    if (FF_OUT) begin
        C_q <= C_mx;
        corr_q  <= corr_mx ;
        corr0_q <= corr0_mx;
        corr1_q <= corr1_mx;
    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Assignments ///////////////////////////////

assign T0 = A_mx[LOGQ0-1:    0] - B_mx[LOGQ0-1:    0];
assign T1 = A_mx[LOGQ -1:LOGQ0] - B_mx[LOGQ -1:LOGQ0] - ((~dual) & T0[LOGQ0]);

assign c  = dual & T0[LOGQ0];

assign Tq0 = {c, T0[LOGQ0-1:0]} + Q[LOGQ0-1:0];
assign Tq1 = T1 + Q[LOGQ-1:LOGQ0] + ((~dual) & Tq0[LOGQ0]);

assign corr0_mx = ((dual && (T0[LOGQ0] == 1)) || (!dual &&  T1[LOGQ0] == 1));
assign corr1_mx = (T1[LOGQ0] == 1);

assign C0 = (corr0_mx && rd_en) ? Tq0[LOGQ0-1:0] : T0[LOGQ0-1:0];
assign C1 = (corr1_mx && rd_en) ? Tq1[LOGQ0-1:0] : T1[LOGQ0-1:0];

assign corr_mx = (dual) ? (corr0_mx | corr1_mx) : corr1_mx;

assign T    = {({T1[LOGQ0], T1} << dual) ^ c, T0[LOGQ0-1:0]};
assign C_mx = {C1, C0};

/////////////////////////////////////////////////////////////////////////


endmodule