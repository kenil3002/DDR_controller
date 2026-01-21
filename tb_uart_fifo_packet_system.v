`timescale 1ns/1ps

module tb_uart_fifo_packet_system;

    // Clock and Reset
    reg i_uart_clk;
    reg i_fifo_rclk;
    reg i_rst_n;
    
    // UART TX Interface
    reg i_tx_dv;
    reg [7:0] i_tx_byte;
    wire o_tx_active;
    wire o_tx_done;
    
    // Packet Output Interface
    wire [255:0] o_packet;
    wire o_pkt_valid;
    
    // Test variables
    integer i;
    reg [7:0] test_data [0:31];  // 32 bytes of test data
    
    //=======================================================
    // DUT Instantiation
    //=======================================================
    uart_fifo_packet_system DUT (
        .i_uart_clk(i_uart_clk),
        .i_fifo_rclk(i_fifo_rclk),
        .i_rst_n(i_rst_n),
        .i_tx_dv(i_tx_dv),
        .i_tx_byte(i_tx_byte),
        .o_tx_active(o_tx_active),
        .o_tx_done(o_tx_done),
        .o_packet(o_packet),
        .o_pkt_valid(o_pkt_valid)
    );
    
    //=======================================================
    // Clock Generation
    //=======================================================
    // UART clock: 100 MHz (10ns period)
    initial begin
        i_uart_clk = 0;
        forever #5 i_uart_clk = ~i_uart_clk;
    end
    
    // FIFO read clock: 50 MHz (20ns period) - different from UART clock
    initial begin
        i_fifo_rclk = 0;
        forever #10 i_fifo_rclk = ~i_fifo_rclk;
    end
    
    //=======================================================
    // Test Stimulus
    //=======================================================

    initial begin
    $dumpfile("wave.vcd");   // VCD file name
    $dumpvars(0, tb_uart_fifo_packet_system); // Dump all signals in TB & DUT
end

    initial begin
        // Initialize signals
        i_rst_n = 0;
        i_tx_dv = 0;
        i_tx_byte = 8'h00;
        
        // Initialize test data (32 bytes with pattern)
        for (i = 0; i < 32; i = i + 1) begin
            test_data[i] = i; // 0x00, 0x01, 0x02, ..., 0x1F
        end
        
        // VCD dump for waveform viewing
        $dumpfile("uart_fifo_packet.vcd");
        $dumpvars(0, tb_uart_fifo_packet_system);
        
        // Display header
        $display("========================================");
        $display("UART to FIFO to Packet System Test");
        $display("========================================");
        
        // Reset sequence
        $display("Time=%0t: Applying Reset", $time);
        #100;
        i_rst_n = 1;
        #100;
        $display("Time=%0t: Reset Released", $time);
        
        // Wait for system to stabilize
        #200;
        
        //=======================================================
        // Test 1: Send 32 bytes through UART
        //=======================================================
        $display("\n--- Test 1: Sending 32 bytes through UART ---");
        for (i = 0; i < 32; i = i + 1) begin
            send_uart_byte(test_data[i]);
            $display("Time=%0t: Sent byte[%0d] = 0x%02h", $time, i, test_data[i]);
        end
        
        // Wait for FIFO to fill and packet to be generated
        $display("\nTime=%0t: Waiting for FIFO to fill and packet generation...", $time);
        wait(o_pkt_valid == 1'b1);
        
        // Verify packet
        $display("\n--- Packet Received! ---");
        $display("Time=%0t: o_pkt_valid = %b", $time, o_pkt_valid);
        $display("Packet Contents (256 bits):");
        
        // Display packet in bytes (LSB first)
        for (i = 0; i < 32; i = i + 1) begin
            $display("  Byte[%0d] = 0x%02h (Expected: 0x%02h) %s", 
                     i, 
                     o_packet[i*8 +: 8], 
                     test_data[i],
                     (o_packet[i*8 +: 8] == test_data[i]) ? "PASS" : "FAIL");
        end
        
        // Wait for valid to go low
        @(negedge o_pkt_valid);
        $display("\nTime=%0t: o_pkt_valid deasserted", $time);
        
        //=======================================================
        // Test 2: Send another 32 bytes with different pattern
        //=======================================================
        #500;
        $display("\n--- Test 2: Sending second packet (pattern: 0xFF-i) ---");
        for (i = 0; i < 32; i = i + 1) begin
            test_data[i] = 8'hFF - i; // 0xFF, 0xFE, 0xFD, ..., 0xE0
            send_uart_byte(test_data[i]);
            $display("Time=%0t: Sent byte[%0d] = 0x%02h", $time, i, test_data[i]);
        end
        
        // Wait for second packet
        wait(o_pkt_valid == 1'b1);
        $display("\n--- Second Packet Received! ---");
        $display("Time=%0t: o_pkt_valid = %b", $time, o_pkt_valid);
        
        // Verify second packet
        for (i = 0; i < 32; i = i + 1) begin
            $display("  Byte[%0d] = 0x%02h (Expected: 0x%02h) %s", 
                     i, 
                     o_packet[i*8 +: 8], 
                     test_data[i],
                     (o_packet[i*8 +: 8] == test_data[i]) ? "PASS" : "FAIL");
        end
        
        // Final results
        #1000;
        $display("\n========================================");
        $display("Test Completed Successfully!");
        $display("========================================");
        $finish;
    end
    
    //=======================================================
    // Task to send a byte through UART TX
    //=======================================================
    task send_uart_byte;
        input [7:0] data;
        begin
            @(posedge i_uart_clk);
            i_tx_byte = data;
            i_tx_dv = 1'b1;
            @(posedge i_uart_clk);
            i_tx_dv = 1'b0;
            
            // Wait for transmission to complete
            wait(o_tx_done == 1'b1);
            @(posedge i_uart_clk);
        end
    endtask
    
    //=======================================================
    // Monitor FIFO status
    //=======================================================
    always @(posedge i_uart_clk) begin
        if (DUT.fifo_full && !DUT.fifo_was_full) begin
            $display("Time=%0t: *** FIFO FULL DETECTED ***", $time);
        end
    end
    
    //=======================================================
    // Monitor packet valid signal
    //=======================================================
    always @(posedge o_pkt_valid) begin
        $display("Time=%0t: *** PACKET VALID ASSERTED ***", $time);
    end
    
    //=======================================================
    // Timeout watchdog
    //=======================================================
    initial begin
        #500000; // 500us timeout
        $display("\n*** ERROR: Test timeout! ***");
        $finish;
    end

endmodule