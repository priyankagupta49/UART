// uart_tx.v
`timescale 1ns/1ps
module uart_tx #(
    parameter OVERSAMPLE = 16
)(
    input  wire         clk,
    input  wire         resetn,
    input  wire         baud16_tick, // pulses at oversample rate
    input  wire [7:0]   data_in,
    input  wire         data_valid,  // indicates FIFO has data
    output reg          rd_en,       // assert to pop FIFO
    output reg          stx,
    output reg          busy
);
    // states
    localparam S_IDLE = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA = 2'd2;
    localparam S_STOP = 2'd3;

    reg [1:0] state;
    reg [3:0] bit_idx; // upto 8
    reg [3:0] sample_cnt; // 0..OVERSAMPLE-1 (OVERSAMPLE=16 -> 0..15)
    reg [7:0] shift_reg;
    reg start_loading;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= S_IDLE;
            stx <= 1'b1; // idle high
            busy <= 1'b0;
            rd_en <= 1'b0;
            bit_idx <= 0;
            sample_cnt <= 0;
            shift_reg <= 8'h00;
            start_loading <= 1'b0;
        end else begin
            // default
            rd_en <= 1'b0;
            if (baud16_tick) begin
                sample_cnt <= sample_cnt + 1'b1;
                if (sample_cnt == OVERSAMPLE-1) begin
                    sample_cnt <= 0;
                    // bit boundary: shift/advance states on LSB of oversample cycle
                    case (state)
                        S_IDLE: begin
                            if (data_valid) begin
                                // load data
                                shift_reg <= data_in;
                                rd_en <= 1'b1; // pop FIFO this cycle
                                busy <= 1'b1;
                                stx <= 1'b0; // start bit
                                state <= S_DATA;
                                bit_idx <= 0;
                            end else begin
                                stx <= 1'b1;
                                busy <= 1'b0;
                            end
                        end
                        S_DATA: begin
                            // shift out LSB first
                            stx <= shift_reg[0];
                            shift_reg <= {1'b0, shift_reg[7:1]};
                            bit_idx <= bit_idx + 1'b1;
                            if (bit_idx == 7) begin
                                state <= S_STOP;
                                bit_idx <= 0;
                            end
                        end
                        S_STOP: begin
                            stx <= 1'b1; // stop bit
                            // After one stop bit, go to idle
                            state <= S_IDLE;
                            busy <= 1'b0;
                        end
                        default: state <= S_IDLE;
                    endcase
                end
            end
        end
    end
endmodule
