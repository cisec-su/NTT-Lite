`timescale 1ns / 1ps

module mac_std_dual_32x34_tb();

parameter mode_e_t MODE_E  = DIS_E;
parameter          FF_IN_A = 0;
parameter          FF_IN_B = 0;
parameter          FF_IN_E = 0;
parameter          FF_MUL  = 0;
parameter          FF_OUT  = 0;
parameter HP               = 5 ;
parameter FP               = (2 * HP);
parameter TEST_NUM         = 100000;

`include "mac_std_dual_32x34.svh"

localparam LOGB = 32;
localparam mac_std_dual_32x34_params_t params = {LOGB, MODE_E, FF_IN_A, FF_IN_B, FF_IN_E, FF_MUL, FF_OUT};
localparam LOGA = mac_std_dual_32x34_loga(params);
localparam LOGE = mac_std_dual_32x34_loge(params);
localparam LOGA0 = mac_std_dual_32x34_loga0(params);
localparam LOGB0 = mac_std_dual_32x34_logb0(params);
localparam LOGE0 = mac_std_dual_32x34_loge0(params);
localparam LOGD  = mac_std_dual_32x34_logd(params);
localparam LOGD0 = mac_std_dual_32x34_logd0(params);
localparam LOGC = mac_std_dual_32x34_logc(params);
localparam LOGC0 = mac_std_dual_32x34_logc0(params);
localparam LAT  = mac_std_dual_32x34_lat(params);



integer i    = 0;
integer seed = 0;
integer f    = 0;
integer j    = 0;


reg                         clk     ;
mode_mul_t                  mode_mul;
reg         [LOGA   -1:0]   A       ;
reg         [LOGB   -1:0]   B       ;
reg         [LOGE   -1:0]   E       ;
reg         [LOGC   -1:0]   C_      ;
reg         [LOGC     :0]   C       ;
reg         [LOGC     :0]   C_d[0:mac_std_dual_32x34_inst.LAT - 1];
wire        [LOGC     :0]   C_mx    ;


always #HP clk = ~clk;


for (genvar i = 1; i < mac_std_dual_32x34_inst.LAT; i = i + 1) begin
    always @(posedge clk) begin
        C_d[i] <= C_d[i - 1];
    end
end

if (mac_std_dual_32x34_inst.LAT > 0) begin
    always @(posedge clk) begin
        C_d[0] <= C;
    end
    assign C_mx = C_d[mac_std_dual_32x34_inst.LAT - 1];
end
else begin
    assign C_mx = C;
end


mac_std_dual_32x34 #(
    .MODE_E (MODE_E),
    .LOGB(LOGB),
    .FF_IN_A(FF_IN_A),
    .FF_IN_B(FF_IN_B),
    .FF_IN_E(FF_IN_E),
    .FF_MUL (FF_MUL ),
    .FF_OUT (FF_OUT )
) mac_std_dual_32x34_inst (
    .clk     (clk     ),
    .mode_mul(mode_mul),
    .A       (A       ),
    .B       (B       ),
    .E       (E       ),
    .C       (C_      )
);

initial begin
    $display("Simulation started.");

    clk = 1'b0;
    #(HP);


    @(posedge clk);
    @(posedge clk);

    mode_mul = MUL_SINGLE;

    for (i = 0; i < TEST_NUM + mac_std_dual_32x34_inst.LAT; i = i + 1) begin
        #0.1

        if (i < TEST_NUM) begin
            A  = {$urandom(2*i),$urandom(2*i + 1)} % ((1 << LOGA) - 1);
            B  = {$urandom(2*A ),$urandom(2*A  + 1)} % ((1 << LOGB) - 1);
            C  = A*B;
            if (MODE_E == SUB_E) begin
                E = {$urandom(2*B),$urandom(2*B + 1)} % ((1 << LOGE) - 1);
                C = C - E;
                $display("[Test %d] A = %x, B = %x, C = %x, E = %x", i, A, B, C, E);
            end
            else
            begin
                E = 0;
                $display("[Test %d] A = %x, B = %x, C = %x", i, A, B, C);
            end
        end
        else begin
            A = 0;
            B = 0;    
            C = 0;                
            E = 0;
        end

        #0.1

        if (i >= mac_std_dual_32x34_inst.LAT) begin
            if (C_ != C_mx) begin
                $display("FAILED (%d)! Expected C = %x, Got C = %x\n", i - mac_std_dual_32x34_inst.LAT, C_mx, C_);
                f += 1;
                $stop;
            end
        end

        @(posedge clk);
    end


    @(posedge clk);
    @(posedge clk);

    mode_mul = MUL_DUAL;

    for (i = 0; i < TEST_NUM + mac_std_dual_32x34_inst.LAT; i = i + 1) begin
        #0.1

        if (i < TEST_NUM) begin
            A[LOGA0-1:    0] = {$urandom(4*i    ),$urandom(4*i + 1)} % ((1 << LOGA0) - 1);
            A[LOGA -1:LOGA0] = {$urandom(4*i + 2),$urandom(4*i + 3)} % ((1 << LOGA0) - 1);
            B[LOGB0-1:    0] = {$urandom(4*A    ),$urandom(4*A + 1)} % ((1 << LOGB0) - 1);
            B[LOGB -1:LOGB0] = {$urandom(4*A + 2),$urandom(4*A + 3)} % ((1 << LOGB0) - 1);
            C[LOGC0-1:    0] = A[LOGA0-1:    0] * B[LOGB0-1:    0];
            C[LOGC -1:LOGC0] = A[LOGA -1:LOGA0] * B[LOGB -1:LOGB0];
            if (MODE_E == SUB_E) begin
                E[LOGE0-1:    0] = {$urandom(4*B    ),$urandom(4*B + 1)} % ((1 << LOGE0) - 1);
                E[LOGE -1:LOGE0] = {$urandom(4*B + 2),$urandom(4*B + 3)} % ((1 << LOGE0) - 1);
                C[LOGC0-1:    0] = C[LOGC0-1:    0] - E[LOGE0-1:    0];
                C[LOGC -1:LOGC0] = C[LOGC -1:LOGC0] - E[LOGE -1:LOGE0];
                $display("[Test %d] A = %x, B = %x, C = %x, E = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x, E0 = %x, E1 = %x",
                         i, A, B, C, E, A[LOGA0-1:0], A[LOGA-1:LOGA0], B[LOGB0-1:0], B[LOGB-1:LOGB0], C[LOGC0-1:0], C[LOGC-1:LOGC0], E[LOGE0-1:0], E[LOGE-1:LOGE0]);
            end
            else
            begin
                E = 0;
                $display("[Test %d] A = %x, B = %x, C = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x",
                i, A, B, C, A[LOGA0-1:0], A[LOGA-1:LOGA0], B[LOGB0-1:0], B[LOGB-1:LOGB0], C[LOGC0-1:0], C[LOGC-1:LOGC0]);
       end
        end
        else begin
            A = 0;
            B = 0;
            C = 0;
            E = 0;
        end

        #0.1

        if (i >= mac_std_dual_32x34_inst.LAT) begin
            if (C_ != C_mx) begin
                $display("FAILED (%d)! Expected C = %x, Got C = %x, C0 = %x, C1 = %x\n",
                         i - mac_std_dual_32x34_inst.LAT, C_mx, C_, C[LOGC0-1:0], C[LOGC-1:LOGC0]);
                f += 1;
                $stop;
            end
        end

        @(posedge clk);
    end


    if (MODE_E != SUB_E) begin

        @(posedge clk);
        @(posedge clk);

        mode_mul = MUL_POLY;

        for (i = 0; i < TEST_NUM + mac_std_dual_32x34_inst.LAT; i = i + 1) begin
            #0

            if (i < TEST_NUM) begin
                A[LOGA0-1:    0] = {$urandom(4*i    ),$urandom(4*i + 1)} % ((1 << LOGA0) - 1);
                A[LOGA -1:LOGA0] = {$urandom(4*i + 2),$urandom(4*i + 3)} % ((1 << LOGA0) - 1);
                B[LOGB0-1:    0] = {$urandom(4*A    ),$urandom(4*A + 1)} % ((1 << LOGB0) - 1);
                B[LOGB -1:LOGB0] = {$urandom(4*A + 2),$urandom(4*A + 3)} % ((1 << LOGB0) - 1);
                C[LOGC0-1:    0] = A[LOGA0-1:    0] * B[LOGB0-1:    0] + A[LOGA -1:LOGA0] * B[LOGB -1:LOGB0];
                C[LOGC -1:LOGC0] = A[LOGA -1:LOGA0] * B[LOGB0-1:    0] + A[LOGA0-1:    0] * B[LOGB -1:LOGB0];
                $display("[Test %d] A = %x, B = %x, C = %x, A0 = %x, A1 = %x, B0 = %x, B1 = %x, C0 = %x, C1 = %x",
                        i, A, B, C, A[LOGA0-1:0], A[LOGA-1:LOGA0], B[LOGB0-1:0], B[LOGB-1:LOGB0], C[LOGC0-1:0], C[LOGC-1:LOGC0]);
            end
            else begin
                A = 0;
                B = 0;    
                C = 0;                
            end

            #0

            if (i >= mac_std_dual_32x34_inst.LAT) begin
                if (C_ != C_mx) begin
                    $display("FAILED (%d)! Expected C = %x, Got C = %x, C0 = %x, C1 = %x\n",
                            i - mac_std_dual_32x34_inst.LAT, C_mx, C_, C[LOGC0-1:0], C[LOGC-1:LOGC0]);
                    f += 1;
                    $stop;
                end
            end

            @(posedge clk);
        end
    
    end


    if (f > 0)
        $display("Total errors: %d", f);
    else
        $display("ALL PASSED!");


    $finish;
end

endmodule