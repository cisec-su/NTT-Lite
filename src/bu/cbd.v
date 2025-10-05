`include "ntt_lite.vh"

module cbd
   #(
        parameter LOGQ = 32
    )
    (
        input                 clk     ,
        input                 rst     ,
        input  [LOGQ    -1:0] A       ,
        input  [LOGQ    -1:0] Q       ,
        input  [         1:0] mode    ,
        input                 cbd_mode,
        input                 i_valid ,
        output                o_valid ,
        output [LOGQ    -1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

reg  [LOGQ-1:0] A_q;
reg  [LOGQ-1:0] C_q;
reg  [LOGQ-1:0] Q_q;
wire [LOGQ-1:0] C_int;
reg  [LOGQ0-1:0] T0L;
reg  [LOGQ0-1:0] T0H;
reg  [LOGQ0-1:0] T1L;
reg  [LOGQ0-1:0] T1H;
wire [LOGQ-1:0] T0;
wire [LOGQ-1:0] T1;
reg  cbd_mode_q;
wire dual;
reg  dual_q;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Comb. Assignments /////////////////////////////

assign dual = (mode != `MODE_SINGLE) ? 1'b1 : 1'b0;

always @(*) begin
    if (cbd_mode_q == 1'b0) begin
        case (A_q[1:0])
            2'b01  : T0L = 1;
            2'b10  : T0L = 1;
            2'b11  : T0L = 2;
            default: T0L = 0;
        endcase
        case (A_q[3:2])
            2'b01  : T1L = 1;
            2'b10  : T1L = 1;
            2'b11  : T1L = 2;
            default: T1L = 0;
        endcase
        if (dual_q) begin
            case (A_q[LOGQ0+1:LOGQ0])
                2'b01  : T0H = 1;
                2'b10  : T0H = 1;
                2'b11  : T0H = 2;
                default: T0H = 0;
            endcase
            case (A_q[LOGQ0+3:LOGQ0+2])
                2'b01  : T1H = 1;
                2'b10  : T1H = 1;
                2'b11  : T1H = 2;
                default: T1H = 0;
            endcase
        end
        else begin
            T0H = 0;
            T1H = 0;
        end
    end
    else begin
        case (A_q[2:0])
            3'b001 : T0L = 1;
            3'b010 : T0L = 1;
            3'b100 : T0L = 1;
            3'b011 : T0L = 2;
            3'b101 : T0L = 2;
            3'b110 : T0L = 2;
            3'b111 : T0L = 3;
            default: T0L = 0;
        endcase
        case (A_q[5:3])
            3'b001 : T1L = 1;
            3'b010 : T1L = 1;
            3'b100 : T1L = 1;
            3'b011 : T1L = 2;
            3'b101 : T1L = 2;
            3'b110 : T1L = 2;
            3'b111 : T1L = 3;
            default: T1L = 0;
        endcase
        if (dual_q) begin
            case (A_q[LOGQ0+2:LOGQ0])
                3'b001 : T0H = 1;
                3'b010 : T0H = 1;
                3'b100 : T0H = 1;
                3'b011 : T0H = 2;
                3'b101 : T0H = 2;
                3'b110 : T0H = 2;
                3'b111 : T0H = 3;
                default: T0H = 0;
            endcase
            case (A_q[LOGQ0+5:LOGQ0+3])
                3'b001 : T1H = 1;
                3'b010 : T1H = 1;
                3'b100 : T1H = 1;
                3'b011 : T1H = 2;
                3'b101 : T1H = 2;
                3'b110 : T1H = 2;
                3'b111 : T1H = 3;
                default: T1H = 0;
            endcase
        end
        else begin
            T0H = 0;
            T1H = 0;
        end
    end
end

assign T0 = (T0H << LOGQ0) | T0L;
assign T1 = (T1H << LOGQ0) | T1L;
assign C = C_q;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Seq. Assignments //////////////////////////////

modsub  #(
    .LOGQ(LOGQ)
) ma (
    .A   (T0   ),
    .B   (T1   ),
    .dual(dual ),
    .Q   (Q_q  ),
    .C   (C_int)
);


shiftreg #(
    .SHIFT(2),
    .DATA (1)
) shreg_encode (
    .clk     (clk    ),
    .rst     (rst    ),
    .data_in (i_valid),
    .data_out(o_valid)
);

/////////////////////////////////////////////////////////////////////////




///////////////////////// Seq. Assignments //////////////////////////////

always @(posedge clk) begin
    A_q <= A;
    C_q <= C_int;
    Q_q <= Q;
    dual_q <= dual;
    cbd_mode_q <= cbd_mode;
end

/////////////////////////////////////////////////////////////////////////


endmodule