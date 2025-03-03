module ntt_lite_acc_fsm
   #(
        parameter B = 32,
        parameter LOGQ = 64,
        parameter LOGN = 6
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
         
        output reg [B-1:0]         fsm_i_data,
        input                      fsm_i_ready,
        output reg                 fsm_i_valid,
        input      [B-1:0]         fsm_o_data,
        output reg                 fsm_o_read,
        input                      fsm_o_valid,
        input      [LOGN+LOGWB-1:0]fsm_io_word,
        
        input      [31:0]          ctrl_din_addr,
        input      [31:0]          ctrl_dout_addr,
        
        input      [3:0]           ctrl_cmd,
        input      [LOGLOGN-1:0]   ctrl_logn,
        input      [1:0]           ctrl_logq
    );


localparam LOGWB   = $clog2(LOGQ/B);
localparam LOGLOGN = $rtoi($ceil($clog2(LOGN+1))); 
localparam [31:0] ST_IDLE = 0;
localparam [31:0] ST_GET = 1;
localparam [31:0] ST_BUSY = 2;
localparam [31:0] ST_PUT = 3;
localparam [31:0] ST_GET0 = 4;
localparam [31:0] ST_GET2 = 5;


reg [31:0] cnt;
reg cnt_up, cnt_rst;
reg [31:0] LIMIT;
reg [31:0] cstate;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        cnt <= 0;
        LIMIT <= 0;
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
            if(ctrl_cmd == 2)
            begin
                LIMIT <= (1 << ctrl_logq);
                cstate <= ST_GET0;
            end
            else if(ctrl_cmd == 3)
            begin
                LIMIT <= (1 << ctrl_logn);
                cstate <= ST_GET0;
            end
            else if(ctrl_cmd == 4)
            begin
                LIMIT <= (1 << ctrl_logn);
                cstate <= ST_GET0;
            end
            else if(fsm_o_valid)
            begin
                cstate <= ST_PUT;
                LIMIT <= (1 << ctrl_logn);
            end
        end
        ST_GET0:
            cstate <= ST_GET;
        ST_GET:
        begin
            if(cnt == (LIMIT-1))
                cstate <= ST_GET2; 
        end
        ST_GET2:
        begin
            cstate <= ST_IDLE;
        end
        
        ST_PUT:
        begin
            if(fsm_io_word == (LIMIT-1))
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
    fsm_i_data = 0;
    fsm_i_valid = mem_i_valid;
    fsm_o_read = 0;
    mem_re = fsm_i_ready;
    mem_we = 0;
    case(cstate)
    ST_GET0:
    begin
        if(fsm_i_ready)
        begin  
            mem_addr = ctrl_din_addr + (cnt << 2);
            cnt_up = 1;
        end
    end
    ST_GET:
    begin
        if(fsm_i_ready)
        begin  
            mem_addr = ctrl_din_addr + (cnt << 2);
            fsm_i_data = mem_i_data;
            cnt_up = 1;
        end
        if(cnt == (LIMIT-1))
            cnt_rst = 1;
       
    end
    ST_GET2:
    begin
        fsm_i_data = mem_i_data;
    end
    ST_PUT:
    begin
        if(fsm_o_valid)
        begin  
            mem_addr = ctrl_dout_addr + (fsm_io_word << 2);
            mem_we = fsm_o_valid;
            fsm_o_read = mem_o_ready;
            // cnt_up = mem_o_ready;
            // if(fsm_io_word == (LIMIT-1))
            //     cnt_rst = 1;
        end
    end
    endcase    
end
endmodule