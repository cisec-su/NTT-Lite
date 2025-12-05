`ifndef KARATSUBA_64x64_DUAL_H
`define KARATSUBA_64x64_DUAL_H


typedef struct packed {
    int FF_IN, FF_SUM0, FF_SUB0, FF_MUL, FF_SUM1, FF_SUM2, FF_SUB1, FF_OUT;
} karatsuba_64x64_dual_params_t;


function int karatsuba_64x64_dual_lat(input karatsuba_64x64_dual_params_t params);
    karatsuba_64x64_dual_lat = (params.FF_IN + params.FF_SUM0 + params.FF_SUB0 + params.FF_MUL + params.FF_SUM1 + params.FF_SUM2 + params.FF_SUB1 + params.FF_OUT);
endfunction


`endif