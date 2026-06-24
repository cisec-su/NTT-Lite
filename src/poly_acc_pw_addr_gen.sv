//////////////////////////////////////
// Copyright (c) 2026 enCRYPTON Labs
// All rights reserved.
//////////////////////////////////////
module poly_acc_pw_addr_gen
   #(
        parameter  LOGQ    = 32  ,
        parameter  LOGN    = 8   ,
        parameter  L       = 10  ,
        localparam LOGLOGN = $clog2(LOGN+1)
    )
    (   
        input  wire               clk     ,
        input  wire               rst     ,
        input  wire [LOGLOGN-1:0] logn_m1 ,

        input  wire               p_wen   ,
        input  wire               p_ren   ,
        input  wire    [LOGN-1:0] p_waddr ,
        input  wire    [LOGQ-1:0] p_din   ,
        input  wire    [LOGN-1:0] p_raddr ,
        output wire    [LOGQ-1:0] p_dout  ,
        output reg     [LOGN-1:0] p_raddr_q,
        
        input  wire               px_wen  ,
        input  wire               px_ren  ,
        input  wire    [LOGN-1:0] px_waddr,
        input  wire    [LOGQ-1:0] px_din  ,
        input  wire    [LOGN-1:0] px_raddr,
        output wire    [LOGQ-1:0] px_dout ,

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
        input  wire    [LOGQ-1:0] p1_dout
    );

localparam N2  = 1 << (LOGN - 1);

reg [LOGQ-1:0] bram0 [N2-1:0];
reg [LOGQ-1:0] bram1 [N2-1:0];


wire p0_wen_int;
wire p1_wen_int;

wire p_wen_p0;
wire p_wen_p1;
wire p_ren_p0;
wire p_ren_p1;

wire px_wen_p0;
wire px_wen_p1;
wire px_ren_p0;
wire px_ren_p1;

wire [LOGQ-1:0] p0_din_int;
wire [LOGQ-1:0] p1_din_int;

wire [LOGN-2:0] p0_waddr_int;
wire [LOGN-2:0] p1_waddr_int;

wire [LOGN-2:0] p0_raddr_int;
wire [LOGN-2:0] p1_raddr_int;


wire p_waddr_shift;
wire p_raddr_shift;
wire px_waddr_shift;
wire px_raddr_shift;
wire [LOGN-1:0] logn_mask;

reg p_rsel_q;
reg px_rsel_q;


assign p_waddr_shift  = p_waddr[logn_m1];
assign p_raddr_shift  = p_raddr[logn_m1];
assign px_waddr_shift = px_waddr[logn_m1];
assign px_raddr_shift = px_raddr[logn_m1];
assign p_wen_p0  = p_wen  & ~(p_waddr_shift );
assign p_wen_p1  = p_wen  &  (p_waddr_shift );
assign px_wen_p0 = px_wen &  (px_waddr_shift);
assign px_wen_p1 = px_wen & ~(px_waddr_shift);
assign p_ren_p0  = p_ren  & ~(p_raddr_shift );
assign p_ren_p1  = p_ren  &  (p_raddr_shift );
assign px_ren_p0 = px_ren &  (px_raddr_shift);
assign px_ren_p1 = px_ren & ~(px_raddr_shift);


assign p0_wen = p_wen_p0 | px_wen_p0;
assign p1_wen = p_wen_p1 | px_wen_p1;

assign p0_ren = p_ren_p0 | px_ren_p0;
assign p1_ren = p_ren_p1 | px_ren_p1;

assign p0_din = (p_wen_p0) ? p_din : px_din;
assign p1_din = (p_wen_p1) ? p_din : px_din;

assign logn_mask = (1 << logn_m1) - 1;

assign p0_waddr = (p_wen_p0) ? (p_waddr & logn_mask) : 
                  (1 << (LOGN - 2)) | (px_waddr & logn_mask);

assign p1_waddr = (p_wen_p1) ? (p_waddr & logn_mask) : 
                  (1 << (LOGN - 2)) | (px_waddr & logn_mask);

assign p0_raddr = (p_ren_p0) ? (p_raddr & logn_mask) : 
                  (1 << (LOGN - 2)) | (px_raddr & logn_mask);

assign p1_raddr = (p_ren_p1) ? (p_raddr & logn_mask) : 
                  (1 << (LOGN - 2)) | (px_raddr & logn_mask);

assign p_dout  = (p_rsel_q ) ? p1_dout : p0_dout;
assign px_dout = (px_rsel_q) ? p0_dout : p1_dout;


always @(posedge clk) begin
    p_rsel_q  <= p_raddr_shift;
    px_rsel_q <= px_raddr_shift;
end

always @(posedge clk) begin
    if (rst) begin
        p_raddr_q <= 0;
    end else if (p_ren) begin
        p_raddr_q <= p_raddr;
    end
end

endmodule