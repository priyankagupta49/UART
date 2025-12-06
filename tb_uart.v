`timescale 1ns/1ps
module tb();
    reg clk=0;
    reg rstn=0;
    always #10 clk = ~clk; // 50MHz

    // APB wires
    reg psel=0, penable=0, pwrite=0;
    reg [7:0] paddr=0;
    reg [31:0] pwdata=0;
    reg [3:0] pstrb=4'b0001;
    wire [31:0] prdata;
    wire pready;
    wire pslverr;

    wire int_o;
    reg srx=1;

    uart_top uut (
        .pclk(clk),
        .presetn(rstn),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .pstrb(pstrb),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .int_o(int_o), .stx_pad_o(), .srx_pad_i(srx),
        .cts_pad_i(1'b1), .dsr_pad_i(1'b1), .ri_pad_i(1'b1), .dcd_pad_i(1'b1),
        .rts_pad_o(), .dtr_pad_o(), .baud_o()
    );

    initial begin
        rstn = 0; #100; rstn = 1;
        // example write to divisor
        @(posedge clk);
        // write LCR to set DLAB=1
        psel=1; pwrite=1; paddr=8'h03; pwdata={24'h0,8'h80}; penable=0; #20;
        psel=0; penable=0; pwrite=0;
        @(posedge clk);
        // write DLL
        psel=1; pwrite=1; paddr=8'h08; pwdata={24'h0,8'd4}; pstrb=4'b0001; #20;
        psel=0;
        @(posedge clk);
        $display("Testbench complete"); #1000; $finish;
    end
endmodule
