`include "../ntt_lite.vh"
// WARNING: mode = dual not verified (single and poly modes are tested).
module encode
   #(
        parameter  LOGQ    = 32,
        parameter  K       = 32,
        localparam LOGLOGQ = $clog2(LOGQ + 1)
    )
    (
        input                     clk    ,
        input                     rst    ,
        input      [LOGQ    -1:0] A      ,
        input      [LOGLOGQ -1:0] d      ,
        input                     decode ,
        input      [         1:0] mode   ,
        input                     i_valid,
        output                    i_ready, // effective for decode
        output reg                o_valid,
        output                    busy   ,
        output reg [LOGQ    -1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

reg  [LOGLOGQ:0] ctr;
wire [LOGLOGQ:0] ctr_read;
wire [LOGLOGQ:0] ctr_read_next;
reg  i_valid_d;
reg  [K+LOGQ -1:0] C_q;
reg  [K+LOGQ -1:0] C_q_next;
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

reg [LOGQ-1:0] A_q;
reg [1:0] mode_q;
reg [LOGLOGQ -1:0] d_q;
reg i_valid_q;
reg decode_q;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Assignments ///////////////////////////////

assign dual = (mode_q != `MODE_SINGLE);


assign d_in     = ( decode_q) ? (LOGQ) : ((dual) ? {d_q,1'b0} : d_q);
assign d_out    = (~decode_q) ? (LOGQ) : ((dual) ? {d_q,1'b0} : d_q);
assign d_in_h   = d_in >> 1;
assign d_out_h  = ( decode_q) ? d_q : (LOGQ>>1);

assign logq0_m_d = LOGQ0 - d_out_h;

assign A_dual = (dual) ? ({A[LOGQ-1:LOGQ0],{(LOGQ0){1'b0}}} >> (LOGQ0 - d_in_h)) ^ A[LOGQ0-1:0] :
                                                                                   A ; 

assign asr_out = C_q >> d_out;

assign d_mask_l = (1 << d_out_h) - 1;
assign d_mask_h = (~dual & decode_q) ? 0  :
                  (d_mask_l << d_out_h) ;

assign i_ready = (~decode_q) ? 1 : (ctr_read_next <= (K)) ? 1'b1 : 1'b0; // some buffer is allowed

assign ctr_read = ctr - ((o_valid) ? d_out : 0);
assign ctr_read_next = (i_valid) ? ctr_read + d_in : ctr_read;

assign busy = i_valid | i_valid_d | o_valid;

assign C_q_next = ((i_valid & i_ready_q) ? (A_dual << ctr_read) : 0) ^ ((o_valid) ? asr_out : C_q);

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Sequential Logic //////////////////////////


always @(posedge clk) begin
    if (rst) begin
        C_q <= 0;
    end
    else begin
        C_q <= C_q_next;
    end
end


always @(posedge clk) begin
    if (rst) begin
        ctr <= 0;
    end
    else begin
        ctr <= ctr_read_next;
    end    
end


always @(posedge clk) begin
    if (rst) begin
        i_valid_d <= 0;
        i_ready_q <= 1;
    end
    else begin
        i_valid_d <= i_valid;
        i_ready_q <= i_ready;
    end
end


always @(posedge clk) begin
    if (rst) begin
        o_valid <= 0;
    end
    else begin
        o_valid <= ctr_read_next >= d_out;
    end
end

always @(posedge clk) begin
    C <=   ((~dual)) ?  C_q_next & {d_mask_h ^ d_mask_l}                        : 
                       (C_q_next & d_mask_l) ^ ((C_q_next & d_mask_h) << logq0_m_d)  ;
end

always @(posedge clk) begin
    if (rst) begin
        i_valid_q <= 0;
    end
    else begin
        i_valid_q <= i_valid;
    end
    decode_q <= decode;
    d_q <= d;
    A_q <= A;
    mode_q <= mode;
end

/////////////////////////////////////////////////////////////////////////

endmodule