// sync_fifo.v
`timescale 1ns/1ps
module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    input  wire                   clk,
    input  wire                   resetn,
    input  wire                   wr_en,
    input  wire [WIDTH-1:0]       din,
    input  wire                   rd_en,
    output reg  [WIDTH-1:0]       dout,
    output wire                   full,
    output wire                   empty,
    output reg  [$clog2(DEPTH+1)-1:0] count
);
    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    integer i;
    initial begin
        for (i=0; i<DEPTH; i=i+1) mem[i] = {WIDTH{1'b0}};
        wr_ptr = 0;
        rd_ptr = 0;
        count = 0;
        dout = 0;
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
            dout <= 0;
        end else begin
            // write
            if (wr_en && (count != DEPTH)) begin
                mem[wr_ptr] <= din;
                wr_ptr <= wr_ptr + 1'b1;
                count <= count + 1'b1;
            end
            // read
            if (rd_en && (count != 0)) begin
                dout <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1'b1;
                count <= count - 1'b1;
            end
        end
    end

    assign full = (count == DEPTH);
    assign empty = (count == 0);

endmodule
