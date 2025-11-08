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
        input                 rej_samp,
        input  [LOGQ    -1:0] bound   ,
        input                 i_valid ,
        input                 center  ,
        input  [LOGLOGQ -1:0] k       ,
        output                o_valid ,
        output [LOGQ    -1:0] C
    );

///////////////////////////// parameters ////////////////////////////////

localparam LOGQ0 = LOGQ >> 1;
localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));

/////////////////////////////////////////////////////////////////////////




///////////////////////// Signals Declaration ///////////////////////////

reg  [LOGQ-1:0] A_q;
reg  [LOGQ-1:0] C_q;
reg  [LOGQ-1:0] Q_q;
wire [LOGQ-1:0] C_mx;
reg  [LOGQ0-1:0] T0L;
reg  [LOGQ0-1:0] T0H;
reg  [LOGQ0-1:0] T1L;
reg  [LOGQ0-1:0] T1H;
wire [LOGQ-1:0] T0;
wire [LOGQ-1:0] T1;
reg  cbd_mode_q;
wire dual;
reg  dual_q;
reg [LOGLOGQ -1:0] k_q;
wire [LOGQ-1:0] modsub0_in_A;
wire [LOGQ-1:0] modsub0_in_B;
wire [LOGQ-1:0] modsub0_in_C;
wire [LOGQ-1:0] modsub1_out_C;
wire [LOGQ -1:0] mask_k;
wire [LOGQ -1:0] mask_k_dual;


reg rej_samp_q;
reg center_q;
wire sub_corr;
wire sub_corr0;
wire sub_corr1;
wire i_valid_d;
wire o_valid_mx;
reg o_valid_rejsamp;
reg [LOGQ-1:0] C_rejsamp;
reg set_dual_full;
reg clr_dual_full;
reg dual_full;
reg [LOGQ-1:0] bound_q;
wire [LOGQ-1:0] bound_half;
wire [LOGQ-1:0] rej_samp_sub_mx;
reg  [LOGQ0-1:0] rej_samp_mem;
reg  [LOGQ0-1:0] rej_samp_mem_next;
wire [LOGQ-1:0] A_q_masked;

/////////////////////////////////////////////////////////////////////////




///////////////////////// Comb. Assignments (CBD) ///////////////////////

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





////////////////////////////// Comb. Assignments (RejSamp) //////////////

assign rej_samp_sub_mx = (center) ? modsub1_out_C : A_q_masked;


always @(*) begin
    o_valid_rejsamp = 0;
    C_rejsamp = rej_samp_sub_mx;
    set_dual_full = 1'b0;
    clr_dual_full = 1'b0;
    rej_samp_mem_next = rej_samp_sub_mx[LOGQ0-1:0];
    if (i_valid_d) begin
        if (~dual_q) begin
            o_valid_rejsamp = sub_corr;
            C_rejsamp = rej_samp_sub_mx;
        end
        else begin
            if (dual_full) begin
                if (sub_corr0) begin
                    o_valid_rejsamp = 1'b1;
                    C_rejsamp = {rej_samp_sub_mx[LOGQ0-1:0], rej_samp_mem};
                    if (sub_corr1) begin
                        set_dual_full = 1'b1;
                        rej_samp_mem_next = rej_samp_sub_mx[LOGQ-1:LOGQ0];
                    end
                    else begin
                        clr_dual_full = 1'b1;
                    end
                end
                else if (sub_corr1) begin
                    o_valid_rejsamp = 1'b1;
                    C_rejsamp = {rej_samp_sub_mx[LOGQ-1:LOGQ0], rej_samp_mem};
                    clr_dual_full = 1'b1;
                end
            end
            else begin
                if (sub_corr0) begin
                    if (sub_corr1) begin
                        C_rejsamp = rej_samp_sub_mx;
                        o_valid_rejsamp = 1'b1;
                    end
                    else begin
                        set_dual_full = 1'b1;
                        rej_samp_mem_next = rej_samp_sub_mx[LOGQ0-1:0];
                    end
                end
                else if (sub_corr1) begin
                    set_dual_full = 1'b1;
                    rej_samp_mem_next = rej_samp_sub_mx[LOGQ-1:LOGQ0];
                end
            end
        end
    end
end

/////////////////////////////////////////////////////////////////////////




////////////////////////////// Comb. Assignments (Misc) /////////////////

assign mask_k      = (k_q == 0) ?  {LOGQ{1'b1}}                          : 
                                 ({{(LOGQ-1){1'b0}}, 1'b1} << k_q) - 1'b1;
assign mask_k_dual = (dual) ?    {mask_k[LOGQ0-1:0], mask_k[LOGQ0-1:0]} : 
                                  mask_k                                ;
assign A_q_masked = A_q & mask_k_dual;

assign modsub0_in_A = (rej_samp_q) ? (A_q_masked & mask_k_dual) : T0;
assign modsub0_in_B = (rej_samp_q) ? bound_q : T1;

assign o_valid_mx = (rej_samp_q) ? o_valid_rejsamp : i_valid_d;
assign C_mx = (rej_samp_q) ? C_rejsamp : modsub0_in_C;

/////////////////////////////////////////////////////////////////////////




/////////////////////////////// Modules /////////////////////////////////

modsub  #(
    .LOGQ(LOGQ)
) ms0 (
    .A    (modsub0_in_A),
    .B    (modsub0_in_B),
    .dual (dual_q      ),
    .Q    (Q_q         ),
    .corr (sub_corr    ),
    .corr0(sub_corr0   ),
    .corr1(sub_corr1   ),
    .C    (modsub0_in_C)
);


modsub  #(
    .LOGQ(LOGQ)
) ms1 (
    .A   (bound_half   ),
    .B   (A_q_masked   ),
    .dual(dual_q       ),
    .Q   (Q_q          ),
    .C   (modsub1_out_C)
);


asr #(
    .LOGQ(LOGQ)
) asr (
    .A   (bound_q),
    .d   (6'd1   ),
    .dual(dual_q ),
    .C   (bound_half)
);


shiftreg #(
    .SHIFT(1),
    .DATA (1)
) shreg0 (
    .clk     (clk      ),
    .rst     (rst      ),
    .data_in (i_valid  ),
    .data_out(i_valid_d)
);


shiftreg #(
    .SHIFT(1),
    .DATA (1)
) shreg1 (
    .clk     (clk       ),
    .rst     (rst       ),
    .data_in (o_valid_mx),
    .data_out(o_valid   )
);


/////////////////////////////////////////////////////////////////////////




///////////////////////// Seq. Assignments //////////////////////////////

always @(posedge clk) begin
    A_q <= A;
    C_q <= C_mx;
    Q_q <= Q;
    dual_q <= dual;
    cbd_mode_q <= cbd_mode;
    rej_samp_q <= rej_samp;
    center_q <= center;
    bound_q <= bound;
    k_q <= k;
end


always @(posedge clk) begin
    if (rst) begin
        dual_full <= 1'b0;
    end
    else begin
        if (set_dual_full) begin
            dual_full <= 1'b1;
        end
        else if (clr_dual_full) begin
            dual_full <= 1'b0;
        end
    end
end


always @(posedge clk) begin
    if (set_dual_full)
        rej_samp_mem <= rej_samp_mem_next;
end

/////////////////////////////////////////////////////////////////////////


endmodule