module barrett_correction
   #(
        parameter LOGQ = 32
    )
    (
        input             dual,
        input  [LOGA-1:0] A   ,
        output [LOGQ-1:0] C   ,
        input  [LOGQ-1:0] Q
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGA  = (LOGQ0 + 2) << 1;
localparam LOGA0 = LOGA >> 1;
localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// signals ///////////////////////////////////

wire [LOGQ  -1:0] Q;
wire [LOGA  -1:0] A;
wire [LOGA  -1:0] T1;
wire [LOGA0   :0] T1_0;
wire [LOGA0-1 :0] T1_1;
wire [LOGA  -1:0] T1;
wire [LOGA  -1:0] T2;
wire [LOGA0   :0] T2_0;
wire [LOGA0-1 :0] T2_1;
wire [LOGA  -1:0] T2;
wire [LOGA  -1:0] T3;
wire [LOGA0   :0] T3_0;
wire [LOGA0-1 :0] T3_1;
wire [LOGA  -1:0] T3;
wire [LOGQ0-1 :0] T4_0;
wire [LOGQ0-1 :0] T4_1;

/////////////////////////////////////////////////////////////////////////

assign T1_0 = A[LOGA0-1:     0] - Q[LOGA0-1:0];
assign T1_1 = A[LOGA  -1:LOGA0] - ((dual) ? Q[LOGA0-1:0] : (Q >> LOGA0) + T1_0[LOGA0]);
assign T1   = {T1_1, T1_0[LOGA0-1:0]};

assign T2_0 = A[LOGA0-1:     0] - {Q[LOGA0-2:0], 1'b0};
assign T2_1 = A[LOGA  -1:LOGA0] - ((dual) ? {Q, 1'b0} : ({Q, 1'b0} >> LOGA0) + T2_0[LOGA0]);
assign T2   = {T2_1, T2_0[LOGA0-1:0]};

assign T3_0 = T2[LOGA0-1:     0] - Q[LOGA0-1:0];
assign T3_1 = T2[LOGA  -1:LOGA0] - ((dual) ? Q : (Q >> LOGA0) + T3_0[LOGA0]);
assign T3   = {T3_1, T3_0[LOGA0-1:0]};


assign T4_0 = ((dual && T1[LOGQ0+1] == 1'b1) || (!dual && T1[LOGQ+1] == 1'b1)) ? A     [LOGQ0-1:0] :
              ((dual && T2[LOGQ0+1] == 1'b1) || (!dual && T2[LOGQ+1] == 1'b1)) ? T1    [LOGQ0-1:0] :
              ((dual && T3[LOGQ0+1] == 1'b1) || (!dual && T3[LOGQ+1] == 1'b1)) ? T2    [LOGQ0-1:0] : 
                                                                                 T3    [LOGQ0-1:0] ;

assign T4_1 = (!dual && T1[LOGQ         +1] == 1'b1) ? A     [LOGQ0 +: LOGQ0] :
              (!dual && T2[LOGQ         +1] == 1'b1) ? T1    [LOGQ0 +: LOGQ0] :
              (!dual && T3[LOGQ         +1] == 1'b1) ? T2    [LOGQ0 +: LOGQ0] : 
              (!dual                               ) ? T3    [LOGQ0 +: LOGQ0] :
              ( dual && T1[LOGA0+LOGQ0  +1] == 1'b1) ? A     [LOGA0 +: LOGQ0] :
              ( dual && T2[LOGA0+LOGQ0  +1] == 1'b1) ? T1    [LOGA0 +: LOGQ0] :
              ( dual && T3[LOGA0+LOGQ0  +1] == 1'b1) ? T2    [LOGA0 +: LOGQ0] : 
                                                       T3    [LOGA0 +: LOGQ0] ;

assign C = {T4_1, T4_0};


endmodule