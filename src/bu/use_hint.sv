//////////////////////////////////////
// Copyright (c) 2026 enCRYPTON Labs
// All rights reserved.
//////////////////////////////////////
module use_hint
   #(
        parameter LOGQ       = 32,
        parameter HINT_DELAY = 0 ,
        parameter FF_OUT     = 1
    )
    (
        input                 clk ,
        input  [LOGQ    -1:0] A0  ,
        input  [LOGQ    -1:0] A1  ,
        input  [LOGQ    -1:0] Q   ,
        input  [LOGQ    -1:0] M   ,        
        input                 hint,
        output [LOGQ    -1:0] B
    );




wire hint_q;

wire inc, dec;

wire [LOGQ-1:0] Q_half;
wire [LOGQ-1:0] B_int;
wire [LOGQ-1:0] B_red;
reg  [LOGQ-1:0] B_q;

/////////////////////////////////////////////////////////////////////////


shiftreg #(
    .SHIFT(HINT_DELAY),
    .DATA (1         )
) sre_1 (
    .clk     (clk   ),
    .rst     (1'b0  ),
    .data_in (hint  ),
    .data_out(hint_q)
);



///////////////////////////// Assignments ///////////////////////////////

assign Q_half = Q >> 1;
assign dec = (A0 == {LOGQ{1'b0}} || (A0 > (Q_half))) ? 1'b1 : 1'b0;

assign B_int = (hint_q == 1'b0) ?  A1          :
               (dec           ) ?  A1 - 1'b1   :
                                   A1 + 1'b1   ;

// simple modular reduction
assign B_red = (B_int == {LOGQ{1'b1}}) ?     M - 1'b1 :
               (B_int == M           ) ? {LOGQ{1'b0}} :
                                                B_int ;

assign B = (FF_OUT) ? B_q : B_red;

/////////////////////////////////////////////////////////////////////////

                                            
if (FF_OUT) begin
    always @(posedge clk) begin
        B_q <= B_red;
    end
end


endmodule