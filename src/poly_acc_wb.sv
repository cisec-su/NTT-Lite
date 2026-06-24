module poly_acc_wb
    #(
        parameter  [31:0]       BASE_ADDR       = 32'h40001000,
        parameter  int unsigned LOGN            = 8           ,
        parameter  bit          FF_BRAM_WADDR   = 1           ,
        parameter  bit          FF_MODADD_IN    = 1           ,
        parameter  bit          FF_MODADD_OUT   = 1           ,
        parameter  bit          FF_INTMUL_MUL   = 1           ,
        parameter  bit          FF_MODRED_MUL   = 1           ,
        parameter  bit          FF_BARRETT_KR_SUM0 = 0           ,
        parameter  bit          FF_BARRETT_KR_SUB0 = 0           ,
        parameter  bit          FF_BARRETT_KR_MUL  = 1           ,
        parameter  bit          FF_BARRETT_KR_SUM1 = 0           ,
        parameter  bit          FF_BARRETT_KR_SUM2 = 1           ,
        parameter  bit          FF_BARRETT_KR_SUB1 = 0           ,
        parameter  bit          FF_HINT            = 0           ,
        parameter  bit          FORWARD_EN         = 1
    )
    (
        input           wb_cyc_i,
        input           wb_stb_i,
        input           wb_we_i,
        input  [31:0]   wb_adr_i,
        input  [31:0]   wb_dat_i,
        input  [ 3:0]   wb_sel_i,
        output          wb_stall_o,
        output          wb_ack_o,
        output [31:0]   wb_dat_o,
        output          wb_err_o,
        input           wb_rst_i,
        input           wb_clk_i,

        output          dma_cyc_i,
        output          dma_stb_i,
        output          dma_we_i,
        output [31:0]   dma_adr_i,
        output [31:0]   dma_dat_i,
        output [ 3:0]   dma_sel_i,
        input           dma_stall_o,
        input           dma_ack_o,
        input  [31:0]   dma_dat_o,
        input           dma_err_o,
        output          dma_rst_i
    );

localparam int unsigned LOGQ    = 32;
localparam int unsigned LOGLOGQ = $clog2(LOGQ + 1);
localparam int unsigned LOGLOGN = $clog2(LOGN+1); 

wire clk, rst;

wire [31:0] csrs_raddr;
wire [31:0] csrs_waddr;
wire [31:0] csrs_wdata;
wire [31:0] csrs_rdata;
wire csrs_we;
wire csrs_re;

wire [LOGQ-1:0] i_data;
wire i_ready;
wire i_valid;
wire [LOGQ-1:0] o_data;
wire o_read;
wire o_valid;
wire i_done;
wire [LOGN-1:0] io_word;
wire [LOGN  :0] io_len;


// csrs & NTT
wire [2:0] csrs_cmd;
wire [LOGLOGN-1:0] csrs_logn;
wire [LOGLOGQ-1:0] csrs_k;
wire [LOGLOGQ-1:0] csrs_d;
wire [1:0] csrs_mode;
wire [4:0] csrs_op;
wire [LOGQ-1:0] csrs_q;
wire [LOGQ*2-1:0] csrs_mu;
wire [LOGQ-1:0] csrs_inv2;
wire [LOGQ-1:0] csrs_bound;
wire csrs_done;
wire csrs_busy;
wire csrs_o_dis;
wire [1:0] csrs_round;
wire csrs_rhs_const;
wire csrs_op_switch;
wire csrs_chknorm;
wire csrs_rej_samp_ip;
wire csrs_bigend;
wire csrs_rst;

// csrs & FSM
wire [31:0] csrs_din_addr;
wire [31:0] csrs_dout_addr;


wire [31:0] dma_r_addr   ;
wire [31:0] dma_w_addr   ;
wire [ 7:0] dma_rw_offset;
wire [ 8:0] dma_rw_len   ;
wire        dma_r_ready  ;
wire        dma_r_valid  ;
wire        dma_w_valid  ;
wire        dma_w_ready  ;
wire [31:0] dma_r_data   ;
wire [31:0] dma_w_data   ;


assign dma_r_addr    = csrs_din_addr;
assign dma_w_addr    = csrs_dout_addr;
assign dma_rw_offset = io_word;
assign dma_rw_len    = io_len;
assign dma_r_ready   = i_ready;
assign i_valid       = dma_r_valid;
assign i_data        = dma_r_data;
assign dma_w_valid   = o_valid;
assign dma_w_data    = o_data;
assign o_read        = dma_w_ready;





poly_acc #(
    .LOGN(LOGN),
    .LOGQ(LOGQ),
    .FF_BRAM_WADDR(FF_BRAM_WADDR),
    .FF_MODADD_IN (FF_MODADD_IN ),
    .FF_MODADD_OUT(FF_MODADD_OUT),
    .FF_INTMUL_MUL(FF_INTMUL_MUL),
    .FF_MODRED_MUL(FF_MODRED_MUL),
    .FF_BARRETT_KR_SUM0(FF_BARRETT_KR_SUM0),
    .FF_BARRETT_KR_SUB0(FF_BARRETT_KR_SUB0),
    .FF_BARRETT_KR_MUL (FF_BARRETT_KR_MUL ),
    .FF_BARRETT_KR_SUM1(FF_BARRETT_KR_SUM1),
    .FF_BARRETT_KR_SUM2(FF_BARRETT_KR_SUM2),
    .FF_BARRETT_KR_SUB1(FF_BARRETT_KR_SUB1),
    .FF_HINT           (FF_HINT           ),
    .FORWARD_EN        (FORWARD_EN        )
) poly_acc_inst (
    .clk        (clk        ),
    .rst        (rst|csrs_rst),
    // ntt <-> fsm
    .i_data     (i_data     ),
    .i_ready    (i_ready    ),
    .i_valid    (i_valid    ),
    .o_data     (o_data     ),
    .o_valid    (o_valid    ),
    .i_done     (i_done     ),
    .o_read     (o_read     ),
    .io_word    (io_word    ),
    .io_len     (io_len     ),
    // ntt <-> csrs
    .cmd        (csrs_cmd   ),
    .logn       (csrs_logn  ),
    .k          (csrs_k     ),
    .d          (csrs_d     ),
    .o_dis      (csrs_o_dis ),
    .round      (csrs_round ),
    .rhs_const  (csrs_rhs_const),
    .op_switch  (csrs_op_switch),
    .bigend     (csrs_bigend),
    .q          (csrs_q     ),
    .mu         (csrs_mu    ),
    .inv2       (csrs_inv2  ),
    .bound      (csrs_bound ),
    .op         (csrs_op    ),
    .mode       (csrs_mode  ),
    .done       (csrs_done  ),
    .busy       (csrs_busy  ),
    .chknorm    (csrs_chknorm),
    .rej_samp_ip(csrs_rej_samp_ip),
    
    .error()
);


poly_acc_csrs #(
    .BASE_ADDR(BASE_ADDR)
) poly_acc_csrs_inst (
    .clk        (clk        ),
    .rst        (rst        ),
    // wb <-> csrs
    .raddr      (csrs_raddr ),
    .waddr      (csrs_waddr ),
    .wdata      (csrs_wdata ),
    .we         (csrs_we    ),
    .re         (csrs_re    ),
    .rdata      (csrs_rdata ),
    // ntt <-> csrs
    .cmd        (csrs_cmd   ),
    .logn       (csrs_logn  ),
    .k          (csrs_k     ),
    .d          (csrs_d     ),
    .o_dis      (csrs_o_dis ),
    .rhs_const  (csrs_rhs_const),
    .op_switch  (csrs_op_switch),
    .bigend     (csrs_bigend),
    .round      (csrs_round ),
    .mode       (csrs_mode  ),
    .op         (csrs_op    ),
    .mu         (csrs_mu    ),
    .inv2       (csrs_inv2  ),
    .q          (csrs_q     ),
    .otf        (csrs_otf   ),
    .done       (csrs_done  ),
    .chknorm    (csrs_chknorm),
    .rej_samp_ip(csrs_rej_samp_ip),
    .busy       (csrs_busy  ),
    .csrs_rst   (csrs_rst   ),
    // fsm <-> csrs
    .din_addr   (csrs_din_addr ),
    .dout_addr  (csrs_dout_addr),
    .bound      (csrs_bound )
);



wb_dma wb_dma_inst (
    .clk          (clk          ),
    .rst          (rst          ),
    .r_addr       (dma_r_addr   ),
    .w_addr       (dma_w_addr   ),
    .rw_offset    (dma_rw_offset),
    .rw_len       (dma_rw_len   ),
    .r_ready      (dma_r_ready  ),
    .r_valid      (dma_r_valid  ),
    .w_valid      (dma_w_valid  ),
    .w_ready      (dma_w_ready  ),
    .r_data       (dma_r_data   ),
    .w_data       (dma_w_data   ),
    // AXI4 master interface
    .dma_cyc_i    (dma_cyc_i    ),
    .dma_stb_i    (dma_stb_i    ),
    .dma_we_i     (dma_we_i     ),
    .dma_adr_i    (dma_adr_i    ),
    .dma_dat_i    (dma_dat_i    ),
    .dma_sel_i    (dma_sel_i    ),
    .dma_stall_o  (dma_stall_o  ),
    .dma_ack_o    (dma_ack_o    ),
    .dma_dat_o    (dma_dat_o    ),
    .dma_err_o    (dma_err_o    ),
    .dma_rst_i    (dma_rst_i    )
);


wb_mmio wb_mmio_inst (
    .clk          (clk          ),
    .rst          (rst          ),
    // csrs-side interface
    .raddr        (csrs_raddr   ),
    .waddr        (csrs_waddr   ),
    .wdata        (csrs_wdata   ),
    .rdata        (csrs_rdata   ),
    .we           (csrs_we      ),
    .re           (csrs_re      ),
    // AXI4-Lite slave interface
    .wb_clk_i   (wb_clk_i   ),
    .wb_cyc_i   (wb_cyc_i   ),
    .wb_stb_i   (wb_stb_i   ),
    .wb_we_i    (wb_we_i    ),
    .wb_adr_i   (wb_adr_i   ),
    .wb_dat_i   (wb_dat_i   ),
    .wb_sel_i   (wb_sel_i   ),
    .wb_stall_o (wb_stall_o ),
    .wb_ack_o   (wb_ack_o   ),
    .wb_dat_o   (wb_dat_o   ),
    .wb_err_o   (wb_err_o   ),
    .wb_rst_i   (wb_rst_i   )
);


endmodule

