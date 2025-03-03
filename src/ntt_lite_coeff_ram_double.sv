module ntt_lite_coeff_ram_double
   #(
        parameter LOGQ  = 32  ,
        parameter LOGN  = 8
    )
    (   input                 clk     ,

        input   [LOGLOGN-1:0] logn    ,
        input                 p0_wen  ,
        input      [LOGN-1:0] p0_waddr,
        input      [LOGQ-1:0] p0_din  ,
        input      [LOGN-1:0] p0_raddr,
        output     [LOGQ-1:0] p0_dout ,
        input                 p0_rsel ,
        input                 p0_wsel ,
  
        input                 p1_wen  ,
        input      [LOGN-1:0] p1_waddr,
        input      [LOGQ-1:0] p1_din  ,
        input      [LOGN-1:0] p1_raddr,
        output     [LOGQ-1:0] p1_dout ,
        input                 p1_rsel ,
        input                 p1_wsel
    );

localparam N  = 1 << LOGN;
localparam LOGLOGN = $rtoi($ceil($clog2(LOGN+1))); 


wire            ram_0_p0_wen ;
wire [LOGQ-1:0] ram_0_p0_dout;
wire            ram_0_p1_wen ;
wire [LOGQ-1:0] ram_0_p1_dout;
wire            ram_1_p0_wen ;
wire [LOGQ-1:0] ram_1_p0_dout;
wire            ram_1_p1_wen ;
wire [LOGQ-1:0] ram_1_p1_dout;

reg p0_rsel_q, p1_rsel_q;


assign ram_0_p0_wen = (p0_wsel == 1'b0) ? p0_wen : 1'b0;
assign ram_0_p1_wen = (p1_wsel == 1'b0) ? p1_wen : 1'b0;

assign ram_1_p0_wen = (p0_wsel == 1'b1) ? p0_wen : 1'b0;
assign ram_1_p1_wen = (p1_wsel == 1'b1) ? p1_wen : 1'b0;

assign p0_dout = (p0_rsel_q == 1'b0) ? ram_0_p0_dout : ram_1_p0_dout;
assign p1_dout = (p1_rsel_q == 1'b0) ? ram_0_p1_dout : ram_1_p1_dout;


always @(posedge clk) begin
    p0_rsel_q <= p0_rsel;
    p1_rsel_q <= p1_rsel;
end



ntt_lite_coeff_ram #(
    .LOGQ(LOGQ),
    .LOGN(LOGN)
) u_ntt_lite_coeff_ram_0 (
    .clk(clk),
    .logn(logn),
    .p0_wen(ram_0_p0_wen),
    .p0_waddr(p0_waddr),
    .p0_din(p0_din),
    .p0_raddr(p0_raddr),
    .p0_dout(ram_0_p0_dout),
    .p1_wen(ram_0_p1_wen),
    .p1_waddr(p1_waddr),
    .p1_din(p1_din),
    .p1_raddr(p1_raddr),
    .p1_dout(ram_0_p1_dout)
);


ntt_lite_coeff_ram #(
    .LOGQ(LOGQ),
    .LOGN(LOGN)
) u_ntt_lite_coeff_ram_1 (
    .clk(clk),
    .logn(logn),
    .p0_wen(ram_1_p0_wen),
    .p0_waddr(p0_waddr),
    .p0_din(p0_din),
    .p0_raddr(p0_raddr),
    .p0_dout(ram_1_p0_dout),
    .p1_wen(ram_1_p1_wen),
    .p1_waddr(p1_waddr),
    .p1_din(p1_din),
    .p1_raddr(p1_raddr),
    .p1_dout(ram_1_p1_dout)
);

endmodule