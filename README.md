# UART
UART-16055A – APB-Based UART Core
A synthesizable Verilog UART inspired by the 16550A with APB interface, FIFOs, TX/RX FSMs, interrupts, modem control, and programmable baud rate.

Features:
1. APB3-Line Interface
2. 16× Baud Rate Generator
3. TX & RX FSM-based modules
4. 16-byte TX/RX FIFOs
5. Interrupt Controller (IIR/IER)
6. Line Control (LCR) & FIFO Control (FCR)
7. Modem Signals: CTS, RTS, DSR, DTR, RI, DCD
8. DLAB support for DLL/DLM baud registers
   

Block Diagram Includes:
1. APB Register File
2. Baud Generator
3. TX/RX FIFOs
4. TX/RX FSM
5. Interrupt Logic
6. Modem Control Unit
