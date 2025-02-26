`ifndef MAC_STD_DUAL_32x34_H
`define MAC_STD_DUAL_32x34_H


typedef struct packed {
    int LOGB, MODE_E, FF_IN_A, FF_IN_B, FF_IN_E, FF_MUL, FF_OUT;
} mac_std_dual_32x34_params_t;


typedef enum int {
    DIS_E = 0,
    SUB_E = 2
} mode_e_t;


typedef enum logic [1:0] {
    MUL_SINGLE = 2'b00,
    MUL_DUAL   = 2'b10,
    MUL_POLY   = 2'b11
} mode_mul_t;


function int mac_std_dual_32x34_lat(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_lat = (params.FF_IN_A || params.FF_IN_B || (params.FF_IN_E & (params.MODE_E != 0))) + params.FF_MUL + params.FF_OUT;
endfunction


function int mac_std_dual_32x34_loga0(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_loga0 = 16;
endfunction


function int mac_std_dual_32x34_logb0(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_logb0 = params.LOGB >> 1;
endfunction


function int mac_std_dual_32x34_loge0(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_loge0 = 18;
endfunction


function int mac_std_dual_32x34_loga(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_loga = mac_std_dual_32x34_loga0(params) << 1;
endfunction


function int mac_std_dual_32x34_loge(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_loge = mac_std_dual_32x34_loge0(params) << 1;
endfunction


function int mac_std_dual_32x34_logd0(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_logd0 = mac_std_dual_32x34_loga0(params) + mac_std_dual_32x34_logb0(params);
endfunction


function int mac_std_dual_32x34_logd(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_logd = mac_std_dual_32x34_logd0(params) << 1;
endfunction


function int mac_std_dual_32x34_logc0(input mac_std_dual_32x34_params_t params);
    if (params.MODE_E == 0) begin
        mac_std_dual_32x34_logc0 = mac_std_dual_32x34_logd0(params);
    end
    else if (params.MODE_E == 2) begin
        if (mac_std_dual_32x34_loge0(params) > mac_std_dual_32x34_logd0(params)) begin
            mac_std_dual_32x34_logc0 = mac_std_dual_32x34_loge0(params) + 1;
        end
        else begin
            mac_std_dual_32x34_logc0 = mac_std_dual_32x34_logd0(params) + 1;
        end
    end
endfunction


function int mac_std_dual_32x34_logc(input mac_std_dual_32x34_params_t params);
    mac_std_dual_32x34_logc = mac_std_dual_32x34_logc0(params) << 1;
endfunction


`endif