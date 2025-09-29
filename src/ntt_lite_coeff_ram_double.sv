module ntt_lite_coeff_ram_double
   #(
        parameter LOGQ  = 32  ,
        parameter LOGN  = 8
    )
    (   
        input                 clk     ,
        input   [LOGLOGN-1:0] logn    ,

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
        output     [LOGQ-1:0] p_dout         
    );

localparam N2  = 1 << (LOGN - 1);
localparam LOGLOGN = $rtoi($ceil($clog2(LOGN+1))); 


(* ram_style="block" *) reg [LOGQ-1:0] bram0 [N2-1:0] = '{default: {LOGQ{1'b0}}};
(* ram_style="block" *) reg [LOGQ-1:0] bram1 [N2-1:0] = '{default: {LOGQ{1'b0}}};


wire p0_wen_int;
wire p1_wen_int;

wire p_wen_p0;
wire p_wen_p1;

wire [LOGQ-1:0] p0_din_int;
wire [LOGQ-1:0] p1_din_int;

wire [LOGN-2:0] p0_waddr_int;
wire [LOGN-2:0] p1_waddr_int;

wire [LOGN-2:0] p0_raddr_int;
wire [LOGN-2:0] p1_raddr_int;

wire [LOGQ-1:0] p0_dout_int;
wire [LOGQ-1:0] p1_dout_int;

wire [LOGN-1:0] p_waddr_shift;
wire [LOGN-1:0] logn_mask;

reg rsel_q;


assign p_waddr_shift = p_waddr >> (logn-1);
assign p_wen_p0 = p_wen &  ~(p_waddr_shift[0]);
assign p_wen_p1 = p_wen &   (p_waddr_shift[0]);

assign p0_wen_int = p0_wen | p_wen_p0;
assign p1_wen_int = p1_wen | p_wen_p1;

assign p0_din_int = p0_wen ? p0_din : p_din;
assign p1_din_int = p1_wen ? p1_din : p_din;

assign logn_mask = (1 << (logn - 1)) - 1;

assign p0_waddr_int = p0_wen ? p0_waddr : p_waddr & logn_mask;
assign p1_waddr_int = p1_wen ? p1_waddr : p_waddr & logn_mask;

assign p0_raddr_int = p0_ren ? p0_raddr : p_raddr & logn_mask;
assign p1_raddr_int = p1_ren ? p1_raddr : p_raddr & logn_mask;

// assign p0_dout_int = bram0[p0_raddr_int];
// assign p1_dout_int = bram1[p1_raddr_int];

assign p_dout = (rsel_q) ? p1_dout : p0_dout;

always @(posedge clk) begin
    if(p0_wen_int)
        bram0[p0_waddr_int] <= p0_din_int;
end


always @(posedge clk) begin
    if(p1_wen_int)
        bram1[p1_waddr_int] <= p1_din_int;
end


always @(posedge clk) begin
    p0_dout <= bram0[p0_raddr_int];
    p1_dout <= bram1[p1_raddr_int];
    rsel_q  <= p_raddr[logn-1];
end


endmodule