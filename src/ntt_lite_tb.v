`timescale 1ns / 1ps

module ntt_lite_tb();

`include "ntt_lite.vh"

parameter HP = 5;
parameter FP = (2*HP);
parameter B = 32;
parameter LOGQ = 64;
parameter N = 16;
parameter L = 11;
parameter EN_PWM_OTF = 1;
parameter EN_NTT_OTF = 1;
localparam LOGN = $clog2(N);

localparam LOGWB = $clog2(LOGQ/B);
localparam WBMASK = (1 << LOGWB) - 1;

localparam TB_MODE = `MODE_NTT;
localparam TB_OTF = 1;

localparam N_ = (TB_MODE == `MODE_PWM && TB_OTF == 1) ? N/2 : N;

reg clk;
reg rst;

reg [LOGQ-1:0] q [0:0];
reg [LOGQ-1:0] psi      [0:N-1];
reg [LOGQ-1:0] poly_in  [0:N-1];
reg [LOGQ-1:0] poly_out [0:N-1];

reg  [2  :0] cmd;
reg  [1  :0] mode;
reg          otf;
reg  [B-1:0] i_data;
reg          i_read;
reg          i_valid;
wire [B-1:0] o_data;
wire         o_valid;
wire         busy;

integer i, j;

always #HP clk = ~clk;


ntt_lite #(
    .LOGN(LOGN),
    .LOGQ(LOGQ),
    .B(B),
    .L(L),
    .EN_NTT_OTF(EN_NTT_OTF),
    .EN_PWM_OTF(EN_PWM_OTF)
) ntt_lite_inst (
    .clk(clk),
    .rst(rst),
    .cmd(cmd),
    .mode(mode),
    .otf(otf),
    .i_data(i_data),
    .i_valid(i_valid),
    .i_read(i_read),
    .o_data(o_data),
    .o_valid(o_valid),
    .busy(busy)
);

initial begin

    $readmemh("../../../../../test/q.txt" , q);
    $readmemh("../../../../../test/psi.txt" , psi);
    $readmemh("../../../../../test/poly_in.txt" , poly_in);
    
    if (TB_MODE == `MODE_PWM)
        $readmemh("../../../../../test/mul_out.txt" , poly_out);
    else if (TB_MODE == `MODE_NTT)
        $readmemh("../../../../../test/poly_out.txt" , poly_out);

    $display("Simulation started.");

    clk = 1'b0;
    rst = 1'b0;
    #FP;
    rst = 1'b1;
    #FP;
    rst = 1'b0;
    #(HP);
    #(1);

    mode = TB_MODE;
    otf = 1'b0;
    i_read = 1'b0;

    cmd = `CMD_LOAD_Q;
    for (i = 0; i < (LOGQ/B); i = i + 1) begin
        i_data = q[0] >> (i*B);
        i_valid = 1'b1;
        #FP;
    end
    i_valid = 1'b0;

    if ((TB_MODE == `MODE_NTT) && TB_OTF) begin
        otf = 1;
    end
    else begin
        otf = 0;    
    end
    cmd = `CMD_LOAD_TWIDDLE;
    for (i = 0; i < N; i = i + 1) begin
        for (j = 0; j < (LOGQ/B); j = j + 1) begin
            i_data = psi[i] >> (j*B);
            i_valid = 1'b1;
            #FP;
        end
    end
    if ((TB_MODE == `MODE_NTT) && TB_OTF) begin
        for (i = 0; i < LOGN; i = i + 1) begin
            for (j = 0; j < (LOGQ/B); j = j + 1) begin
                i_data = psi[i] >> (j*B);
                i_valid = 1'b1;
                #FP;
            end
        end
    end

    i_valid = 1'b0;
    otf = TB_OTF;

    cmd = `CMD_LOAD_POLY;
    for (i = 0; i < N_; i = i + 1) begin
        for (j = 0; j < (LOGQ/B); j = j + 1) begin
            i_data = poly_in[i] >> (j*B);
            i_valid = 1'b1;
            #FP;
        end
    end
    i_valid = 1'b0;
    i = 0;
    j = 0;

    while(1) begin
        #FP;
        if (o_valid) begin
            $display("Output: %h", o_data);
            if (o_data != poly_out[i >> LOGWB][(i & WBMASK) * B +: B]) begin
                $display("Output mismatch at index %d: %h != %h", i, o_data, poly_out[i >> LOGWB][(i & WBMASK) * B +: B]);
                j = 1;
            end
            i = i + 1;
            i_read = 1'b1;
        end
        else if(!busy) begin
            $display("Simulation finished.");
            if (j == 0)
                $display("(SUCCESS)");
            else
                $display("(FAIL)");
            $finish;
        end
    end

end

endmodule