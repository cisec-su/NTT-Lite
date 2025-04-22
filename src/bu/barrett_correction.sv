module barrett_correction
   #(
        parameter LOGQ = 32
    )
    (
        input             dual,
        input  [LOGA-1:0] A   ,
        input  [LOGQ-1:0] Q   ,
        output [     1:0] K   ,
        output [LOGQ-1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;
localparam LOGA0 = LOGQ0 + 1;    
localparam LOGA  = LOGA0 << 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// signals ///////////////////////////////////

wire [LOGQ -1:0] Q;
wire [LOGA -1:0] A;
wire [LOGA -1:0] T1;
wire [LOGA0  :0] T1_0;
wire [LOGA0  :0] T1_1;
wire [LOGQ0-1:0] T4_0;
wire [LOGQ0-1:0] T4_1;
wire [1:0] T2;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// subtract Q //////////////////////////////////


addsub_dual #(
    .MODE (1    ),
    .LOGA0(LOGA0),
    .LOGB0(LOGQ0)
) addsub_neg_inst (
    .A   (A     ),
    .B   (Q     ),
    .dual(dual  ),
    .C   (T1    ),
    .K   (T2    )    
);

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Assignments ///////////////////////////////

assign K[0] = ((dual & T2[0]) || (~dual & T2[1])) ? 1'b0 :
                                                    1'b1 ;

assign K[1] = (T2[1]) ? 1'b0 :
                        dual ;




assign T4_0 = (K[0] == 1'b0) ? A     [LOGQ0-1:0] :
                               T1    [LOGQ0-1:0] ;



assign T4_1 = (!dual && K[0] == 1'b0) ? A     [LOGQ0 +: LOGQ0] :
              (!dual && K[0] == 1'b1) ? T1    [LOGQ0 +: LOGQ0] :
              ( dual && K[1] == 1'b0) ? A     [LOGA0 +: LOGQ0] :
                                        T1    [LOGA0 +: LOGQ0] ;

assign C = {T4_1, T4_0};

/////////////////////////////////////////////////////////////////////////

endmodule