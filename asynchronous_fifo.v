`include "fifo_mem.v"
`include "synchronizer.v"
`include "wptr_handler.v"
`include "rptr_handler.v"

module asynchronous_fifo(
    input wclk, wrst_n,
    input rclk, rrst_n,
    input w_en, r_en,
    input [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire full, empty
);

    parameter DEPTH=32;
    parameter DATA_WIDTH=8;
  
   parameter PTR_WIDTH = $clog2(DEPTH);

    
    wire [PTR_WIDTH:0] g_wptr_sync, g_rptr_sync;
    wire [PTR_WIDTH:0] b_wptr, b_rptr;
    wire [PTR_WIDTH:0] g_wptr, g_rptr;

    wire [PTR_WIDTH-1:0] waddr, raddr;

   synchronizer  sync_wptr (rclk, rrst_n, g_wptr, g_wptr_sync); 
   synchronizer sync_rptr (wclk, wrst_n, g_rptr, g_rptr_sync);

    wptr_handler wptr_h(wclk, wrst_n, w_en,g_rptr_sync,b_wptr,g_wptr,full);
    rptr_handler rptr_h(rclk, rrst_n, r_en,g_wptr_sync,b_rptr,g_rptr,empty);
    fifo_mem fifom(wclk, w_en, rclk, r_en,b_wptr, b_rptr, data_in,full,empty, data_out);

endmodule