//////////////////////////////////////
// Copyright (c) 2026 enCRYPTON Labs
// All rights reserved.
//////////////////////////////////////
module poly_acc_ntt_addr_gen
   #(   
        parameter  int unsigned LOGN       = 8 ,
        parameter  int unsigned LOGQ       = 32,
        localparam int unsigned LOGLOGN    = $clog2(LOGN+1)
    )
    (
        input  wire               clk       ,
        input  wire               rst       ,
        input  wire               is_sum    ,
        input  wire               ren       ,
        input  wire               forward   ,
        input  wire [LOGLOGN-1:0] logn      ,
        input  wire [LOGLOGN-1:0] logn_m1   ,
        input  wire    [LOGN-1:0] ctr0      ,
        input  wire    [LOGN-1:0] ctr1      ,
        input  wire    [LOGN-1:0] ctr2      ,
        input  wire    [LOGQ-1:0] A_o       ,
        input  wire    [LOGQ-1:0] B_o       ,
        input  wire               bu_o_valid,
        output wire    [LOGQ-1:0] A_i       ,
        output wire    [LOGQ-1:0] B_i       ,
        output wire    [LOGQ-1:0] PSI_i     ,
        output wire               o_valid   ,

        output wire               p0_wen  ,
        output wire               p0_ren  ,
        output wire    [LOGN-2:0] p0_waddr,
        output wire    [LOGQ-1:0] p0_din  ,
        output wire    [LOGN-2:0] p0_raddr,
        input  wire    [LOGQ-1:0] p0_dout ,
  
        output wire               p1_wen  ,
        output wire               p1_ren  ,
        output wire    [LOGN-2:0] p1_waddr,
        output wire    [LOGQ-1:0] p1_din  ,
        output wire    [LOGN-2:0] p1_raddr,
        input  wire    [LOGQ-1:0] p1_dout ,

        input  wire    [LOGQ-1:0] t_dout  ,
        output wire    [LOGN-1:0] t_raddr

    );

wire [LOGN-1:0] maskS; // stage mask
wire [LOGN-1:0] maskIS; // stage inv. mask
wire [LOGN-1:0] twiddle_ntt_ctr1;

wire ntt_o_valid;
wire sr_ntt;
wire flag_o;
wire flag_i;
reg  flag_i_d;
wire ntt_isfirst_r, ntt_isfirst_w;
wire [LOGN-1:0] ntt_rshift;
wire [LOGN-1:0] ntt_wshift;
wire [LOGN-1:0] ntt_rmask;
wire [LOGN-1:0] ntt_wmask;
reg bu_o_valid_q;
reg  [LOGQ-1:0] p0_dout_q;
reg  [LOGQ-1:0] p1_dout_q;
reg  [LOGQ-1:0] t_dout_q;
reg  [LOGQ-1:0] B_o_q;
reg  [LOGN-1:0] ctr2_d;
reg  [LOGN-1:0] ctr2_q;
wire [LOGLOGN-1:0] logn_ctr2;
wire [LOGLOGN-1:0] logn_m1_ctr2;

wire [LOGN-2:0] ntt_raddr;
wire [LOGN-2:0] ntt_waddr;
wire [LOGN-2:0] d_raddr_mx;
wire [LOGN-2:0] d_waddr_mx;
reg  [LOGN-2:0] d_waddr_q;

wire sum_o_valid;
wire [LOGN-2:0] sum_raddr;
wire [LOGN-2:0] sum_waddr;


reg o_valid_q;

assign logn_ctr2     = logn - ctr2;
assign logn_m1_ctr2  = logn_ctr2 - 1;

// SUM ADDRESS GEN ///////////////////
assign sum_o_valid = (ctr2_d == logn_m1) ? bu_o_valid : bu_o_valid_q;
assign sum_raddr   = ctr1 << ctr2;
assign sum_waddr   = ctr0 << ctr2_d;
//////////////////////////////////////

// NTT ADDRESS GEN ///////////////////
assign sr_ntt        = (forward && ctr2 != 0) ? 1'b1 : ((~forward) && ctr2_q != logn_m1) ? 1'b1 : 1'b0;
assign ntt_o_valid   = (forward && ctr2_d == 0) ? bu_o_valid : ((~forward) && ctr2_d == logn_m1) ? bu_o_valid : bu_o_valid_q;

assign flag_o        = ctr0[0];
assign flag_i        = ctr1[0];

assign ntt_isfirst_r = (forward) ? (ctr2   != 0) : (ctr2   != logn_m1);
assign ntt_isfirst_w = (forward) ? (ctr2_d != 0) : (ctr2_d != logn_m1);

assign ntt_rmask     = (ntt_isfirst_r) ? (1 << (((forward) ? logn_ctr2     : ctr2   + 1))) - 1 : 1;
assign ntt_wmask     = (ntt_isfirst_w) ? (1 << (((forward) ? logn - ctr2_d : ctr2_d + 1))) - 1 : 1;

assign ntt_rshift    = (!ntt_isfirst_r) ? 0 : (forward) ? logn_m1_ctr2     : ctr2  ;
assign ntt_wshift    = (!ntt_isfirst_w) ? 0 : (forward) ? logn_m1 - ctr2_d : ctr2_d;

assign ntt_raddr       = (ctr1[0] << ntt_rshift) + ((ctr1 & ntt_rmask) >> 1) + (ctr1 & ~ntt_rmask);
assign ntt_waddr       = (ctr0[0] << ntt_wshift) + ((ctr0 & ntt_wmask) >> 1) + (ctr0 & ~ntt_wmask);

assign maskS             = (1 << ctr2) - 1 ;
assign maskIS            = ((1 << (logn_m1_ctr2)) - 1);

assign twiddle_ntt_ctr1  = (forward) ? (ctr1[0] << (ctr2 - 1))                + (ctr1 >> (logn_ctr2)) : 
                                       (ctr1[0] << ((logn_m1 - 1'b1) - ctr2)) + (ctr1 >> (ctr2 + 1 )) ;

assign t_raddr           = (forward) ? (maskS  + twiddle_ntt_ctr1) : 
                                       (maskIS + twiddle_ntt_ctr1) ;

assign A_i   = (!sr_ntt) ? p0_dout    : (flag_i_d) ? p0_dout_q : p0_dout_q;
assign B_i   = (!sr_ntt) ? p1_dout    : (flag_i_d) ? p0_dout   : p1_dout_q;
assign PSI_i = ( sr_ntt) ? t_dout_q : t_dout;
//////////////////////////////////////

assign d_raddr_mx = (is_sum) ? sum_raddr : ntt_raddr;
assign d_waddr_mx = (is_sum) ? sum_waddr : ntt_waddr;

assign p0_wen   = o_valid;
assign p0_ren   = ren;
assign p0_waddr = d_waddr_mx;
assign p0_din   = (flag_o & ntt_isfirst_w) ? B_o_q : A_o;
assign p0_raddr = d_raddr_mx;

assign p1_wen   = o_valid_q;
assign p1_ren   = ren;
assign p1_waddr = d_waddr_q;
assign p1_din   = (flag_o & ntt_isfirst_w) ? A_o   : B_o_q;
assign p1_raddr = d_raddr_mx;

assign o_valid    = (is_sum) ?  sum_o_valid : ntt_o_valid;

assign ctr2_d_set = (is_sum) ? ~sum_o_valid : ~bu_o_valid;



always @(posedge clk) begin
    bu_o_valid_q <= bu_o_valid;
end

always @(posedge clk) begin
    flag_i_d <= flag_i;
end

always @(posedge clk) begin
    if (flag_i_d == 1'b0) begin
        p0_dout_q <= p0_dout;
        p1_dout_q <= p1_dout;
    end
    else begin
        p0_dout_q <= p1_dout_q;
        p1_dout_q <= p1_dout;
    end
    t_dout_q <= t_dout;
end

always @(posedge clk) begin
    B_o_q       <= B_o;
    ctr2_q      <= ctr2;
    o_valid_q   <= o_valid;
    d_waddr_q   <= d_waddr_mx;
end

always @(posedge clk) begin
    if (ctr2_d_set)
        ctr2_d <= ctr2;
end
                                       
endmodule