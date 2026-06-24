`include "poly_acc.vh"
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
        input                 fn_decomp, // effective for decode
        input  [         1:0] mode   ,
        input                 i_valid,
        input                 bigend , // effective for decode
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
wire [LOGQ   -1:0] C_int;
wire [LOGQ   -1:0] C_rev;
wire [LOGQ   -1:0] C_rev_dual;
wire [LOGQ   -1:0] A_rev;
wire [LOGQ   -1:0] A_dual;
wire [LOGLOGQ-2:0] logq0_m_d;
wire [LOGQ-1  :0] d_mask_l;
wire [LOGQ-1  :0] d_mask_h;


wire [LOGQ+K-1:0] asr_out;
wire [LOGQ  -1:0] asr_out1;

reg i_ready_q;

wire dual;

reg bigend_q;
reg [1:0] mode_q;
reg [LOGLOGQ -1:0] d_q;

wire [LOGLOGQ:0] d_in;
wire [LOGLOGQ:0] d_out;

wire [LOGLOGQ:0] d_in_h;
wire [LOGLOGQ:0] d_out_h;

reg fn_decomp_q;
wire [LOGLOGQ:0] fn_decomp_d;
wire [LOGQ -1:0] fn_decomp_B;
wire             fn_decomp_o_valid, fn_decomp_o_valid0;

wire o_valid_int;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Assignments ///////////////////////////////

assign dual = (mode_q != `MODE_SINGLE);


assign d_in     = ( decode) ? (LOGQ) :                                ((dual) ? {d_q,1'b0} : d_q);
assign d_out    = (~decode) ? (LOGQ) : ((fn_decomp_q) ? fn_decomp_d : ((dual) ? {d_q,1'b0} : d_q));
assign d_in_h   = d_in >> 1;
assign d_out_h  = ( decode) ? d_q : (LOGQ>>1);

assign logq0_m_d = LOGQ0 - d_out_h;

// big-endian logic below
for (genvar i = 0; i < LOGQ >> 3; i++) begin
    for (genvar j = 0; j < 8; j++) begin
        assign A_rev[(i << 3) + (8 - j - 1)] = (bigend_q) ?  A[(i << 3) + j] : A[(i << 3) + (8 - j - 1)];
    end
end
// big-endian logic end


assign A_dual = (dual) ? ({A_rev[LOGQ-1:LOGQ0],{(LOGQ0){1'b0}}} >> (LOGQ0 - d_in_h)) ^ A_rev[LOGQ0-1:0] :
                                                                                       A_rev ; 

assign asr_out = C_q >> d_out;

assign d_mask_l = (1 << d_out_h) - 1;
assign d_mask_h = (~dual & decode) ? 0  :
                  (d_mask_l << d_out_h) ;

assign C_int = ((~dual)) ?  C_q & {d_mask_h ^ d_mask_l}                        : 
                       (    C_q & d_mask_l) ^ ((C_q & d_mask_h) << logq0_m_d)  ;

// big-endian logic below
for (genvar i = 0; i < LOGQ; i++) begin
    assign C_rev[i] = C_int[LOGQ - 1 - i];
end
            
for (genvar i = 0; i < LOGQ; i++) begin
    localparam idx_dual = (i + LOGQ0) & (LOGQ - 1);
    assign C_rev_dual[i] = (~bigend_q) ? C_int[i       ] :
                           (     dual) ? C_rev[idx_dual] :
                                         C_rev[i       ] ;
end
// big-endian logic end

assign C = (fn_decomp_q) ? fn_decomp_B : (bigend_q) ? asr_out1 : C_int[LOGQ-1:0];


assign o_valid_int = (ctr >= d_out) && (fn_decomp_o_valid0 || (!fn_decomp_q));

assign i_ready = (~decode) ? 1 : (ctr_read_next <= (K)) ? 1'b1 : 1'b0; // some buffer is allowed

assign ctr_read = ctr - ((o_valid_int) ? d_out : 0);
assign ctr_read_next = (i_valid) ? ctr_read + d_in : ctr_read;

assign busy = i_valid | i_valid_q | o_valid_int;
assign o_valid = (fn_decomp_q) ? (fn_decomp_o_valid && o_valid_int) : o_valid_int;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// ASR with dual mode for Big-Endian /////////

asr #(
    .LOGQ(LOGQ)
) asr (
    .A   (C_rev_dual      ),
    .d   ({1'b0,logq0_m_d}),
    .dual(dual            ),
    .C   (asr_out1        )
);

/////////////////////////////////////////////////////////////////////////




///////////////////////////// ASR with dual mode for Big-Endian /////////

fndecomp_pp #(
    .LOGQ  (LOGQ)
) fndecomp_pp_inst (
    .clk(clk),
    .rst(rst),
    .A  (C_q),
    .o_valid0(fn_decomp_o_valid0),
    .o_valid (fn_decomp_o_valid ),
    .d  (fn_decomp_d),
    .B  (fn_decomp_B)
);

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Sequential Logic //////////////////////////


always @(posedge clk) begin
    if (rst) begin
        C_q <= 0;
    end
    else begin
        C_q <= ((i_valid & i_ready_q) ? (A_dual << ctr_read) : 0) ^ ((o_valid_int) ? asr_out : C_q);
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
        i_valid_q <= 0;
        i_ready_q <= 1;
    end
    else begin
        i_valid_q <= i_valid;
        i_ready_q <= i_ready;
    end
end


always @(posedge clk) begin
    bigend_q <= bigend;
    d_q <= d;
    mode_q <= mode;
    fn_decomp_q <= fn_decomp;
end


/////////////////////////////////////////////////////////////////////////

endmodule