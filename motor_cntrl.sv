module motor_cntrl(clk, rst_n, lft, rht, fwd_lft, rev_lft, fwd_rht, rev_rht);

////////////////////////////////////////////////////////////////////////////////
// Inputs and outputs
input clk, rst_n;
input [10:0] lft, rht;
output reg fwd_lft, rev_lft, fwd_rht, rev_rht;

////////////////////////////////////////////////////////////////////////////////
// Internal nodes
reg [9:0] abs_lft, abs_rht;
wire lft_pwm, rht_pwm;

////////////////////////////////////////////////////////////////////////////////
// Get absolute value of left and right
always_comb begin
	if(lft == 11'h400)
		abs_lft = 10'h3ff;
	else if (lft[10] == 0)
		abs_lft = lft[9:0];
	else 
		abs_lft = (~lft[9:0]) + 1'b1;

	if(rht == 11'h400)
		abs_rht = 10'h3ff;
	else if (rht[10] == 0)
		abs_rht = rht[9:0];
	else 
		abs_rht = (~rht[9:0]) + 1'b1;
end

////////////////////////////////////////////////////////////////////////////////
// Instantiate PWM module
pwm gen_lft(.duty(abs_lft), .clk(clk), .rst_n(rst_n), .out(lft_pwm));
pwm gen_rht(.duty(abs_rht), .clk(clk), .rst_n(rst_n), .out(rht_pwm));

////////////////////////////////////////////////////////////////////////////////
// Decide left's outputs
always_comb begin
	if (lft == 11'h000) begin
		fwd_lft = 1'b1;
		rev_lft = 1'b1;
	end
	else if (lft[10] == 1'b0) begin
		fwd_lft = lft_pwm;
		rev_lft = 1'b0;
	end
	else begin
		fwd_lft = 1'b0;
		rev_lft = lft_pwm;
	end
end

////////////////////////////////////////////////////////////////////////////////
// Decide right's outputs
always_comb begin
	if (rht == 11'h000) begin
		fwd_rht = 1'b1;
		rev_rht = 1'b1;
	end
	else if (rht[10] == 1'b0) begin
		fwd_rht = rht_pwm;
		rev_rht = 1'b0;
	end
	else begin
		fwd_rht = 1'b0;
		rev_rht = rht_pwm;
	end
end

endmodule
