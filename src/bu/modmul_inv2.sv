module modmul_inv2
   #(
        parameter LOGQ = 32
    )
    (
        input  [LOGQ    -1:0] A   ,
        input  [LOGQ    -1:0] inv2,
        input  [LOGQ    -1:0] Q   ,        
        input                 dual,
        output [LOGQ    -1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));    
localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

wire [LOGLOGQ-1:0] one;
wire [LOGQ   -1:0] asr_out;
wire [LOGQ   -1:0] inv2_dual;
wire [LOGQ   -1:0] add_out;

/////////////////////////////////////////////////////////////////////////



///////////////////////////// Assignments ///////////////////////////////

assign one = 1;
assign inv2_dual = (dual) ? {inv2[LOGQ0-1:0], inv2[LOGQ0-1:0]} : 
                             inv2                              ;

assign C[LOGQ0-1:    0] = (                 A[0]                 ) ? add_out[LOGQ0-1:    0] : 
                                                                     asr_out[LOGQ0-1:    0] ;

assign C[LOGQ -1:LOGQ0] = ((dual & A[LOGQ0]) | (~dual & A[0])) ? add_out[LOGQ -1:LOGQ0] : 
                                                                 asr_out[LOGQ -1:LOGQ0] ;


/////////////////////////////////////////////////////////////////////////


///////////////////////////// Shift-Right and Add 2^-1 //////////////////

asr #(
    .LOGQ(LOGQ)
) asr (
    .A   (A      ),
    .d   (one    ),
    .dual(dual   ),
    .C   (asr_out)
);


modadd  #(
    .LOGQ(LOGQ)
) ma (
    .A   (asr_out  ),
    .B   (inv2_dual),
    .dual(dual     ),
    .Q   (Q        ),
    .C   (add_out  ) 
);

/////////////////////////////////////////////////////////////////////////


endmodule