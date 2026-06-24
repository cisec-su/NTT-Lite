module modadd
   #(
        parameter int unsigned LOGQ   = 32,
        parameter bit          FF_IN  = 0 ,
        parameter bit          FF_OUT = 0
    )
    (
        input             clk ,
        input  [LOGQ-1:0] A   ,
        input  [LOGQ-1:0] B   ,
        input  [LOGQ-1:0] Q   ,
        input             dual,
        input             rd_en,
        output [LOGQ+1:0] T   ,
        output [LOGQ-1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

wire [LOGQ-1:0] A_mx;
reg  [LOGQ-1:0] A_q ;
wire [LOGQ-1:0] B_mx;
reg  [LOGQ-1:0] B_q ;
wire [LOGQ-1:0] C_mx;
reg  [LOGQ-1:0] C_q ;

wire [LOGQ0:0] T0;
wire [LOGQ0:0] T1;

wire [LOGQ0:0] Tq0;
wire [LOGQ0:0] Tq1;

wire [LOGQ0-1:0] C0;
wire [LOGQ0-1:0] C1;

wire c;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Pipeline Steps ////////////////////////////

assign A_mx = (FF_IN ) ? A_q : A;
assign B_mx = (FF_IN ) ? B_q : B;
assign C    = (FF_OUT) ? C_q : C_mx;

always @(posedge clk) begin
    if (FF_IN) begin
        A_q <= A;
        B_q <= B;
    end
    if (FF_OUT) begin
        C_q <= C_mx;
    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// Assignments ///////////////////////////////

assign T0 = A_mx[LOGQ0-1:    0] + B_mx[LOGQ0-1:    0];
assign T1 = A_mx[LOGQ -1:LOGQ0] + B_mx[LOGQ -1:LOGQ0] + ((~dual) & T0[LOGQ0]);

assign c  = dual & T0[LOGQ0];

assign Tq0 = {c, T0[LOGQ0-1:0]} - Q[LOGQ0-1:0];
assign Tq1 = T1 - Q[LOGQ-1:LOGQ0] - ((~dual) & Tq0[LOGQ0]);

assign C0 = (((dual && (Tq0[LOGQ0] == 0)) || (!dual &&  Tq1[LOGQ0] == 0)) && rd_en) ? Tq0[LOGQ0-1:0] : T0[LOGQ0-1:0];
assign C1 = (Tq1[LOGQ0] == 0 && rd_en) ? Tq1[LOGQ0-1:0] : T1[LOGQ0-1:0];

assign T    = {({1'b0, T1} << dual) ^ c, T0[LOGQ0-1:0]};
assign C_mx = {C1, C0};

/////////////////////////////////////////////////////////////////////////






endmodule