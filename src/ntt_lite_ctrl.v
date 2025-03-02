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
        output reg [ 1:0]  mode,         // (Read/Write)
        output reg [ 3:0]  op  ,         // (Write)
        output reg         otf,          // (Read/Write)
        output reg [ 5:0]  logq,         // (Read/Write)
        output reg [31:0]  q,            // (Read/Write)
        output reg [32:0]  mu,           // (Read/Write)
        //data address registers
        output reg [31:0]  din_addr,     // (Write)
        output reg [31:0]  dout_addr,    // (Write)
        output reg [31:0]  stride,       // (Read/Write)

        input              busy,         // Busy status input
        input              done          // Done status input
    );

// Register relative addresses
localparam CTRL_ADDR      = 8'h00; // Offset for ctrl register
localparam DIN_ADDR       = 8'h04; // Offset for din_addr register
localparam DOUT_ADDR      = 8'h08; // Offset for dout_addr register
localparam STRIDE_ADDR    = 8'h0C; // Offset for stride register
localparam Q_ADDR         = 8'h10; // Offset for coefficient modulus register
localparam MU_ADDR_LOW    = 8'h14; // Offset for mu register lsb 32-bits
localparam MU_ADDR_HIGH   = 8'h18; // Offset for mu register msb 2-bit

// Bit-fields for ctrl register
localparam CTRL_CMD_LSB   = 0;
localparam CTRL_CMD_MSB   = 3;
localparam CTRL_CMD_LEN   = CTRL_CMD_MSB - CTRL_CMD_LSB + 1;
localparam CTRL_LOGN_LSB  = 4;
localparam CTRL_LOGN_MSB  = 7;
localparam CTRL_LOGN_LEN  = CTRL_LOGN_MSB - CTRL_LOGN_LSB + 1;
localparam CTRL_OP_LSB    = 8;
localparam CTRL_OP_MSB    = 11;
localparam CTRL_OP_LEN    = CTRL_OP_MSB - CTRL_OP_LSB + 1;
localparam CTRL_OTF_BIT   = 12;
localparam CTRL_LOGQ_LSB  = 13;
localparam CTRL_LOGQ_MSB  = 18;
localparam CTRL_LOGQ_LEN  = CTRL_LOGQ_MSB - CTRL_LOGQ_LSB + 1;
localparam CTRL_MODE_LSB  = 19;
localparam CTRL_MODE_MSB  = 20;
localparam CTRL_MODE_LEN  = CTRL_MODE_MSB - CTRL_MODE_LSB + 1;
localparam CTRL_BUSY_BIT  = 30;
localparam CTRL_DONE_BIT  = 31;


reg done_q;

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
        op    <= {CTRL_OP_LEN{1'b0}};
        otf   <= 1'b0;
        logq  <= {CTRL_LOGQ_LEN{1'b0}};
        q     <= 32'd0;
        mu    <= 33'd0;
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
                op   <= wdata[CTRL_OP_MSB  :CTRL_OP_LSB  ];
            end
            DIN_ADDR    : din_addr  <= wdata;
            DOUT_ADDR   : dout_addr <= wdata;
            STRIDE_ADDR : stride    <= wdata;
            Q_ADDR      : q         <= wdata;
            MU_ADDR_LOW : mu[31:0]  <= wdata;
            MU_ADDR_HIGH: mu[32]    <= wdata[0];
            default: ;
        endcase
    end
end

// (Read)
always @(posedge clk) begin
    if (rst) begin
        rdata <= 32'd0;
    end else if (re) begin
        case (addr - BASE_ADDR)
            CTRL_ADDR: begin
                rdata[CTRL_LOGN_MSB:CTRL_LOGN_LSB] <= logn;
                rdata[CTRL_MODE_MSB:CTRL_MODE_LSB] <= mode;
                rdata[CTRL_OTF_BIT]                <= otf;
                rdata[CTRL_LOGQ_MSB:CTRL_LOGQ_LSB] <= logq;
                rdata[CTRL_BUSY_BIT]               <= busy;
                rdata[CTRL_DONE_BIT]               <= done_q | done;
            end
            DIN_ADDR    : rdata <= 32'd0;
            DOUT_ADDR   : rdata <= 32'd0;
            STRIDE_ADDR : rdata <= stride;
            Q_ADDR      : rdata <= q;
            MU_ADDR_LOW : rdata <= mu[31:0];
            MU_ADDR_HIGH: rdata <= mu[32];
            default     : rdata <= 32'd0;
        endcase
    end
end

endmodule
