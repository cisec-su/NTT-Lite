 /* Decompress (FN-DSA) Post-Process
    !!!!! Only DUAL MODE */
module fndecomp_pp
   #(
        parameter  LOGQ  = 32,
        parameter  LOGM  = 8 ,// since this is unit is highly dedicated, we hard-code the length of mantissa
        localparam LOGLOGQ = $clog2(LOGQ + 1)
    )
    (
        input                     clk    ,
        input                     rst    ,
        input      [LOGQ    -1:0] A      ,
        output                    o_valid,
        output reg                o_valid0,
        output     [LOGLOGQ   :0] d      ,
        output reg [LOGQ    -1:0] B
    );


localparam LOGQ0   = LOGQ >> 1;


///////////////////////// Signals Declaration ///////////////////////////


reg  [LOGLOGQ :0] d0_int ;
reg  [LOGLOGQ :0] d0_int_;
wire [LOGQ  -1:0] A_int  ;
wire [LOGM  -2:0] A0_rev ;

reg [LOGQ0-1:0] B0;
reg [LOGQ0-1:0] B0_q;

reg full;

/////////////////////////////////////////////////////////////////////////



///////////////////////////// Assignments ///////////////////////////////

assign o_valid = o_valid0 & full;
assign d = d0_int;

for (genvar i = 0; i < LOGM - 1; i++) begin
    assign A0_rev[i] = A    [LOGM-1-i];
end


assign B[LOGQ0-1:0] = B0_q;
assign B[LOGQ-1:LOGQ0] = B0;


always @(*) begin
    d0_int_ = 0;
    o_valid0 = 0;
    d0_int = 0;
    for (int i = LOGM; i < 3*LOGM; i++) begin
        if (A[i] == 1) begin
            d0_int_ = i - LOGM;
            o_valid0 = 1'b1;
            d0_int = LOGM + d0_int_ + 1;
            break; 
        end
    end
    B0 = A0_rev + (d0_int_ << (LOGM - 1));
    if (A[0] == 1) begin
        B0 = ~B0 + 1;
    end
end


always @(posedge clk) begin
    if (rst) begin
        B0_q <= 0;
        full <= 0;
    end
    else if (o_valid0) begin
        B0_q <= B0;
        full <= (full) ? 0 : 1;
    end
end


/////////////////////////////////////////////////////////////////////////




endmodule