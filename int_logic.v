// int_logic.v
`timescale 1ns/1ps
module int_logic (
    input  wire        clk,
    input  wire        resetn,
    input  wire [7:0]  ier, // bits: bit0 RX data avail, bit1 THR empty, bit7 timeout enable
    input  wire        irq_tx_empty,
    input  wire        irq_rx_data,
    input  wire [31:0] rx_fifo_count, // but we will pass small width; unused in this mid-level impl
    input  wire        rx_activity_tick, // pulse when a byte arrives
    output reg         irq_out,
    output reg  [7:0]  iir // simple code: 0x01 no int, 0x02 THRE, 0x04 RX, 0x06 TIMEOUT
);
    // Timeout logic
    reg [15:0] timeout_cnt;
    reg timeout_flag;
    parameter TIMEOUT_TICKS = 2000; // configurable threshold (depends on system clock)
    // priority: line-status (not implemented), RX data/timeout, THRE

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            timeout_cnt <= 0;
            timeout_flag <= 1'b0;
            irq_out <= 1'b0;
            iir <= 8'h01;
        end else begin
            // timeout: reset on activity
            if (rx_activity_tick) begin
                timeout_cnt <= 0;
                timeout_flag <= 1'b0;
            end else begin
                if (timeout_cnt < 16'hFFFF) timeout_cnt <= timeout_cnt + 1'b1;
                if (timeout_cnt >= TIMEOUT_TICKS) timeout_flag <= 1'b1;
            end

            // decide interrupt
            irq_out <= 1'b0;
            iir <= 8'h01; // default no interrupt pending

            // RX data or timeout (priority higher than THRE)
            if ((irq_rx_data && ier[0]) || (timeout_flag && ier[7])) begin
                irq_out <= 1'b1;
                if (timeout_flag && ier[7]) iir <= 8'h06; // timeout code
                else iir <= 8'h04; // RX data available
            end else if (irq_tx_empty && ier[1]) begin
                irq_out <= 1'b1;
                iir <= 8'h02; // THR empty
            end else begin
                irq_out <= 1'b0;
                iir <= 8'h01;
            end
        end
    end
endmodule
