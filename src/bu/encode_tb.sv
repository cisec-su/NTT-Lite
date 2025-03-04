`timescale 1ns / 1ps

module encode_tb();

`include "ntt_lite.vh"

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
integer ready_cnt = 0;


reg                   clk    ;
reg                   rst    ;
reg   [        1:0]   mode   ;
reg                   decode ;
reg                   i_valid;
wire                  i_ready;
wire                  o_valid;
reg                   dual   ;
reg   [LOGQ   -1:0]   A      ;
reg   [4*LOGQ -1:0]   T      ;
reg   [LOGLOGQ-1:0]   d      ;
reg   [LOGQ   -1:0]   C      ;
reg   [LOGQ   -1:0]   C_     ;

always #HP clk = ~clk;



encode #(
    .LOGQ   (LOGQ)
) encode_inst (
    .clk (clk ),
    .rst (rst ),
    .A   (A   ),
    .d   (d   ),
    .decode(decode),
    .mode(mode),
    .i_valid(i_valid),
    .i_ready(i_ready),
    .o_valid(o_valid),
    .C   (C_  )
);

initial begin
    $display("Simulation started.");

    clk = 1'b0;
    rst = 1'b0;
    #FP;
    rst = 1'b1;
    #FP;
    rst = 1'b0;
    #(HP);
    #(1);

    mode = `MODE_SINGLE;
    decode = 0;
    d = 1;
    C = 0;
    i_valid = 0;

    @(posedge clk);
    @(posedge clk);

    #0.01;


    for (d = 1; d < LOGQ; d = d + 1) begin
        for (j = 0; j < TEST_NUM; j = j + 1) begin

            A = {$urandom(2*j),$urandom(2*j + 1)} & ((1 << d) - 1);
            C = C ^ ((A & ((1 << d) - 1)) << i);
            i = i + d;
            i_valid = 1;

            @(posedge clk);

            #0.01;

            if (i >= LOGQ) begin
                if (!o_valid) begin
                    $display("FAILED (%d)! d = %d, Expected o_valid = 1, Got o_valid = 0\n", j, d);
                    f += 1;
                    $stop;
                end
                else begin
                    if (C != C_) begin
                        $display("FAILED (%d)! Expected C = %x, Got C = %x\n", j, C, C_);
                        f += 1;
                        $stop;
                    end
                end
                C = C >> LOGQ;
                i = i - LOGQ;
            end
            else if (o_valid) begin
                $display("FAILED (%d)! d = %d, Expected o_valid = 0, Got o_valid = 1\n", d, j);
                f += 1;
                $stop;
            end
        end
    end

    i_valid = 0;
    rst = 1'b1;
    @(posedge clk);
    #0.01;

    rst = 1'b0;
    mode = `MODE_POLY;


    @(posedge clk);
    @(posedge clk);

    #0.01;


    for (d = 1; d < LOGQ0; d = d + 1) begin
        for (j = 0; j < TEST_NUM; j = j + 1) begin

            A[LOGQ0-1:    0] = {$urandom(4*j    ),$urandom(4*j + 2)} & ((1 << d) - 1);
            A[LOGQ -1:LOGQ0] = {$urandom(4*j + 1),$urandom(4*j + 3)} & ((1 << d) - 1);
            C = C ^ ((A[LOGQ0-1:    0] & ((1 << d) - 1)) << i);
            i = i + d;
            C = C ^ ((A[LOGQ -1:LOGQ0] & ((1 << d) - 1)) << i);
            i = i + d;

            i_valid = 1;

            @(posedge clk);

            #0.01;

            if (i >= LOGQ) begin
                if (!o_valid) begin
                    $display("FAILED POLY (%d)! d = %d, Expected o_valid = 1, Got o_valid = 0\n", j, d);
                    f += 1;
                    $stop;
                end
                else begin
                    if (C != C_) begin
                        $display("FAILED POLY (%d)! Expected C = %x, Got C = %x\n", j, C, C_);
                        f += 1;
                        $stop;
                    end
                end
                C = C >> LOGQ;
                i = i - LOGQ;
            end
        end
    end


    i_valid = 0;
    rst = 1'b1;
    @(posedge clk);
    #0.01;

    rst = 1'b0;
    mode = `MODE_SINGLE;
    decode = 1'b1;

    @(posedge clk);
    @(posedge clk);
    #0.01;


    for (d = 1; d < LOGQ; d = d + 1) begin

        i = 0;
        T = 0;

        for (j = 0; j < TEST_NUM; j = j + 1) begin
            
            if (i_ready) begin
                A = {$urandom(2*j),$urandom(2*j + 1)} & ((1 << LOGQ) - 1);
                T = T ^ ({128'd0,A} << i);
                i_valid = 1;
                i = i + LOGQ;
                ready_cnt = ready_cnt + 1;
            end
            else begin
                i_valid = 0;
                if (i <= 0) begin
                    $display("FAILED decode (%d)! d = %d, Expected i_ready = 1, Got i_ready = 0\n", j, d);
                    $stop;
                end
            end

            C = T & ((1 << d) - 1);
            #0.01;
            T = T >> d;
            #0.01;
            i = i - d;

            @(posedge clk);

            #0.01;


            if (o_valid && (j != 0)) begin
                if (C != C_) begin
                    $display("FAILED decode (%d)! d = %d. Expected C = %x, Got C = %x\n", j, d, C, C_);
                    f += 1;
                    $stop;
                end
            end
            else if (!o_valid && (j != 0)) begin
                $display("FAILED decode (%d)! d = %d, Expected o_valid = 1, Got o_valid = 0\n", j, d);
                f += 1;
                $stop;
            end
        end

        i_valid = 0;
        rst = 1'b1;
        @(posedge clk);
        #0.01;
    
        rst = 1'b0;    
        @(posedge clk);
        @(posedge clk);
    
        #0.01;

    end


    i_valid = 0;
    rst = 1'b1;
    @(posedge clk);
    #0.01;

    rst = 1'b0;
    mode = `MODE_POLY;
    decode = 1'b1;
    ready_cnt = 0;
    @(posedge clk);
    @(posedge clk);

    #0.01;


    for (d = 1; d < LOGQ0; d = d + 1) begin

        i = 0;
        T = 0;

        for (j = 0; j < TEST_NUM; j = j + 1) begin
            
            if (i_ready) begin
                A = {$urandom(2*j),$urandom(2*j + 1)} & ((1 << LOGQ) - 1);
                T = T ^ ({128'd0,A} << i);
                i_valid = 1;
                i = i + LOGQ;
                ready_cnt = ready_cnt + 1;
            end
            else begin
                i_valid = 0;
                if (i <= 0) begin
                    $display("FAILED decode POLY (%d)! d = %d, Expected i_ready = 1, Got i_ready = 0\n", j, d);
                    $stop;
                end
            end

            C[LOGQ0-1:    0] = T & ((1 << d) - 1);
            T = T >> d;
            C[LOGQ   :LOGQ0] = T & ((1 << d) - 1);
            T = T >> d;
            #0.01;
            #0.01;
            i = i - d;
            i = i - d;

            @(posedge clk);

            #0.01;


            if (o_valid && (j != 0)) begin
                if (C != C_) begin
                    $display("FAILED decode POLY (%d)! d = %d. Expected C = %x, Got C = %x\n", j, d, C, C_);
                    f += 1;
                    $stop;
                end
            end
            else if (!o_valid && (j != 0)) begin
                $display("FAILED decode POLY (%d)! d = %d, Expected o_valid = 1, Got o_valid = 0\n", j, d);
                f += 1;
                $stop;
            end
        end

        i_valid = 0;
        rst = 1'b1;
        @(posedge clk);
        #0.01;
    
        rst = 1'b0;    
        @(posedge clk);
        @(posedge clk);
    
        #0.01;


    end

    

    if (f > 0)
        $display("Total errors: %d", f);
    else
        $display("ALL PASSED!");


    $finish;
end

endmodule