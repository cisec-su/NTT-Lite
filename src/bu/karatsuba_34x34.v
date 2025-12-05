/*////////////////////////////////////////////////////////////////
 
 Computes C = A*B
 using 3 DSP blocks.

*/////////////////////////////////////////////////////////////////

module karatsuba_34x34
   #(
        parameter FF_IN     = 1,
        parameter FF_SUB    = 1,
        parameter FF_MUL    = 1,
        parameter FF_SUM    = 1,
        parameter FF_OUT    = 1
    )
    (
        input               clk,
        input  wire  [33:0] A  ,
        input  wire  [33:0] B  ,
        output wire  [67:0] C
    );



///////////////////////////// signals /////////////////////////////

wire [16:0] A0;
reg  [16:0] A0_q;
wire [16:0] A0_mx;
reg  [16:0] A0_d1;
wire [16:0] A0_mx_d1;

wire [16:0] A1;
reg  [16:0] A1_q;
wire [16:0] A1_mx;
reg  [16:0] A1_d1;
wire [16:0] A1_mx_d1;


wire [16:0] B0;
reg  [16:0] B0_q;
wire [16:0] B0_mx;
reg  [16:0] B0_d1;
wire [16:0] B0_mx_d1;

wire [16:0] B1;
reg  [16:0] B1_q;
wire [16:0] B1_mx;
reg  [16:0] B1_d1;
wire [16:0] B1_mx_d1;

wire signed [17:0] A1A0;
reg  signed [17:0] A1A0_q;
wire signed [17:0] A1A0_mx;

wire signed [17:0] B1B0;
reg  signed [17:0] B1B0_q;
wire signed [17:0] B1B0_mx;

wire [33:0] A0B0;
reg  [33:0] A0B0_q;
wire [33:0] A0B0_mx;
reg  [33:0] A0B0_d1;
wire [33:0] A0B0_mx_d1;

wire [33:0] A1B1;
reg  [33:0] A1B1_q;
wire [33:0] A1B1_mx;
reg  [33:0] A1B1_d1;
wire [33:0] A1B1_mx_d1;

wire [34:0] A1A0_B1B0;
reg  [34:0] A1A0_B1B0_q;
wire [34:0] A1A0_B1B0_mx;

(* use_dsp = "no" *) wire [34:0] A1B0_B1A0;
(* use_dsp = "no" *) reg  [34:0] A1B0_B1A0_q;
(* use_dsp = "no" *) wire [34:0] A1B0_B1A0_mx;

wire [67:0] AB;
reg  [67:0] AB_q;

/////////////////////////////////////////////////////////////////////////




//////////////////////////// partitioning ///////////////////////////////

assign A0 = A[16: 0];
assign A1 = A[33:17];
assign B0 = B[16: 0];
assign B1 = B[33:17];

/////////////////////////////////////////////////////////////////////////




///////////////////////////// pipeline steps ////////////////////////////

assign A0_mx        = (FF_IN ) ? A0_q        : A0       ;
assign A1_mx        = (FF_IN ) ? A1_q        : A1       ;
assign B0_mx        = (FF_IN ) ? B0_q        : B0       ;
assign B1_mx        = (FF_IN ) ? B1_q        : B1       ;

assign A0_mx_d1     = (FF_SUB) ? A0_d1       : A0_mx    ;
assign A1_mx_d1     = (FF_SUB) ? A1_d1       : A1_mx    ;
assign B0_mx_d1     = (FF_SUB) ? B0_d1       : B0_mx    ;
assign B1_mx_d1     = (FF_SUB) ? B1_d1       : B1_mx    ;
assign A1A0_mx      = (FF_SUB) ? A1A0_q      : A1A0     ;
assign B1B0_mx      = (FF_SUB) ? B1B0_q      : B1B0     ;

assign A0B0_mx      = (FF_MUL) ? A0B0_q      : A0B0     ;
assign A1B1_mx      = (FF_MUL) ? A1B1_q      : A1B1     ;
assign A1A0_B1B0_mx = (FF_MUL) ? A1A0_B1B0_q : A1A0_B1B0;

assign A1B0_B1A0_mx = (FF_SUM) ? A1B0_B1A0_q : A1B0_B1A0;
assign A0B0_mx_d1   = (FF_SUM) ? A0B0_d1     : A0B0_mx  ;
assign A1B1_mx_d1   = (FF_SUM) ? A1B1_d1     : A1B1_mx  ;

assign C            = (FF_OUT) ? AB_q        : AB       ;

/////////////////////////////////////////////////////////////////////////




////////////////////////// karatsuba pre-subtraction /////////////////////

assign A1A0 = $signed({1'b0, A1_mx}) - $signed({1'b0, A0_mx});
assign B1B0 = $signed({1'b0, B0_mx}) - $signed({1'b0, B1_mx});

/////////////////////////////////////////////////////////////////////////




/////////////////////////////// multiplications /////////////////////////

assign A1A0_B1B0 = A1A0_mx  * B1B0_mx ;
assign A0B0      = A0_mx_d1 * B0_mx_d1;
assign A1B1      = A1_mx_d1 * B1_mx_d1;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// karatsuba post-addition /////////////////////

assign A1B0_B1A0 = A1A0_B1B0_mx + $signed({1'd0, A1B1_mx}) + $signed({1'd0, A0B0_mx});

/////////////////////////////////////////////////////////////////////////




/////////////////////////////// final summation /////////////////////////

assign AB = {A1B1_mx_d1, A0B0_mx_d1} + {A1B0_B1A0_mx, {(17){1'b0}}};

/////////////////////////////////////////////////////////////////////////




///////////////////////////// sequential logic ///////////////////////////

always @(posedge clk) begin
    if (FF_IN) begin
        A0_q <= A0;
        A1_q <= A1;
        B0_q <= B0;
        B1_q <= B1;
    end

    if (FF_SUB) begin
        A0_d1 <= A0_mx;
        A1_d1 <= A1_mx;
        B0_d1 <= B0_mx;
        B1_d1 <= B1_mx;
        A1A0_q <= A1A0;
        B1B0_q <= B1B0;
    end

    if (FF_MUL) begin
        A0B0_q <= A0B0;
        A1B1_q <= A1B1;
        A1A0_B1B0_q <= A1A0_B1B0;
    end

    if (FF_SUM)  begin
        A1B0_B1A0_q <= A1B0_B1A0;
        A1B1_d1 <= A1B1_mx;
        A0B0_d1 <= A0B0_mx;
    end

    if (FF_OUT) begin
        AB_q <= AB;
    end
end

/////////////////////////////////////////////////////////////////////////

endmodule