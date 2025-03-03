`timescale 1ns / 1ps

module modsub_tb();

parameter LOGQ     = 32;
parameter HP       = 5 ;
parameter FP       = (2 * HP);
parameter TEST_NUM = 1000;

localparam LOGQ0 = LOGQ >> 1;

integer i    = 0;
integer seed = 0;
integer f    = 0;
integer j    = 0;


reg                clk ;
reg                dual;
reg   [LOGQ  :0]   A   ;
reg   [LOGQ  :0]   B   ;
reg   [LOGQ0 :0]   q0  ;
reg   [LOGQ  :0]   q   ;
reg   [LOGQ+1:0]   C_  ;
reg   [LOGQ+1:0]   C   ;
reg   [LOGQ-1:0]   T_  ;
reg   [LOGQ-1:0]   T   ;

always #HP clk = ~clk;


modsub #(
    .LOGQ   (LOGQ)
) modsub_inst (
    .dual(dual),
    .A   (A   ),
    .B   (B   ),
    .q   (q   ),
    .C   (C_  ),
    .T   (T_  )
);

initial begin
    $display("Simulation started.");

    clk = 1'b0;
    #(HP);

    @(posedge clk);
    @(posedge clk);

    dual = 0;

    for (i = 0; i < TEST_NUM; i = i + 1) begin
        #0.01

        if (i < TEST_NUM) begin
            q = {$urandom(2*i ),$urandom(2*i + 1)} & ((1 << LOGQ) - 1);
            A = {$urandom(2*q ),$urandom(2*q + 1)} % q;
            B = {$urandom(2*A ),$urandom(2*A + 1)} % q;
            C = A - B;
            T = (C + q) % q;
            $display("[Test %d] A = %x, B = %x, q = %x, C = %x, T = %x", i, A, B, q, C, T);
        end
        else begin
            A = 0;
            B = 0;
            q = 0;
        end

        #0.01

        if (C_ != C || T != T_) begin
            $display("FAILED (%d)! Expected C = %x, T = %x, Got C = %x, T = %x\n", i, C, T, C_, T_);
            f += 1;
            $stop;
        end

        @(posedge clk);
    end

    @(posedge clk);
    @(posedge clk);

    dual = 1'b1;

    for (i = 0; i < TEST_NUM; i = i + 1) begin
        #0.01

        if (i < TEST_NUM) begin
            q0 = {$urandom(2*i),$urandom(2*i + 1)} & ((1 << LOGQ0) - 1);
            q  = {q0[LOGQ0-1:0], q0[LOGQ0-1:0]};
            A[LOGQ0-1:    0]  = {$urandom(4*q),$urandom(4*q + 1)} % q0;
            A[LOGQ -1:LOGQ0]  = {$urandom(4*q),$urandom(4*q + 3)} % q0;
            B[LOGQ0-1:    0]  = {$urandom(4*A ),$urandom(4*A  + 1)} % q0;
            B[LOGQ -1:LOGQ0]  = {$urandom(4*A ),$urandom(4*A  + 3)} % q0;
            T[LOGQ0-1:    0]  = (A[LOGQ0-1:    0] - B[LOGQ0-1:    0] + q0) % q0;
            T[LOGQ -1:LOGQ0]  = (A[LOGQ -1:LOGQ0] - B[LOGQ -1:LOGQ0] + q0) % q0;
            C[LOGQ0  :    0]  = (A[LOGQ0-1:    0] - B[LOGQ0-1:    0]);
            C[LOGQ+1 :LOGQ0+1]  = (A[LOGQ -1:LOGQ0] - B[LOGQ -1:LOGQ0]);

            $display("[Test %d] A = %x, B = %x, q = %x, C = %x, T = %x", i, A, B, q, C, T);
        end
        else begin
            A = 0;
            B = 0;    
            q = 0;                
        end

        #0.01

        if (C_ != C || T != T_) begin
            $display("FAILED (%d)! Expected C = %x, T = %x, Got C = %x, T = %x\n", i, C, T, C_, T_);
            f += 1;
            $stop;
        end

        @(posedge clk);

    end


    if (f > 0)
        $display("Total errors: %d", f);
    else
        $display("ALL PASSED!");


    $finish;
end

endmodule