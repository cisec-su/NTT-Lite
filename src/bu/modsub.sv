module modsub
    #(
        parameter LOGQ = 32
    )
    (
        input  [LOGQ-1:0] A   ,
        input  [LOGQ-1:0] B   ,
        input  [LOGQ-1:0] q   ,
        input             dual,
        output [LOGQ+1:0] C   ,
        output [LOGQ-1:0] T
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

wire [LOGQ0:0] C0;
wire [LOGQ0:0] C1;

wire [LOGQ0:0] Cq0;
wire [LOGQ0:0] Cq1;

wire [LOGQ0-1:0] T0;
wire [LOGQ0-1:0] T1;

wire c;

/////////////////////////////////////////////////////////////////////////


///////////////////////////// Assignments ///////////////////////////////

assign C0 = A[LOGQ0-1:    0] - B[LOGQ0-1:    0];
assign C1 = A[LOGQ -1:LOGQ0] - B[LOGQ -1:LOGQ0] - ((~dual) & C0[LOGQ0]);

assign c  = dual & C0[LOGQ0];

assign Cq0 = {c, C0[LOGQ0-1:0]} + q[LOGQ0-1:0];
assign Cq1 = C1 + q[LOGQ-1:LOGQ0] + ((~dual) & Cq0[LOGQ0]);

assign T0 = ((dual && (C0[LOGQ0] == 1)) || (!dual &&  C1[LOGQ0] == 1)) ? Cq0[LOGQ0-1:0] : C0[LOGQ0-1:0];
assign T1 = (C1[LOGQ0] == 1) ? Cq1[LOGQ0-1:0] : C1[LOGQ0-1:0];

assign C = {({C1[LOGQ0], C1} << dual) ^ c, C0[LOGQ0-1:0]};
assign T = {T1, T0};

/////////////////////////////////////////////////////////////////////////


endmodule