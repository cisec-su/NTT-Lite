`include "ntt_lite.vh"
// WARNING: mode = dual not verified (single and poly modes are tested).
module encode
   #(
        parameter LOGQ = 32,
        parameter K    = 32
    )
    (
        input                 clk    ,
        input                 rst    ,
        input  [LOGQ    -1:0] A      ,
        input  [LOGLOGQ -1:0] d      ,
        input                 decode ,
        input  [         1:0] mode   ,
        input                 i_valid,
        output                i_ready, // effective for decode
        output                o_valid,
        output [LOGQ    -1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));
localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

reg  [LOGLOGQ:0] ctr;
wire [LOGLOGQ:0] ctr_read;
wire [LOGLOGQ:0] d_dual;
reg  i_valid_q;
reg  [K+LOGQ -1:0] C_q;
wire [LOGQ   -1:0] A_dual;
wire [LOGLOGQ-2:0] logq0_m_d;
wire [LOGQ-1  :0] d_mask_l;
wire [LOGQ-1  :0] d_mask_h;

wire [LOGQ+K-1:0] asr_out;
wire  asr_dual;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Assignments ///////////////////////////////

assign logq0_m_d = LOGQ0 - d;

assign A_dual = (mode == `MODE_POLY) ? ({A[LOGQ-1:LOGQ0],{(LOGQ0){1'b0}}} >> logq0_m_d) ^ A[LOGQ0-1:0] :
                                                                                                     A ; 
assign d_dual = (mode != `MODE_POLY) ? d        : 
                                      {d, 1'b0} ;

assign asr_dual = (mode == `MODE_DUAL) ? 1'b1 :
                                         1'b0 ;

assign d_mask_l = (1 << d) - 1;
assign d_mask_h = (mode == `MODE_SINGLE) ? 0                                                :
                                           (d_mask_l << ((mode == `MODE_DUAL) ? LOGQ0 : d)) ;

assign C = (decode && (mode != `MODE_POLY)) ?  C_q & {d_mask_h, d_mask_l}                        : 
           (decode                        ) ? (C_q & d_mask_l) ^ ((C_q & d_mask_h) << logq0_m_d) : 
                                               C_q                                               ;

assign o_valid = (~decode & ctr[LOGLOGQ-1]) || (decode && (ctr >= d_dual));                                              

assign i_ready = (ctr_read <= (K)) ? 1'b1 : 1'b0; // some buffer is allowed

assign ctr_read = ctr - ((ctr >= d_dual) ? d_dual : 0);

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Shift Right ///////////////////////////////

asr #(
    .LOGQ(LOGQ + K)
) asr0 (
    .A   (C_q     ),
    .d   (d_dual  ),
    .dual(asr_dual),
    .C   (asr_out )
);

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Sequential Logic //////////////////////////


always @(posedge clk) begin
    if (rst) begin
        C_q <= 0;
    end
    else if(~decode) begin
        C_q <= ((o_valid) ? 0 : C_q) ^ ((i_valid) ? (A_dual << ctr[LOGLOGQ-2:0]) : 0);
    end
    else if( decode) begin
        C_q <= ((i_valid & i_ready) ? (A << ctr_read) : 0) ^ asr_out;
    end
end


always @(posedge clk) begin
    if (rst) begin
        ctr <= 0;
    end
    else if (~decode & i_valid) begin
        ctr <= ctr + d_dual - ({ctr[LOGLOGQ-1], {(LOGLOGQ-1){1'b0}}});
    end
    else if (decode) begin
        ctr <= ctr_read + ((i_valid & i_ready) ? LOGQ : 0);
    end    
end


always @(posedge clk) begin
    if (rst) begin
        i_valid_q <= 0;
    end
    else begin
        i_valid_q <= i_valid;
    end
end


/////////////////////////////////////////////////////////////////////////

endmodule