`timescale 1ns / 1ps

module modmul_tb();

`include "mac_std_dual_32x34.svh"

parameter LOGQ             = 32;
parameter HP               = 5 ;
parameter FP               = (2 * HP);
parameter TEST_NUM         = 1000;
parameter TEST_NUM_OUTER   = 10;
parameter L                = 8;
parameter LOGQ_INIT        = 12;

localparam LOGQ0   = LOGQ >> 1;
localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));
localparam LOGD    = (LOGQ + 1) << 1;
localparam LOGD0   = LOGD >> 1;

integer i    = 0;
integer seed = 0;
integer f    = 0;
integer j    = 0;


reg                       clk ;
mode_mul_t                mode;
reg         [LOGQ-1:0]    Q   ;
reg         [LOGQ+1:0]    MU  ;
reg         [LOGLOGQ-1:0] logq;
reg         [LOGQ-1:0]    A   ;
reg         [LOGQ-1:0]    B   ;
reg         [LOGQ-1:0]    C_  ;
reg         [LOGQ  :0]    C   ;
reg         [LOGQ  :0]    C_d[0:L - 1];
wire        [LOGQ  :0]    C_mx;
reg         [LOGD-1:0]    D_  ;
reg         [LOGD-1:0]    D   ;
reg         [LOGD-1:0]    D_d[0:L - 1];
wire        [LOGD-1:0]    D_mx;


always #HP clk = ~clk;


for (genvar i = 1; i < L; i = i + 1) begin
    always @(posedge clk) begin
        C_d[i] <= C_d[i - 1];
        D_d[i] <= D_d[i - 1];
    end
end

if (L > 0) begin
    always @(posedge clk) begin
        C_d[0] <= C;
        D_d[0] <= D;
    end
    assign C_mx = C_d[L - 1];
    assign D_mx = D_d[L - 1];
end
else begin
    assign C_mx = C;
    assign D_mx = D;
end


modmul #(
    .LOGQ (LOGQ)
) modmul_inst (
    .clk (clk ),
    .mode(mode),
    .Q   (Q   ),
    .MU  (MU  ),
    .logq(logq),
    .A   (A   ),
    .B   (B   ),
    .C   (C_  ),
    .D   (D_  )
);

initial begin
    $display("Simulation started.");

    clk = 1'b0;
    #(HP);


    @(posedge clk);
    @(posedge clk);

    mode = MUL_SINGLE;

    logq = LOGQ_INIT;

    while (logq <= LOGQ) begin
        for (j = 0; j < TEST_NUM_OUTER; j = j + 1) begin
            #0.1
            Q  = ({$urandom(2*j ),$urandom(2*j  + 1)} % ((1 << logq) - 1)) | (1 << (logq - 1));
            MU = (1 << ({{(LOGQ+1){1'b0}},logq} << 1)) / {{(LOGQ+1){1'b0}},Q};
            for (i = 0; i < TEST_NUM + L; i = i + 1) begin
                #0.1

                if (i < TEST_NUM) begin
                    A  = {$urandom(2*i),$urandom(2*i + 1)} % Q;
                    B  = {$urandom(2*A ),$urandom(2*A  + 1)} % Q;
                    C  = {{(LOGQ+1){1'b0}},A}*{{(LOGQ+1){1'b0}},B} % {{(LOGQ+1){1'b0}},Q};
                    D  = {{(LOGQ+1){1'b0}},A} * {{(LOGQ+1){1'b0}},B} / {{(LOGQ+1){1'b0}},Q};
                    $display("[Test %d-%d-%d] A = %x, B = %x, C = %x, Q = %x, D = %x, MU = %x", logq, j, i, A, B, C, Q, D, MU);
                end
                else begin
                    A = 0;
                    B = 0;    
                    C = 0;
                    D = 0;                
                end

                #0.1

                if (i >= L) begin
                    if (C_ != C_mx || D_ != D_mx) begin
                        $display("FAILED (%d-%d-%d)! Expected C = %x, D = %x, Got C = %x, Got D = %x\n", logq, j, i - L, C_mx, D_mx, C_, D_);
                        f += 1;
                        $stop;
                    end
                end
                
                @(posedge clk);
            end
        end
        logq = logq + 1;
    end


    logq = LOGQ_INIT;

    @(posedge clk);
    @(posedge clk);

    mode = MUL_DUAL;

    while (logq <= (LOGQ >> 1)) begin
        for (j = 0; j < TEST_NUM_OUTER; j = j + 1) begin
            #0.1
            Q  = ({$urandom(2*j ),$urandom(2*j  + 1)} % ((1 << logq) - 1)) | (1 << (logq - 1));
            MU = (1 << ({{(LOGQ+1){1'b0}},logq} << 1)) / {{(LOGQ+1){1'b0}},Q};
            for (i = 0; i < TEST_NUM + L; i = i + 1) begin
                #0.1

                if (i < TEST_NUM) begin
                    A[LOGQ0-1:    0] = {$urandom(2*i    )} % Q;
                    A[LOGQ -1:LOGQ0] = {$urandom(2*i + 1)} % Q;
                    B[LOGQ0-1:    0] = {$urandom(2*A    )} % Q;
                    B[LOGQ -1:LOGQ0] = {$urandom(2*A + 1)} % Q;
                    C[LOGQ0-1:    0] = A[LOGQ0-1:    0] * B[LOGQ0-1:    0]  % Q;
                    C[LOGQ -1:LOGQ0] = A[LOGQ -1:LOGQ0] * B[LOGQ -1:LOGQ0]  % Q;
                    D[LOGD0-1:    0] = ({{LOGQ0{1'b0}},A[LOGQ0-1:    0]} * {{LOGQ0{1'b0}},B[LOGQ0-1:    0]} / {{LOGQ0{1'b0}},Q});
                    D[LOGD-1 :LOGD0] = {{LOGQ0{1'b0}},A[LOGQ -1:LOGQ0]} * {{LOGQ0{1'b0}},B[LOGQ -1:LOGQ0]} / {{LOGQ0{1'b0}},Q};

                    $display("[Test DUAL %d-%d-%d] A = %x, B = %x, C = %x, Q = %x, D = %x, MU = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x, D0 = %x, D1 = %x",
                              logq, j, i, A, B, C, Q, D, MU, A[LOGQ0-1:0], A[LOGQ-1:LOGQ0], B[LOGQ0-1:0], B[LOGQ-1:LOGQ0], C[LOGQ0-1:0], C[LOGQ-1:LOGQ0], D[LOGQ0-1:0], D[LOGQ-1:LOGQ0]);
                end
                else begin
                    A = 0;
                    B = 0;    
                    C = 0;
                    D = 0;                
                end

                #0.1

                if (i >= L) begin
                    if (C_ != C_mx || D_ != D_mx) begin
                        $display("FAILED DUAL (%d-%d-%d)! Expected C = %x, D = %x, Got C = %x, Got D = %x\n", logq, j, i - L, C_mx, D_mx, C_, D_);
                        f += 1;
                        $stop;
                    end
                end

                @(posedge clk);
            end
        end
        logq = logq + 1;
    end


    logq = LOGQ_INIT;

    @(posedge clk);
    @(posedge clk);

    mode = MUL_POLY;

    while (logq <= (LOGQ >> 1)) begin
        for (j = 0; j < TEST_NUM_OUTER; j = j + 1) begin
            #0.1
            Q  = ({$urandom(2*j ),$urandom(2*j  + 1)} % ((1 << logq) - 1)) | (1 << (logq - 1));
            MU = (1 << ({{(LOGQ+1){1'b0}},logq} << 1)) / {{(LOGQ+1){1'b0}},Q};
            for (i = 0; i < TEST_NUM + L; i = i + 1) begin
                #0.1

                if (i < TEST_NUM) begin
                    A[LOGQ0-1:    0] = {$urandom(2*i    )} % Q;
                    A[LOGQ -1:LOGQ0] = {$urandom(2*i + 1)} % Q;
                    B[LOGQ0-1:    0] = {$urandom(2*A    )} % Q;
                    B[LOGQ -1:LOGQ0] = {$urandom(2*A + 1)} % Q;
                    C[LOGQ0-1:    0] = (A[LOGQ -1:LOGQ0] * B[LOGQ-1:LOGQ0]  + A[LOGQ0-1:    0] * B[LOGQ0-1:    0]) % Q;
                    C[LOGQ -1:LOGQ0] = (A[LOGQ0-1:    0] * B[LOGQ-1:LOGQ0]  + A[LOGQ -1:LOGQ0] * B[LOGQ0-1:    0]) % Q;
                    D[LOGD0-1:    0] = (({{(LOGQ0+1){1'b0}},A[LOGQ0-1:    0]} * {{(LOGQ0+1){1'b0}},B[LOGQ0-1:    0]} + ({{(LOGQ0+1){1'b0}},A[LOGQ -1:LOGQ0]} * {{(LOGQ0+1){1'b0}},B[LOGQ -1:LOGQ0]})) / {{LOGQ0{1'b0}},Q});
                    D[LOGD-1 :LOGD0] = (({{(LOGQ0+1){1'b0}},A[LOGQ0-1:    0]} * {{(LOGQ0+1){1'b0}},B[LOGQ -1:LOGQ0]} + ({{(LOGQ0+1){1'b0}},A[LOGQ -1:LOGQ0]} * {{(LOGQ0+1){1'b0}},B[LOGQ0-1:    0]})) / {{LOGQ0{1'b0}},Q});

                    $display("[Test POLY %d-%d-%d] A = %x, B = %x, C = %x, Q = %x, D = %x, MU = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x, D0 = %x, D1 = %x",
                              logq, j, i, A, B, C, Q, D, MU, A[LOGQ0-1:0], A[LOGQ-1:LOGQ0], B[LOGQ0-1:0], B[LOGQ-1:LOGQ0], C[LOGQ0-1:0], C[LOGQ-1:LOGQ0], D[LOGQ0-1:0], D[LOGQ-1:LOGQ0]);
                end
                else begin
                    A = 0;
                    B = 0;    
                    C = 0;
                    D = 0;                
                end

                #0.1

                if (i >= L) begin
                    if (C_ != C_mx || (D_ != D_mx && logq != (LOGQ >> 1))) begin
                        $display("FAILED POLY (%d-%d-%d)! Expected C = %x, D = %x, Got C = %x, Got D = %x\n", logq, j, i - L, C_mx, D_mx, C_, D_);
                        f += 1;
                        $stop;
                    end
                end

                @(posedge clk);
            end
        end
        logq = logq + 1;
    end


    if (f > 0)
        $display("Total errors: %d", f);
    else
        $display("ALL PASSED!");


    $finish;
end

endmodule