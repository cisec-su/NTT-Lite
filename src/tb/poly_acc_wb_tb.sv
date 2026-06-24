module poly_acc_wb_tb
   #(
        parameter int unsigned BASE_ADDR       = 32'h40000000,
        parameter int unsigned LOGN            = 8           ,
        parameter int unsigned DATA_W          = 32          ,
        parameter bit          FF_BRAM_WADDR   = 1           ,
        parameter bit          FF_MODADD_IN    = 1           ,
        parameter bit          FF_MODADD_OUT   = 1           ,
        parameter bit          FF_INTMUL_MUL   = 1           ,
        parameter bit          FF_MODRED_MUL   = 1           ,
        parameter bit          FF_BARRETT_KR_SUM0 = 0           ,
        parameter bit          FF_BARRETT_KR_SUB0 = 1           ,
        parameter bit          FF_BARRETT_KR_MUL  = 1           ,
        parameter bit          FF_BARRETT_KR_SUM1 = 0           ,
        parameter bit          FF_BARRETT_KR_SUM2 = 1           ,
        parameter bit          FF_BARRETT_KR_SUB1 = 0           ,
        parameter bit          FF_HINT            = 1           ,
        parameter bit          FORWARD_EN         = 0           ,
        ///////////////////////////////////////
        parameter int unsigned MEM_SIZE        = 2048        ,
        parameter int unsigned TWIDDLE_BASE    = 0           ,
        parameter int unsigned POLYIN_BASE     = 1 << (LOGN + 2),
        parameter int unsigned POLYOUT_BASE    = 1 << (LOGN + 3),        
        parameter bit          TEST_DUAL       = 1              
    )();

`include "poly_acc.vh"
`define mem mem
    
localparam CLOCK_PERIOD = 10;

localparam int unsigned LOGQ = 32;
localparam int unsigned N    = 1 << LOGN;
localparam int unsigned LOGLOGQ = $clog2(LOGQ + 1);
localparam int unsigned LOGLOGN = $clog2(LOGN+1); 

// Clock and reset signals
reg clk;
reg rst_n;

// Wishbone signals
reg wb_cyc_i;
reg wb_stb_i;
reg wb_we_i;
reg [31:0] wb_adr_i;
reg [31:0] wb_dat_i;
reg [3:0] wb_sel_i;
wire wb_stall_o;
wire wb_ack_o;
wire [31:0] wb_dat_o;
wire wb_err_o;
reg wb_rst_i;

// DMA signals
wire        dma_cyc_i  ;
wire        dma_stb_i  ;
wire        dma_we_i   ;
wire [31:0] dma_adr_i  ;
wire [31:0] dma_dat_i  ;
wire [ 3:0] dma_sel_i  ;
reg         dma_stall_o;
reg         dma_ack_o  ;
reg  [31:0] dma_dat_o  ;
reg         dma_err_o  ;
wire        dma_rst_i  ;

reg [LOGQ-1:0] q;
reg [LOGQ*2-1:0] mu;
reg [LOGQ-1:0] inv2;
reg [LOGQ-1:0] bound;
reg [LOGQ*2-1:0] meta   [0:  7];
reg [LOGQ-1:0] psi      [0:N-1];
reg [LOGQ-1:0] poly_in  [0:N-1];
reg [LOGQ-1:0] poly_out [0:N-1];
reg  [LOGLOGN-1:0] logn;
reg  [LOGLOGQ-1:0] k;
reg  [LOGLOGQ-1:0] d;

// tb signals
reg [31:0] read_data;
reg [31:0] write_data;
reg [31:0] mem [0:MEM_SIZE-1]; // 4KB memory

reg [31:0] temp;
reg [31:0] temp1;
reg flag, flag1;
reg chknorm;

// --- added cumulative counters ---
integer tc_total;
integer tc_passed;
integer tc_failed;

task automatic record_tc_result(input bit pass_bit);
begin
    tc_total = tc_total + 1;
    if (pass_bit) begin
        tc_passed = tc_passed + 1;
    end else begin
        tc_failed = tc_failed + 1;
        flag1 = 1'b1;
    end
end
endtask


// Clock generation
initial begin
    clk = 0;
    forever #(CLOCK_PERIOD / 2) clk = ~clk; // 100MHz clock
end

// Reset generation
initial begin
    rst_n = 0;
    #20 rst_n = 1;
end

localparam MEM_SHIFT = (DATA_W == 32) ? 0 : 1;
localparam MEM32_DEPTH = (DATA_W == 32) ? MEM_SIZE : (MEM_SIZE * 2);

// 32-bit-word count -> DATA_W-word count
function automatic [31:0] data_len_words(input [31:0] words32);
begin
    data_len_words = (DATA_W == 32) ? words32 : (words32 >> 1);
end
endfunction

wire [31:0] mem32_view [MEM32_DEPTH-1:0];

for (genvar i = 0; i < MEM32_DEPTH; i = i + 1) begin
    assign mem32_view[i] = `mem[i >> MEM_SHIFT][(i & (MEM_SHIFT))*32 +: 32];
end


// Instantiate the keccak_acc_top module
poly_acc_wb #(
    .BASE_ADDR     (BASE_ADDR     ),
    .LOGN          (LOGN          ),
    .FF_BRAM_WADDR (FF_BRAM_WADDR ),
    .FF_MODADD_IN  (FF_MODADD_IN  ),
    .FF_MODADD_OUT (FF_MODADD_OUT ),
    .FF_INTMUL_MUL (FF_INTMUL_MUL ),
    .FF_MODRED_MUL (FF_MODRED_MUL ),
    .FF_BARRETT_KR_SUM0(FF_BARRETT_KR_SUM0),
    .FF_BARRETT_KR_SUB0(FF_BARRETT_KR_SUB0),
    .FF_BARRETT_KR_MUL (FF_BARRETT_KR_MUL ),
    .FF_BARRETT_KR_SUM1(FF_BARRETT_KR_SUM1),
    .FF_BARRETT_KR_SUM2(FF_BARRETT_KR_SUM2),
    .FF_BARRETT_KR_SUB1(FF_BARRETT_KR_SUB1),
    .FF_HINT           (FF_HINT           ),
    .FORWARD_EN        (FORWARD_EN        )
) uut (
    .wb_cyc_i(wb_cyc_i),
    .wb_stb_i(wb_stb_i),
    .wb_we_i(wb_we_i),
    .wb_adr_i(wb_adr_i),
    .wb_dat_i(wb_dat_i),
    .wb_sel_i(wb_sel_i),
    .wb_stall_o(wb_stall_o),
    .wb_ack_o(wb_ack_o),
    .wb_dat_o(wb_dat_o),
    .wb_err_o(wb_err_o),
    .wb_rst_i(!rst_n),
    .wb_clk_i(clk),
    .dma_cyc_i(dma_cyc_i),
    .dma_stb_i(dma_stb_i),
    .dma_we_i(dma_we_i),
    .dma_adr_i(dma_adr_i),
    .dma_dat_i(dma_dat_i),
    .dma_sel_i(dma_sel_i),
    .dma_stall_o(dma_stall_o),
    .dma_ack_o(dma_ack_o),
    .dma_dat_o(dma_dat_o),
    .dma_err_o(dma_err_o),
    .dma_rst_i(dma_rst_i)
);


always @(posedge clk) begin
    if (dma_stb_i && !dma_we_i) begin
        dma_dat_o <= mem[dma_adr_i >> 2];
    end
    else begin
        dma_dat_o <= 0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        for (int i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] <= 0;
        end
    end
    else if (dma_we_i) begin
        mem[dma_adr_i >> 2] <= dma_dat_i;
    end
end


task wb_write(input [31:0] address, input [31:0] data);
begin
    @(posedge clk);
    wb_cyc_i = 1;
    wb_stb_i = 1;
    wb_we_i = 1;
    wb_adr_i = address;
    wb_dat_i = data;
    @(posedge clk);
    wb_cyc_i = 0;
    wb_stb_i = 0;
    wb_we_i = 0;
end
endtask


task wb_read(input [31:0] address, output [31:0] read_data);
begin
    @(posedge clk);
    wb_cyc_i = 1;
    wb_stb_i = 1;
    wb_we_i = 0;
    wb_adr_i = address;
    @(posedge clk);
    read_data = wb_dat_o;
    wb_cyc_i = 0;
    wb_stb_i = 0;
end
endtask

// Testbench logic
initial begin
    // Initialize AXI4-Lite control-plane signals
    wb_cyc_i = 0;
    wb_stb_i = 0;
    wb_we_i = 0;
    wb_adr_i = 0;
    wb_dat_i = 0;
    wb_sel_i = 4'b1111;
    wb_rst_i = 0;

    flag1 = 0;
    tc_total = 0;
    tc_passed = 0;
    tc_failed = 0;

    // Wait for reset deassertion
    @(posedge rst_n);
    @(posedge clk);

    //-----------------------------------------------------------------------------------------------//
    // Adapted SINGLE NTT testcase

    $readmemh("../../../../../test/meta.txt"          , meta);
    $readmemh("../../../../../test/psi.txt"           , psi);
    $readmemh("../../../../../test/poly_in_single.txt", poly_in);
    $readmemh("../../../../../test/ntt_out_single.txt", poly_out);

    $display("Simulation started.");

    q = meta[0];
    mu    = meta[1];
    logn     = meta[2][7:0];

    // preload vectors into AXI RAM address space
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
    end

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR        , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW   , mu[31: 0]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH  , mu[63:32]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR    , bound);

    // load twiddle
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);


    // load poly + run NTT op
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_NTT        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn             << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // check output
    flag  = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("Output mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag)
        $display("(SUCCESS SINGLE NTT)");
    else begin
        $display("(FAIL SINGLE NTT)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    if (TEST_DUAL) begin

        $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
        $readmemh("../../../../../test/ntt_out_dual.txt" , poly_out);
        $readmemh("../../../../../test/psi_dual.txt"     , psi);
        $readmemh("../../../../../test/meta.txt"         , meta);

        q = (meta[0] << 16) + meta[0];
        mu  = meta[1];
        logn   = meta[2][7:0];

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW  , mu[31:0]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH , mu[63:32]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR   , bound);

        // load dual twiddle
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                    (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                    (`MODE_DUAL        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                    (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        // run dual NTT
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                    (`OP_NTT        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                    (`MODE_DUAL     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                    (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DUAL NTT mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag)
            $display("(SUCCESS DUAL NTT)");
        else begin
            $display("(FAIL DUAL NTT)");
            $stop;
        end
    end

    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE INTT

    $readmemh("../../../../../test/ntt_out_single.txt", poly_in);
    $readmemh("../../../../../test/psi_inv.txt"       , psi);
    $readmemh("../../../../../test/poly_in_single.txt", poly_out);

    // reuse same meta-derived config from prior case
    q = meta[0];
    mu    = meta[1];
    logn     = meta[2][7:0];
    inv2     = meta[5];

    // preload vectors
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW  , mu[31:0]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH , mu[63:32]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.INV2_ADDR    , inv2);

    // load inverse twiddle
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // load poly + run INTT
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_INTT       << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // check output
    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("INTT mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag)
        $display("(SUCCESS SINGLE INTT)");
    else begin
        $display("(FAIL SINGLE INTT)");
        $stop;
    end

    


    //-----------------------------------------------------------------------------------------------//
    // New test case: DUAL INTT
    if (TEST_DUAL) begin
        $readmemh("../../../../../test/ntt_out_dual.txt" , poly_in);
        $readmemh("../../../../../test/psi_inv_dual.txt" , psi);
        $readmemh("../../../../../test/poly_in_dual.txt" , poly_out);
        $readmemh("../../../../../test/meta.txt"         , meta);

        q      = (meta[0] << 16) + meta[0];
        mu  = meta[1];
        logn   = meta[2][7:0];
        inv2   = (meta[5] << 16) + meta[5];

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW  , mu[31:0]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH , mu[63:32]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.INV2_ADDR    , inv2);

        // op = 0, cmd = CMD_LOAD_TWIDDLE, mode = MODE_DUAL
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                    (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                    (`MODE_DUAL        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                    (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        // op = OP_INTT, mode = MODE_DUAL, cmd = CMD_LOAD_POLY
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                    (`OP_INTT       << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                    (`MODE_DUAL     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                    (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DUAL INTT mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag)
            $display("(SUCCESS DUAL INTT)");
        else begin
            $display("(FAIL DUAL INTT)");
            $stop;
        end
    end

    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE PWM

    $readmemh("../../../../../test/poly_in_single.txt"   , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
    $readmemh("../../../../../test/mul_out_single.txt"   , poly_out);

    // reuse same meta-derived config
    q = meta[0];
    mu    = meta[1];
    logn     = meta[2][7:0];
    inv2     = meta[5];
    bound    = 32'd0;

    // preload vectors
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW  , mu[31:0]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH , mu[63:32]);

    // load second polynomial (B path) via twiddle load channel
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // load first polynomial + run PWM
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_PWM        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // check output
    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("PWM mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag) begin
        $display("(SUCCESS SINGLE PWM)");
    end
    else begin
        $display("(FAIL SINGLE PWM)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE MAC
    if (FORWARD_EN) begin
        $readmemh("../../../../../test/poly_in_single.txt"   , poly_in);
        $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
        $readmemh("../../../../../test/mac_out_single.txt"   , poly_out);

        bound = 0;

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR       , bound);

        // load B operand
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        // load A operand
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_POLY    << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (`OP_ADD           << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB)|
                     (1'b1              << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);


        // run MAC with A operand
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (`OP_MAC        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("MAC mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag) begin
            $display("(SUCCESS SINGLE MAC)");
        end else begin
            $display("(FAIL SINGLE MAC)");
            $stop;
        end
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: DUAL PWM
    if (TEST_DUAL) begin
        $readmemh("../../../../../test/meta.txt"            , meta);
        $readmemh("../../../../../test/poly_in_dual.txt"    , poly_in);
        $readmemh("../../../../../test/poly_in_B_dual.txt"  , psi);
        $readmemh("../../../../../test/mul_out_dual.txt"    , poly_out);

        q      = (meta[0] << 16) + meta[0];
        mu     = meta[1];
        logn   = meta[2][7:0];

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW  , mu[31:0]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH , mu[63:32]);

        // op=0, mode=MODE_DUAL, cmd=CMD_LOAD_TWIDDLE
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_DUAL        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        // op=OP_PWM, mode=MODE_DUAL, cmd=CMD_LOAD_POLY
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (`OP_PWM        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_DUAL     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DUAL PWM mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag) $display("(SUCCESS DUAL PWM)");
        else begin
            $display("(FAIL DUAL PWM)");
            $stop;
        end
    end


    //-----------------------------------------------------------------------------------------------//

    if (TEST_DUAL) begin
        $readmemh("../../../../../test/poly_in_dual.txt"    , poly_in);
        $readmemh("../../../../../test/poly_in_B_dual.txt" , psi);
        $readmemh("../../../../../test/meta.txt"          , meta);
        logn   = meta[2][7:0];
        if (logn != LOGN) begin
            for (int w = 0; w < (1 << logn); w = w + 1) begin
                `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            end
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
            write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                        (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                        (`MODE_POLY        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                        (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);
            do begin
                wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
            end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);



            $readmemh("../../../../../test/poly_in_dual.txt"  , poly_in);
            $readmemh("../../../../../test/zeta_in.txt"       , psi);
            $readmemh("../../../../../test/mul_out_poly.txt"  , poly_out);

            q = (meta[0] << 16) + meta[0];
            logn   = meta[2][7:0];

            for (int w = 0; w < (1 << logn); w = w + 1) begin
                `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
                `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
                `mem[(POLYOUT_BASE >> 2) + w] = '0;
            end

            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR   , q);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW , mu[31:0]);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH, mu[63:32]);

            // op = 0, mode = MODE_POLY, cmd = CMD_LOAD_ZETA
            write_data = (`CMD_LOAD_ZETA << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                        (5'd0           << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                        (`MODE_POLY     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                        (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

            do begin
                wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
            end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

            // op = OP_PWM, mode = MODE_POLY, cmd = CMD_LOAD_POLY
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
            write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                        (`OP_PWM        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                        (`MODE_POLY     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                        (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

            do begin
                wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
            end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

            flag = 1'b1;
            for (int w = 0; w < (1 << logn); w = w + 1) begin
                temp  = `mem[(POLYOUT_BASE >> 2) + w];
                temp1 = poly_out[w];
                if (temp !== temp1 || $isunknown(temp)) begin
                    $display("POLY PWM mismatch at index %0d: %h != %h", w, temp, temp1);
                    flag = 1'b0;
                end
            end

            record_tc_result(flag);
            if (flag) begin
                $display("(SUCCESS POLY PWM)");
            end
            else begin
                $display("(FAIL POLY PWM)");
                $stop;
            end
        end
        else begin
            $display("Skipping POLY PWM test since logn matches LOGN");
        end
    end


    //-----------------------------------------------------------------------------------------------//
    if (TEST_DUAL) begin
        $readmemh("../../../../../test/poly_in_dual.txt"   , poly_in);
        $readmemh("../../../../../test/poly_in_B_dual.txt" , psi);
        $readmemh("../../../../../test/mac_out_poly.txt"   , poly_out);
        $readmemh("../../../../../test/meta.txt"           , meta);

        logn   = meta[2][7:0];
        if (logn != LOGN) begin

            bound = 0;

            for (int w = 0; w < (1 << logn); w = w + 1) begin
                `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
                `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
                `mem[(POLYOUT_BASE >> 2) + w] = '0;
            end

            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR       , bound);

            // load B operand
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
            write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                        (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                        (`MODE_POLY        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                        (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

            do begin
                wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
            end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

            // load A operand
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
            write_data = (`CMD_LOAD_POLY    << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                        (`OP_ADD           << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                        (`MODE_POLY        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                        (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB)|
                        (1'b1              << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

            do begin
                wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
            end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);


            // run MAC with A operand
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
            write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                        (`OP_MAC        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                        (`MODE_POLY     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                        (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
            wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

            do begin
                wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
            end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

            flag = 1'b1;
            for (int w = 0; w < (1 << logn); w = w + 1) begin
                temp  = `mem[(POLYOUT_BASE >> 2) + w];
                temp1 = poly_out[w];
                if (temp !== temp1 || $isunknown(temp)) begin
                    $display("MAC mismatch at index %0d: %h != %h", w, temp, temp1);
                    flag = 1'b0;
                end
            end

            record_tc_result(flag);
            if (flag) begin
                $display("(SUCCESS POLY MAC)");
            end else begin
                $display("(FAIL POLY MAC)");
                $stop;
            end
        end
        else begin
            $display("Skipping POLY MAC test since logn matches LOGN");
        end
    end
    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE SQADD

    $readmemh("../../../../../test/meta.txt"              , meta);
    $readmemh("../../../../../test/poly_in_single.txt"    , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt"  , psi);
    $readmemh("../../../../../test/sqadd_out_single.txt"  , poly_out);

    q    = meta[0];
    mu   = meta[1];
    logn = meta[2][7:0];
    

    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR   , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW , mu[31:0]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH, mu[63:32]);

    // cmd = CMD_LOAD_TWIDDLE, op = 0
    write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);

    // cmd = CMD_LOAD_POLY, op = OP_SQADD
    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_SQADD      << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("SQADD mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag) begin
        $display("(SUCCESS SINGLE SQADD)");
    end
    else begin
        $display("(FAIL SINGLE SQADD)");
        $stop;
    end

    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE ADD

    $readmemh("../../../../../test/poly_in_single.txt"   , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
    $readmemh("../../../../../test/add_out_single.txt"   , poly_out);

    // reuse same meta-derived config
    q = meta[0];
    mu    = meta[1];
    logn     = meta[2][7:0];
    inv2     = meta[5];
    bound    = 32'd0;

    // preload vectors
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);

    // load second polynomial (B path) via twiddle load channel
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // load first polynomial + run ADD
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_ADD        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // check output
    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("ADD mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag) begin
        $display("(SUCCESS SINGLE ADD)");
    end
    else begin
        $display("(FAIL SINGLE ADD)");
        $stop;
    end

    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE SUB

    $readmemh("../../../../../test/poly_in_single.txt"   , poly_in);
    $readmemh("../../../../../test/poly_in_B_single.txt" , psi);
    $readmemh("../../../../../test/sub_out_single.txt"   , poly_out);

    // reuse same meta-derived config
    q = meta[0];
    mu    = meta[1];
    logn     = meta[2][7:0];

    // preload vectors
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);

    // load second polynomial (B path) via twiddle load channel
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , TWIDDLE_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // load first polynomial + run SUB
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_SUB        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // check output
    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("SUB mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag) begin
        $display("(SUCCESS SINGLE SUB)");
    end
    else begin
        $display("(FAIL SINGLE SUB)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: DUAL ADD / DUAL SUB
    if (TEST_DUAL) begin
        // ---------------- DUAL ADD ----------------
        $readmemh("../../../../../test/meta.txt"            , meta);
        $readmemh("../../../../../test/poly_in_dual.txt"    , poly_in);
        $readmemh("../../../../../test/poly_in_B_dual.txt"  , psi);
        $readmemh("../../../../../test/add_out_dual.txt"    , poly_out);

        q    = (meta[0] << 16) + meta[0];
        mu   = meta[1];
        logn = meta[2][7:0];

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR      , q);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW , mu[31:0]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH, mu[63:32]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR    , TWIDDLE_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR   , POLYOUT_BASE);

        write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_DUAL        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (`OP_ADD        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_DUAL     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DUAL ADD mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag) $display("(SUCCESS DUAL ADD)");
        else begin
            $display("(FAIL DUAL ADD)");
            $stop;
        end

        // ---------------- DUAL SUB ----------------
        $readmemh("../../../../../test/meta.txt"            , meta);
        $readmemh("../../../../../test/poly_in_dual.txt"    , poly_in);
        $readmemh("../../../../../test/poly_in_B_dual.txt"  , psi);
        $readmemh("../../../../../test/sub_out_dual.txt"    , poly_out);

        q    = (meta[0] << 16) + meta[0];
        mu   = meta[1];
        logn = meta[2][7:0];

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR      , q);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW , mu[31:0]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH, mu[63:32]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR    , TWIDDLE_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR   , POLYOUT_BASE);

        write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_DUAL        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (`OP_SUB        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_DUAL     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DUAL SUB mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag) $display("(SUCCESS DUAL SUB)");
        else begin
            $display("(FAIL DUAL SUB)");
            $stop;
        end
    end

    
    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE COMPRESS

    $readmemh("../../../../../test/poly_in_single.txt"  , poly_in);
    $readmemh("../../../../../test/comp_out_single.txt" , poly_out);

    // reuse same meta-derived config
    logn     = meta[2][7:0];
    d        = meta[4][7:0];
    q        = meta[0];
    mu    = meta[1];
    bound    = 1 << d;

    // preload vectors
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW  , mu[31:0]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH , mu[63:32]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR   , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR     , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR    , POLYOUT_BASE);

    // run COMPRESS
    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB)  |
                 (`OP_COMPRESS   << uut.poly_acc_csrs_inst.CTRL_OP_LSB )  |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                 (`ROUND_HALFUP  << uut.poly_acc_csrs_inst.CTRL_ROUND_LSB)|
                 (1'b1           << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // check output
    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("COMPRESS mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag)
        $display("(SUCCESS SINGLE COMPRESS)");
    else begin
        $display("(FAIL SINGLE COMPRESS)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: DUAL COMPRESS
    if (TEST_DUAL) begin
        $readmemh("../../../../../test/meta.txt"          , meta);
        $readmemh("../../../../../test/poly_in_dual.txt"  , poly_in);
        $readmemh("../../../../../test/comp_out_dual.txt" , poly_out);

        q     = (meta[0] << 16) + meta[0];
        mu    = meta[1];
        logn  = meta[2][7:0];
        d     = meta[4][7:0];
        bound = ((1 << d) << 16) + (1 << d);

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR      , q);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW , mu[31:0]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH, mu[63:32]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR  , bound);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR    , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR   , POLYOUT_BASE);

        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (`OP_COMPRESS   << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                     (`MODE_DUAL     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                     (`ROUND_HALFUP  << uut.poly_acc_csrs_inst.CTRL_ROUND_LSB)|
                     (1'b1           << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DUAL COMPRESS mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag)
            $display("(SUCCESS DUAL COMPRESS)");
        else begin
            $display("(FAIL DUAL COMPRESS)");
            $stop;
        end
    end

    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE DECOMPRESS

    $readmemh("../../../../../test/comp_out_single.txt"   , poly_in);
    $readmemh("../../../../../test/decomp_out_single.txt" , poly_out);

    // reuse same meta-derived config
    logn     = meta[2][7:0];
    q        = 1 << (meta[4][7:0]);
    mu       = 1 << (64 - (meta[4][7:0]));
    inv2     = 32'hffffffff;//meta[5];
    bound    = meta[0]; // q

    // preload vectors
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW  , mu[31:0]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH , mu[63:32]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR   , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR     , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR    , POLYOUT_BASE);

    // run COMPRESS
    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB)  |
                 (`OP_COMPRESS   << uut.poly_acc_csrs_inst.CTRL_OP_LSB )  |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                 (`ROUND_HALFUP  << uut.poly_acc_csrs_inst.CTRL_ROUND_LSB)|
                 (1'b1           << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);//|
                //  (d              << uut.poly_acc_csrs_inst.CTRL_D_LSB   );
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // check output
    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("DECOMPRESS mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag)
        $display("(SUCCESS SINGLE (DE)COMPRESS)");
    else begin
        $display("(FAIL SINGLE (DE)COMPRESS)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: DUAL DECOMPRESS
    if (TEST_DUAL) begin
        $readmemh("../../../../../test/meta.txt"            , meta);
        $readmemh("../../../../../test/comp_out_dual.txt"   , poly_in);
        $readmemh("../../../../../test/decomp_out_dual.txt" , poly_out);

        q     = ((1 << (meta[4][7:0])) << 16) | (1 << (meta[4][7:0]));
        mu    = ((1 << (32 - (meta[4][7:0]))) << 32) | (1 << (32 - (meta[4][7:0])));
        logn  = meta[2][7:0];
        inv2  = 32'hffffffff;
        bound = (meta[0] << 16) + meta[0];

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW  , mu[31:0]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH , mu[63:32]);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.INV2_ADDR    , inv2);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR   , bound);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR     , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR    , POLYOUT_BASE);

        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB ) |
                     (`OP_COMPRESS   << uut.poly_acc_csrs_inst.CTRL_OP_LSB  ) |
                     (`MODE_DUAL     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                     (`ROUND_HALFUP  << uut.poly_acc_csrs_inst.CTRL_ROUND_LSB)|
                     (1'b1           << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DUAL DECOMPRESS mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag)
            $display("(SUCCESS DUAL DECOMPRESS)");
        else begin
            $display("(FAIL DUAL DECOMPRESS)");
            $stop;
        end
    end

    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE DECOMPOSE (LOW + HIGH)

    $readmemh("../../../../../test/decompose_in.txt"      , poly_in);
    $readmemh("../../../../../test/decompose_out_low.txt" , poly_out);
    $readmemh("../../../../../test/decompose_meta.txt"    , meta);

    // config from decompose meta
    q        = meta[0];
    mu       = meta[1];
    logn     = meta[2][7:0];
    inv2     = meta[5];
    bound    = 1'b1; // multiplied with 1 

    // preload input, clear output
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR      , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW , mu[31:0]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH, mu[63:32]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.INV2_ADDR   , inv2);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR  , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR    , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR   , POLYOUT_BASE);

    // run DECOMPOSE -> low output
    write_data = (`CMD_LOAD_POLY  << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_DECOMPOSE   << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE    << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn            << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB)|
                 (`ROUND_HALFDOWN << uut.poly_acc_csrs_inst.CTRL_ROUND_LSB)|
                 (1'b1            << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("DECOMPOSE LOW mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag)
        $display("(SUCCESS DECOMPOSE OUT LOW)");
    else begin
        $display("(FAIL DECOMPOSE OUT LOW)");
        $stop;
    end

    // read high output from twiddle side
    $readmemh("../../../../../test/decompose_out_high.txt", poly_out);

    // clear output buffer before dump
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
    write_data = (`CMD_READ_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (5'd0              << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB)|
                 (`ROUND_HALFDOWN   << uut.poly_acc_csrs_inst.CTRL_ROUND_LSB)  |
                 (d                 << uut.poly_acc_csrs_inst.CTRL_D_LSB   );
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("DECOMPOSE HIGH mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag)
        $display("(SUCCESS DECOMPOSE OUT HIGH)");
    else begin
        $display("(FAIL DECOMPOSE OUT HIGH)");
        $stop;
    end

    //-----------------------------------------------------------------------------------------------//
    // New test case: USE_HINT (LOW + HIGH)


    $readmemh("../../../../../test/decompose_in.txt"  , poly_in);
    $readmemh("../../../../../test/usehint_in.txt"    , psi);
    $readmemh("../../../../../test/usehint_out.txt"   , poly_out);
    $readmemh("../../../../../test/decompose_meta.txt", meta);

    // config from decompose meta
    q        = meta[0];
    mu       = meta[1];
    logn     = meta[2][7:0];
    inv2     = meta[5];
    bound    = 1'b1; // multiplied with 1 

    // preload input, clear output
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR    , TWIDDLE_BASE);

    // load hint into twiddle memory using LOAD_TWIDDLE command
    write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`MODE_SINGLE    << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn            << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    // program config
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR      , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_LOW , mu[31:0]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.MU_ADDR_HIGH, mu[63:32]);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.INV2_ADDR   , inv2);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR  , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR    , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR   , POLYOUT_BASE);

    // run DECOMPOSE -> low output
    write_data = (`CMD_LOAD_POLY  << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_USEHINT     << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE    << uut.poly_acc_csrs_inst.CTRL_MODE_LSB)|
                 (logn            << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB)|
                 (`ROUND_HALFDOWN << uut.poly_acc_csrs_inst.CTRL_ROUND_LSB)|
                 (1'b1            << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("USE HINT at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag)
        $display("(SUCCESS USE HINT)");
    else begin
        $display("(FAIL USE HINT)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE CHKINFNORM CORRECT CASE

    $readmemh("../../../../../test/chknorm_in_succ.txt"       , poly_in);
    $readmemh("../../../../../test/chknorm_makehint_meta.txt" , meta);

    q        = meta[0];
    logn     = meta[2][7:0];
    bound    = meta[6];

    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR   , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR     , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR    , POLYOUT_BASE);

    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_CHKINFNORM << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                 (1'b1            << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    chknorm = (read_data >> uut.poly_acc_csrs_inst.STATUS_CHKNORM_BIT) & 32'd1;
    flag    = (chknorm == 1'b0);

    record_tc_result(flag);
    if (flag) begin
        $display("(SUCCESS CHKINFNORM CORRECT CASE)");
    end else begin
        $display("(FAIL CHKINFNORM CORRECT CASE)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE CHKINFNORM INCORRECT CASE

    $readmemh("../../../../../test/chknorm_in_fail.txt"       , poly_in);
    $readmemh("../../../../../test/chknorm_makehint_meta.txt" , meta);

    q     = meta[0];
    bound = meta[6];

    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR   , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR     , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR    , POLYOUT_BASE);

    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_CHKINFNORM << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                 (1'b1            << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    chknorm = (read_data >> uut.poly_acc_csrs_inst.STATUS_CHKNORM_BIT) & 32'd1;
    flag    = (chknorm);

    record_tc_result(flag);
    if (flag) begin
        $display("(SUCCESS CHKINFNORM INCORRECT CASE)");
    end else begin
        $display("(FAIL CHKINFNORM INCORRECT CASE)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE CHKL1NORM CORRECT CASE
    $readmemh("../../../../../test/chkl1norm_in.txt"   , poly_in);
    $readmemh("../../../../../test/chkl1norm_meta.txt" , meta);

    bound    = meta[6] + 1; // to check x > B, we provide B + 1

    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR   , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR     , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR    , POLYOUT_BASE);

    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_CHKL1NORM << uut.poly_acc_csrs_inst.CTRL_OP_LSB  ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                 (1'b1            << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    chknorm = (read_data >> uut.poly_acc_csrs_inst.STATUS_CHKNORM_BIT) & 32'd1;
    flag    = (chknorm == 1'b0);

    record_tc_result(flag);
    if (flag) begin
        $display("(SUCCESS CHKL1NORM CORRECT CASE)");
    end else begin
        $display("(FAIL CHKL1NORM CORRECT CASE)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: SINGLE CHKL1NORM INCORRECT CASE

    bound    = bound  - 1;

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR   , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR     , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR    , POLYOUT_BASE);

    write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_CHKL1NORM << uut.poly_acc_csrs_inst.CTRL_OP_LSB  ) |
                 (`MODE_SINGLE   << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                 (1'b1            << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    chknorm = (read_data >> uut.poly_acc_csrs_inst.STATUS_CHKNORM_BIT) & 32'd1;
    flag    = (chknorm);

    record_tc_result(flag);
    if (flag) begin
        $display("(SUCCESS CHKL1NORM INCORRECT CASE)");
    end else begin
        $display("(FAIL CHKL1NORM INCORRECT CASE)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//
    // New test case: MAKEHINT
    $readmemh("../../../../../test/makehint_in_low.txt"  , poly_in);
    $readmemh("../../../../../test/makehint_in_high.txt" , psi);
    $readmemh("../../../../../test/makehint_out.txt"     , poly_out);
    $readmemh("../../../../../test/chknorm_makehint_meta.txt" , meta);

    inv2  = meta[5];
    bound = meta[6];

    // reuse currently programmed q/mu/logn context; set DMA pointers
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
        `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
        `mem[(POLYOUT_BASE >> 2) + w] = '0;
    end

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.BOUND_ADDR , bound);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.INV2_ADDR  , inv2);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR   , TWIDDLE_BASE);


    // cmd = CMD_LOAD_TWIDDLE, op = OP_MAKEHINT, mode = MODE_SINGLE
    write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);

    // cmd = CMD_LOAD_TWIDDLE, op = OP_MAKEHINT, mode = MODE_SINGLE
    write_data = (`CMD_LOAD_POLY    << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                 (`OP_MAKEHINT      << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                 (`MODE_SINGLE      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                 (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB) |
                 (1'b1              << uut.poly_acc_csrs_inst.CTRL_RHS_CONST_BIT);
    wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

    do begin
        wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
    end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

    flag = 1'b1;
    for (int w = 0; w < (1 << logn); w = w + 1) begin
        temp  = `mem[(POLYOUT_BASE >> 2) + w];
        temp1 = poly_out[w];
        if (temp !== temp1 || $isunknown(temp)) begin
            $display("MAKEHINT mismatch at index %0d: %h != %h", w, temp, temp1);
            flag = 1'b0;
        end
    end

    record_tc_result(flag);
    if (flag)
        $display("(SUCCESS MAKEHINT)");
    else begin
        $display("(FAIL MAKEHINT)");
        $stop;
    end


    //-----------------------------------------------------------------------------------------------//

    if (TEST_DUAL) begin
        $readmemh("../../../../../test/poly_in_dual.txt" , poly_in);
        $readmemh("../../../../../test/sum_out_dual.txt" , poly_out);
        $readmemh("../../../../../test/meta.txt"         , meta);

        q = (meta[0] << 16) + meta[0];
        logn   = meta[2][7:0];

        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.Q_ADDR       , q);


        // run dual NTT
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);
        write_data = (`CMD_LOAD_POLY << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                    (`OP_SUM        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                    (`MODE_DUAL     << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                    (logn           << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < 1; w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DUAL SUM mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag) $display("(SUCCESS DUAL SUM)");
        else begin
            $display("(FAIL DUAL SUM)");
            $stop;
        end
    end
    
    //-----------------------------------------------------------------------------------------------//

    if (TEST_DUAL) begin
        $readmemh("../../../../../test/encode_out_poly.txt", psi);
        $readmemh("../../../../../test/comp_out_dual.txt", poly_out);
        $readmemh("../../../../../test/meta.txt"         , meta);
        d = meta[4];

        // reuse currently programmed q/mu/logn context; set DMA pointers
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            `mem[(TWIDDLE_BASE >> 2) + w] = psi[w];
            `mem[(POLYIN_BASE  >> 2) + w] = poly_in[w];
            `mem[(POLYOUT_BASE >> 2) + w] = '0;
        end

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR   , TWIDDLE_BASE);


        // cmd = CMD_LOAD_TWIDDLE, op = OP_MAKEHINT, mode = MODE_SINGLE
        write_data = (`CMD_LOAD_TWIDDLE << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                     (`MODE_DUAL      << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                     (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DIN_ADDR , POLYIN_BASE);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.DOUT_ADDR, POLYOUT_BASE);

        // cmd = CMD_LOAD_TWIDDLE, op = OP_MAKEHINT, mode = MODE_SINGLE
        write_data = (`CMD_LOAD_POLY    << uut.poly_acc_csrs_inst.CTRL_CMD_LSB) |
                    (`OP_DECODE        << uut.poly_acc_csrs_inst.CTRL_OP_LSB ) |
                    (`MODE_DUAL        << uut.poly_acc_csrs_inst.CTRL_MODE_LSB) |
                    (d                 << uut.poly_acc_csrs_inst.CTRL_D_LSB   ) |
                    (logn              << uut.poly_acc_csrs_inst.CTRL_LOGN_LSB);
        wb_write(BASE_ADDR + uut.poly_acc_csrs_inst.CTRL_ADDR, write_data);

        do begin
            wb_read(BASE_ADDR + uut.poly_acc_csrs_inst.STATUS_ADDR, read_data);
        end while ((read_data & (32'd1 << uut.poly_acc_csrs_inst.STATUS_DONE_BIT)) == 0);

        flag = 1'b1;
        for (int w = 0; w < (1 << logn); w = w + 1) begin
            temp  = `mem[(POLYOUT_BASE >> 2) + w];
            temp1 = poly_out[w];
            if (temp !== temp1 || $isunknown(temp)) begin
                $display("DECODE DUAL mismatch at index %0d: %h != %h", w, temp, temp1);
                flag = 1'b0;
            end
        end

        record_tc_result(flag);
        if (flag)
            $display("(SUCCESS DECODE DUAL)");
        else begin
            $display("(FAIL DECODE DUAL)");
            $stop;
        end        
    end

    // Finish simulation
    $display("Simulation finished");
    $display("==============================================");
    $display("CUMULATIVE RESULT: total=%0d passed=%0d failed=%0d overall=%s",
             tc_total, tc_passed, tc_failed, (tc_failed == 0) ? "PASS" : "FAIL");
    $display("==============================================");
    $finish;
end

endmodule


