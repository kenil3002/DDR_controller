module packet (
    input  wire        rclk,
    input  wire        rrst_n,
    input  wire        fifo_full,
    input  wire        fifo_empty, // not strictly needed
    input  wire [7:0]  fifo_data,

    output reg         fifo_rd_en,
    output reg [255:0] packet_data,
    output reg         packet_valid
);

    reg [1:0]   state;
    reg [5:0]   byte_count;      // counts 0–31
    reg [255:0] packet_reg;

    parameter IDLE = 2'b00, START = 2'b01, READ = 2'b10, DONE = 2'b11 ;
    //eg fifo_full_sync1, fifo_full_sync2;

reg fifo_full_sync1, fifo_full_sync2;

always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
        fifo_full_sync1 <= 1'b0;
        fifo_full_sync2 <= 1'b0;
    end else begin
        fifo_full_sync1 <= fifo_full;
        fifo_full_sync2 <= fifo_full_sync1;
    end
end

wire fifo_full_rclk = fifo_full_sync2;



    always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
        state        <= IDLE;
        fifo_rd_en   <= 1'b0;
        packet_reg   <= 256'd0;
        packet_data  <= 256'd0;
        packet_valid <= 1'b0;
        byte_count   <= 6'd0;
    end else begin
        case (state)

        // ---------------- IDLE ----------------
        IDLE: begin
            fifo_rd_en   <= 1'b0;
            packet_valid <= 1'b0;
            byte_count   <= 6'd0;

            if (fifo_full_rclk) begin
                packet_reg <= 256'd0;
                fifo_rd_en <= 1'b1;      // start read
                state      <= READ;
            end
        end

        // ---------------- READ ----------------
        READ: begin
            if (!fifo_empty) begin
                packet_reg <= {packet_reg[247:0], fifo_data};
                byte_count <= byte_count + 1'b1;

                if (byte_count == 6'd32) begin
                    fifo_rd_en <= 1'b0;
                    state      <= DONE;
                end
            end
        end

        // ---------------- DONE ----------------
        DONE: begin
            packet_data  <= packet_reg;
            packet_valid <= 1'b1;
            state        <= IDLE;
        end

        default: state <= IDLE;
        endcase
    end
end


endmodule
