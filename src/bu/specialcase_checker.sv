//////////////////////////////////////
// Copyright (c) 2026 enCRYPTON Labs
// All rights reserved.
//////////////////////////////////////
module specialcase_checker
   #(
        parameter LOGQ = 32
    )
    (
        input  [LOGQ    -1:0] A0  , // A0 == 0 check only for single mode
        input  [LOGQ    -1:0] A1  ,
        input  [LOGQ    -1:0] S   ,
        input  [LOGQ    -1:0] Q   ,
        input                 dual,
        output [LOGQ    -1:0] B0  ,
        output [LOGQ    -1:0] B1  ,
        output                sc
    );

localparam LOGQ0 = LOGQ >> 1;


wire sc1_0, sc1_1;
wire sc1_0_d, sc1_1_d;
wire sc0, sc1;

wire [LOGQ0-1:0] b1_0, b1_1;

/////////////////////////////////////////////////////////////////////////



///////////////////////////// Assignments ///////////////////////////////

// both used by compress and decompose
assign sc1_0 = (A1[LOGQ0-1:    0] == S[LOGQ0-1:    0]);
assign sc1_1 = (A1[LOGQ -1:LOGQ0] == S[LOGQ -1:LOGQ0]);
assign sc1     = sc1_1 & sc1_0;

assign sc0     = A0 == {LOGQ{1'b0}};

assign sc1_0_d = (dual & sc1_0) | (~dual & sc1);
assign sc1_1_d = (dual & sc1_1) | (~dual & sc1);

assign b1_0 = sc1_0_d ? {LOGQ0{1'b0}} : A1[LOGQ0-1:    0];
assign b1_1 = sc1_1_d ? {LOGQ0{1'b0}} : A1[ LOGQ-1:LOGQ0];

assign B1 = {b1_1, b1_0};
assign B0 = (~sc1) ? A0 : ((sc0 ? Q : A0) - 1'b1);

assign sc = sc1 & ~sc0; // Dilithium's make-hint

/////////////////////////////////////////////////////////////////////////




endmodule