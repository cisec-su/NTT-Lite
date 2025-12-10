module asr /* Arithmetic Shift Right */
   #(
        parameter LOGQ       = 64,
        parameter LOGLOGQ    = $clog2(LOGQ + 1)
    )
    (
        input  [LOGQ    -1:0] A   ,
        input  [LOGLOGQ -1:0] d   ,        
        input                 dual,
        output [LOGQ    -1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

wire [LOGQ -1:0] C1;
wire [LOGQ0-1:0] C0;

/////////////////////////////////////////////////////////////////////////



///////////////////////////// Assignments ///////////////////////////////

assign C0 =  A[LOGQ0-1:    0]                 >> d;
assign C1 = {A[LOGQ -1:LOGQ0], {LOGQ0{1'b0}}} >> d;

assign C[LOGQ0-1:    0] = C0 ^ ((dual) ? {LOGQ0{1'b0}} : C1[LOGQ0-1:0]);
assign C[LOGQ -1:LOGQ0] = C1[LOGQ-1:LOGQ0];


/////////////////////////////////////////////////////////////////////////




endmodule