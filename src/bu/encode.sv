`include "../ntt_lite.vh"

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

wire [LOGQ-1:0] C_int;
wire o_valid_int;


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

assign C_int = ((~dual)) ?  C_q & {d_mask_h ^ d_mask_l}                        : 
                           (C_q & d_mask_l) ^ ((C_q & d_mask_h) << logq0_m_d)  ;

assign o_valid_int = ctr >= d_out;                                              

assign i_ready = (~decode) ? 1 : (ctr_read_next <= (K)) ? 1'b1 : 1'b0;

assign ctr_read = ctr - ((o_valid_int) ? d_out : 0);
assign ctr_read_next = (i_valid) ? ctr_read + d_in : ctr_read;

assign busy = i_valid | i_valid_q | o_valid_int | o_valid;

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
    if (rst) begin
        o_valid <= 0;
    end
    else begin
        o_valid <= o_valid_int;
    end
    C <= C_int;
end


/////////////////////////////////////////////////////////////////////////

endmodule