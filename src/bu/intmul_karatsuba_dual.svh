`ifndef INTMUL_KARATSUBA_DUAL_H
`define INTMUL_KARATSUBA_DUAL_H


typedef struct packed {
    int FF_IN_A, FF_IN_B, FF_SUM, FF_MUL, FF_SUB, FF_OUT;
} intmul_karatsuba_dual_params_t;


function int intmul_karatsuba_dual_lat(input intmul_karatsuba_dual_params_t params);
    intmul_karatsuba_dual_lat = (params.FF_IN_A || params.FF_IN_B) + params.FF_SUM + params.FF_MUL + params.FF_SUB + params.FF_OUT;
endfunction


`endif