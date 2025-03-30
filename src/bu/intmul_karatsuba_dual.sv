`include "intmul_karatsuba_dual.svh"

module intmul_karatsuba_dual
   #(  
        parameter LOGA    = 64    ,        
        parameter LOGM    = 16    ,
        parameter FF_IN_A = 1     ,
        parameter FF_IN_B = 1     ,
        parameter FF_SUM  = 0     ,
        parameter FF_MUL  = 1     ,
        parameter FF_SUB  = 0     ,
        parameter FF_OUT  = 1
    )
    (
        input               clk ,
        input               dual,
        input   [LOGA-1:0]  A   ,
        input   [LOGA-1:0]  B   ,
        output  [LOGC-1:0]  C
    );


///////////////////////////// input check ///////////////////////////////

if ((LOGA & (LOGA - 1)) != 0) begin
    LOGA_MUST_BE_POWER_OF_2();
end
if ((LOGM & (LOGM - 1)) != 0) begin
    LOGM_MUST_BE_POWER_OF_2();
end
if (LOGA < LOGM) begin
    LOGM_MUST_BE_LESS_THAN_LOGA();
end

/////////////////////////////////////////////////////////////////////////



///////////////////////////// parameters ////////////////////////////////

localparam intmul_karatsuba_dual_params_t params = {FF_IN_A, FF_IN_A, FF_SUM, FF_MUL, FF_SUB, FF_OUT};
localparam LOGA0 = LOGA >> 1;
localparam LOGC0 = LOGA0 << 1;
localparam LOGC = LOGC0 << 1;
localparam LAT  = intmul_karatsuba_dual_lat(params);

localparam N_A = ((LOGA - 1) / LOGM) + 1;

localparam LOGT = LOGM + 1;

localparam LOGP0 = LOGM << 1;
localparam LOGP1 = LOGT << 1;
localparam LOGP  = (LOGM << 1) + 1;

localparam LOGD = LOGA;
localparam N_D = (N_A >> 1) + (N_A >> 1) - 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// signals ///////////////////////////////////

wire [LOGM-1:0] A_i   [0:1][0:N_A-1];
reg  [LOGM-1:0] A_i_q [0:1][0:N_A-1];
wire [LOGM-1:0] A_i_mx[0:1][0:N_A-1];

wire [LOGM-1:0] B_i   [0:1][0:N_A-1];
reg  [LOGM-1:0] B_i_q [0:1][0:N_A-1];
wire [LOGM-1:0] B_i_mx[0:1][0:N_A-1];

(* use_dsp = "no" *) wire [LOGT-1:0] T_A [0:N_A-1][0:N_A-1];
reg  [LOGT-1:0] T_A_q [0:N_A-1][0:N_A-1];
wire [LOGT-1:0] T_A_mx[0:N_A-1][0:N_A-1];

(* use_dsp = "no" *) wire [LOGT-1:0] T_B [0:N_A-1][0:N_A-1];
reg  [LOGT-1:0] T_B_q [0:N_A-1][0:N_A-1];
wire [LOGT-1:0] T_B_mx[0:N_A-1][0:N_A-1];


(* use_dsp = "yes" *) wire [LOGP0-1:0] P_0 [0:N_A-1];
reg  [LOGP0-1:0] P_0_q [0:N_A-1];
wire [LOGP0-1:0] P_0_mx[0:N_A-1];

reg  [LOGP0-1:0] P_0_q1 [0:N_A-1];
wire [LOGP0-1:0] P_0_mx1[0:N_A-1];

(* use_dsp = "yes" *) wire [LOGP1-1:0] P_1 [0:N_A-1][0:N_A-1];
reg  [LOGP1-1:0] P_1_q [0:N_A-1][0:N_A-1];
wire [LOGP1-1:0] P_1_mx[0:N_A-1][0:N_A-1];

(* use_dsp = "no" *) wire [LOGP-1:0] P [0:N_A-1][0:N_A-1];
reg  [LOGP-1:0] P_q [0:N_A-1][0:N_A-1];
wire [LOGP-1:0] P_mx[0:N_A-1][0:N_A-1];

(* use_dsp = "no" *) reg [LOGD:0] D [0:1][0:1];

(* use_dsp = "no" *) reg [LOGC-1:0] S;
reg [LOGC-1:0] S_q;

int k, l;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// partitioning //////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign A_i[0][i] = A[LOGM*i +: LOGM];
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign B_i[0][i] = B[LOGM*i +: LOGM];
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// pipeline steps ////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign A_i_mx[0][i] = (FF_IN_A) ? A_i_q[0][i] : A_i[0][i];
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign B_i_mx[0][i] = (FF_IN_B) ? B_i_q[0][i] : B_i[0][i];
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = i + 1; j < N_A; j = j + 1) begin
        assign T_A_mx[i] = (FF_SUM) ? T_A_q[i] : T_A[i];
    end
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = i + 1; j < N_A; j = j + 1) begin
        assign T_B_mx[i] = (FF_SUM) ? T_B_q[i] : T_B[i];
    end
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign A_i_mx[1][i] = (FF_SUM) ? A_i_q[1][i] : A_i_mx[0][i];
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign B_i_mx[1][i] = (FF_SUM) ? B_i_q[1][i] : B_i_mx[0][i];
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign P_0_mx[i] = (FF_MUL) ? P_0_q[i] : P_0[i];
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = i + 1; j < N_A; j = j + 1) begin
        assign P_1_mx[i][j] = (FF_MUL) ? P_1_q[i][j] : P_1[i][j];
    end
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = i + 1; j < N_A; j = j + 1) begin
        assign P_mx[i][j] = (FF_SUB) ? P_q[i][j] : P[i][j];
    end
end
for (genvar i = 0; i < N_A; i = i + 1) begin
    assign P_0_mx1[i] = (FF_SUB) ? P_0_q1[i] : P_0_mx[i];
end

assign C = (FF_OUT) ? S_q : S;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// summation /////////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = i + 1; j < N_A; j = j + 1) begin
        assign T_A[i][j] = A_i_mx[0][i] + A_i_mx[0][j];
    end
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = i + 1; j < N_A; j = j + 1) begin
        assign T_B[i][j] = B_i_mx[0][i] + B_i_mx[0][j];
    end
end

/////////////////////////////////////////////////////////////////////////





///////////////////////////// multiplication ////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign P_0[i] = A_i_mx[1][i] * B_i_mx[1][i];
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = i + 1; j < N_A; j = j + 1) begin
        assign P_1[i][j] = T_A_mx[i][j] * T_B_mx[i][j];
    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// subtraction ///////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = i + 1; j < N_A; j = j + 1) begin
        assign P[i][j] = P_1_mx[i][j] - P_0_mx[i] - P_0_mx[j];
    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// summation /////////////////////////////////

for (genvar i = 0; i < 2; i = i + 1) begin
    for (genvar j = 0; j < 2; j = j + 1) begin
        always @(*) begin
            D[i][j] = 0;
            for (k = 0; k < (N_A >> 1); k = k + 1) begin
                for (l = 0; l < (N_A >> 1); l = l + 1) begin
                    if (((i*(N_A >> 1)) + k) <= ((j*(N_A >> 1)) + l)) begin
                        if (k == l && i == j) begin
                            D[i][j] = D[i][j] + ((P_0_mx1[((i*(N_A >> 1)) + k)]) << (LOGM * (k + l)));                                                    
                        end
                        else begin
                            D[i][j] = D[i][j] + ((P_mx[((i*(N_A >> 1)) + k)][((j*(N_A >> 1)) + l)]) << (LOGM * (k + l)));                        
                        end
                    end
                end
            end
        end
    end
end

always @(*) begin
    S = 0;
    case (dual)
        1'b0:
        begin
            S = {D[1][1][LOGD-1:0],D[0][0][LOGD-1:0]} + (D[0][1] << LOGA0);
        end
        1'b1:
        begin
            S[LOGC0-1:    0] = D[0][0][LOGD-1:0];
            S[LOGC -1:LOGC0] = D[1][1][LOGD-1:0];
        end
    endcase
end


/////////////////////////////////////////////////////////////////////////




///////////////////////////// sequential logic //////////////////////////


if (FF_IN_A) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        always @(posedge clk) begin
            A_i_q[0][i] <= A_i[0][i];
        end
    end
end
if (FF_IN_B) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        always @(posedge clk) begin
            B_i_q[0][i] <= B_i[0][i];
        end
    end
end

if (FF_SUM) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        for (genvar j = i + 1; j < N_A; j = j + 1) begin
            always @(posedge clk) begin
                T_A_q[i] <= T_A[i];
                T_B_q[i] <= T_B[i];
            end
        end
    end
end

if (FF_SUM) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        always @(posedge clk) begin
            A_i_q[1][i] <= A_i_mx[0][i];
        end
    end
end

if (FF_SUM) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        always @(posedge clk) begin
            B_i_q[1][i] <= B_i_mx[0][i];
        end
    end
end


if (FF_MUL) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        always @(posedge clk) begin
            P_0_q[i] <= P_0[i];
        end
    end
end
if (FF_MUL) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        for (genvar j = i + 1; j < N_A; j = j + 1) begin
            always @(posedge clk) begin
                P_1_q[i][j] <= P_1[i][j];
            end
        end
    end
end

if (FF_SUB) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        for (genvar j = i + 1; j < N_A; j = j + 1) begin
            always @(posedge clk) begin
                P_q[i][j] <= P[i][j];
            end
        end
    end
end
if (FF_SUB) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        always @(posedge clk) begin
            P_0_q1[i] <= P_0_mx[i];
        end
    end
end


if (FF_OUT) begin
    always @(posedge clk) begin
        S_q <= S;
    end
end

/////////////////////////////////////////////////////////////////////////


endmodule
