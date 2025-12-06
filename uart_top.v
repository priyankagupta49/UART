
`timescale 1ns/1ps
module uart_top #(
    parameter SYS_CLK_FREQ = 50_000_000,
    parameter FIFO_DEPTH = 16
)(
    input  wire        pclk,
    input  wire        presetn, // active low
    // APB3-lite-like (byte-granular). This simple wrapper assumes APB single-cycle ready.
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [7:0]  paddr,
    input  wire [31:0] pwdata,
    input  wire [3:0]  pstrb,
    output reg  [31:0] prdata,
    output reg         pready,
    output reg         pslverr,
    // interrupt
    output wire        int_o,
    // serial
    output wire        stx_pad_o,
    input  wire        srx_pad_i,
    // modem (basic)
    input  wire        cts_pad_i,
    input  wire        dsr_pad_i,
    input  wire        ri_pad_i,
    input  wire        dcd_pad_i,
    output wire        rts_pad_o,
    output wire        dtr_pad_o,
    // optional test output
    output wire        baud_o
);
    // local params
    localparam CNT_WIDTH = $clog2(FIFO_DEPTH+1); // enough to represent 0..DEPTH

    // registers
    reg [7:0] IER; // interrupt enable
    reg [7:0] FCR; // FIFO control (bits: bit0 FIFO enable, bits1-2 rx trigger, bit2 tx reset, bit1 rx reset)
    reg [7:0] LCR; // line control (bit7 = DLAB)
    reg [7:0] MCR;
    reg [7:0] MSR_reg;
    reg [7:0] LSR_reg;
    reg [7:0] dll; // DLL (LSB)
    reg [7:0] dlm; // DLM (MSB)

    // wires for FIFOs
    wire tx_fifo_wr;
    wire tx_fifo_full;
    wire tx_fifo_rd;
    wire tx_fifo_empty;
    wire [7:0] tx_fifo_dout;
    wire [CNT_WIDTH-1:0] tx_count;

    wire rx_fifo_wr;
    wire rx_fifo_full;
    wire rx_fifo_rd;
    wire rx_fifo_empty;
    wire [7:0] rx_fifo_din;
    wire [7:0] rx_fifo_dout;
    wire [CNT_WIDTH-1:0] rx_count;

    // Baud generator
    wire baud16_tick;
    wire baud_out;
    wire [15:0] divisor;
    assign divisor = {dlm, dll}; // 16-bit divisor = clock/(baud*16)
    baud_gen baud_i (
        .clk(pclk),
        .resetn(presetn),
        .divisor(divisor),
        .baud16_tick(baud16_tick),
        .baud_out(baud_out)
    );
    assign baud_o = baud_out;

    // instantiate FIFOs
    sync_fifo #(.WIDTH(8), .DEPTH(FIFO_DEPTH)) txfifo (
        .clk(pclk), .resetn(presetn),
        .wr_en(tx_fifo_wr), .din(pwdata[7:0]),
        .rd_en(tx_fifo_rd), .dout(tx_fifo_dout),
        .full(tx_fifo_full), .empty(tx_fifo_empty),
        .count(tx_count)
    );

    sync_fifo #(.WIDTH(8), .DEPTH(FIFO_DEPTH)) rxfifo (
        .clk(pclk), .resetn(presetn),
        .wr_en(rx_fifo_wr), .din(rx_fifo_din),
        .rd_en(rx_fifo_rd), .dout(rx_fifo_dout),
        .full(rx_fifo_full), .empty(rx_fifo_empty),
        .count(rx_count)
    );

    // UART core
    wire tx_busy;
    wire tx_rd;
    uart_tx #(.OVERSAMPLE(16)) txcore (
        .clk(pclk),
        .resetn(presetn),
        .baud16_tick(baud16_tick),
        .data_in(tx_fifo_dout),
        .data_valid(!tx_fifo_empty),
        .rd_en(tx_rd),
        .stx(stx_pad_o),
        .busy(tx_busy)
    );
    assign tx_fifo_rd = tx_rd;

    wire rx_data_valid;
    wire [7:0] rx_data;
    uart_rx #(.OVERSAMPLE(16)) rxcore (
        .clk(pclk),
        .resetn(presetn),
        .baud16_tick(baud16_tick),
        .srx(srx_pad_i),
        .data_out(rx_data),
        .data_valid(rx_data_valid)
    );
    assign rx_fifo_din = rx_data;
    // write to RX FIFO if data_valid and FIFO not full
    assign rx_fifo_wr = rx_data_valid && !rx_fifo_full;

    // LSR/MSR generation (read-only registers)
    // LSR bits simplified: bit0 Data Ready (DR), bit5 THR Empty (THRE), bit6 TEMT (transmitter empty)
    always @(*) begin
        LSR_reg = 8'h00;
        LSR_reg[0] = (rx_count != 0);         // DR
        LSR_reg[5] = (tx_fifo_empty && !tx_busy); // THRE
        LSR_reg[6] = (tx_fifo_empty && !tx_busy); // TEMT (same simplified)
    end

    always @(*) begin
        // MSR basic reflect levels (no delta tracking in this mid-level impl)
        MSR_reg = 8'h00;
        MSR_reg[0] = cts_pad_i; // CTS
        MSR_reg[1] = dsr_pad_i; // DSR
        MSR_reg[2] = ri_pad_i;  // RI
        MSR_reg[3] = dcd_pad_i; // DCD
    end

    // interrupt logic
    wire irq_tx_empty;
    wire irq_rx_data;
    wire irq_timeout;
    wire [7:0] IIR; // driven by int_logic (read-only)
    assign irq_tx_empty = (tx_fifo_empty && !tx_busy);
    // rx_data available when count >= trigger or count !=0 depending on trigger selection
    // decode trigger from FCR bits [7:6] (we will use bits [7:6] to represent trigger: 00=1,01=4,10=8,11=14)
    wire [1:0] rx_trig_sel = FCR[7:6];
    wire [CNT_WIDTH-1:0] rx_trigger_level;
    assign rx_trigger_level = (rx_trig_sel == 2'b00) ? 1 :
                              (rx_trig_sel == 2'b01) ? 4 :
                              (rx_trig_sel == 2'b10) ? 8 : 14;
    assign irq_rx_data = (rx_count >= rx_trigger_level);

    int_logic intcore (
        .clk(pclk),
        .resetn(presetn),
        .ier(IER),
        .irq_tx_empty(irq_tx_empty),
        .irq_rx_data(irq_rx_data),
        .rx_fifo_count(rx_count),
        .rx_activity_tick(rx_data_valid), // activity when a byte arrives
        .irq_out(int_o),
        .iir(IIR)
    );

    // APB read/write behavior (simple single-cycle pready)
    // Implement DLAB: when LCR[7]==1, addresses 0 and 1 map to DLL and DLM
    // Write to THR pushes to tx FIFO (if FIFO enabled via FCR[0])
    // Read from RBR pops RX FIFO (rx_fifo_rd asserted on read)

    // APB write strobes detection (byte 0 only used)
    wire apb_write_byte0 = psel && !penable && pwrite && pstrb[0];

    // map register addresses
    // 0x00: RBR(read) / THR(write)
    // 0x01: IER
    // 0x02: IIR(read) / FCR(write)
    // 0x03: LCR
    // 0x04: MCR
    // 0x05: LSR (read)
    // 0x06: MSR (read)
    // 0x08: DLL (when DLAB=1)
    // 0x09: DLM (when DLAB=1)
    reg rx_read_pending;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            IER <= 8'h00;
            FCR <= 8'h00;
            LCR <= 8'h03; // default 8N1, DLAB=0
            MCR <= 8'h00;
            dll <= 8'h00;
            dlm <= 8'h00;
            pready <= 1'b0;
            prdata <= 32'h0;
            pslverr <= 1'b0;
            rx_read_pending <= 1'b0;
        end else begin
            pready <= 1'b0;
            pslverr <= 1'b0;
            rx_read_pending <= 1'b0;
            if (psel && !penable && pwrite) begin
                // write phase
                case (paddr[7:0])
                    8'h00: begin
                        if (!LCR[7]) begin // DLAB==0 -> THR
                            if (FCR[0]) begin // FIFO enabled
                                if (!tx_fifo_full) begin
                                    // txfifo write done by combinational tx_fifo_wr
                                    // the txfifo takes pwdata[7:0] as din in instance
                                end
                            end
                        end
                    end
                    8'h01: IER <= pwdata[7:0];
                    8'h02: begin
                        // FCR write: bit0 FIFO enable, bit1 rx reset, bit2 tx reset, bits7-6 trigger
                        FCR <= pwdata[7:0];
                        // if reset bits asserted, FIFO core must be reset - our sync_fifo supports resetn only,
                        // so to implement reset we could add a reinit signal. For mid-level, we use reset sequence:
                        // (If bit1 or bit2 set, not implemented as immediate reset - user can toggle global reset.)
                    end
                    8'h03: LCR <= pwdata[7:0];
                    8'h04: MCR <= pwdata[7:0];
                    8'h08: if (LCR[7]) dll <= pwdata[7:0];
                    8'h09: if (LCR[7]) dlm <= pwdata[7:0];
                    default: ;
                endcase
                pready <= 1'b1;
            end else if (psel && !penable && !pwrite) begin
                // read phase
                case (paddr[7:0])
                    8'h00: begin
                        if (!LCR[7]) begin
                            // read RBR: we'll present data from rx_fifo_dout and pop by asserting rx_fifo_rd for one cycle
                            prdata <= {24'h0, rx_fifo_dout};
                            rx_read_pending <= 1'b1;
                        end else begin
                            // DLAB=1 -> DLL read
                            prdata <= {24'h0, dll};
                        end
                    end
                    8'h01: prdata <= {24'h0, IER};
                    8'h02: prdata <= {24'h0, IIR};
                    8'h03: prdata <= {24'h0, LCR};
                    8'h04: prdata <= {24'h0, MCR};
                    8'h05: prdata <= {24'h0, LSR_reg};
                    8'h06: prdata <= {24'h0, MSR_reg};
                    8'h08: if (LCR[7]) prdata <= {24'h0, dll};
                    8'h09: if (LCR[7]) prdata <= {24'h0, dlm};
                    8'h10: prdata <= {{(32-CNT_WIDTH){1'b0}}, rx_count}; // rx count in low bits
                    default: prdata <= 32'h0;
                endcase
                pready <= 1'b1;
            end
        end
    end

    // generate rx_fifo_rd one cycle when reading RBR
    assign rx_fifo_rd = (psel && !penable && !pwrite && (paddr[7:0]==8'h00) && !LCR[7] && pstrb[0]);

    // TX FIFO write strobe
    assign tx_fifo_wr = (psel && !penable && pwrite && (paddr[7:0]==8'h00) && !LCR[7] && pstrb[0] && FCR[0]);

    // modem outputs
    assign rts_pad_o = MCR[1]; // example: bit1 RTS
    assign dtr_pad_o = MCR[0]; // example: bit0 DTR

endmodule
