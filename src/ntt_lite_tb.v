`timescale 1ns / 1ps

module ntt_lite_tb();

`include "ntt_lite.vh"

parameter HP = 5;
parameter FP = (2*HP);
parameter B = 32;
parameter LOGQ = 32;
parameter N = 16;
//parameter L = 11;
parameter EN_NTT_OTF = 1;
localparam LOGN = $clog2(N);
localparam LOGLOGN = $rtoi($ceil($clog2(LOGN+1))); 
localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));

localparam LOGQB = $clog2(LOGQ/B);
localparam QBMASK = (1 << LOGQB) - 1;

localparam TB_MODE = `MODE_NTT;
localparam TB_OTF = 0;

localparam N_ = (TB_MODE == `MODE_PWM && TB_OTF == 1) ? N/2 : N;


reg clk;
reg rst;

reg [LOGQ  :0] q [0:1]; // higher address is for mu
reg [LOGQ-1:0] psi      [0:N-1];
reg [LOGQ-1:0] poly_in  [0:N-1];
reg [LOGQ-1:0] poly_out [0:N-1];

reg  [2  :0] cmd;
reg  [1  :0] mode;
reg          otf;
reg  [LOGLOGN-1:0] logn;
reg  [LOGLOGQ-1:0] logq;
reg  [B-1:0] i_data;
reg          o_read;
reg          i_valid;
wire         i_ready;
wire [B-1:0] o_data;
wire         o_valid;
wire         busy;
wire         done;
wire [LOGN+LOGQB-1:0] io_word;


always #HP clk = ~clk;

integer flag;

ntt_lite #(
    .LOGN(LOGN),
    .LOGQ(LOGQ),
    .B(B),
   // .L(L),
    .EN_NTT_OTF(EN_NTT_OTF)
) ntt_lite_inst (
    .clk(clk),
    .rst(rst),
    .cmd(cmd),
    .mode(mode),
    .otf(otf),
    .logn(logn),
    .logq(logq),
    .q(q[0]),
    .mu(q[1]),
    .i_data(i_data),
    .i_valid(i_valid),
    .i_ready(i_ready),
    .o_read(o_read),
    .o_data(o_data),
    .o_valid(o_valid),
    .busy(busy),
    .done(done),
    .io_word(io_word)
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
    o_read = 1'b0;
    logn = LOGN;
    logq = 12;

/*    cmd = `CMD_LOAD_Q;
    #FP;
    while (!done) begin
        if (i_ready) begin
            i_data = q[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
            #FP;
        end
    end
    i_valid = 1'b0;*/

    if ((TB_MODE == `MODE_NTT) && TB_OTF) begin
        otf = 1;
    end
    else begin
        otf = 0;    
    end
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
            #FP;
        end
    end

    i_valid = 1'b0;
    otf = TB_OTF;

    cmd = `CMD_LOAD_POLY;
    #FP;
    flag = 0;

    while(!done) begin
        if (i_ready) begin
            i_data = poly_in[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
            o_read = 1'b0;
        end
        else if (o_valid) begin
            o_read = 1'b1;
            i_valid = 1'b0;
            $display("Output: %h", o_data);
            if (o_data != poly_out[io_word >> LOGQB][(io_word & QBMASK) * B +: B]) begin
                $display("Output mismatch at index %d: %h != %h", io_word, o_data, poly_out[io_word >> LOGQB][(io_word & QBMASK) * B +: B]);
                flag = 1;
            end
        end
        else begin
            o_read = 1'b0;
            i_valid = 1'b0;
        end
        #FP;
    end
    o_read = 1'b0;
    i_valid = 1'b0;

    $display("Simulation finished.");
    if (flag == 0)
        $display("(SUCCESS)");
    else
        $display("(FAIL)");
    $finish;

end

endmodule