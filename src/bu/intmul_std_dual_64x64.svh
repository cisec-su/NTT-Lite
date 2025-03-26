`ifndef INTMUL_STD_DUAL_64x64_H
`define INTMUL_STD_DUAL_64x64_H


typedef struct packed {
    int FF_IN_A, FF_IN_B, FF_MUL, FF_OUT;
} intmul_std_dual_64x64_params_t;


function int intmul_std_dual_64x64_lat(input intmul_std_dual_64x64_params_t params);
    intmul_std_dual_64x64_lat = (params.FF_IN_A || params.FF_IN_B) + params.FF_MUL + params.FF_OUT;
endfunction



`endif