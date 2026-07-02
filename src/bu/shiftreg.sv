
module shiftreg 
  #(
        parameter int unsigned SHIFT = 0 , 
        parameter int unsigned DATA  = 32,
        parameter bit          EN_OR  = 0
   )
   (
        input             clk     ,
        input             rst     ,
        input  [DATA-1:0] data_in ,
        output [DATA-1:0] data_out,
        output reg        data_or
    );

if (SHIFT > 0) begin
    reg [DATA-1:0] shift_array [SHIFT-1:0];

    for(genvar shft = 0; shft < SHIFT; shft = shft + 1) begin: DELAY_BLOCK
        always @(posedge clk) begin
            if (rst)
                shift_array[shft] <= 0;
            else
                shift_array[shft] <= (shft == 0) ? data_in : shift_array[shft - 1];
        end
    end

    assign data_out = shift_array[SHIFT - 1];
    always @(*) begin
        if (EN_OR) begin
            data_or = 0;
            for (int i = 0; i < SHIFT; i++) begin
                data_or = data_or | shift_array[i];
            end
        end
    end
end
else begin
    assign data_out = data_in;
    if (EN_OR) begin
        assign data_or = data_in;
    end
end

endmodule
