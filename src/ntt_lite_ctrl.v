module ntt_lite_ctrl 
   #(
        parameter BASE_ADDR = 32'h40001000
    )
    (
        input              clk,
        input              rst,          // Active-low reset
        input      [31:0]  addr,         // Address input
        input      [31:0]  wdata,        // Write data
        input              we,           // Write enable
        input              re,           // Read enable
        output reg [31:0]  rdata,        // Read data

        // ctrl reg fields
        output reg [ 3:0]  cmd,          // (Write/Self-Clear)
        output reg [ 3:0]  logn,         // (Read/Write)
        output reg [ 2:0]  mode,         // (Read/Write)
        output reg         otf,          // (Read/Write)
        output reg [ 1:0]  logq,         // (Read/Write)
        //data address registers
        output reg [31:0]  din_addr;     // (Write)
        output reg [31:0]  dout_addr;    // (Write)
        output reg [31:0]  stride;       // (Read/Write)

        input              busy,         // Busy status input
        input              done          // Done status input
    );

    // Register relative addresses
    localparam CTRL_ADDR      = 8'h00; // Offset for ctrl register
    localparam DIN_ADDR       = 8'h04; // Offset for din_addr register
    localparam DOUT_ADDR      = 8'h08; // Offset for dout_addr register
    localparam STRIDE_ADDR    = 8'h0C; // Offset for stride register

    // Bit-fields for ctrl register
    localparam CTRL_CMD_LSB   = 0;
    localparam CTRL_CMD_MSB   = 3;
    localparam CTRL_CMD_LEN   = CTRL_CMD_MSB - CTRL_CMD_LSB + 1;
    localparam CTRL_LOGN_LSB  = 4;
    localparam CTRL_LOGN_MSB  = 7;
    localparam CTRL_LOGN_LEN  = CTRL_LOGN_MSB - CTRL_LOGN_LSB + 1;
    localparam CTRL_MODE_LSB  = 8;
    localparam CTRL_MODE_MSB  = 10;
    localparam CTRL_MODE_LEN  = CTRL_MODE_MSB - CTRL_MODE_LSB + 1;
    localparam CTRL_OTF_BIT   = 11;
    localparam CTRL_LOGQ_LSB  = 12;
    localparam CTRL_LOGQ_MSB  = 13;
    localparam CTRL_LOGQ_LEN  = CTRL_LOGQ_MSB - CTRL_LOGQ_LSB + 1;
    localparam CTRL_BUSY_BIT  = 30;
    localparam CTRL_DONE_BIT  = 31;


    // DONE flag (Clear on Read)
    always @(posedge clk) begin
        if (rst) begin
            done_q <= 1'b0;
        end else if (done) begin
            done_q <= 1'b1;
        end else if (re && (addr == (BASE_ADDR + CTRL_ADDR)) && done_q) begin
            done_q <= 1'b0;
        end
    end

    // CMD (Self-Clear)
    always @(posedge clk) begin
        if (rst) begin
            cmd <= {CTRL_CMD_LEN{1'b0}};
        end
        else if (cmd != {CTRL_CMD_LEN{1'b0}}) begin
            cmd <= {CTRL_CMD_LEN{1'b0}};
        end
        else if (we && (addr == (BASE_ADDR + CTRL_ADDR))) begin
            cmd <= wdata[CTRL_CMD_MSB:CTRL_CMD_LSB];
        end
    end

    // (Write)
    always @(posedge clk) begin
        if (rst) begin
            logn  <= {CTRL_LOGN_LEN{1'b0}};
            mode  <= {CTRL_MODE_LEN{1'b0}};
            otf   <= 1'b0;
            logq  <= {CTRL_LOGQ_LEN{1'b0}};
            din_addr  <= 32'd0;
            dout_addr <= 32'd0;
            stride    <= 32'd0;
        end else if (we) begin
            case (addr - BASE_ADDR)
                CTRL_ADDR: begin
                    logn <= wdata[CTRL_LOGN_MSB:CTRL_LOGN_LSB];
                    mode <= wdata[CTRL_MODE_MSB:CTRL_MODE_LSB];
                    otf  <= wdata[CTRL_OTF_BIT];
                    logq <= wdata[CTRL_LOGQ_MSB:CTRL_LOGQ_LSB];
                end
                DIN_ADDR:    din_addr  <= wdata;
                DOUT_ADDR:   dout_addr <= wdata;
                STRIDE_ADDR: stride    <= wdata;
                default: ;
            endcase
        end
    end

    // (Read)
    always @(posedge clk) begin
        if (rst) begin
            rdata <= 32'b0;
        end else if (re) begin
            case (addr - BASE_ADDR)
                CTRL_ADDR: begin
                    rdata[CTRL_CMD_MSB:CTRL_CMD_LSB]   <= cmd;
                    rdata[CTRL_LOGN_MSB:CTRL_LOGN_LSB] <= logn;
                    rdata[CTRL_MODE_MSB:CTRL_MODE_LSB] <= mode;
                    rdata[CTRL_OTF_BIT]                <= otf;
                    rdata[CTRL_LOGQ_MSB:CTRL_LOGQ_LSB] <= logq;
                    rdata[CTRL_BUSY_BIT]               <= busy;
                    rdata[CTRL_DONE_BIT]               <= done_q | done;
                end
                DIN_ADDR:    rdata <= 32'd0;
                DOUT_ADDR:   rdata <= 32'd0;
                STRIDE_ADDR: rdata <= stride;
                default:     rdata <= 32'd0;
            endcase
        end
    end

endmodule
