`timescale 1ns / 1ps
module karatsuba_34x34_tb();


parameter TEST_NUM = 10000;

parameter HP = 5;
parameter FP = (2*HP);

parameter FF_IN     = 1;
parameter FF_SUB    = 1;
parameter FF_MUL    = 1;
parameter FF_SUM    = 1;
parameter FF_OUT    = 1;

localparam LAT = FF_IN + FF_SUM + FF_SUB + FF_MUL + FF_OUT;

reg clk;
reg  [33:0] A;
reg  [33:0] B;
wire [67:0] C;
reg  [67:0] C_[0:LAT-1];
integer i;

always #HP clk = ~clk;

karatsuba_34x34 #(
    .FF_IN(FF_IN),
    .FF_SUM(FF_SUM),
    .FF_SUB(FF_SUB), 
    .FF_MUL(FF_MUL),
    .FF_OUT(FF_OUT)
)  karatsuba (
    .clk(clk),
    .A(A),
    .B(B),
    .C(C)
);



initial begin


    $display("Simulation started.");

    clk = 1'b0;
    #FP;
    #FP;
    #(HP);
    #(1);

    for (i = 0; i < TEST_NUM + LAT; i = i + 1) begin
        A = {$urandom(), $urandom(), $urandom()};
        B = {$urandom(), $urandom(), $urandom()};
        C_[i % LAT] = (A*B);
        $display("A = %x, B = %x, C = %x", A, B, C_[i % LAT]);

        #FP;

        if (i >= LAT - 1) begin
            if (C == C_[(i - (LAT - 1)) % LAT])
                $display("SUCCESS!\n");
            else begin
                $display("ERROR: Expected C = %x\n", C_[(i - (LAT - 1)) % LAT]);
                $finish;
            end
        end
    end
    #FP;
    #FP;
    #FP;
    #FP;
    #FP;
    $display("ALL SUCCESS!\n");


    $finish;
end

endmodule

