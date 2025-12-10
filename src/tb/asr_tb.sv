`timescale 1ns / 1ps

module asr_tb();

parameter LOGQ     = 32;
parameter HP       = 5 ;
parameter FP       = (2 * HP);
parameter TEST_NUM = 1000;

localparam LOGQ0 = LOGQ >> 1;
localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));

integer i    = 0;
integer seed = 0;
integer f    = 0;
integer j    = 0;


reg                   clk ;
reg                   dual;
reg   [LOGQ   -1:0]   A   ;
reg   [LOGLOGQ-1:0]   d   ;
reg   [LOGQ   -1:0]   C   ;
reg   [LOGQ   -1:0]   C_  ;

always #HP clk = ~clk;



asr #(
    .LOGQ   (LOGQ)
) asr_inst (
    .A   (A   ),
    .d   (d   ),
    .dual(dual),
    .C   (C_  )
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
            A = {$urandom(2*i),$urandom(2*i + 1)} & ((1 << LOGQ) - 1);
            d = {$urandom(2*A),$urandom(2*A + 1)} & ((1 << LOGLOGQ) - 1);
            C = A >> d;
            $display("[Test %d] A = %x, d = %x, C = %x", i, A, d, C);
        end
        else begin
            A = 0;
            d = 0;    
            C = 0;                
        end

        #0.01

        if (C_ != C) begin
            $display("FAILED (%d)! Expected C = %x, Got C = %x\n", i, C, C_);
            f += 1;
            $stop;
        end

        @(posedge clk);
    end

    @(posedge clk);
    @(posedge clk);

    dual = 1;

    for (i = 0; i < TEST_NUM; i = i + 1) begin
        #0.01

        if (i < TEST_NUM) begin
            A[LOGQ0-1:0    ] = {$urandom(4*i    ),$urandom(4*i + 1)} & ((1 << LOGQ) - 1);
            A[LOGQ -1:LOGQ0] = {$urandom(4*i + 2),$urandom(4*i + 3)} & ((1 << LOGQ) - 1);
            d = {$urandom(2*A),$urandom(2*A + 1)} & ((1 << (LOGLOGQ - 1)) - 1);
            C[LOGQ0-1:0    ] = A[LOGQ0-1:0    ] >> d;
            C[LOGQ -1:LOGQ0] = A[LOGQ -1:LOGQ0] >> d;
            $display("[Test %d] A = %x, d = %x, C = %x, A0 = %x, A1 = %x, C0 = %x, C1 = %x", i, A, d, C,
                     A[LOGQ0-1:0], A[LOGQ -1:LOGQ0], C[LOGQ0-1:0], C[LOGQ -1:LOGQ0]);
        end
        else begin
            A = 0;
            d = 0;    
            C = 0;                
        end

        #0.01

        if (C_ != C) begin
            $display("FAILED (%d)! Expected C = %x, Got C = %x\n", i, C, C_);
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