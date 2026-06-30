module wb_dma
    (
        input              clk        ,
        input              rst        ,
        input      [31:0]  r_addr     ,
        input      [31:0]  w_addr     ,        
        input      [ 7:0]  rw_offset  ,
        input      [ 8:0]  r_len      ,
        input      [ 8:0]  w_len      ,        
        input              r_ready    ,
        output             r_valid    ,
        output             w_ready    ,
        input              w_valid    ,
(* dont_touch *) output reg [31:0]  r_data,
        input      [31:0]  w_data     ,
        // dma connections
        output reg         dma_cyc_i  ,
        output reg         dma_stb_i  ,
        output reg         dma_we_i   ,
        output reg [31:0]  dma_adr_i  ,
        output reg [31:0]  dma_dat_i  ,
        output reg [ 3:0]  dma_sel_i  ,
        input              dma_stall_o,
        input              dma_ack_o  ,
        input      [31:0]  dma_dat_o  ,
        input              dma_err_o  ,
        output reg         dma_rst_i
    );


typedef enum logic [3:0] {
    S_IDLE       = 3'd0,
    S_READ0      = 3'd1,
    S_READ1      = 3'd2,
    S_READ2      = 3'd3,    
    S_WRITE0     = 3'd4
} fsm_state_t;



fsm_state_t  state;
reg [31:0] cur_addr;
reg [8:0]  beats_left;
reg        r_valid_r;
reg        w_ready_r;

assign r_valid = r_valid_r;
assign w_ready = 1;

//wire wb_done = dma_ack_o | dma_err_o;
wire [31:0] start_r_addr = r_addr + {24'd0, rw_offset};
wire [31:0] start_w_addr = w_addr + {24'd0, rw_offset};

always @(posedge clk) begin
    if (rst) begin
        state      <= S_IDLE;
        cur_addr   <= 32'd0;
        beats_left <= 9'd0;
        r_valid_r  <= 1'b0;
        w_ready_r  <= 1'b0;
        r_data     <= 32'd0;

        dma_cyc_i  <= 1'b0;
        dma_stb_i  <= 1'b0;
        dma_we_i   <= 1'b0;
        dma_adr_i  <= 32'd0;
        dma_dat_i  <= 32'd0;
        dma_sel_i  <= 4'hF;
        dma_rst_i  <= 1'b1;
    end else begin
        dma_rst_i <= 1'b0;
        dma_sel_i <= 4'hF;

        case (state)
            S_IDLE: begin
                dma_cyc_i <= 1'b0;
                dma_stb_i <= 1'b0;
                dma_we_i  <= 1'b0;
                w_ready_r <= 1'b0;
                r_valid_r <= 1'b0;
                r_data    <= 32'd0;
                if ((w_len != 9'd0) && w_valid) begin
                    // Start WRITE burst.
                    beats_left <= w_len;
                    dma_cyc_i  <= 1'b1;
                    dma_stb_i  <= 1'b1;
                    dma_we_i   <= 1'b1;
                    dma_adr_i  <= start_w_addr;
                    dma_dat_i  <= w_data;
                    state      <= S_WRITE0;
                end else if ((r_len != 9'd0) && r_ready) begin
                    // Start READ burst.
                    beats_left <= r_len;
                    dma_cyc_i  <= 1'b1;
                    dma_stb_i  <= 1'b1;
                    dma_we_i   <= 1'b0;
                    dma_adr_i  <= start_r_addr;
                    state      <= S_READ0;
                end
            end
            S_READ0: begin
                beats_left <= beats_left - 9'd1;
                if (beats_left == 9'd1) begin
                    dma_cyc_i <= 1'b0;
                    dma_stb_i <= 1'b0;
                    state     <= S_READ2;
                end
                else begin
                    dma_adr_i <= dma_adr_i + 32'd4;
                    state <= S_READ1;
                end
            end
            S_READ1: begin
                r_data    <= dma_dat_o;
                r_valid_r <= 1'b1;
                beats_left <= beats_left - 9'd1;
                if (beats_left == 9'd1) begin
                    dma_cyc_i <= 1'b0;
                    dma_stb_i <= 1'b0;
                    state     <= S_READ2;
                end
                else begin
                    dma_adr_i <= dma_adr_i + 32'd4;
                end
            end
            S_READ2: begin
                r_data    <= dma_dat_o;
                r_valid_r <= 1'b1;
                state    <= S_IDLE;
            end
            S_WRITE0: begin
                beats_left <= beats_left - 9'd1;
                if (beats_left == 9'd1) begin
                    dma_cyc_i <= 1'b0;
                    dma_stb_i <= 1'b0;
                    state     <= S_IDLE;
                    dma_we_i  <= 1'b0;
                    dma_dat_i <= 32'd0;
                end
                else begin
                    dma_adr_i <= dma_adr_i + 32'd4;
                    dma_dat_i <= w_data;
                end                
            end
            default: begin
                state <= S_IDLE;
            end
        endcase

        // `dma_stall_o` is intentionally ignored in this non-pipelined mode.
        // Master keeps `stb` asserted until `ack/err`.
    end
end

endmodule