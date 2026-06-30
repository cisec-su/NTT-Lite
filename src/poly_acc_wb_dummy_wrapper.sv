module poly_acc_wb_dummy_wrapper
(
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] impl_probe
);

    // -------------------------
    // Internal WB stimulus
    // -------------------------
    logic        wb_cyc_i, wb_stb_i, wb_we_i, wb_rst_i;
    logic [31:0] wb_adr_i, wb_dat_i;
    logic [ 3:0] wb_sel_i;
    logic        wb_stall_o, wb_ack_o, wb_err_o;
    logic [31:0] wb_dat_o;

    logic [31:0] tick;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) tick <= 32'd0;
        else        tick <= tick + 32'd1;
    end

    assign wb_rst_i = ~rst_n;
    assign wb_cyc_i = 1'b1;
    assign wb_stb_i = tick[0];
    assign wb_we_i  = tick[1];
    assign wb_adr_i = 32'h4000_1000 + {tick[9:0], 2'b00};
    assign wb_dat_i = tick ^ 32'hA5A5_5A5A;
    assign wb_sel_i = 4'hF;

    // -------------------------
    // Internal DMA responder
    // -------------------------
    logic        dma_cyc_i, dma_stb_i, dma_we_i, dma_rst_i;
    logic [31:0] dma_adr_i, dma_dat_i, dma_dat_o;
    logic [ 3:0] dma_sel_i;
    logic        dma_stall_o, dma_ack_o, dma_err_o;

    assign dma_stall_o = 1'b0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_ack_o <= 1'b0;
            dma_err_o <= 1'b0;
            dma_dat_o <= 32'd0;
        end else begin
            dma_ack_o <= dma_cyc_i && dma_stb_i; // 1-cycle response
            dma_err_o <= 1'b0;
            if (dma_cyc_i && dma_stb_i && !dma_we_i)
                dma_dat_o <= dma_adr_i ^ 32'hD00D_0000 ^ {31'd0, dma_rst_i};
        end
    end

    // -------------------------
    // DUT
    // -------------------------
    (* keep_hierarchy = "yes" *)
    poly_acc_wb dut (
        .wb_cyc_i   (wb_cyc_i),
        .wb_stb_i   (wb_stb_i),
        .wb_we_i    (wb_we_i),
        .wb_adr_i   (wb_adr_i),
        .wb_dat_i   (wb_dat_i),
        .wb_sel_i   (wb_sel_i),
        .wb_stall_o (wb_stall_o),
        .wb_ack_o   (wb_ack_o),
        .wb_dat_o   (wb_dat_o),
        .wb_err_o   (wb_err_o),
        .wb_rst_i   (wb_rst_i),
        .wb_clk_i   (clk),

        .dma_cyc_i   (dma_cyc_i),
        .dma_stb_i   (dma_stb_i),
        .dma_we_i    (dma_we_i),
        .dma_adr_i   (dma_adr_i),
        .dma_dat_i   (dma_dat_i),
        .dma_sel_i   (dma_sel_i),
        .dma_stall_o (dma_stall_o),
        .dma_ack_o   (dma_ack_o),
        .dma_dat_o   (dma_dat_o),
        .dma_err_o   (dma_err_o),
        .dma_rst_i   (dma_rst_i)
    );

    // Keep observable activity for implementation realism
    always_comb begin
        impl_probe = wb_dat_o ^ dma_adr_i ^ dma_dat_i ^ dma_dat_o ^
                     {29'd0, wb_ack_o, wb_err_o, dma_we_i};
    end

endmodule
