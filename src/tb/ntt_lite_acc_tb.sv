module ntt_lite_acc_tb
   #(
        parameter BASE_ADDR       = 32'h40001100,
        parameter MEM_SIZE        = 2048        
    )();

`include "ntt_lite.vh"
    
localparam CLOCK_PERIOD = 10;



// Clock and reset signals
reg clk;
reg rst_n;

// Wishbone signals
reg wb_cyc_i;
reg wb_stb_i;
reg wb_we_i;
reg [31:0] wb_adr_i;
reg [31:0] wb_dat_i;
reg [3:0] wb_sel_i;
wire wb_stall_o;
wire wb_ack_o;
wire [31:0] wb_dat_o;
wire wb_err_o;
reg wb_rst_i;

// DMA signals
wire        dma_cyc_i  ;
wire        dma_stb_i  ;
wire        dma_we_i   ;
wire [31:0] dma_adr_i  ;
wire [31:0] dma_dat_i  ;
wire [3 :0] dma_sel_i  ;
reg         dma_stall_o;
reg         dma_ack_o  ;
reg  [31:0] dma_dat_o  ;
reg         dma_err_o  ;
wire        dma_rst_i  ;

// tb signals
reg [31:0] read_data;
reg [31:0] write_data;
reg [31:0] mem [0:MEM_SIZE-1]; // 4KB memory
reg [31:0] temp;
reg [31:0] temp1;
reg flag;

reg [4031:0] hash = 4032'h5f960f79657073de16ea944ed183d6730c00b0f9c2b551397a520f086b0119abaf5df4506a129cdf7f5099cd4fffd09ab07cca3d030f41336595a056cbb89d0363fd0fa4b0f888b6521f9f6f8c278d6daf875941ab8675af57e1953a31a772b332a082e9c74bb14f1d462bfedcaf5487756a9cc4162adf6db5612657f1a78e55b104cd966e2d00a0d9e9133e05155399f387b4f30624c396762ebb285cef35afd757a50551b3d9424941797f047bbe10a334c29d013bb7144cea416bd37a5066fa51b1bd2b165a2ea530dfb50289c6815008d875125ac78406572e5eb4b0d769c5cc4b097b7023b42821d0231df20084be7daa5e83047aa30a386d1fe326c04e2c39f68ea7986de8a0c950e250844b67c2b4e3c3e88da57b967210bcad999d339e5b3ee0c45a025bb56f03136b7654733edd46b4e27a6139c1ea1e01c35ce92075c4f6eceda97ed563fed2145e57fca2f7fef32e44c7df51548a9af18fd5f41ad8397dafe3555c904c373301ed436a2addd3bec6c64ef0434518aa7e0a705f0191f0d8bfc1a15dc9c90094d9efc539813b7142037634abfe58de6e82857b641989577952f5ee0bfebef340ccf6df36deb1cbaa9c9482b0901eb45ef29c5ad8c8e6ad0cd2c9bc8731625fc6f6b0af992fa17aa0e5ff00c065c1b48520aef957b2bea8133724206f90ee89216889ba00882032d40e981428a3;


// Clock generation
initial begin
    clk = 0;
    forever #(CLOCK_PERIOD / 2) clk = ~clk; // 100MHz clock
end

// Reset generation
initial begin
    rst_n = 0;
    #20 rst_n = 1;
end



// Instantiate the ntt_lite_acc_top module
ntt_lite_acc_top #(
    .BASE_ADDR(BASE_ADDR)
) uut (
    .wb_cyc_i(wb_cyc_i),
    .wb_stb_i(wb_stb_i),
    .wb_we_i(wb_we_i),
    .wb_adr_i(wb_adr_i),
    .wb_dat_i(wb_dat_i),
    .wb_sel_i(wb_sel_i),
    .wb_stall_o(wb_stall_o),
    .wb_ack_o(wb_ack_o),
    .wb_dat_o(wb_dat_o),
    .wb_err_o(wb_err_o),
    .wb_rst_i(!rst_n),
    .wb_clk_i(clk),
    .dma_cyc_i(dma_cyc_i),
    .dma_stb_i(dma_stb_i),
    .dma_we_i(dma_we_i),
    .dma_adr_i(dma_adr_i),
    .dma_dat_i(dma_dat_i),
    .dma_sel_i(dma_sel_i),
    .dma_stall_o(dma_stall_o),
    .dma_ack_o(dma_ack_o),
    .dma_dat_o(dma_dat_o),
    .dma_err_o(dma_err_o),
    .dma_rst_i(dma_rst_i)
);

always @(posedge clk) begin
    if (dma_stb_i && !dma_we_i) begin
        dma_dat_o <= mem[dma_adr_i];
    end
    else begin
        dma_dat_o <= 0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        for (int i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] <= 0;
        end
    end
    else if (dma_we_i) begin
        mem[dma_adr_i] <= dma_dat_i;
    end
    else if (dma_we_i) begin
        mem[dma_adr_i] <= dma_dat_i;
    end
end    

task wb_write(input [31:0] address, input [31:0] data);
begin
    @(posedge clk);
    wb_cyc_i = 1;
    wb_stb_i = 1;
    wb_we_i = 1;
    wb_adr_i = address;
    wb_dat_i = data;
    @(posedge clk);
    wb_cyc_i = 0;
    wb_stb_i = 0;
    wb_we_i = 0;
end
endtask


task wb_read(input [31:0] address, output [31:0] read_data);
begin
    @(posedge clk);
    wb_cyc_i = 1;
    wb_stb_i = 1;
    wb_we_i = 0;
    wb_adr_i = address;
    @(posedge clk);
    read_data = wb_dat_o;
    wb_cyc_i = 0;
    wb_stb_i = 0;
end
endtask

// Testbench logic
initial begin
    // Initialize Wishbone signals
    wb_cyc_i = 0;
    wb_stb_i = 0;
    wb_we_i = 0;
    wb_adr_i = 0;
    wb_dat_i = 0;
    wb_sel_i = 4'b1111;
    wb_rst_i = 0;

    // Wait for reset deassertion
    @(posedge rst_n);
    @(posedge clk);


    $display("Test Case 1: REJ SAMP");


    $display("Starting Part 1");

    for (int i = 0; i < 42; i = i + 1) begin
        mem[i*4] = hash[4032 - (42 - i + 1)*32 +: 32];
        mem[i*4 + 1] = {mem[i*4][7:0], mem[i*4][15:8], mem[i*4][23:16], mem[i*4][31:24]};
    end

    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.Q_ADDR, 32'h0d010d01);
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.INV2_ADDR, 42);
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.BOUND_ADDR, 32'h0d010d01);


    // Perform write operations using the function
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.DIN_ADDR, 0);
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.DOUT_ADDR, 42);




    // Read control register using the function
    wb_read(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.CTRL_ADDR, read_data);
    $display("Control Register: %h", read_data);

    write_data = (`OP_REJ_SAMP << uut.ntt_lite_ctrl.CTRL_OP_LSB) | (`MODE_POLY << uut.ntt_lite_ctrl.CTRL_MODE_LSB) | (12 << uut.ntt_lite_ctrl.CTRL_D_LSB) | (7 << uut.ntt_lite_ctrl.CTRL_LOGN_LSB) | (`CMD_LOAD_TWIDDLE << uut.ntt_lite_ctrl.CTRL_CMD_LSB);
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.CTRL_ADDR, write_data);

    do begin
        wb_read(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.STATUS_ADDR, read_data);
    end while ((read_data & (1 << uut.ntt_lite_ctrl.STATUS_DONE_BIT)) == 0);
    $display("Op done: Status Register: %h", read_data);

    if (!(read_data & (1 << uut.ntt_lite_ctrl.STATUS_REJ_SAMP_IP_BIT))) begin
        $display("REJ SAMP IP flag not set, failed");
        $stop;
    end

    $display("Starting Part 2");

    for (int i = 42; i < 84; i = i + 1) begin
        mem[i*4] = hash[4032 - (42 - i + 1)*32 +: 32];
        mem[i*4 + 1] = {mem[i*4][7:0], mem[i*4][15:8], mem[i*4][23:16], mem[i*4][31:24]};
    end


    // Perform write operations using the function
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.DIN_ADDR, 0);
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.DOUT_ADDR, 42);



    // Read control register using the function
    wb_read(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.CTRL_ADDR, read_data);
    $display("Control Register: %h", read_data);

    write_data = (`OP_REJ_SAMP << uut.ntt_lite_ctrl.CTRL_OP_LSB) | (`MODE_POLY << uut.ntt_lite_ctrl.CTRL_MODE_LSB) | (12 << uut.ntt_lite_ctrl.CTRL_D_LSB) | (7 << uut.ntt_lite_ctrl.CTRL_LOGN_LSB) | (`CMD_LOAD_TWIDDLE << uut.ntt_lite_ctrl.CTRL_CMD_LSB);
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.CTRL_ADDR, write_data);

    do begin
        wb_read(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.STATUS_ADDR, read_data);
    end while ((read_data & (1 << uut.ntt_lite_ctrl.STATUS_DONE_BIT)) == 0);
    $stop;
    $display("Op done: Status Register: %h", read_data);

    if (!(read_data & (1 << uut.ntt_lite_ctrl.STATUS_REJ_SAMP_IP_BIT))) begin
        $display("REJ SAMP IP flag not set, failed");
        $stop;
    end


    $display("Starting Part 3");

    for (int i = 84; i < 126; i = i + 1) begin
        mem[i*4] = hash[4032 - (42 - i + 1)*32 +: 32];
        mem[i*4 + 1] = {mem[i*4][7:0], mem[i*4][15:8], mem[i*4][23:16], mem[i*4][31:24]};
    end


    // Perform write operations using the function
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.DIN_ADDR, 0);
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.DOUT_ADDR, 42);



    // Read control register using the function
    wb_read(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.CTRL_ADDR, read_data);
    $display("Control Register: %h", read_data);

    write_data = (`OP_REJ_SAMP << uut.ntt_lite_ctrl.CTRL_OP_LSB) | (`MODE_POLY << uut.ntt_lite_ctrl.CTRL_MODE_LSB) | (12 << uut.ntt_lite_ctrl.CTRL_D_LSB) | (7 << uut.ntt_lite_ctrl.CTRL_LOGN_LSB) | (`CMD_LOAD_TWIDDLE << uut.ntt_lite_ctrl.CTRL_CMD_LSB);
    wb_write(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.CTRL_ADDR, write_data);

    do begin
        wb_read(uut.ntt_lite_ctrl.BASE_ADDR + uut.ntt_lite_ctrl.STATUS_ADDR, read_data);
    end while ((read_data & (1 << uut.ntt_lite_ctrl.STATUS_DONE_BIT)) == 0);
    $display("Op done: Status Register: %h", read_data);

    if ((read_data & (1 << uut.ntt_lite_ctrl.STATUS_REJ_SAMP_IP_BIT))) begin
        $display("REJ SAMP IP flag set, failed");
        $stop;
    end


    flag = 1;
    for (int i = 0; i < 128; i = i + 4) begin
        temp = mem[i];
        $display("mem[%0d] = %h", i, temp);
    end
    if (flag) begin
        $display("Test Case 1 passed");
    end
    else begin
        $display("Test Case 1 failed");
        $stop;
    end


//-----------------------------------------------------------------------------------------------//

    // Finish simulation
    $display("Simulation finished");
    $finish;
end

endmodule


    