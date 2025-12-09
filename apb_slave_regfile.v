`timescale 1ns/1ps

module apb_if (
    input  wire        pclk,
    input  wire        presetn,

    // APB interface signals
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [7:0]  paddr,
    input  wire [7:0]  pwdata,
    output reg  [7:0]  prdata,

    // Register outputs to UART blocks
    output reg  [7:0]  LCR, MCR, IER, FCR,
    input  wire [7:0]  LSR, MSR, IIR,

    // FIFO & baud generator
    output reg         thr_we,
    output reg         dll_we,
    output reg         dlm_we,

    output wire [7:0]  thr_wdata,
    input  wire [7:0]  rbr_rdata,

    // MCR write strobe for modem block
    output wire        mcr_we,
    output wire [7:0]  mcr_wdata
);

    
    // Internal
    
    wire write = psel && penable && pwrite;
    wire read  = psel && !pwrite;

    reg [7:0] SCR;

   
    // Default
    
    assign thr_wdata = pwdata;

    assign mcr_we    = write && (paddr == 8'h04);
    assign mcr_wdata = pwdata;

    
    // Write Logic
    
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            LCR <= 0; MCR <= 0; IER <= 0; FCR <= 0;
            SCR <= 0;
            dll_we <= 0;
            dlm_we <= 0;
            thr_we <= 0;
        end else begin
            thr_we <= 0;
            dll_we <= 0;
            dlm_we <= 0;

            if (write) begin
                case (paddr)
                    8'h00: begin
                        if (LCR[7])  // DLAB = 1
                            dll_we <= 1;
                        else
                            thr_we <= 1;   // THR
                    end

                    8'h01: begin
                        if (LCR[7])
                            dlm_we <= 1;   // DLM
                        else
                            IER <= pwdata;
                    end

                    8'h02: FCR <= pwdata;  // FCR

                    8'h03: LCR <= pwdata;  // LCR
                    8'h04: MCR <= pwdata;  // MCR
                    8'h07: SCR <= pwdata;  // Scratch Reg
                endcase
            end
        end
    end

    
    // Read Logic
   
    always @(*) begin
        prdata = 8'h00;

        if (read) begin
            case (paddr)
                8'h00: prdata = (LCR[7] ? rbr_rdata : rbr_rdata);  // RBR
                8'h01: prdata = IER;
                8'h02: prdata = IIR;
                8'h03: prdata = LCR;
                8'h04: prdata = MCR;
                8'h05: prdata = LSR;
                8'h06: prdata = MSR;
                8'h07: prdata = SCR;
            endcase
        end
    end

endmodule