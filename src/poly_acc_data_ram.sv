module poly_acc_data_ram
   #(
        parameter  LOGQ    = 32  ,
        parameter  LOGN    = 8   ,
        parameter  L       = 10  ,
        localparam LOGLOGN = $clog2(LOGN+1)
    )
    (   
        input                 clk     ,

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
        output reg [LOGQ-1:0] p1_dout
    );

localparam N2  = 1 << (LOGN - 1);

reg [LOGQ-1:0] bram0 [N2-1:0];
reg [LOGQ-1:0] bram1 [N2-1:0];

wire [LOGQ-1:0] p0_dout_int;
wire [LOGQ-1:0] p1_dout_int;

always @(posedge clk) begin
    if(p0_wen)
        bram0[p0_waddr] <= p0_din;
end

always @(posedge clk) begin
    if(p1_wen)
        bram1[p1_waddr] <= p1_din;
end

assign p0_dout_int = bram0[p0_raddr];
assign p1_dout_int = bram1[p1_raddr];

always @(posedge clk) begin
    p0_dout <= (p0_ren) ? p0_dout_int : p0_dout;
    p1_dout <= (p1_ren) ? p1_dout_int : p1_dout;
end


endmodule