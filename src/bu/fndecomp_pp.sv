 /* Decompress (FN-DSA) Post-Process
    !!!!! Only DUAL MODE */
module fndecomp_pp
   #(
        parameter  LOGQ  = 32,
        parameter  LOGM  = 8 ,// since this is unit is highly dedicated, we hard-code the length of mantissa
        localparam LOGLOGQ = $clog2(LOGQ + 1)
    )
    (
        input      [LOGQ    -1:0] A      ,
        output                    o_valid,
        output     [LOGLOGQ   :0] d      ,
        output reg [LOGQ    -1:0] B
    );


localparam LOGQ0   = LOGQ >> 1;


///////////////////////// Signals Declaration ///////////////////////////

reg o_valid0, o_valid1;
reg  [LOGLOGQ :0] d0_int ;
reg  [LOGLOGQ :0] d1_int ;
reg  [LOGLOGQ :0] d0_int_;
reg  [LOGLOGQ :0] d1_int_;
wire [LOGQ  -1:0] A_int  ;
wire [LOGM  -2:0] A0_rev ;
wire [LOGM  -2:0] A1_rev ;

/////////////////////////////////////////////////////////////////////////



///////////////////////////// Assignments ///////////////////////////////

assign A_int = A >> d0_int;
assign o_valid = o_valid0 & o_valid1;
assign d = d0_int + d1_int;

for (genvar i = 0; i < LOGM - 1; i++) begin
    assign A0_rev[i] = A    [LOGM-1-i];
    assign A1_rev[i] = A_int[LOGM-1-i];
end


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
    B[LOGQ0-1:0] = A0_rev + (d0_int_ << (LOGM - 1));
    if (A[0] == 1) begin
        B[LOGQ0-1:0] = ~B[LOGQ0-1:0] + 1;
    end

    d1_int_ = 0;
    o_valid1 = 0;
    d1_int = 0;
    for (int i = LOGM; i < 3*LOGM; i++) begin
        if (A_int[i] == 1) begin
            d1_int_ = i - LOGM;
            o_valid1 = 1'b1;
            d1_int = LOGM + d1_int_ + 1;
            break; 
        end
    end
    B[LOGQ-1:LOGQ0] = A1_rev + (d1_int_ << (LOGM - 1));
    if (A_int[0] == 1) begin
        B[LOGQ-1:LOGQ0] = ~B[LOGQ-1:LOGQ0] + 1;
    end

end

/////////////////////////////////////////////////////////////////////////




endmodule