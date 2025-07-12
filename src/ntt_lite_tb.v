`timescale 1ns / 1ps

module ntt_lite_tb();

`include "ntt_lite.vh"

parameter HP = 5;
parameter FP = (2*HP);
parameter B = 32;
parameter LOGQ = 32;
parameter LOGN = 8;
//parameter L = 11;
parameter EN_NTT_OTF = 1;
localparam N = 1 << LOGN;
localparam LOGLOGN = $rtoi($ceil($clog2(LOGN+1))); 
localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));

localparam LOGQB = $clog2(LOGQ/B);
localparam QBMASK = (1 << LOGQB) - 1;

localparam TB_OTF = 0;

localparam N_ = N;


reg clk;
reg rst;

reg [LOGQ-1:0] q;
wire [LOGQ*2-1:0] mu;
reg [LOGQ*2-1:0] mu_64;
reg [LOGQ*2-1:0] mu_32;
reg [LOGQ-1:0] inv2;
reg [LOGQ-1:0] bound;
reg [LOGQ*2-1:0] meta   [0:  7];
reg [LOGQ-1:0] psi      [0:N-1];
reg [LOGQ-1:0] poly_in  [0:N-1];
reg [LOGQ-1:0] poly_out [0:N-1];

reg  [3  :0] cmd;
reg  [3  :0] op;
reg          otf;
reg          rhs_const;
reg          op_switch;
reg          dual;
reg  [1  :0] mode;
reg  [LOGLOGN-1:0] logn;
reg  [LOGLOGQ-1:0] k;
reg  [LOGLOGQ-1:0] d;
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

integer flag, flag1;


ntt_lite #(
    .LOGN(LOGN),
    .LOGQ(LOGQ),
    .B(B),
    .EN_NTT_OTF(EN_NTT_OTF)
) ntt_lite_inst (
    .clk(clk),
    .rst(rst),
    .cmd(cmd),
    .op(op),
    .otf(otf),
    .logn(logn),
    .k(k),
    .mode(mode),
    .q(q),
    .floor(0),
    .bound(bound),
    .inv2(inv2),
    .d(d),
    .o_dis(1'b0),
    .rhs_const(rhs_const),
    .op_switch(op_switch),
    .mu(mu),
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

assign mu = (mode == `MODE_SINGLE) ? mu_64 : mu_32;


initial begin

    $readmemh("../../../../../test/meta.txt" , meta);
    $readmemh("../../../../../test/psi.txt" , psi);
    $readmemh("../../../../../test/poly_in_single.txt" , poly_in);
    $readmemh("../../../../../test/ntt_out_single.txt" , poly_out);

    $display("Simulation started.");

    clk = 1'b0;
    rst = 1'b0;
    #FP;
    rst = 1'b1;
    #FP;
    rst = 1'b0;
    #(HP);
    #(1);

    otf = 1'b0;
    o_read = 1'b0;
    rhs_const = 1'b0;
    op_switch = 1'b0;

    q = meta[0];
    mu_64 = meta[1];
    logn = meta[2];
    k = meta[3];
    d = meta[4];
    inv2 = meta[5];
    mu_32 = meta[6];
    bound = 0;

    op = `OP_NTT;
    mode = `MODE_SINGLE;

    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    i_valid = 1'b0;

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;

    flag = 0;
    flag1 = 0;

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

    if (flag == 0)
        $display("(SUCCESS SINGLE NTT)");
    else begin
        $display("(FAIL SINGLE NTT)");
        flag1 = 1;
    end

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
    $readmemh("../../../../../test/ntt_out_dual.txt" , poly_out);
    #FP;
    #FP;

    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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
        $display("(SUCCESS DUAL NTT)");
    else begin
        $display("(FAIL DUAL NTT)");
        flag1 = 1;
    end

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_single.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
    $readmemh("../../../../../test/mul_out_single.txt" , poly_out);

    op = `OP_PWM;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS SINGLE PWM)");
    else begin
        $display("(FAIL SINGLE PWM)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_dual.txt" , psi);
    $readmemh("../../../../../test/mul_out_dual.txt" , poly_out);

    op = `OP_PWM;
    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DUAL PWM)");
    else begin
        $display("(FAIL DUAL PWM)");
        flag1 = 1;
    end



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
    $readmemh("../../../../../test/mul_out_poly.txt" , poly_out);

    op = `OP_PWM;
    mode = `MODE_POLY;

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS POLY PWM)");
    else begin
        $display("(FAIL POLY PWM)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/ntt_out_single.txt" , poly_in);
    $readmemh("../../../../../test/psi_inv.txt" , psi);
    $readmemh("../../../../../test/poly_in_single.txt" , poly_out);

    op = `OP_INTT;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS SINGLE INTT)");
    else begin
        $display("(FAIL SINGLE INTT)");
        flag1 = 1;
    end

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    $readmemh("../../../../../test/ntt_out_dual.txt" , poly_in);
    $readmemh("../../../../../test/psi_inv.txt" , psi);
    $readmemh("../../../../../test/poly_in_dual.txt" , poly_out);

    op = `OP_INTT;
    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DUAL INTT)");
    else begin
        $display("(FAIL DUAL INTT)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    $readmemh("../../../../../test/poly_in_single.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
    $readmemh("../../../../../test/add_out_single.txt" , poly_out);

    op = `OP_ADD;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS SINGLE ADD)");
    else begin
        $display("(FAIL SINGLE ADD)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_single.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
    $readmemh("../../../../../test/sub_out_single.txt" , poly_out);

    op = `OP_SUB;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS SINGLE SUB)");
    else begin
        $display("(FAIL SINGLE SUB)");
        flag1 = 1;
    end


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_dual.txt" , psi);
    $readmemh("../../../../../test/add_out_dual.txt" , poly_out);

    op = `OP_ADD;
    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DUAL ADD)");
    else begin
        $display("(FAIL DUAL ADD)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_dual.txt" , psi);
    $readmemh("../../../../../test/sub_out_dual.txt" , poly_out);

    op = `OP_SUB;
    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DUAL SUB)");
    else begin
        $display("(FAIL DUAL SUB)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/comp_out_single.txt" , poly_in);
    $readmemh("../../../../../test/decomp_out_single.txt" , poly_out);

    op = `OP_DECOMPRESS;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS SINGLE DECOMPRESS)");
    else begin
        $display("(FAIL SINGLE DECOMPRESS)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/comp_out_dual.txt" , poly_in);
    $readmemh("../../../../../test/decomp_out_dual.txt" , poly_out);

    op = `OP_DECOMPRESS;
    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DUAL DECOMPRESS)");
    else begin
        $display("(FAIL DUAL DECOMPRESS)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_single.txt" , poly_in);
    $readmemh("../../../../../test/comp_out_single.txt" , poly_out);

    op = `OP_COMPRESS;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS SINGLE COMPRESS)");
    else begin
        $display("(FAIL SINGLE COMPRESS)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
    $readmemh("../../../../../test/comp_out_dual.txt" , poly_out);

    op = `OP_COMPRESS;
    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DUAL COMPRESS)");
    else begin
        $display("(FAIL DUAL COMPRESS)");
        flag1 = 1;
    end


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/encode_in_poly_d1.txt" , poly_in);
    $readmemh("../../../../../test/encode_out_poly_d1.txt" , poly_out);

    op = `OP_ENCODE;
    mode = `MODE_POLY;
    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
    flag = 0;
    d = 1; // this test is specific to d = 1 (poly_to_msg)

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

    if (flag == 0)
        $display("(SUCCESS POLY ENCODE d=1)");
    else begin
        $display("(FAIL POLY ENCODE d=1)");
        flag1 = 1;
    end

    d = meta[4];


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    $readmemh("../../../../../test/encode_out_poly.txt", psi);
    $readmemh("../../../../../test/comp_out_dual.txt", poly_out);

    mode = `MODE_POLY;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_START;
    op = `OP_DECODE;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS POLY DECODE)");
    else begin
        $display("(FAIL POLY DECODE)");
        flag1 = 1;
    end

    d = meta[4];


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
    $readmemh("../../../../../test/sum_out_dual.txt" , poly_out);
    #FP;
    #FP;

    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_POLY;
    op = `OP_SUM;
    #FP;
    cmd = 0;
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
        $display("(SUCCESS DUAL SUM)");
    else begin
        $display("(FAIL DUAL SUM)");
        flag1 = 1;
    end

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_dual.txt" , psi);
    $readmemh("../../../../../test/add_out_dual_const.txt" , poly_out);

    op = `OP_ADD;
    mode = `MODE_DUAL;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;
    rhs_const = 1'b1;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DUAL ADD CONST)");
    else begin
        $display("(FAIL DUAL ADD CONST)");
        flag1 = 1;
    end

    rhs_const = 1'b0;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    $readmemh("../../../../../test/poly_in_single.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
    $readmemh("../../../../../test/add_out_single_const.txt" , poly_out);

    op = `OP_ADD;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;
    rhs_const = 1'b1;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS SINGLE ADD CONST)");
    else begin
        $display("(FAIL SINGLE ADD CONST)");
        flag1 = 1;
    end

    rhs_const = 1'b0;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/poly_in_single.txt" , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
    $readmemh("../../../../../test/sub_out_single_const_switched.txt" , poly_out);

    op = `OP_SUB;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_TWIDDLE;
    #FP;
    cmd = 0;
    rhs_const = 1'b1;
    op_switch = 1'b1;

    while (!done) begin
        if (i_ready) begin
            i_data = psi[io_word >> LOGQB] >> ((io_word & QBMASK)*B);
            i_valid = 1'b1;
        end
        #FP;
    end

    cmd = `CMD_LOAD_POLY;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS SINGLE SUB CONST SWITCHED)");
    else begin
        $display("(FAIL SINGLE SUB CONST SWITCHED)");
        flag1 = 1;
    end

    rhs_const = 1'b0;
    op_switch = 1'b0;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    $readmemh("../../../../../test/decompose_in.txt" , poly_in);
    $readmemh("../../../../../test/decompose_out_low.txt" , poly_out);
    $readmemh("../../../../../test/decompose_meta.txt" , meta);

    op = `OP_DECOMPOSE;
    mode = `MODE_SINGLE;
    cmd = `CMD_LOAD_POLY;
    q = meta[0];
    mu_64 = meta[1];
    logn = meta[2];
    k = meta[3];
    d = meta[4];
    inv2 = meta[5];
    mu_32 = meta[6];
    bound = meta[7];
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DECOMPOSE OUT LOW)");
    else begin
        $display("(FAIL DECOMPOSE OUT LOW)");
        flag1 = 1;
    end

    $readmemh("../../../../../test/decompose_out_high.txt" , poly_out);
    cmd = `CMD_READ_TWIDDLE;
    #FP;
    cmd = 0;
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

    if (flag == 0)
        $display("(SUCCESS DECOMPOSE OUT HIGH)");
    else begin
        $display("(FAIL DECOMPOSE OUT HIGH)");
        flag1 = 1;
    end



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    if (flag1 == 0)
        $display("(ALL SUCCESS)");
    else
        $display("(FAIL)");
    $finish;

end

endmodule