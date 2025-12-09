`timescale 1ns/1ps

module modem_ctrl(
    input  wire        clk,
    input  wire        resetn,

    // APB register writes
    input  wire        mcr_we,      // Write enable for MCR
    input  wire [7:0]  mcr_wdata,   // Data written to MCR

    // APB register reads
    output wire [7:0]  mcr_rdata,   // MCR read out
    output wire [7:0]  msr_rdata,   // MSR read out

    // External modem inputs
    input  wire        cts_i,
    input  wire        dsr_i,
    input  wire        ri_i,
    input  wire        dcd_i,

    // Outputs to UART core (RTS, DTR)
    output wire        rts_o,
    output wire        dtr_o,

    // Interrupt output
    output wire        modem_status_int
);

    // 1. Modem Control Register (MCR)
    
    // Bit 0 - DTR
    // Bit 1 - RTS
    // Bit 2 - OUT1
    // Bit 3 - OUT2
    // Bit 4 - Loopback enable (optional)
    reg [7:0] MCR;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            MCR <= 8'h00;
        else if (mcr_we)
            MCR <= mcr_wdata;
    end

    assign mcr_rdata = MCR;

    assign dtr_o = MCR[0];
    assign rts_o = MCR[1];

    // 2. Modem Status Register (MSR)
   
    // Bit 0 - ΔCTS (CTS changed)
    // Bit 1 - ΔDSR
    // Bit 2 - TERI (RI toggled from high to low)
    // Bit 3 - ΔDCD
    // Bit 4 - CTS
    // Bit 5 - DSR
    // Bit 6 - RI
    // Bit 7 - DCD

    reg cts_d, dsr_d, ri_d, dcd_d;
    reg [7:0] MSR;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cts_d <= 0; dsr_d <= 0; ri_d <= 0; dcd_d <= 0;
            MSR <= 8'h00;
        end else begin
            cts_d <= cts_i;
            dsr_d <= dsr_i;
            ri_d  <= ri_i;
            dcd_d <= dcd_i;

            MSR[0] <= (cts_i != cts_d);  // ΔCTS
            MSR[1] <= (dsr_i != dsr_d);  // ΔDSR
            MSR[2] <= (ri_d & ~ri_i);    // TERI (falling edge of RI)
            MSR[3] <= (dcd_i != dcd_d);  // ΔDCD

            MSR[4] <= cts_i;
            MSR[5] <= dsr_i;
            MSR[6] <= ri_i;
            MSR[7] <= dcd_i;
        end
    end

    assign msr_rdata = MSR;

    // 3. Interrupt Generation

    // Interrupt occurs when any delta bit is set:
    assign modem_status_int = (MSR[3:0] != 4'b0000);

endmodule