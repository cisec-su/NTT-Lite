`timescale 1ns / 1ps

module modadd_tb();

parameter LOGQ     = 64;
parameter LOGQH    = 17; 
parameter LOGQH_DUAL = 15;
parameter FF_IN    = 1 ;
parameter FF_ADD   = 0 ;
parameter FF_OUT   = 0 ;
parameter EN_DUAL  = 1 ;
parameter HP       = 5 ;
parameter FP       = (2 * HP);
parameter TEST_NUM = 1000;

localparam LOGQ0 = LOGQ >> 1;

integer i    = 0;
integer seed = 0;
integer f    = 0;
integer j    = 0;


reg                   clk ;
reg                   dual;
reg   [LOGQ   -1:0]   A   ;
reg   [LOGQ   -1:0]   B   ;
reg   [LOGQH  -1:0]   qH  ;
reg   [LOGQ   -1:0]   q   ;
reg   [LOGQ   -1:0]   C_  ;
reg   [LOGQ     :0]   C   ;
reg   [LOGQ     :0]   C_d[0:modadd_inst.LAT - 1];
wire  [LOGQ     :0]   C_mx;

always #HP clk = ~clk;


for (genvar i = 1; i < modadd_inst.LAT; i = i + 1) begin
    always @(posedge clk) begin
        C_d[i] <= C_d[i - 1];
    end
end

if (modadd_inst.LAT > 0) begin
    always @(posedge clk) begin
        C_d[0] <= C;
    end
    assign C_mx = C_d[modadd_inst.LAT - 1];
end
else begin
    assign C_mx = C;
end


modadd #(
    .LOGQ   (LOGQ   ),
    .LOGQH  (LOGQH  ),
    .EN_DUAL(EN_DUAL),
    .FF_IN  (FF_IN  ),
    .FF_ADD (FF_ADD ),
    .FF_OUT (FF_OUT )
) modadd_inst (
    .clk (clk ),
    .dual(dual),
    .A   (A   ),
    .B   (B   ),
    .qH  (qH  ),
    .C   (C_  )
);

initial begin
    $display("Simulation started.");

    clk = 1'b0;
    #(HP);

    @(posedge clk);
    @(posedge clk);

    dual = 0;

    for (i = 0; i < TEST_NUM + modadd_inst.LAT; i = i + 1) begin
        #0.01

        if (i < TEST_NUM) begin
            qH = {$urandom(2*i),$urandom(2*i + 1)} & ((1 << LOGQH) - 1);
            q  = (qH << (LOGQ - LOGQH)) + 1;
            A  = {$urandom(2*qH),$urandom(2*qH + 1)} % q;
            B  = {$urandom(2*A ),$urandom(2*A  + 1)} % q;
            C  = (A + B) % q;
            $display("[Test %d] A = %x, B = %x, qH = %x, q = %x, C = %x", i, A, B, qH, q, C);
        end
        else begin
            A = 0;
            B = 0;    
            qH = 0;                
        end

        #0.01

        if (i >= modadd_inst.LAT) begin
            if (C_ != C_mx) begin
                $display("FAILED (%d)! Expected C = %x, Got C = %x\n", i - modadd_inst.LAT, C_mx, C_);
                f += 1;
                $stop;
            end
        end

        @(posedge clk);
    end

    @(posedge clk);
    @(posedge clk);

    dual = 1'b1;

    if (EN_DUAL) begin

        for (i = 0; i < TEST_NUM + modadd_inst.LAT; i = i + 1) begin
            #0.01

            if (i < TEST_NUM) begin
                qH = {$urandom(2*i),$urandom(2*i + 1)} & ((1 << LOGQH_DUAL) - 1);
                q  = (qH << (LOGQ0 - LOGQH_DUAL)) + 1;
                A[LOGQ0-1:    0]  = {$urandom(4*qH),$urandom(4*qH + 1)} % q;
                A[LOGQ -1:LOGQ0]  = {$urandom(4*qH),$urandom(4*qH + 3)} % q;
                B[LOGQ0-1:    0]  = {$urandom(4*A ),$urandom(4*A  + 1)} % q;
                B[LOGQ -1:LOGQ0]  = {$urandom(4*A ),$urandom(4*A  + 3)} % q;
                C[LOGQ0-1:    0]  = (A[LOGQ0-1:    0] + B[LOGQ0-1:    0]) % q;
                C[LOGQ -1:LOGQ0]  = (A[LOGQ -1:LOGQ0] + B[LOGQ -1:LOGQ0]) % q;

                $display("[Test DUAL %d] A = %x, B = %x, qH = %x, q = %x, C = %x", i, A, B, qH, q, C);
            end
            else begin
                A = 0;
                B = 0;    
                qH = 0;                
            end

            #0.01

            if (i >= modadd_inst.LAT) begin
                if (C_[LOGQ0-1:0] != C_mx[LOGQ0-1:0]) begin
                    $display("FAILED DUAL0 (%d)! Expected C = %x, Got C = %x\n", i - modadd_inst.LAT, C_mx[LOGQ0-1:0], C_[LOGQ0-1:0]);
                    f += 1;
                    $stop;
                end
                else if (C_[LOGQ-1:LOGQ0] != C_mx[LOGQ-1:LOGQ0]) begin
                    $display("FAILED DUAL0 (%d)! Expected C = %x, Got C = %x\n", i - modadd_inst.LAT, C_mx[LOGQ-1:LOGQ0], C_[LOGQ-1:LOGQ0]);
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