`timescale 1ns / 1ps

module ntt_lite_sum_stage_tb;

    `include "../ntt_lite.vh"

    localparam LOGN = 4;
    localparam LOGQ = 32;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [2:0] cmd = `CMD_IDLE;
    reg [4:0] op = `OP_SUM;
    reg [3:0] logn = LOGN;
    reg [5:0] k = 0;
    reg [5:0] d = 0;
    reg [31:0] q = 32'h7fffffff;
    reg [31:0] inv2 = 0;
    reg [31:0] bound = 0;
    reg [63:0] mu = 0;
    reg [1:0] mode = `MODE_SINGLE;
    reg [31:0] i_data = 0;
    reg i_valid = 1'b0;
    reg o_read = 1'b0;
    reg op_switch = 1'b0;
    reg rhs_const = 1'b0;
    reg floor = 1'b0;
    reg [3:0] sum_stage = 0;
    wire i_ready;
    wire [31:0] o_data;
    wire o_valid;
    wire chknorm;
    wire rej_samp_ip;
    wire done;
    wire busy;
    wire i_done;
    wire [3:0] io_word;
    wire [3:0] io_limit;

    integer input_index;
    integer output_index;
    integer errors;
    reg [31:0] expected [0:7];

    always #5 clk = ~clk;

    ntt_lite #(
        .LOGN(LOGN),
        .LOGQ(LOGQ)
    ) dut (
        .clk(clk),
        .rst(rst),
        .cmd(cmd),
        .op(op),
        .otf(1'b0),
        .logn(logn),
        .k(k),
        .d(d),
        .q(q),
        .inv2(inv2),
        .bound(bound),
        .mu(mu),
        .mode(mode),
        .i_data(i_data),
        .i_ready(i_ready),
        .op_switch(op_switch),
        .rhs_const(rhs_const),
        .i_valid(i_valid),
        .o_dis(1'b0),
        .floor(floor),
        .sum_stage(sum_stage),
        .o_data(o_data),
        .o_read(o_read),
        .chknorm(chknorm),
        .rej_samp_ip(rej_samp_ip),
        .o_valid(o_valid),
        .i_done(i_done),
        .io_word(io_word),
        .io_limit(io_limit),
        .done(done),
        .busy(busy),
        .error()
    );

    initial begin
        expected[0] = 3;
        expected[1] = 7;
        expected[2] = 11;
        expected[3] = 15;
        expected[4] = 19;
        expected[5] = 23;
        expected[6] = 27;
        expected[7] = 31;
        input_index = 0;
        output_index = 0;
        errors = 0;

        repeat (2) @(posedge clk);
        rst = 1'b0;
        cmd = `CMD_LOAD_POLY;
        repeat (2) @(posedge clk);
        cmd = `CMD_IDLE;

        while (input_index < 16) begin
            @(negedge clk);
            if (i_ready) begin
                i_data = input_index + 1;
                input_index = input_index + 1;
                i_valid = 1'b1;
            end
            else begin
                i_valid = 1'b0;
            end
        end

        @(negedge clk);
        i_valid = 1'b0;

        begin : output_wait
        repeat (1000) begin
            @(negedge clk);
            if (o_valid && o_read && output_index < 8) begin
                if (io_word != output_index || o_data != expected[output_index]) begin
                    $display("Mismatch index=%0d word=%0d got=%0d expected=%0d", output_index, io_word, o_data, expected[output_index]);
                    errors = errors + 1;
                end
                output_index = output_index + 1;
                o_read = 1'b1;
            end
            else if (o_valid) begin
                o_read = 1'b1;
            end
            else begin
                o_read = 1'b0;
            end
            if (done && output_index == 8)
                disable output_wait;
        end
        end

        if (output_index != 8)
            errors = errors + 1;


        if (errors == 0)
            $display("SUCCESS NTT_LITE SUM STAGE 0");
        else
            $display("FAIL NTT_LITE SUM STAGE 0 errors=%0d outputs=%0d", errors, output_index);

        $finish;
    end

endmodule