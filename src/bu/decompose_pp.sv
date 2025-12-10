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
wire [LOGQ-1:0] T_half;

/////////////////////////////////////////////////////////////////////////



///////////////////////////// Assignments ///////////////////////////////

assign T_half = (T >> 1);
assign check1 = (A1 == sc);
assign check0 = (A0 == 0);
assign B1 = (~check1) ? A1 : 0;
assign B0 = (~check1) ? A0 : (((~check0) ? A0 : q) - 1'b1);

/////////////////////////////////////////////////////////////////////////




endmodule