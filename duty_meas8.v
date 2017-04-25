module duty_meas8(clk,rst_n,PWM,duty);

input clk,rst_n;
input PWM;
output reg [7:0] duty;

reg PWM_ff;
reg [7:0] duty_cnt;

wire start;

always @(posedge clk, negedge rst_n)
  if (!rst_n)
    duty_cnt <= 8'h00;
  else if (start)
    duty_cnt <= 8'h01;
  else if (PWM)
    duty_cnt <= duty_cnt + 1;

always @(posedge clk)
  if (start)
    duty <= duty_cnt;
	
always @(posedge clk)
  PWM_ff <= PWM;
  
assign start = PWM & ~PWM_ff;

endmodule
	