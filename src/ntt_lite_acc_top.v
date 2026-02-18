module ntt_lite_acc_top
    #(
        parameter BASE_ADDR  = 32'h40001000,
        parameter LOGN       = 8           ,
        parameter LOGQ       = 32          
    )
    (
        input           wb_cyc_i,
        input           wb_stb_i,
        input           wb_we_i,
        input [31:0]    wb_adr_i,
        input [31:0]    wb_dat_i,
        input [ 3:0]    wb_sel_i,
        output          wb_stall_o,
        output          wb_ack_o,
        output[31:0]    wb_dat_o,
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

localparam LOGLOGQ = $clog2(LOGQ + 1);
localparam LOGLOGN = $clog2(LOGN+1); 


wire clk, rst;
//WB & CTRL
wire [31:0] ctrl_addr;
wire [31:0] ctrl_wdata;
wire [31:0] ctrl_rdata;
wire ctrl_we;
wire ctrl_re;

//DMA & FSM
wire [31:0] mem_addr;
wire [31:0] mem_o_data;
wire mem_o_ready;
wire [31:0] mem_i_data;
wire mem_i_ready;
wire mem_i_valid;
wire mem_we;
wire mem_re;

// FSM & NTT
wire [LOGQ-1:0] fsm_i_data;
wire fsm_i_ready;
wire fsm_i_valid;
wire [LOGQ-1:0] fsm_o_data;
wire fsm_o_read;
wire fsm_o_valid;
wire fsm_i_done;
wire [LOGN-1:0] fsm_io_word;
wire [LOGN-1:0] fsm_io_limit;


// CTRL & NTT
wire [2:0] ctrl_cmd;
wire [LOGLOGN-1:0] ctrl_logn;
wire [LOGLOGQ-1:0] ctrl_k;
wire [LOGLOGQ-1:0] ctrl_d;
wire [1:0] ctrl_mode;
wire [4:0] ctrl_op;
wire [LOGQ-1:0] ctrl_q;
wire [LOGQ*2-1:0] ctrl_mu;
wire [LOGQ-1:0] ctrl_inv2;
wire [LOGQ-1:0] ctrl_bound;
wire ctrl_otf;
wire ctrl_done;
wire ctrl_busy;
wire ctrl_o_dis;
wire ctrl_floor;
wire ctrl_rhs_const;
wire ctrl_op_switch;
wire ctrl_chknorm;
wire ctrl_rej_samp_ip;

// CTRL & FSM
wire [31:0] ctrl_din_addr;
wire [31:0] ctrl_dout_addr;



ntt_lite #(
    .LOGN(LOGN),
    .LOGQ(LOGQ)
) ntt_lite (
    .clk        (clk        ),
    .rst        (rst        ),
    // ntt <-> fsm
    .i_data     (fsm_i_data ),
    .i_ready    (fsm_i_ready),
    .i_valid    (fsm_i_valid),
    .o_data     (fsm_o_data ),
    .o_valid    (fsm_o_valid),
    .i_done     (fsm_i_done ),
    .o_read     (fsm_o_read ),
    .io_word    (fsm_io_word),
    .io_limit   (fsm_io_limit),
    // ntt <-> ctrl
    .cmd        (ctrl_cmd   ),
    .logn       (ctrl_logn  ),
    .k          (ctrl_k     ),
    .d          (ctrl_d     ),
    .o_dis      (ctrl_o_dis ),
    .floor      (ctrl_floor ),
    .rhs_const  (ctrl_rhs_const),
    .op_switch  (ctrl_op_switch),
    .q          (ctrl_q     ),
    .mu         (ctrl_mu    ),
    .inv2       (ctrl_inv2  ),
    .bound      (ctrl_bound ),
    .op         (ctrl_op    ),
    .mode       (ctrl_mode  ),
    .otf        (ctrl_otf   ),
    .done       (ctrl_done  ),
    .busy       (ctrl_busy  ),
    .chknorm    (ctrl_chknorm),
    .rej_samp_ip(ctrl_rej_samp_ip),
    
    .error()
);


ntt_lite_ctrl #(
    .BASE_ADDR(BASE_ADDR)
) ntt_lite_ctrl(
    .clk        (clk        ),
    .rst        (rst        ),
    // wb <-> ctrl
    .addr       (ctrl_addr  ),
    .wdata      (ctrl_wdata ),
    .we         (ctrl_we    ),
    .re         (ctrl_re    ),
    .rdata      (ctrl_rdata ),
    // ntt <-> ctrl
    .cmd        (ctrl_cmd   ),
    .logn       (ctrl_logn  ),
    .k          (ctrl_k     ),
    .d          (ctrl_d     ),
    .o_dis      (ctrl_o_dis ),
    .rhs_const  (ctrl_rhs_const),
    .op_switch  (ctrl_op_switch),
    .floor      (ctrl_floor ),
    .mode       (ctrl_mode  ),
    .op         (ctrl_op    ),
    .mu         (ctrl_mu    ),
    .inv2       (ctrl_inv2  ),
    .q          (ctrl_q     ),
    .otf        (ctrl_otf   ),
    .done       (ctrl_done  ),
    .chknorm    (ctrl_chknorm),
    .rej_samp_ip(ctrl_rej_samp_ip),
    .busy       (ctrl_busy  ),
    // fsm <-> ctrl
    .din_addr   (ctrl_din_addr ),
    .dout_addr  (ctrl_dout_addr),
    .bound      (ctrl_bound )
);


ntt_lite_acc_dma ntt_lite_acc_dma_inst 
(
    .clk         (clk        ),
    .rst         (rst        ),
    // dma <-> fsm
    .addr        (mem_addr   ),
    .re          (mem_re     ),
    .we          (mem_we     ),
    .i_data      (mem_i_data ),
    .i_valid     (mem_i_valid),
    .i_ready     (mem_i_ready),
    .o_ready     (mem_o_ready),
    .o_data      (mem_o_data ),
    // dma connections
    .dma_cyc_i   (dma_cyc_i  ),
    .dma_stb_i   (dma_stb_i  ),
    .dma_we_i    (dma_we_i   ),
    .dma_adr_i   (dma_adr_i  ),
    .dma_dat_i   (dma_dat_i  ),
    .dma_sel_i   (dma_sel_i  ),
    .dma_stall_o (dma_stall_o),
    .dma_ack_o   (dma_ack_o  ),
    .dma_dat_o   (dma_dat_o  ),
    .dma_err_o   (dma_err_o  ),
    .dma_rst_i   (dma_rst_i  )
);


ntt_lite_acc_wb ntt_lite_acc_wb_inst (
    // wb <-> ctrl
    .addr       (ctrl_addr  ),
    .wdata      (ctrl_wdata ),
    .we         (ctrl_we    ),
    .re         (ctrl_re    ),
    .rdata      (ctrl_rdata ),
    .clk        (clk        ),
    .rst        (rst        ),
    // wishbone connections
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


ntt_lite_acc_fsm #(
    .LOGQ(LOGQ),
    .LOGN(LOGN)
) ntt_lite_acc_fsm_inst (
    .clk            (clk            ),
    .rst            (rst            ),
    // dma <-> fsm
    .mem_addr       (mem_addr       ),
    .mem_re         (mem_re         ),
    .mem_we         (mem_we         ),
    .mem_i_data     (mem_i_data     ),
    .mem_i_valid    (mem_i_valid    ),
    .mem_i_ready    (mem_i_ready    ),
    .mem_o_ready    (mem_o_ready    ),
    .mem_o_data     (mem_o_data     ),
    // ntt <-> fsm
    .fsm_i_data     (fsm_i_data     ),
    .fsm_i_ready    (fsm_i_ready    ),
    .fsm_i_valid    (fsm_i_valid    ),
    .fsm_i_done     (fsm_i_done     ),
    .fsm_o_data     (fsm_o_data     ),
    .fsm_o_valid    (fsm_o_valid    ),
    .fsm_o_read     (fsm_o_read     ),
    .fsm_io_word    (fsm_io_word    ),
    .fsm_io_limit   (fsm_io_limit   ),
    .fsm_o_done     (ctrl_done      ),    
    // fsm <-> ctrl
    .ctrl_din_addr  (ctrl_din_addr  ),
    .ctrl_dout_addr (ctrl_dout_addr ),
    .ctrl_logn      (ctrl_logn      ),
    .ctrl_cmd       (ctrl_cmd       )
);


endmodule

