module synchronizer(
input clk, rst_n,
input [PTR_WIDTH:0]d_in, 
output reg [PTR_WIDTH:0] d_out
);

parameter PTR_WIDTH = 5;

reg [PTR_WIDTH:0] q1;
 
always@(posedge clk or negedge rst_n) 
    begin
        if(!rst_n) 
            begin
                q1 <= 0;
                d_out <= 0;
            end
        else 
            begin
                q1 <= d_in;
                d_out <= q1;
            end
    end
endmodule