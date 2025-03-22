`ifndef INTMUL_STD_DUAL_64x34_H
`define INTMUL_STD_DUAL_64x34_H


typedef struct packed {
    int FF_IN_A, FF_IN_B, FF_IN_E, FF_MUL, FF_OUT;
} intmul_std_dual_64x34_params_t;


function int intmul_std_dual_64x34_lat(input intmul_std_dual_64x34_params_t params);
    intmul_std_dual_64x34_lat = (params.FF_IN_A || params.FF_IN_B) + params.FF_MUL + params.FF_OUT;
endfunction


function int intmul_std_dual_64x34_loga0(input intmul_std_dual_64x34_params_t params);
    intmul_std_dual_64x34_loga0 = 32;
endfunction


function int intmul_std_dual_64x34_logb0(input intmul_std_dual_64x34_params_t params);
    intmul_std_dual_64x34_logb0 = 17;
endfunction


function int intmul_std_dual_64x34_loga(input intmul_std_dual_64x34_params_t params);
    intmul_std_dual_64x34_loga = intmul_std_dual_64x34_loga0(params) << 1;
endfunction


function int intmul_std_dual_64x34_logb(input intmul_std_dual_64x34_params_t params);
    intmul_std_dual_64x34_logb = intmul_std_dual_64x34_logb0(params) << 1;
endfunction


function int intmul_std_dual_64x34_logc0(input intmul_std_dual_64x34_params_t params);
    intmul_std_dual_64x34_logc0 = intmul_std_dual_64x34_loga0(params) + intmul_std_dual_64x34_logb0(params);
endfunction


function int intmul_std_dual_64x34_logc(input intmul_std_dual_64x34_params_t params);
    intmul_std_dual_64x34_logc = intmul_std_dual_64x34_logc0(params) << 1;
endfunction


`endif