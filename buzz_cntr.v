module buzz_counter(clk, rst_n, buzz, buzz_n, clr_cnt, cnt, cnt_n, high_time);

  input clk, rst_n;
  input buzz,buzz_n;
  input clr_cnt;
  
  output reg [3:0] cnt;
  output reg [3:0] cnt_n;
  output reg [13:0] high_time;
  
  reg first_high;
  
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
	  high_time <= 14'h0000;
    else if (first_high)
	  high_time <= high_time + 1;
	  
  always @(posedge buzz)
    if (first_high===1'bx)
	  first_high = 1'b1;
	  
  always @(negedge buzz)
    if (first_high)
	  first_high <= 1'b0;
	
  always @(posedge buzz, posedge clr_cnt)
    if (clr_cnt)
	  cnt <= 4'b0000;
	else
	  cnt <= cnt + 1;
	  
  always @(posedge buzz_n, posedge clr_cnt)
    if (clr_cnt)
	  cnt_n <= 4'b0000;
	else
	  cnt_n <= cnt_n + 1;
	  
endmodule
	  
	  