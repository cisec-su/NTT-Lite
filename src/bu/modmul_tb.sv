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


localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));

integer i    = 0;
integer seed = 0;
integer f    = 0;
integer j    = 0;


reg                      clk ;
mode_mul_t               mode;
reg         [LOGQ-1:0]   Q   ;
reg         [LOGQ+1:0]   MU  ;
reg         [LOGLOGQ-1:0] logq;
reg         [LOGQ-1:0]   A   ;
reg         [LOGQ-1:0]   B   ;
reg         [LOGQ-1:0]   C_  ;
reg         [LOGQ  :0]   C   ;
reg         [LOGQ  :0]   C_d[0:L - 1];
wire        [LOGQ  :0]   C_mx    ;


always #HP clk = ~clk;


for (genvar i = 1; i < L; i = i + 1) begin
    always @(posedge clk) begin
        C_d[i] <= C_d[i - 1];
    end
end

if (L > 0) begin
    always @(posedge clk) begin
        C_d[0] <= C;
    end
    assign C_mx = C_d[L - 1];
end
else begin
    assign C_mx = C;
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
    .C   (C_  )
);

initial begin
    $display("Simulation started.");

    clk = 1'b0;
    #(HP);


    @(posedge clk);
    @(posedge clk);

    mode = MUL_DOUBLE;

    logq = LOGQ_INIT;

    while (logq <= LOGQ) begin
        for (j = 0; j < TEST_NUM + L; j = j + 1) begin
            #0.1
            Q  = ({$urandom(2*j ),$urandom(2*j  + 1)} % ((1 << logq) - 1)) | (1 << (logq - 1));
            MU = (1 << ({{(LOGQ+1){1'b0}},logq} << 1)) / {{(LOGQ+1){1'b0}},Q};
            for (i = 0; i < TEST_NUM + L; i = i + 1) begin
                #0.1

                if (i < TEST_NUM) begin
                    A  = {$urandom(2*i),$urandom(2*i + 1)} % Q;
                    B  = {$urandom(2*A ),$urandom(2*A  + 1)} % Q;
                    C  = {{(LOGQ+1){1'b0}},A}*{{(LOGQ+1){1'b0}},B} % {{(LOGQ+1){1'b0}},Q};
                    $display("[Test %d-%d-%d] A = %x, B = %x, C = %x, Q = %x, MU = %x", logq, j, i, A, B, C, Q, MU);
                end
                else begin
                    A = 0;
                    B = 0;    
                    C = 0;                
                end

                #0.1

                if (i >= L) begin
                    if (C_ != C_mx) begin
                        $display("FAILED (%d-%d-%d)! Expected C = %x, Got C = %x\n", logq, j, i - L, C_mx, C_);
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

    // @(posedge clk);
    // @(posedge clk);

    // mode = MUL_DUAL;

    // for (i = 0; i < TEST_NUM + L; i = i + 1) begin
    //     #0.1

    //     if (i < TEST_NUM) begin
    //         A[LOGQ0-1:    0] = {$urandom(4*i    ),$urandom(4*i + 1)} % ((1 << LOGQ0) - 1);
    //         A[LOGQ -1:LOGQ0] = {$urandom(4*i + 2),$urandom(4*i + 3)} % ((1 << LOGQ0) - 1);
    //         B[LOGQ0-1:    0] = {$urandom(4*A    ),$urandom(4*A + 1)} % ((1 << LOGQ0) - 1);
    //         B[LOGQ -1:LOGQ0] = {$urandom(4*A + 2),$urandom(4*A + 3)} % ((1 << LOGQ0) - 1);
    //         C[LOGQ0-1:    0] = A[LOGQ0-1:    0] * B[LOGQ0-1:    0];
    //         C[LOGQ -1:LOGQ0] = A[LOGQ -1:LOGQ0] * B[LOGQ -1:LOGQ0];
    //         if (MODE_E == SUB_E) begin
    //             E[LOGE0-1:    0] = {$urandom(4*B    ),$urandom(4*B + 1)} % ((1 << LOGE0) - 1);
    //             E[LOGE -1:LOGE0] = {$urandom(4*B + 2),$urandom(4*B + 3)} % ((1 << LOGE0) - 1);
    //             C[LOGQ0-1:    0] = C[LOGQ0-1:    0] - E[LOGE0-1:    0];
    //             C[LOGQ -1:LOGQ0] = C[LOGQ -1:LOGQ0] - E[LOGE -1:LOGE0];
    //             $display("[Test %d] A = %x, B = %x, C = %x, E = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x, E0 = %x, E1 = %x",
    //                      i, A, B, C, E, A[LOGQ0-1:0], A[LOGQ-1:LOGQ0], B[LOGQ0-1:0], B[LOGQ-1:LOGQ0], C[LOGQ0-1:0], C[LOGQ-1:LOGQ0], E[LOGE0-1:0], E[LOGE-1:LOGE0]);
    //         end
    //         else
    //         begin
    //             E = 0;
    //             $display("[Test %d] A = %x, B = %x, C = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x",
    //             i, A, B, C, A[LOGQ0-1:0], A[LOGQ-1:LOGQ0], B[LOGQ0-1:0], B[LOGQ-1:LOGQ0], C[LOGQ0-1:0], C[LOGQ-1:LOGQ0]);
    //    end
    //     end
    //     else begin
    //         A = 0;
    //         B = 0;
    //         C = 0;
    //         E = 0;
    //     end

    //     #0.1

    //     if (i >= L) begin
    //         if (C_ != C_mx) begin
    //             $display("FAILED (%d)! Expected C = %x, Got C = %x, C0 = %x, C1 = %x\n",
    //                      i - L, C_mx, C_, C[LOGQ0-1:0], C[LOGQ-1:LOGQ0]);
    //             f += 1;
    //             $stop;
    //         end
    //     end

    //     @(posedge clk);
    // end


    // if (MODE_E != SUB_E) begin

    //     @(posedge clk);
    //     @(posedge clk);

    //     mode = MUL_POLY;

    //     for (i = 0; i < TEST_NUM + L; i = i + 1) begin
    //         #0

    //         if (i < TEST_NUM) begin
    //             A[LOGQ0-1:    0] = {$urandom(4*i    ),$urandom(4*i + 1)} % ((1 << LOGQ0) - 1);
    //             A[LOGQ -1:LOGQ0] = {$urandom(4*i + 2),$urandom(4*i + 3)} % ((1 << LOGQ0) - 1);
    //             B[LOGQ0-1:    0] = {$urandom(4*A    ),$urandom(4*A + 1)} % ((1 << LOGQ0) - 1);
    //             B[LOGQ -1:LOGQ0] = {$urandom(4*A + 2),$urandom(4*A + 3)} % ((1 << LOGQ0) - 1);
    //             C[LOGQ0-1:    0] = A[LOGQ0-1:    0] * B[LOGQ0-1:    0] + A[LOGQ -1:LOGQ0] * B[LOGQ -1:LOGQ0];
    //             C[LOGQ -1:LOGQ0] = A[LOGQ -1:LOGQ0] * B[LOGQ0-1:    0] + A[LOGQ0-1:    0] * B[LOGQ -1:LOGQ0];
    //             $display("[Test %d] A = %x, B = %x, C = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x",
    //                     i, A, B, C, A[LOGQ0-1:0], A[LOGQ-1:LOGQ0], B[LOGQ0-1:0], B[LOGQ-1:LOGQ0], C[LOGQ0-1:0], C[LOGQ-1:LOGQ0]);
    //         end
    //         else begin
    //             A = 0;
    //             B = 0;    
    //             C = 0;                
    //         end

    //         #0

    //         if (i >= L) begin
    //             if (C_ != C_mx) begin
    //                 $display("FAILED (%d)! Expected C = %x, Got C = %x, C0 = %x, C1 = %x\n",
    //                         i - L, C_mx, C_, C[LOGQ0-1:0], C[LOGQ-1:LOGQ0]);
    //                 f += 1;
    //                 $stop;
    //             end
    //         end

    //         @(posedge clk);
    //     end
    
    // end


    if (f > 0)
        $display("Total errors: %d", f);
    else
        $display("ALL PASSED!");


    $finish;
end

endmodule