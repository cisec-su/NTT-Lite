`ifndef BARRETT
`define BARRETT

`include "mac_std_dual_32x34.svh"


typedef struct packed {
    int LOGQ, LOGQH, FF_IN, FF_SHF, FF_MUL, FF_OUT;
} barrett_params_t;


function mac_std_dual_32x34_params_t barrett_mac_0_params(input barrett_params_t params);
    barrett_mac_0_params = '{LOGB : params.LOGQ + 2,  MODE_E : DIS_E, FF_IN_A: params.FF_SHF,  FF_IN_B: params.FF_SHF,
                             FF_IN_E: 0, FF_MUL : params.FF_MUL,  FF_OUT : 1};
endfunction


function int barrett_logt0(input barrett_params_t params);
    barrett_logt0 = mac_std_dual_32x34_logc(barrett_mac_0_params(params));;
endfunction


function int barrett_mac_0_lat(input barrett_params_t params);
    barrett_mac_0_lat = mac_std_dual_32x34_lat(barrett_mac_0_params(params));
endfunction


function int barrett_ff_out_1(input barrett_params_t params);
    barrett_ff_out_1 = 1;
endfunction


function mac_std_dual_32x34_params_t barrett_mac_1_params(input barrett_params_t params);
    barrett_mac_1_params = '{LOGB : params.LOGQ + 2, MODE_E : SUB_E, FF_IN_A: params.FF_SHF,  FF_IN_B: params.FF_SHF,
                             FF_IN_E: params.FF_SHF, FF_MUL : params.FF_MUL, FF_OUT : barrett_ff_out_1(params)};
endfunction


function int barrett_logt1(input barrett_params_t params);
    barrett_logt1 = mac_std_dual_32x34_logc(barrett_mac_1_params(params));
endfunction


function int barrett_mac_1_lat(input barrett_params_t params);
    barrett_mac_1_lat = mac_std_dual_32x34_lat(barrett_mac_1_params(params));
endfunction


function int barrett_lat(input barrett_params_t params);
    barrett_lat = params.FF_IN + barrett_mac_0_lat(params) + barrett_mac_1_lat(params) + params.FF_OUT;
endfunction


`endif