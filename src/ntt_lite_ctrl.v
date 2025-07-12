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
        output reg [ 5:0]  k,            // (Read/Write)
        output reg [ 5:0]  d,            // (Write)
        output reg         floor,        // (Write)        
        output reg         o_dis,        // (Write)        
        output reg         rhs_const,    // (Write)        
        output reg         op_switch,    // (Write)        
        output reg [31:0]  q,            // (Read/Write)
        output reg [31:0]  inv2,            // (Read/Write)        
        output reg [63:0]  mu,           // (Read/Write)
        //data address registers
        output reg [31:0]  din_addr,     // (Write)
        output reg [31:0]  dout_addr,    // (Write)
        output reg [31:0]  bound,       // (Read/Write)

        input              busy,         // Busy status input
        input              done          // Done status input
    );

// Register relative addresses
localparam CTRL_ADDR      = 8'h00; // Offset for ctrl register
localparam DIN_ADDR       = 8'h04; // Offset for din_addr register
localparam DOUT_ADDR      = 8'h08; // Offset for dout_addr register
localparam BOUND_ADDR     = 8'h0C; // Offset for bound register
localparam Q_ADDR         = 8'h10; // Offset for coefficient modulus register
localparam MU_ADDR_LOW    = 8'h14; // Offset for mu register lsb 32-bits
localparam MU_ADDR_HIGH   = 8'h18; // Offset for mu register msb 2-bit
localparam INV2_ADDR      = 8'h1C; // Offset for mu register lsb 32-bits

// Bit-fields for ctrl register
localparam CTRL_CMD_LSB       = 0;
localparam CTRL_CMD_MSB       = 3;
localparam CTRL_CMD_LEN       = CTRL_CMD_MSB - CTRL_CMD_LSB + 1;
localparam CTRL_LOGN_LSB      = 4;
localparam CTRL_LOGN_MSB      = 7;
localparam CTRL_LOGN_LEN      = CTRL_LOGN_MSB - CTRL_LOGN_LSB + 1;
localparam CTRL_OP_LSB        = 8;
localparam CTRL_OP_MSB        = 11;
localparam CTRL_OP_LEN        = CTRL_OP_MSB - CTRL_OP_LSB + 1;
localparam CTRL_OP_SWITCH_BIT = 12;
localparam CTRL_K_LSB         = 13;
localparam CTRL_K_MSB         = 17;
localparam CTRL_K_LEN         = CTRL_K_MSB - CTRL_K_LSB + 1;
localparam CTRL_MODE_LSB      = 19;
localparam CTRL_MODE_MSB      = 20;
localparam CTRL_MODE_LEN      = CTRL_MODE_MSB - CTRL_MODE_LSB + 1;
localparam CTRL_D_LSB         = 21;
localparam CTRL_D_MSB         = 25;
localparam CTRL_D_LEN         = CTRL_D_MSB - CTRL_D_LSB + 1;
localparam CTRL_RHS_CONST_BIT = 27;
localparam CTRL_FLOOR_BIT     = 28;
localparam CTRL_O_DIS_BIT     = 29;
localparam CTRL_BUSY_BIT      = 30;
localparam CTRL_DONE_BIT      = 31;


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
        k     <= {CTRL_K_LEN{1'b0}};
        d     <= {CTRL_D_LEN{1'b0}};
        q     <= 32'd0;
        mu    <= 64'd0;
        din_addr  <= 32'd0;
        dout_addr <= 32'd0;
        bound     <= 32'd0;
        floor     <= 1'b0;
        rhs_const <= 1'b0;
        op_switch <= 1'b0;
        o_dis     <= 1'b0;
    end else if (we) begin
        case (addr - BASE_ADDR)
            CTRL_ADDR: begin
                logn      <= wdata[CTRL_LOGN_MSB:CTRL_LOGN_LSB];
                mode      <= wdata[CTRL_MODE_MSB:CTRL_MODE_LSB];
                op_switch <= wdata[CTRL_OP_SWITCH_BIT];
                k         <= {1'b0, wdata[CTRL_K_MSB:CTRL_K_LSB]};
                op        <= wdata[CTRL_OP_MSB  :CTRL_OP_LSB  ];
                d         <= {1'b0, wdata[CTRL_D_MSB:CTRL_D_LSB]};
                floor     <= wdata[CTRL_FLOOR_BIT];
                rhs_const <= wdata[CTRL_RHS_CONST_BIT];
                o_dis     <= wdata[CTRL_O_DIS_BIT];
            end
            DIN_ADDR    : din_addr  <= wdata;
            DOUT_ADDR   : dout_addr <= wdata;
            BOUND_ADDR  : bound     <= wdata;
            Q_ADDR      : q         <= wdata;
            MU_ADDR_LOW : mu[31: 0] <= wdata;
            MU_ADDR_HIGH: mu[63:32] <= wdata;
            INV2_ADDR   : inv2      <= wdata;
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
                rdata[CTRL_K_MSB   :CTRL_K_LSB   ] <= k;
                rdata[CTRL_BUSY_BIT]               <= busy;
                rdata[CTRL_DONE_BIT]               <= done_q | done;
            end
            DIN_ADDR    : rdata <= 32'd0;
            DOUT_ADDR   : rdata <= 32'd0;
            BOUND_ADDR  : rdata <= bound;
            Q_ADDR      : rdata <= q;
            MU_ADDR_LOW : rdata <= mu[31: 0];
            MU_ADDR_HIGH: rdata <= mu[63:32];
            INV2_ADDR   : rdata <= inv2;
            default     : rdata <= 32'd0;
        endcase
    end
end

endmodule
