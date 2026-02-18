`include "../ntt_lite.vh"
// WARNING: mode = dual not verified (single and poly modes are tested).
module encode
   #(
        parameter  LOGQ    = 32,
        parameter  K       = 32,
        localparam LOGLOGQ = $clog2(LOGQ + 1)
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
        output                busy   ,
        output [LOGQ    -1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

reg  [LOGLOGQ:0] ctr;
wire [LOGLOGQ:0] ctr_read;
wire [LOGLOGQ:0] ctr_read_next;
reg  i_valid_q;
reg  [K+LOGQ -1:0] C_q;
wire [LOGQ   -1:0] A_dual;
wire [LOGLOGQ-2:0] logq0_m_d;
wire [LOGQ-1  :0] d_mask_l;
wire [LOGQ-1  :0] d_mask_h;

wire [LOGQ+K-1:0] asr_out;

reg i_ready_q;

wire dual;

wire [LOGLOGQ:0] d_in;
wire [LOGLOGQ:0] d_out;

wire [LOGLOGQ:0] d_in_h;
wire [LOGLOGQ:0] d_out_h;


/////////////////////////////////////////////////////////////////////////




///////////////////////////// Assignments ///////////////////////////////

assign dual = (mode != `MODE_SINGLE);


assign d_in     = ( decode) ? (LOGQ) : ((dual) ? {d,1'b0} : d);
assign d_out    = (~decode) ? (LOGQ) : ((dual) ? {d,1'b0} : d);
assign d_in_h   = d_in >> 1;
assign d_out_h  = ( decode) ? d : (LOGQ>>1);

assign logq0_m_d = LOGQ0 - d_out_h;

assign A_dual = (dual) ? ({A[LOGQ-1:LOGQ0],{(LOGQ0){1'b0}}} >> (LOGQ0 - d_in_h)) ^ A[LOGQ0-1:0] :
                                                                                   A ; 

assign asr_out = C_q >> d_out;

assign d_mask_l = (1 << d_out_h) - 1;
assign d_mask_h = (~dual & decode) ? 0  :
                  (d_mask_l << d_out_h) ;

assign C = ((~dual)) ?  C_q & {d_mask_h ^ d_mask_l}                        : 
                       (C_q & d_mask_l) ^ ((C_q & d_mask_h) << logq0_m_d)  ;

assign o_valid = ctr >= d_out;                                              

assign i_ready = (~decode) ? 1 : (ctr_read_next <= (K)) ? 1'b1 : 1'b0; // some buffer is allowed

assign ctr_read = ctr - ((o_valid) ? d_out : 0);
assign ctr_read_next = (i_valid) ? ctr_read + d_in : ctr_read;

assign busy = i_valid | i_valid_q | o_valid;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Sequential Logic //////////////////////////


always @(posedge clk) begin
    if (rst) begin
        C_q <= 0;
    end
    else begin// if(~decode) begin
        C_q <= ((i_valid & i_ready_q) ? (A_dual << ctr_read) : 0) ^ ((o_valid) ? asr_out : C_q);
    end
    // else if( decode) begin
    //     C_q <= ((i_valid & i_ready_q) ? (A_dual << ctr_read) : 0) ^ ((o_valid) ? asr_out : C_q);
    // end
end


always @(posedge clk) begin
    if (rst) begin
        ctr <= 0;
    end
    // else if (~decode) begin
    //     ctr <= ctr_read_next;// + ((i_valid) ? d_dual : 0);// - ({ctr[LOGLOGQ-1], {(LOGLOGQ-1){1'b0}}});
    // end
    // else if (decode) begin
    else begin
        ctr <= ctr_read_next;//ctr_read + ((i_valid & i_ready_q) ? LOGQ : 0);
    end    
end


always @(posedge clk) begin
    if (rst) begin
        i_valid_q <= 0;
        i_ready_q <= 1;
    end
    else begin
        i_valid_q <= i_valid;
        i_ready_q <= i_ready;
    end
end


/////////////////////////////////////////////////////////////////////////

endmodule