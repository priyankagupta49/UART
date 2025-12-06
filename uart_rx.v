// uart_rx.v
`timescale 1ns/1ps
module uart_rx #(
    parameter OVERSAMPLE = 16
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        baud16_tick, // pulses at oversample rate
    input  wire        srx,
    output reg [7:0]   data_out,
    output reg         data_valid
);
    localparam S_IDLE = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA = 2'd2;
    localparam S_STOP = 2'd3;

    reg [1:0] state;
    reg [3:0] sample_cnt; // 0..OVERSAMPLE-1
    reg [3:0] bit_idx;
    reg [7:0] shift_reg;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= S_IDLE;
            sample_cnt <= 0;
            bit_idx <= 0;
            shift_reg <= 8'h00;
            data_out <= 8'h00;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0; // default clear
            if (baud16_tick) begin
                sample_cnt <= sample_cnt + 1'b1;
                case (state)
                    S_IDLE: begin
                        if (!srx) begin // start bit detected (line low)
                            state <= S_START;
                            sample_cnt <= 0;
                        end
                    end
                    S_START: begin
                        // wait for center of start bit (sample at OVERSAMPLE/2)
                        if (sample_cnt == (OVERSAMPLE/2 - 1)) begin
                            // validate still low
                            if (!srx) begin
                                state <= S_DATA;
                                sample_cnt <= 0;
                                bit_idx <= 0;
                            end else begin
                                // false start, go idle
                                state <= S_IDLE;
                            end
                        end
                    end
                    S_DATA: begin
                        // sample each bit at center
                        if (sample_cnt == OVERSAMPLE-1) begin
                            sample_cnt <= 0;
                            shift_reg[bit_idx] <= srx;
                            bit_idx <= bit_idx + 1'b1;
                            if (bit_idx == 7) begin
                                state <= S_STOP;
                            end
                        end
                    end
                    S_STOP: begin
                        if (sample_cnt == OVERSAMPLE-1) begin
                            // could check stop bit == 1 for framing error - omitted here
                            data_out <= shift_reg;
                            data_valid <= 1'b1;
                            state <= S_IDLE;
                        end
                    end
                    default: state <= S_IDLE;
                endcase
            end
        end
    end
endmodule
