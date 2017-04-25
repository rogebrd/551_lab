module pwm(duty, rst_n, clk, out);

input [9:0] duty;
input clk, rst_n;
output reg out;
reg [9:0] cnt;
reg set, reset;

// Make 10-bit counter
always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		cnt <= 10'h000;
	else 
		cnt <= cnt + 1;
end

// Check counter to generate set and reset
always @(duty, cnt) begin
	set = 0;
	reset = 0;
	if (cnt == 10'hFFF)
		set = 1;
	else if (cnt == duty)
		reset = 1;
end

// Select output based on set and reset
always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		out <= 0;
	else if (set)
		out <= 1;
	else if (reset)
		out <= 0;
	else 
		out <= out;
end

endmodule
