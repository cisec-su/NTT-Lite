`timescale 1ns / 1ps
module karatsuba_64x64_dual_tb();


parameter TEST_NUM = 10000;

parameter HP = 5;
parameter FP = (2*HP);

parameter FF_IN     = 0;
parameter FF_SUM0   = 0;
parameter FF_SUB0   = 0;
parameter FF_MUL    = 1;
parameter FF_SUM1   = 0;
parameter FF_SUM2   = 0;
parameter FF_SUB1   = 0;
parameter FF_OUT    = 1;

localparam LAT = FF_IN + FF_SUM0 + FF_SUB0 + FF_MUL + FF_SUM1 + FF_SUM2 + FF_SUB1 + FF_OUT;

reg clk;
reg  [63:0] A;
reg  [63:0] B;
wire [127:0] C;
reg  [127:0] C_[0:LAT-1];
integer i;

always #HP clk = ~clk;


karatsuba_64x64_dual #(
    .FF_IN(FF_IN),
    .FF_SUM0(FF_SUM0),
    .FF_SUB0(FF_SUB0), 
    .FF_MUL(FF_MUL),
    .FF_SUM1(FF_SUM1),
    .FF_SUM2(FF_SUM2),
    .FF_SUB1(FF_SUB1),
    .FF_OUT(FF_OUT)
)  karatsuba (
    .clk(clk),
    .A(A),
    .B(B),
    .dual(0),
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

