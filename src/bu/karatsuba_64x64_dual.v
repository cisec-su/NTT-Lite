/*///////////////////////////////////////////////////////////////////////
 
 Computes C = A*B
 using 9 DSP blocks.

*////////////////////////////////////////////////////////////////////////
module karatsuba_64x64_dual
   #(  
        parameter FF_IN     = 1,
        parameter FF_SUM0   = 1,
        parameter FF_SUB0   = 1,
        parameter FF_MUL    = 1,
        parameter FF_SUM1   = 1,
        parameter FF_SUM2   = 1,
        parameter FF_SUB1   = 1,
        parameter FF_OUT    = 1
    )
    (
        input                clk,
        input wire           dual,
        input wire  [ 63:0]  A  ,
        input wire  [ 63:0]  B  ,
        output wire [127:0]  C
    );


localparam LAT = FF_IN + FF_SUM0 + FF_SUB0 + FF_MUL + FF_SUM1 + FF_SUM2 + FF_SUB1 + FF_OUT;

///////////////////////////// signals ///////////////////////////////////

wire [31:0] A0;
reg  [31:0] A0_q;
wire [31:0] A0_mx;

wire [31:0] A1;
reg  [31:0] A1_q;
wire [31:0] A1_mx;

wire [31:0] B0;
reg  [31:0] B0_q;
wire [31:0] B0_mx;

wire [31:0] B1;
reg  [31:0] B1_q;
wire [31:0] B1_mx;

wire [63:0] A0B0;
reg  [63:0] A0B0_q;
wire [63:0] A0B0_mx;

wire [63:0] A1B1;
reg  [63:0] A1B1_q;
wire [63:0] A1B1_mx;

wire [32:0] A1A0;
wire [32:0] B1B0;
wire [65:0] A1A0_B1B0;

wire [64:0] A1B0_A0B1;
reg  [64:0] A1B0_A0B1_q;
wire [64:0] A1B0_A0B1_mx;

wire [127:0] AB;
reg  [127:0] AB_q;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// partitioning //////////////////////////////

assign A0 = A[31: 0];
assign A1 = A[63:32];
assign B0 = B[31: 0];
assign B1 = B[63:32];

/////////////////////////////////////////////////////////////////////////




///////////////////////////// pipeline steps ////////////////////////////

assign A0_mx         = (FF_IN  ) ? A0_q        : A0       ;
assign A1_mx         = (FF_IN  ) ? A1_q        : A1       ;
assign B0_mx         = (FF_IN  ) ? B0_q        : B0       ;
assign B1_mx         = (FF_IN  ) ? B1_q        : B1       ;

assign A0B0_mx       = (FF_SUB1) ? A0B0_q      : A0B0     ;
assign A1B1_mx       = (FF_SUB1) ? A1B1_q      : A1B1     ;
assign A1B0_A0B1_mx  = (FF_SUB1) ? A1B0_A0B1_q : A1B0_A0B1;

assign C             = (FF_OUT ) ? AB_q        : AB       ;

/////////////////////////////////////////////////////////////////////////




////////////////////////// karatsuba pre-addition ///////////////////////

assign A1A0 = A1_mx + A0_mx;
assign B1B0 = B1_mx + B0_mx;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// multiplications /////////////////////////////

karatsuba_34x34 #(
    .FF_IN (FF_SUM0),
    .FF_SUB(FF_SUB0),
    .FF_MUL(FF_MUL ),
    .FF_SUM(FF_SUM1),
    .FF_OUT(FF_SUM2),
    .LOGA  (32),
    .LOGB  (32)
)  karatsuba_0 (
    .clk(clk),
    .A(A0_mx),
    .B(B0_mx),
    .C(A0B0 )
);

karatsuba_34x34 #(
    .FF_IN (FF_SUM0),
    .FF_SUB(FF_SUB0),
    .FF_MUL(FF_MUL ),
    .FF_SUM(FF_SUM1),
    .FF_OUT(FF_SUM2),
    .LOGA  (33),
    .LOGB  (33)
)  karatsuba_1 (
    .clk(clk),
    .A(A1A0),
    .B(B1B0),
    .C(A1A0_B1B0)
);


karatsuba_34x34 #(
    .FF_IN (FF_SUM0),
    .FF_SUB(FF_SUB0),
    .FF_MUL(FF_MUL ),
    .FF_SUM(FF_SUM1),
    .FF_OUT(FF_SUM2),
    .LOGA  (32),
    .LOGB  (32)
)  karatsuba_2 (
    .clk(clk),
    .A(A1_mx),
    .B(B1_mx),
    .C(A1B1 )
);

/////////////////////////////////////////////////////////////////////////




////////////////////////// karatsuba post-subtraction ///////////////////

assign A1B0_A0B1 = A1A0_B1B0 - {1'b0,A1B1} - {1'b0, A0B0};

/////////////////////////////////////////////////////////////////////////




/////////////////////////////// final summation /////////////////////////

assign AB = {A1B1_mx, A0B0_mx} + ((dual)? 0 : {A1B0_A0B1_mx, 32'd0});

/////////////////////////////////////////////////////////////////////////



///////////////////////////// sequential logic ///////////////////////////

always @(posedge clk) begin
    if (FF_IN) begin
        A0_q <= A0;
        A1_q <= A1;
        B0_q <= B0;
        B1_q <= B1;
    end

    if (FF_SUB1) begin
        A1B1_q      <= A1B1;
        A0B0_q      <= A0B0;
        A1B0_A0B1_q <= A1B0_A0B1;
    end

    if (FF_OUT) begin
        AB_q <= AB;
    end
end

/////////////////////////////////////////////////////////////////////////

endmodule
