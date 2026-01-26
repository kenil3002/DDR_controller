# DDR Controller – UART to DDR Read/Write System

## Problem Statement

**DDR Controller**

The objective of this project is to design a system that receives a continuous stream of data, writes it into DDR memory, and then reads back the same data from DDR to verify correctness and data integrity.

The data stream is received through a UART interface, internally buffered, packetized, and finally interfaced with DDR memory.

---

## Approach 1: UART Loopback System

### Description
The first approach focuses on validating basic data flow, FIFO operation, and clock domain handling using a UART loopback system.

### Implementation
- Designed UART RX and UART TX modules  
- Implemented synchronous FIFO and asynchronous FIFO  
- Combined UART RX → FIFO → UART TX to create a loopback system  
- Verified the design on **Trion 120 F324 FPGA**

### Result
- UART communication successfully verified  
- FIFO functionality validated  
- Clock domain crossing issues identified and resolved  

---

## Approach 2: Packetization (256-bit Data Formation)

### Description
This approach focuses on converting serial UART data into wide packets suitable for DDR access.

### Implementation
- UART RX receives 8-bit serial data  
- Data is stored in a FIFO with:
  - Width: 8 bits  
  - Depth: 32  
- When FIFO read enable is asserted:
  - A packetizer module combines 32 bytes  
  - Forms a single 256-bit data packet  
- Initial challenges included:
  - Multiple buses  
  - Data alignment issues  
- These issues were debugged and resolved

### Result
- Stable 256-bit packets generated  
- Data format prepared for DDR write operations  

---

## Approach 3: AXI-Based DDR Controller

### Description
The final approach introduces an AXI-based controller to interface the 256-bit packet data with DDR memory.

### Implementation
- Studied AXI protocol fundamentals  
- Designed AXI master logic supporting:
  - Write address, write data, and write response channels  
  - Read address and read data channels  
- Targeted a 256-bit wide AXI data bus  
- Integrated packetized data path with AXI controller logic

### Status
- AXI DDR controller under development  
- Focus on stable burst transfers and read-back verification  

---

## Target Hardware

- FPGA: **Efinix Trion 120**  
- Package: **F324**

---

## Key Learnings

- UART protocol implementation  
- Synchronous and asynchronous FIFO design  
- Clock domain crossing techniques  
- Data packetization (8-bit to 256-bit conversion)  
- AXI protocol fundamentals  
- DDR memory interfacing concepts  
- FPGA bring-up and on-board debugging  

---

## Author

**Kenil Faldu**
