`timescale 1ns/1ps

module ntt_acc_top
                    (
input         wb_cyc_i,
input         wb_stb_i,
input         wb_we_i,
input [31:0]  wb_adr_i,
input [31:0]  wb_dat_i,
input [3:0]   wb_sel_i,
output        wb_stall_o,
output        wb_ack_o,
output  [31:0] wb_dat_o,
output        wb_err_o,
input         wb_rst_i,
input         wb_clk_i,

output          dma_cyc_i,
output          dma_stb_i,
output          dma_we_i,
output  [31:0]  dma_adr_i,
output  [31:0]  dma_dat_i,
output  [3:0]   dma_sel_i,
input              dma_stall_o,
input              dma_ack_o,
input  [31:0]      dma_dat_o,
input              dma_err_o,
output          dma_rst_i);


parameter [31:0] CTRL_ADDR =       32'h00040020;
parameter [31:0] DIN_ADDR =       32'h00040024;
parameter [31:0] DOUT_ADDR =    32'h00040028;
parameter [31:0] STRIDE_ADDR =    32'h0004002C;

// Init NTT_LITE & NTT_CTRL

parameter HP = 5;
parameter FP = (2*HP);
parameter B = 32;
parameter LOGQ = 64;
parameter N = 64;
parameter LOGN = 6;
parameter L = 13;
localparam LOGWB   = $clog2(LOGQ/B);

wire clk, rst;
assign clk = wb_clk_i;
assign rst = wb_rst_i;

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
wire [B-1:0] fsm_i_data;
wire fsm_i_ready;
wire fsm_i_valid;
wire [B-1:0] fsm_o_data;
wire fsm_o_read;
wire fsm_o_valid;
wire [LOGN+LOGWB-1:0] fsm_io_word;

// CTRL & NTT
wire [3:0] ctrl_cmd;
wire [3:0] ctrl_logn;
wire [3:0] ctrl_logq;
wire [1:0] ctrl_mode;
wire ctrl_otf;
wire ctrl_done;
wire ctrl_busy;

// CTRL & FSM
wire [31:0] ctrl_din_addr;
wire [31:0] ctrl_dout_addr;

ntt_lite #(
    .LOGN(LOGN),
    .LOGQ(LOGQ),
    .B(B),
    .L(L)
) ntt_lite (
    .clk(clk),
    .rst(rst),
    // ntt <-> fsm
    .i_data(fsm_i_data),//
    .i_ready(fsm_i_ready),//
    .i_valid(fsm_i_valid),//
    .o_data(fsm_o_data),//
    .o_valid(fsm_o_valid),//
    .o_read(fsm_o_read),//
    .io_word(fsm_io_word),//
    // ntt <-> ctrl
    .cmd(ctrl_cmd),//
    .logn(ctrl_logn),//
    .logq(ctrl_logq),//
    .mode(ctrl_mode),//
    .otf(ctrl_otf),//
    .done(ctrl_done),//
    .busy(ctrl_busy),//
    
    
    .error()
);

ntt_lite_ctrl #(
    .BASE_ADDR(32'h00040020)
) ntt_lite_ctrl(
    .clk(clk),
    .rst(rst),
    // wb <-> ctrl
    .addr(ctrl_addr),//
    .wdata(ctrl_wdata),//
    .we(ctrl_we),//
    .re(ctrl_re),//
    .rdata(ctrl_rdata),//
    // ntt <-> ctrl
    .cmd(ctrl_cmd),//
    .logn(ctrl_logn),//
    .logq(ctrl_logq),//
    .mode(ctrl_mode),//
    .otf(ctrl_otf),//
    .done(ctrl_done),//
    .busy(ctrl_busy),//
    // fsm <-> ctrl
    .din_addr(ctrl_din_addr),//
    .dout_addr(ctrl_dout_addr),//
    
    .stride()
);

ntt_acc_dma ntt_acc_dma_inst 
(
    .clk         (clk        ),
    .rst       (rst      ),
    // dma <-> fsm
    .addr        (mem_addr),//
    .re          (mem_re),//
    .we          (mem_we),//
    .i_data      (mem_i_data),//
    .i_valid     (mem_i_valid),//
    .i_ready     (mem_i_ready),//
    .o_ready     (mem_o_ready),//
    .o_data      (mem_o_data),//
    // dma connections
    .dma_cyc_i   (dma_cyc_i  ),//
    .dma_stb_i   (dma_stb_i  ),//
    .dma_we_i    (dma_we_i   ),//
    .dma_adr_i   (dma_adr_i  ),//
    .dma_dat_i   (dma_dat_i  ),//
    .dma_sel_i   (dma_sel_i  ),//
    .dma_stall_o (dma_stall_o),//
    .dma_ack_o   (dma_ack_o  ),//
    .dma_dat_o   (dma_dat_o  ),//
    .dma_err_o   (dma_err_o  ),//
    .dma_rst_i   (dma_rst_i  )//
);


ntt_acc_wb ntt_acc_wb_inst (
    .clk        (clk        ),
    .rst      (rst      ),
    // wb <-> ctrl
    .addr       (ctrl_addr  ),//
    .wdata      (ctrl_wdata ),//
    .we         (ctrl_we    ),//
    .re         (ctrl_re    ),//
    .rdata      (ctrl_rdata ),//
    // wishbone connections
    .wb_cyc_i   (wb_cyc_i   ),//
    .wb_stb_i   (wb_stb_i   ),//
    .wb_we_i    (wb_we_i    ),//
    .wb_adr_i   (wb_adr_i   ),//
    .wb_dat_i   (wb_dat_i   ),//
    .wb_sel_i   (wb_sel_i   ),//
    .wb_stall_o (wb_stall_o ),//
    .wb_ack_o   (wb_ack_o   ),//
    .wb_dat_o   (wb_dat_o   ),//
    .wb_err_o   (wb_err_o   ),//
    .wb_rst_i   (wb_rst_i   )//
);

ntt_acc_fsm ntt_acc_fsm (
    .clk       (clk),
    .rst       (rst) ,
    // dma <-> fsm
    .mem_addr        (mem_addr),//
    .mem_re          (mem_re),//
    .mem_we          (mem_we),//
    .mem_i_data      (mem_i_data),//
    .mem_i_valid     (mem_i_valid),//
    .mem_i_ready     (mem_i_ready),//
    .mem_o_ready     (mem_o_ready),//
    .mem_o_data      (mem_o_data),//
    
    // ntt <-> fsm
    .fsm_i_data(fsm_i_data),//
    .fsm_i_ready(fsm_i_ready),//
    .fsm_i_valid(fsm_i_valid),//
    .fsm_o_data(fsm_o_data),//
    .fsm_o_valid(fsm_o_valid),//
    .fsm_o_read(fsm_o_read),//
    .fsm_io_word(fsm_io_word),//
    // fsm <-> ctrl
    .ctrl_din_addr(ctrl_din_addr),//
    .ctrl_dout_addr(ctrl_dout_addr),//
    .ctrl_logn(ctrl_logn),//
    .ctrl_logq(ctrl_logq),//
    .ctrl_cmd(ctrl_cmd)//
    );


endmodule

