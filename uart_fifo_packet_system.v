`include "UART_TX.v"
`include "UART_RX.v"
`include "asynchronous_fifo.v"

module uart_fifo_packet_system(
    input wire i_uart_clk,        // UART TX/RX clock (same clock)
    input wire i_fifo_rclk,       // FIFO read clock
    input wire i_rst_n,           // Active low reset
    
    // UART TX Interface
    input wire i_tx_dv,           // TX data valid
    input wire [7:0] i_tx_byte,   // TX data byte
    output wire o_tx_active,      // TX active
    output wire o_tx_done,        // TX done
    
    // Packet Output Interface
    output reg [255:0] o_packet,  // 256-bit packet (32 bytes)
    output reg o_pkt_valid        // Packet valid flag
);

    // Internal wires
    wire uart_rx_serial;
    wire uart_rx_dv;
    wire [7:0] uart_rx_byte;
    
    wire fifo_full;
    wire fifo_empty;
    wire [7:0] fifo_data_out;
    
    // FIFO control signals
    reg fifo_ren;
    reg fifo_wen;
    
    // Packet building state machine
    reg [4:0] byte_count;         // Count 0-31 bytes
    reg [4:0] read_count;         // Separate counter for reads issued
    reg [255:0] packet_buffer;    // Temporary packet storage
    
    // State machine for reading from FIFO
    localparam IDLE = 3'b000;
    localparam WAIT_FULL = 3'b001;
    localparam START_READ = 3'b010;
    localparam READ_FIFO = 3'b011;
    localparam CAPTURE_LAST = 3'b100;
    localparam PACKET_DONE = 3'b101;
    
    reg [2:0] state;
    reg fifo_was_full;            // Edge detection for FIFO full
    
    //=======================================================
    // UART TX Instance
    //=======================================================
    UART_TX uart_tx_inst (
        .i_Clock(i_uart_clk),
        .i_Tx_DV(i_tx_dv),
        .i_Tx_Byte(i_tx_byte),
        .o_Tx_Active(o_tx_active),
        .o_Tx_Serial(uart_rx_serial),  // Connected to UART RX
        .o_Tx_Done(o_tx_done)
    );
    
    //=======================================================
    // UART RX Instance
    //=======================================================
    UART_RX uart_rx_inst (
        .i_Clock(i_uart_clk),
        .i_Rx_Serial(uart_rx_serial),
        .o_Rx_DV(uart_rx_dv),
        .o_Rx_Byte(uart_rx_byte)
    );
    
    //=======================================================
    // FIFO Write Enable Logic
    // Write to FIFO when UART RX has valid data
    //=======================================================
    always @(posedge i_uart_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            fifo_wen <= 1'b0;
        end else begin
            fifo_wen <= uart_rx_dv & ~fifo_full;
        end
    end
    
    //=======================================================
    // Asynchronous FIFO Instance
    //=======================================================
    asynchronous_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(8)
    ) async_fifo_inst (
        .wclk(i_uart_clk),
        .wrst_n(i_rst_n),
        .rclk(i_fifo_rclk),
        .rrst_n(i_rst_n),
        .w_en(fifo_wen),
        .r_en(fifo_ren),
        .data_in(uart_rx_byte),
        .data_out(fifo_data_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );
    
    //=======================================================
    // FIFO Full Edge Detection
    //=======================================================
    always @(posedge i_fifo_rclk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            fifo_was_full <= 1'b0;
        end else begin
            fifo_was_full <= fifo_full;
        end
    end
    
    wire fifo_full_edge = fifo_full & ~fifo_was_full;
    
    //=======================================================
    // Packet Building State Machine
    // Read from FIFO when it's full and build 256-bit packet
    //=======================================================
    always @(posedge i_fifo_rclk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= IDLE;
            byte_count <= 5'd0;
            read_count <= 5'd0;
            packet_buffer <= 256'd0;
            o_packet <= 256'd0;
            o_pkt_valid <= 1'b0;
            fifo_ren <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    o_pkt_valid <= 1'b0;
                    fifo_ren <= 1'b0;
                    byte_count <= 5'd0;
                    read_count <= 5'd0;
                    
                    if (fifo_full_edge) begin
                        state <= START_READ;
                    end
                end
                
                START_READ: begin
                    // Assert read enable for first read
                    fifo_ren <= 1'b1;
                    read_count <= 5'd0;  // Start at 0
                    byte_count <= 5'd0;
                    state <= READ_FIFO;
                end
                
                READ_FIFO: begin
                    // Increment read counter first (this read was issued)
                    read_count <= read_count + 1'b1;
                    
                    // Store data from PREVIOUS cycle's read (if not the very first entry)
                    if (read_count > 5'd0) begin
                        packet_buffer[(read_count-1)*8 +: 8] <= fifo_data_out;
                        byte_count <= byte_count + 1'b1;
                    end
                    
                    // Continue issuing reads until we've issued 32 reads (0-31)
                    if (read_count < 5'd31) begin
                        fifo_ren <= 1'b1;
                    end else begin
                        fifo_ren <= 1'b0;
                        // After 32nd read issued, need one more cycle to capture last data
                        state <= CAPTURE_LAST;
                    end
                end
                
                CAPTURE_LAST: begin
                    // Capture the final byte that just appeared
                    packet_buffer[31*8 +: 8] <= fifo_data_out;
                    state <= PACKET_DONE;
                end
                
                PACKET_DONE: begin
                    // Latch the complete packet and assert valid
                    o_packet <= packet_buffer;
                    o_pkt_valid <= 1'b1;
                    byte_count <= 5'd0;
                    read_count <= 5'd0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule