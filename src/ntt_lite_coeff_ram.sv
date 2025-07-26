module ntt_lite_coeff_ram
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
  
        input                 p1_wen  ,
        input      [LOGN-1:0] p1_waddr,
        input      [LOGQ-1:0] p1_din  ,
        input      [LOGN-1:0] p1_raddr,
        output     [LOGQ-1:0] p1_dout
    );

localparam N  = 1 << LOGN;
localparam LOGN4 = LOGN - 2;
localparam N4 = 1 << LOGN4;
localparam LOGLOGN = $rtoi($ceil($clog2(LOGN+1))); 


localparam RAM0 = 2'b00;
localparam RAM1 = 2'b01;
localparam RAM2 = 2'b10;
localparam RAM3 = 2'b11;


(* ram_style="block" *) reg [LOGQ-1:0] bram_0 [N4-1:0] = '{default: {LOGQ{1'b0}}}; // low -even
(* ram_style="block" *) reg [LOGQ-1:0] bram_1 [N4-1:0] = '{default: {LOGQ{1'b0}}}; // low -odd
(* ram_style="block" *) reg [LOGQ-1:0] bram_2 [N4-1:0] = '{default: {LOGQ{1'b0}}}; // high-even
(* ram_style="block" *) reg [LOGQ-1:0] bram_3 [N4-1:0] = '{default: {LOGQ{1'b0}}}; // high-odd


wire [1:0] p0_waddr_ram_id;
wire [1:0] p0_raddr_ram_id;
wire [1:0] p1_waddr_ram_id;
wire [1:0] p1_raddr_ram_id;


wire [LOGN4-1:0] bram_0_waddr;
wire [LOGN4-1:0] bram_0_raddr;
wire [LOGN4-1:0] bram_1_waddr;
wire [LOGN4-1:0] bram_1_raddr;
wire [LOGN4-1:0] bram_2_waddr;
wire [LOGN4-1:0] bram_2_raddr;
wire [LOGN4-1:0] bram_3_waddr;
wire [LOGN4-1:0] bram_3_raddr;


wire p0_waddr_ram_0;
wire p0_raddr_ram_0;
wire p1_waddr_ram_0;
wire p1_raddr_ram_0;
wire p0_waddr_ram_1;
wire p0_raddr_ram_1;
wire p1_waddr_ram_1;
wire p1_raddr_ram_1;
wire p0_waddr_ram_2;
wire p0_raddr_ram_2;
wire p1_waddr_ram_2;
wire p1_raddr_ram_2;
wire p0_waddr_ram_3;
wire p0_raddr_ram_3;
wire p1_waddr_ram_3;
wire p1_raddr_ram_3;

reg p0_raddr_ram_0_q;
reg p0_raddr_ram_1_q;
reg p0_raddr_ram_2_q;
reg p1_raddr_ram_0_q;
reg p1_raddr_ram_1_q;
reg p1_raddr_ram_2_q;


reg [LOGQ-1:0] bram_0_dout;
reg [LOGQ-1:0] bram_1_dout;
reg [LOGQ-1:0] bram_2_dout;
reg [LOGQ-1:0] bram_3_dout;


wire [LOGQ-1:0] bram_0_din;
wire [LOGQ-1:0] bram_1_din;
wire [LOGQ-1:0] bram_2_din;
wire [LOGQ-1:0] bram_3_din;


wire bram_0_wen;
wire bram_1_wen;
wire bram_2_wen;
wire bram_3_wen;


wire p0_wen_ram_0;
wire p0_wen_ram_1;
wire p0_wen_ram_2;
wire p0_wen_ram_3;

wire [LOGN-1:0] addr_mask;

wire [LOGN-1:0] p0_waddr_masked;
wire [LOGN-1:0] p0_raddr_masked;
wire [LOGN-1:0] p1_waddr_masked;
wire [LOGN-1:0] p1_raddr_masked;


assign p0_waddr_ram_id = {p0_waddr[logn-1],p0_waddr[0]};
assign p0_raddr_ram_id = {p0_raddr[logn-1],p0_raddr[0]};
assign p1_waddr_ram_id = {p1_waddr[logn-1],p1_waddr[0]};
assign p1_raddr_ram_id = {p1_raddr[logn-1],p1_raddr[0]};


assign p0_waddr_ram_0 = (p0_waddr_ram_id == RAM0);
assign p0_raddr_ram_0 = (p0_raddr_ram_id == RAM0);
assign p1_waddr_ram_0 = (p1_waddr_ram_id == RAM0);
assign p1_raddr_ram_0 = (p1_raddr_ram_id == RAM0);
assign p0_waddr_ram_1 = (p0_waddr_ram_id == RAM1);
assign p0_raddr_ram_1 = (p0_raddr_ram_id == RAM1);
assign p1_waddr_ram_1 = (p1_waddr_ram_id == RAM1);
assign p1_raddr_ram_1 = (p1_raddr_ram_id == RAM1);
assign p0_waddr_ram_2 = (p0_waddr_ram_id == RAM2);
assign p0_raddr_ram_2 = (p0_raddr_ram_id == RAM2);
assign p1_waddr_ram_2 = (p1_waddr_ram_id == RAM2);
assign p1_raddr_ram_2 = (p1_raddr_ram_id == RAM2);
assign p0_waddr_ram_3 = (p0_waddr_ram_id == RAM3);
assign p0_raddr_ram_3 = (p0_raddr_ram_id == RAM3);
assign p1_waddr_ram_3 = (p1_waddr_ram_id == RAM3);
assign p1_raddr_ram_3 = (p1_raddr_ram_id == RAM3);


assign addr_mask = ((1 << (logn - 2)) - 1) << 1;
assign p0_waddr_masked = (p0_waddr & addr_mask) >> 1;
assign p0_raddr_masked = (p0_raddr & addr_mask) >> 1;
assign p1_waddr_masked = (p1_waddr & addr_mask) >> 1;
assign p1_raddr_masked = (p1_raddr & addr_mask) >> 1;


assign bram_0_waddr = (p0_wen_ram_0 && p0_waddr_ram_0) ? p0_waddr_masked :
                                                         p1_waddr_masked ;

assign bram_0_raddr = (p0_raddr_ram_0) ? p0_raddr_masked :
                                         p1_raddr_masked ;

assign bram_1_waddr = (p0_wen_ram_1 && p0_waddr_ram_1) ? p0_waddr_masked :
                                                         p1_waddr_masked ;

assign bram_1_raddr = (p0_raddr_ram_1) ? p0_raddr_masked :
                                         p1_raddr_masked ;

assign bram_2_waddr = (p0_wen_ram_2 && p0_waddr_ram_2) ? p0_waddr_masked :
                                                         p1_waddr_masked ;

assign bram_2_raddr = (p0_raddr_ram_2) ? p0_raddr_masked :
                                         p1_raddr_masked ;

assign bram_3_waddr = (p0_wen_ram_3 && p0_waddr_ram_3) ? p0_waddr_masked :
                                                         p1_waddr_masked ;

assign bram_3_raddr = (p0_raddr_ram_3) ? p0_raddr_masked :
                                         p1_raddr_masked ;


assign p0_wen_ram_0 = (p0_wen && p0_waddr_ram_0);
assign p0_wen_ram_1 = (p0_wen && p0_waddr_ram_1);
assign p0_wen_ram_2 = (p0_wen && p0_waddr_ram_2);
assign p0_wen_ram_3 = (p0_wen && p0_waddr_ram_3);


assign bram_0_wen = (p0_wen_ram_0) || (p1_wen && p1_waddr_ram_0);
assign bram_1_wen = (p0_wen_ram_1) || (p1_wen && p1_waddr_ram_1);
assign bram_2_wen = (p0_wen_ram_2) || (p1_wen && p1_waddr_ram_2);
assign bram_3_wen = (p0_wen_ram_3) || (p1_wen && p1_waddr_ram_3);


assign bram_0_din = (p0_wen_ram_0) ? p0_din : p1_din;
assign bram_1_din = (p0_wen_ram_1) ? p0_din : p1_din;
assign bram_2_din = (p0_wen_ram_2) ? p0_din : p1_din;
assign bram_3_din = (p0_wen_ram_3) ? p0_din : p1_din;


assign p0_dout = (p0_raddr_ram_0_q) ? bram_0_dout :
                 (p0_raddr_ram_1_q) ? bram_1_dout :
                 (p0_raddr_ram_2_q) ? bram_2_dout :
                                      bram_3_dout ;

assign p1_dout = (p1_raddr_ram_0_q) ? bram_0_dout :
                 (p1_raddr_ram_1_q) ? bram_1_dout :
                 (p1_raddr_ram_2_q) ? bram_2_dout :
                                      bram_3_dout ;


always @(posedge clk) begin
    if(bram_0_wen)
        bram_0[bram_0_waddr] <= bram_0_din;
end

always @(posedge clk) begin
    if(bram_1_wen)
        bram_1[bram_1_waddr] <= bram_1_din;
end

always @(posedge clk) begin
    if(bram_2_wen)
        bram_2[bram_2_waddr] <= bram_2_din;
end

always @(posedge clk) begin
    if(bram_3_wen)
        bram_3[bram_3_waddr] <= bram_3_din;
end


always @(posedge clk) begin
    bram_0_dout <= bram_0[bram_0_raddr];
end

always @(posedge clk) begin
    bram_1_dout <= bram_1[bram_1_raddr];
end

always @(posedge clk) begin
    bram_2_dout <= bram_2[bram_2_raddr];
end

always @(posedge clk) begin
    bram_3_dout <= bram_3[bram_3_raddr];
end


always @(posedge clk) begin
    p0_raddr_ram_0_q <= p0_raddr_ram_0;
    p0_raddr_ram_1_q <= p0_raddr_ram_1;
    p0_raddr_ram_2_q <= p0_raddr_ram_2;
    p1_raddr_ram_0_q <= p1_raddr_ram_0;
    p1_raddr_ram_1_q <= p1_raddr_ram_1;
    p1_raddr_ram_2_q <= p1_raddr_ram_2;
end

endmodule