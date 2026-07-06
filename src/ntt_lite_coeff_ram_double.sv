module ntt_lite_coeff_ram_double
   #(
        parameter  LOGQ    = 32  ,
        parameter  LOGN    = 8   ,
        parameter  L       = 10  ,
        localparam LOGLOGN = $clog2(LOGN+1)
    )
    (   
        input                 clk     ,
        input   [LOGLOGN-1:0] logn    ,
        input                 ren     ,

        input                 p0_wen  ,
        input                 p0_ren  ,
        input      [LOGN-2:0] p0_waddr,
        input      [LOGQ-1:0] p0_din  ,
        input      [LOGN-2:0] p0_raddr,
        output reg [LOGQ-1:0] p0_dout ,
  
        input                 p1_wen  ,
        input                 p1_ren  ,
        input      [LOGN-2:0] p1_waddr,
        input      [LOGQ-1:0] p1_din  ,
        input      [LOGN-2:0] p1_raddr,
        output reg [LOGQ-1:0] p1_dout ,

        input                 p_wen   ,
        input      [LOGN-1:0] p_waddr ,
        input      [LOGQ-1:0] p_din   ,
        input      [LOGN-1:0] p_raddr ,
        output reg [LOGQ-1:0] p_dout  ,
        
        input                 px_wen  ,
        input      [LOGN-1:0] px_waddr,
        input      [LOGQ-1:0] px_din  ,
        input      [LOGN-1:0] px_raddr,
        output reg [LOGQ-1:0] px_dout        
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

wire [LOGQ-1:0] p0_dout_int;
wire [LOGQ-1:0] p1_dout_int;

wire [LOGLOGN-1:0] logn_m1;
wire p_waddr_shift;
wire p_raddr_shift;
wire px_waddr_shift;
wire px_raddr_shift;
wire [LOGN-1:0] logn_mask;

reg p_rsel_q;
reg px_rsel_q;

wire [LOGQ-1:0] p0_dout_int;
wire [LOGQ-1:0] p1_dout_int;

reg [LOGQ-1:0] p0_din_q;
reg [LOGQ-1:0] p1_din_q;

reg [LOGN-2:0] p0_waddr_q;
reg [LOGN-2:0] p1_waddr_q;

reg p0_wen_q;
reg p1_wen_q;


assign logn_m1 = logn - 1;
assign p_waddr_shift  = p_waddr[logn_m1];
assign p_raddr_shift  = p_raddr[logn_m1];
assign px_waddr_shift = px_waddr[logn_m1];
assign px_raddr_shift = px_raddr[logn_m1];
assign p_wen_p0  = p_wen  & ~(p_waddr_shift );
assign p_wen_p1  = p_wen  &  (p_waddr_shift );
assign px_wen_p0 = px_wen &  (px_waddr_shift);
assign px_wen_p1 = px_wen & ~(px_waddr_shift);
assign p_ren_p0  = ~p_raddr_shift;
assign p_ren_p1  =  p_raddr_shift;


assign p0_wen_int = p0_wen | p_wen_p0 | px_wen_p0;
assign p1_wen_int = p1_wen | p_wen_p1 | px_wen_p1;

assign p0_din_int = p0_wen ? p0_din : (p_wen_p0) ? p_din : px_din;
assign p1_din_int = p1_wen ? p1_din : (p_wen_p1) ? p_din : px_din;

assign logn_mask = (1 << logn_m1) - 1;

assign p0_waddr_int = (p0_wen  ) ?              p0_waddr : 
                      (p_wen_p0) ? (p_waddr & logn_mask) : 
                      (1 << (LOGN - 2)) | (px_waddr & logn_mask);

assign p1_waddr_int = (p1_wen  ) ?              p1_waddr : 
                      (p_wen_p1) ? (p_waddr & logn_mask) : 
                      (1 << (LOGN - 2)) | (px_waddr & logn_mask);

assign p0_raddr_int = (p0_ren  ) ?              p0_raddr : 
                      (p_ren_p0) ? (p_raddr & logn_mask) : 
                      (1 << (LOGN - 2)) | (px_raddr & logn_mask);

assign p1_raddr_int = (p1_ren  ) ?              p1_raddr : 
                      (p_ren_p1) ? (p_raddr & logn_mask) : 
                      (1 << (LOGN - 2)) | (px_raddr & logn_mask);

assign p0_dout_int = (ren) ? bram0[p0_raddr_int] : {LOGQ{1'b0}};
assign p1_dout_int = (ren) ? bram1[p1_raddr_int] : {LOGQ{1'b0}};

always @(posedge clk) begin
    if(p0_wen_q)
        bram0[p0_waddr_q] <= p0_din_q;
end


always @(posedge clk) begin
    if(p1_wen_q)
        bram1[p1_waddr_q] <= p1_din_q;
end


always @(posedge clk) begin
    p0_dout <= p0_dout_int;
    p1_dout <= p1_dout_int;
    p_dout  <= (p_raddr_shift ) ? p1_dout_int : p0_dout_int;
    px_dout <= (px_raddr_shift) ? p0_dout_int : p1_dout_int;
end

always @(posedge clk) begin
    p_rsel_q  <= p_raddr_shift;
    px_rsel_q <= px_raddr_shift;
end

always @(posedge clk) begin
    p0_din_q   <= p0_din_int;
    p1_din_q   <= p1_din_int;
    p0_waddr_q <= p0_waddr_int;
    p1_waddr_q <= p1_waddr_int;
    p0_wen_q   <= p0_wen_int;
    p1_wen_q   <= p1_wen_int;
end

endmodule