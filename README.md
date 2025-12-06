# UART
UART-16550A – APB-Based UART Core

A synthesizable Verilog implementation of a UART inspired by the classic 16550A. Includes APB interface, FIFO buffering, TX/RX state machines, interrupts, modem control, and programmable baud rate.

Features

APB3-Lite Interface

16× Baud Rate Generator

TX & RX FSM-Based Modules

16-byte TX/RX FIFOs

Interrupt Controller (IIR/IER)

Line Control (LCR), FIFO Control (FCR)

Modem Signals: CTS, RTS, DSR, DTR, RI, DCD

DLAB support for DLL/DLM baud registers

Block Diagram Includes

APB Register File

Baud Generator

TX/RX FIFOs

TX/RX FSM

Interrupt Logic

Modem Control Unit
