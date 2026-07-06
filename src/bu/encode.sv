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
localparam LOGCTR = $clog2(2*K+LOGQ);

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

reg  [LOGCTR-1:0] ctr;
wire [LOGCTR-1:0] ctr_read;
wire [LOGCTR-1:0] ctr_read_next;
reg  i_valid_d;
reg  [2*K+LOGQ -1:0] C_q;
reg  [2*K+LOGQ -1:0] C_q_next;
wire [LOGQ   -1:0] A_dual;
wire [LOGLOGQ-2:0] logq0_m_d;
reg  [LOGLOGQ-2:0] logq0_m_d_q;
wire [LOGQ-1  :0] d_mask_l;
wire [LOGQ-1  :0] d_mask_h;
reg  [LOGQ-1  :0] d_mask_l_q;
reg  [LOGQ-1  :0] d_mask_h_q;

wire [LOGQ+2*K-1:0] asr_out;

reg i_ready_q;

wire dual;

wire [LOGLOGQ:0] d_in;
wire [LOGLOGQ:0] d_out;

wire [LOGLOGQ:0] d_in_h;
wire [LOGLOGQ:0] d_out_h;

reg [LOGLOGQ:0] d_in_q;
reg [LOGLOGQ:0] d_out_q;

reg [LOGLOGQ:0] d_in_h_q;
reg [LOGLOGQ:0] d_out_h_q;

reg [LOGQ-1:0] A_q;
reg [1:0] mode_q;
reg [LOGLOGQ -1:0] d_q;
reg i_valid_q;
reg decode_q;

reg dual_q;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Assignments ///////////////////////////////

assign dual = (mode_q != `MODE_SINGLE);


assign d_in     = ( decode) ? (LOGQ) : ((dual) ? {d,1'b0} : d);
assign d_out    = (~decode) ? (LOGQ) : ((dual) ? {d,1'b0} : d);
assign d_in_h   = d_in >> 1;
assign d_out_h  = ( decode) ? d : (LOGQ>>1);

assign logq0_m_d = LOGQ0 - d_out_h;

assign d_mask_l = (1 << d_out_h) - 1;
assign d_mask_h = (~dual & decode) ? 0  :
                  (d_mask_l << d_out_h) ;


assign A_dual = (dual_q) ? ({A_q[LOGQ-1:LOGQ0],{(LOGQ0){1'b0}}} >> (LOGQ0 - d_in_h_q)) ^ A_q[LOGQ0-1:0] :
                                                                                       A_q ; 

assign asr_out = C_q >> d_out_q;


assign i_ready = (~decode_q) ? 1 : (ctr_read_next <= (K)) ? 1'b1 : 1'b0; // some buffer is allowed

assign ctr_read = ctr - ((o_valid) ? d_out_q : 0);
assign ctr_read_next = (i_valid_q) ? ctr_read + d_in_q : ctr_read;

assign busy = i_valid | i_valid_q | i_valid_d | o_valid;

assign C_q_next = ((i_valid_q & 1) ? (A_dual << ctr_read) : 0) ^ ((o_valid) ? asr_out : C_q);

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
        i_valid_q <= 0;
    end
    else begin
        i_valid_d <= i_valid_q;
        i_ready_q <= i_ready;
        i_valid_q <= i_valid;
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
    C <=   (~dual_q) ?  C_q_next & {d_mask_h_q ^ d_mask_l_q}                        : 
                       (C_q_next & d_mask_l_q) ^ ((C_q_next & d_mask_h_q) << logq0_m_d_q)  ;
end

always @(posedge clk) begin
    decode_q <= decode;
    d_q <= d;
    A_q <= A;
    mode_q <= mode;
end

always @(posedge clk) begin
    d_in_q <= d_in;
    d_out_q <= d_out;
    d_in_h_q <= d_in_h;
    d_out_h_q <= d_out_h;
    logq0_m_d_q <= logq0_m_d;
    d_mask_l_q <= d_mask_l;
    d_mask_h_q <= d_mask_h;
    dual_q <= dual;
end

/////////////////////////////////////////////////////////////////////////

endmodule