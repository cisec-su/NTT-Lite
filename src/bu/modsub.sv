module modsub
    #(
        parameter LOGQ = 32
    )
    (
        input  [LOGQ-1:0] A   ,
        input  [LOGQ-1:0] B   ,
        input  [LOGQ-1:0] Q   ,
        input             dual,
        output            corr,
        output [LOGQ+1:0] T   ,
        output [LOGQ-1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

wire [LOGQ0:0] T0;
wire [LOGQ0:0] T1;

wire [LOGQ0:0] Tq0;
wire [LOGQ0:0] Tq1;

wire [LOGQ0-1:0] C0;
wire [LOGQ0-1:0] C1;

wire c;

wire corr0, corr1;

/////////////////////////////////////////////////////////////////////////


///////////////////////////// Assignments ///////////////////////////////

assign T0 = A[LOGQ0-1:    0] - B[LOGQ0-1:    0];
assign T1 = A[LOGQ -1:LOGQ0] - B[LOGQ -1:LOGQ0] - ((~dual) & T0[LOGQ0]);

assign c  = dual & T0[LOGQ0];

assign Tq0 = {c, T0[LOGQ0-1:0]} + Q[LOGQ0-1:0];
assign Tq1 = T1 + Q[LOGQ-1:LOGQ0] + ((~dual) & Tq0[LOGQ0]);

assign corr0 = ((dual && (T0[LOGQ0] == 1)) || (!dual &&  T1[LOGQ0] == 1));
assign corr1 = (T1[LOGQ0] == 1);

assign C0 = (corr0) ? Tq0[LOGQ0-1:0] : T0[LOGQ0-1:0];
assign C1 = (corr1) ? Tq1[LOGQ0-1:0] : T1[LOGQ0-1:0];

assign corr = (dual) ? (corr0 | corr1) : corr1;

assign T = {({T1[LOGQ0], T1} << dual) ^ c, T0[LOGQ0-1:0]};
assign C = {C1, C0};

/////////////////////////////////////////////////////////////////////////


endmodule