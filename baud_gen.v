// baud_gen.v
`timescale 1ns/1ps
module baud_gen (
    input  wire        clk,
    input  wire        resetn,
    input  wire [15:0] divisor,     // divisor = sys_clk / (baud*oversample)
    output reg         baud16_tick, // pulses at oversample rate (one tick per oversample)
    output reg         baud_out     // optional toggled signal at bit rate/2 (not used strictly)
);
    reg [15:0] cnt;
    reg togg;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cnt <= 16'd0;
            baud16_tick <= 1'b0;
            togg <= 1'b0;
            baud_out <= 1'b0;
        end else begin
            if (divisor == 16'd0) begin
                baud16_tick <= 1'b0;
            end else begin
                if (cnt == divisor-1) begin
                    cnt <= 16'd0;
                    baud16_tick <= 1'b1;
                    togg <= ~togg;
                    baud_out <= togg;
                end else begin
                    cnt <= cnt + 1'b1;
                    baud16_tick <= 1'b0;
                end
            end
        end
    end
endmodule
