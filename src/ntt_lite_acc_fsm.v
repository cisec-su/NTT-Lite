`include "ntt_lite.vh"

module ntt_lite_acc_fsm
   #(
        parameter LOGQ = 32,
        parameter LOGN = 8 ,
        parameter LOGLOGN = $clog2(LOGN+1)
    )
    (
        input                      clk,
        input                      rst,
 
        output reg [31:0]          mem_addr,
        output reg                 mem_re,
        output reg                 mem_we,
        input      [31:0]          mem_i_data,
        input                      mem_i_valid,
        input                      mem_i_ready,
        input                      mem_o_ready,
        output reg [31:0]          mem_o_data,
         
        output reg [LOGQ-1:0]      fsm_i_data,
        input                      fsm_i_ready,
        output reg                 fsm_i_valid,
        input      [LOGQ-1:0]      fsm_o_data,
        output reg                 fsm_o_read,
        input                      fsm_o_valid,
        input      [LOGN-1:0]      fsm_io_word,
        input                      fsm_o_done,
        input      [LOGN-1:0]      fsm_io_limit,

        input      [31:0]          ctrl_din_addr,
        input      [31:0]          ctrl_dout_addr,

        input      [3:0]           ctrl_cmd,

        input      [LOGLOGN-1:0]   ctrl_logn
    );


localparam ST_IDLE = 3'd0;
localparam ST_GET  = 3'd1;
localparam ST_BUSY = 3'd2;
localparam ST_PUT  = 3'd3;
localparam ST_GET0 = 3'd4;


reg [LOGN-1:0] cnt;
reg cnt_up, cnt_rst;
reg [2:0] cstate;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        cnt <= 0;
        cstate <= ST_IDLE;
    end
    else
    begin
        if(cnt_rst)
            cnt <= 0;
        else if(cnt_up)
            cnt <= cnt + 1;
        else
            cnt <= cnt;
        
        case(cstate)
        ST_IDLE:
        begin
            if(ctrl_cmd == `CMD_LOAD_TWIDDLE)
            begin
                cstate <=  ST_GET;
            end
            else if(ctrl_cmd == `CMD_LOAD_ZETA)
            begin
                cstate <= ST_GET;
            end
            else if(ctrl_cmd == `CMD_LOAD_POLY)
            begin
                cstate <= ST_GET;
            end
            else if(fsm_o_valid)
            begin
                cstate <= ST_PUT;
            end
        end
        ST_GET:
        begin
            if(cnt >= (fsm_io_limit))
                cstate <= ST_IDLE; 
        end
        
        ST_PUT:
        begin
            if(fsm_o_done)
                cstate <= ST_IDLE; 
        end
        endcase
    end
    
end        
  
always @ (*)
begin
    cnt_up = 0;
    cnt_rst = 0;

    mem_addr = 0;
        
    mem_o_data = fsm_o_data;
    fsm_i_data = mem_i_data;
    fsm_i_valid = mem_i_valid;
    fsm_o_read = 0;
    mem_re = 0;
    mem_we = 0;
    case(cstate)
    ST_IDLE:
    begin
        cnt_rst = 1;
    end
    ST_GET:
    begin
        mem_addr = ctrl_din_addr + ({cnt, 2'b00});
        if(fsm_i_ready)
        begin
            mem_re = 1;  
            if (cnt >= (fsm_io_limit))
                cnt_rst = 1;
            else
                cnt_up = 1;
        end
    end
    ST_PUT:
    begin
        mem_addr = ctrl_dout_addr + (fsm_io_word << 2);
        if(fsm_o_valid)
        begin  
            mem_we = 1;
            fsm_o_read = mem_o_ready;
        end
    end
    endcase    
end
endmodule