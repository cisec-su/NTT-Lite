 /* Decompose Post-Process
    !!!!! Not Supported by DUAL MODE */
module decompose_pp
   #(
        parameter LOGQ = 32
    )
    (
        input  [LOGQ    -1:0] A0  ,
        input  [LOGQ    -1:0] A1  ,
        input  [LOGQ    -1:0] q   ,
        input  [LOGQ    -1:0] sc  ,
        input  [LOGQ    -1:0] T   ,
        output [LOGQ    -1:0] B0  ,
        output [LOGQ    -1:0] B1
    );



///////////////////////// Signals Declaration ///////////////////////////

wire check0;
wire check1;
wire check2;
wire [LOGQ-1:0] T_half;

wire [LOGQ-1:0] A0_center;

/////////////////////////////////////////////////////////////////////////



///////////////////////////// Assignments ///////////////////////////////

assign T_half = (T >> 1);

assign check1 = (A1 == sc);
assign check0 = (A0 == 0);
assign check2 = (A0 > (T_half)) || ((T_half[0] == 1'b0) && A0 == (T_half));

assign A0_center = (check2) ? A0 + q - T : A0;

assign B1 = (~check1) ? A1 : 0;
assign B0 = (~check1) ? A0_center : (((~check0) ? A0_center : q) - 1'b1);

/////////////////////////////////////////////////////////////////////////




endmodule