module addsub_dual
   #(
        parameter MODE  = 0 , // 0: A + B, 1: A - B
        parameter LOGA0 = 32,
        parameter LOGB0 = 32
    )
    (
        input  [2*LOGA0-1:0] A   ,
        input  [2*LOGB0-1:0] B   ,
        input                dual,
        output [2*LOGA0-1:0] C   ,
        output [        1:0] K
    );

///////////////////////////// input check ///////////////////////////////

if (LOGB0 > LOGA0) begin
    LOGB0_CANT_BE_GREATER_THAN_LOGA0();
end
if (MODE != 0 && MODE != 1) begin
    MODE_MUST_BE_EITHER_0_OR_1();
end
    
/////////////////////////////////////////////////////////////////////////




///////////////////////////// parameters ////////////////////////////////

localparam LOGA = LOGA0 << 1;
localparam LOGB = LOGB0 << 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

wire [LOGA0-1:0] B0;
wire [LOGA0-1:0] B1;

wire [LOGA0-1:0] A0;
wire [LOGA0-1:0] A1;

wire [LOGA0:0] C0;
wire [LOGA0:0] C1;

/////////////////////////////////////////////////////////////////////////


///////////////////////////// Assignments ///////////////////////////////

assign B0 = (dual) ? B[LOGB0-1:    0] : (LOGA0 < LOGB) ? B[LOGA0-1:0    ] : B;
assign B1 = (dual) ? B[LOGB -1:LOGB0] : (LOGA0 < LOGB) ? B[LOGB -1:LOGA0] : 0;

assign A0 = A[LOGA0-1:    0];
assign A1 = A[LOGA -1:LOGA0];

if (MODE == 0) begin
    assign C0 = A0 + B0;
    assign C1 = A1 + B1 + ((~dual) & C0[LOGA0]);
end
else begin
    assign C0 = A0 - B0;
    assign C1 = A1 - B1 - ((~dual) & C0[LOGA0]); 
end

assign C = {C1[LOGA0-1:0], C0[LOGA0-1:0]};
assign K = {C1[LOGA0], C0[LOGA0]};

/////////////////////////////////////////////////////////////////////////


endmodule