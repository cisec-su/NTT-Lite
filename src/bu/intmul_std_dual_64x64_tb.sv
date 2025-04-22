`timescale 1ns / 1ps

`include "intmul_std_dual_64x64.svh"

module intmul_std_dual_64x64_tb();

parameter          FF_IN_A = 0;
parameter          FF_IN_B = 0;
parameter          FF_MUL  = 0;
parameter          FF_OUT  = 0;
parameter HP               = 5 ;
parameter FP               = (2 * HP);
parameter TEST_NUM         = 100000;


localparam intmul_std_dual_64x64_params_t params = {FF_IN_A, FF_IN_B, FF_MUL, FF_OUT};
localparam LOGA = 64;
localparam LOGB = 64;
localparam LOGA0 = 64;
localparam LOGB0 = 64;
localparam LOGC0 = (LOGA0 + LOGB0);
localparam LOGC = LOGC0 << 1;
localparam LAT  = intmul_std_dual_64x64_lat(params);



integer i    = 0;
integer seed = 0;
integer f    = 0;
integer j    = 0;


reg                         clk     ;
reg                         dual    ;
reg         [LOGA   -1:0]   A       ;
reg         [LOGB   -1:0]   B       ;
reg         [LOGC   -1:0]   C_      ;
reg         [LOGC     :0]   C       ;
reg         [LOGC     :0]   C_d[0:intmul_std_dual_64x64_inst.LAT - 1];
wire        [LOGC     :0]   C_mx    ;


always #HP clk = ~clk;


for (genvar i = 1; i < intmul_std_dual_64x64_inst.LAT; i = i + 1) begin
    always @(posedge clk) begin
        C_d[i] <= C_d[i - 1];
    end
end

if (intmul_std_dual_64x64_inst.LAT > 0) begin
    always @(posedge clk) begin
        C_d[0] <= C;
    end
    assign C_mx = C_d[intmul_std_dual_64x64_inst.LAT - 1];
end
else begin
    assign C_mx = C;
end


intmul_std_dual_64x64 #(
    .FF_IN_A(FF_IN_A),
    .FF_IN_B(FF_IN_B),
    .FF_MUL (FF_MUL ),
    .FF_OUT (FF_OUT )
) intmul_std_dual_64x64_inst (
    .clk     (clk     ),
    .dual    (dual    ),
    .A       (A       ),
    .B       (B       ),
    .C       (C_      )
);

initial begin
    $display("Simulation started.");

    clk = 1'b0;
    #(HP);


    @(posedge clk);
    @(posedge clk);

    dual = 1'b0;

    for (i = 0; i < TEST_NUM + intmul_std_dual_64x64_inst.LAT; i = i + 1) begin
        #0.1

        if (i < TEST_NUM) begin
            A  = {$urandom(2*i),$urandom(2*i + 1),$urandom(2*i + 2),$urandom(2*i + 3)} % ((1 << LOGA) - 1);
            B  = {$urandom(2*A ),$urandom(2*A  + 1),$urandom(2*A  + 2),$urandom(2*A  + 3)} % ((1 << LOGB) - 1);
            C  = A*B;
            $display("[Test %d] A = %x, B = %x, C = %x", i, A, B, C);
        end
        else begin
            A = 0;
            B = 0;    
            C = 0;                
        end

        #0.1

        if (i >= intmul_std_dual_64x64_inst.LAT) begin
            if (C_ != C_mx) begin
                $display("FAILED (%d)! Expected C = %x, Got C = %x\n", i - intmul_std_dual_64x64_inst.LAT, C_mx, C_);
                f += 1;
                $stop;
            end
        end

        @(posedge clk);
    end


    @(posedge clk);
    @(posedge clk);

    dual = 1'b1;

    for (i = 0; i < TEST_NUM + intmul_std_dual_64x64_inst.LAT; i = i + 1) begin
        #0.1

        if (i < TEST_NUM) begin
            A[LOGA0-1:    0] = {$urandom(4*i    ),$urandom(4*i + 1)} % ((1 << LOGA0) - 1);
            A[LOGA -1:LOGA0] = {$urandom(4*i + 2),$urandom(4*i + 3)} % ((1 << LOGA0) - 1);
            B[LOGB0-1:    0] = {$urandom(4*A    ),$urandom(4*A + 1)} % ((1 << LOGB0) - 1);
            B[LOGB -1:LOGB0] = {$urandom(4*A + 2),$urandom(4*A + 3)} % ((1 << LOGB0) - 1);
            C[LOGC0-1:    0] = A[LOGA0-1:    0] * B[LOGB0-1:    0];
            C[LOGC -1:LOGC0] = A[LOGA -1:LOGA0] * B[LOGB -1:LOGB0];
            $display("[Test %d] A = %x, B = %x, C = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x",
            i, A, B, C, A[LOGA0-1:0], A[LOGA-1:LOGA0], B[LOGB0-1:0], B[LOGB-1:LOGB0], C[LOGC0-1:0], C[LOGC-1:LOGC0]);
        end
        else begin
            A = 0;
            B = 0;
            C = 0;
        end

        #0.1

        if (i >= intmul_std_dual_64x64_inst.LAT) begin
            if (C_ != C_mx) begin
                $display("FAILED (%d)! Expected C = %x, Got C = %x, C0 = %x, C1 = %x\n",
                         i - intmul_std_dual_64x64_inst.LAT, C_mx, C_, C[LOGC0-1:0], C[LOGC-1:LOGC0]);
                f += 1;
                $stop;
            end
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