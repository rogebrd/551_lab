module motion_cntrl(clk, rst_n, go, cnv_cmplt, A2D_res, start_conv, chnnl, IR_in_en, IR_mid_en, IR_out_en, LEDs, lft, rht);
	

//NOTES:
// - Should Pterm & Iterm be hardcoded as params?
// - Are we waiting 2 cycles for multiplication?

	//inputs
	input clk, rst_n, go, cnv_cmplt;
	input[11:0] A2D_res;
	
	//outputs
	output reg start_conv;
	output reg IR_in_en, IR_mid_en, IR_out_en;
	output reg[2:0] chnnl;
	output[7:0] LEDs;
	output[10:0] lft, rht;
	
	//alu vars
	reg[15:0] Accum, Pcomp;
	reg[11:0] Error, Intgrl, Icomp, lft_reg, rht_reg, Fwd;
	reg[2:0] src0sel, src1sel;
	reg sub, multiply, mult2, mult4, saturate;
	reg dst2Accum, dst2Err, dst2Int, dst2Icmp, dst2Pcmp, dst2lft, dst2rht;
	localparam Iterm = 12'h500;
	localparam Pterm = 14'h3680;
	reg[15:0] dst;
	reg[1:0] int_dec;
	reg int_rst, int_enable;
	
	//timer variables
	reg timer_rst, timer_en;
	reg[63:0] timer;
	
	//channel counter
	//read 1, 0, 4, 2, 3, 7
	reg[2:0] chnnl_cntr;
	
	//states
	typedef enum {RESET, CONV, A2D_1, ALU_1, A2D_2, ALU_2, PI_CNTRL} State;
	State n_state, state;
	
	//output vars
	assign lft = lft_reg[11:1];
	assign rht = rht_reg[11:1];
	assign LEDs = Error[11:4];
	
	alu alu1(.Accum(Accum), .Pcomp(Pcomp), .Icomp(Icomp), .Pterm(Pterm), .Iterm(Iterm), .Fwd(Fwd), .A2D_res(A2D_res), .Error(Error), .Intgrl(Intgrl), .src0sel(src0sel), .src1sel(src1sel), .multiply(multiply), .sub(sub), .mult2(mult2), .mult4(mult4), .saturate(saturate), .dst(dst));
	
	//pwm vars
	reg pwm;
	reg[7:0] duty = 8'h8C;
	pwm pwm_motion(.duty(duty), .rst_n(rst_n), .clk(clk), .out(pwm));


	//timer logic
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			timer <= 64'h0000000000000000;
		else if(timer_rst)
			timer <= 64'h0000000000000000;
		else if(timer_en)
			timer <= timer + 1;
	end
	
	//state transition logic
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= RESET;
		else
			state <= n_state;
	end

	//fwd control
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			Fwd <= 12'h000;
		else if (~go) // if go deasserted Fwd knocked down so
			Fwd <= 12'b000; // we accelerate from zero on next start.
		else if (dst2Int & ~&Fwd[10:8]) // 43.75% full speed
			Fwd <= Fwd + 1'b1;
	end

	//implement int_dec to control integrl
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			int_dec <= 2'b00;
		else if(int_rst)
			int_dec <= 2'b00;
		else if(int_enable)
			int_dec <= int_dec + 1;
		else
			int_dec <= int_dec;
	end


	//dst results for ALU

	//code for Accum
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			Accum <= 16'h0000;
		else if(!go)
			Accum <= 16'h0000;
		else if(dst2Accum)
			Accum <= dst;
	end
	//code for Pcomp
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			Pcomp <= 16'h000;
		else if(!go)
			Pcomp <= 16'h000;
		else if(dst2Pcmp)
			Pcomp <= dst;
	end
	//code for Error
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			Error <= 12'h000;
		else if(!go)
			Error <= 12'h000;
		else if(dst2Err)
			Error <= dst[11:0];
	end
	//code for Icomp
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			Icomp <= 12'h000;
		else if(!go)
			Icomp <= 12'h000;
		else if(dst2Icmp)
			Icomp <= dst[11:0];
	end
	//code for Error
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			Intgrl <= 12'h000;
		else if(!go)
			Intgrl <= 12'h000;
		else if(dst2Int)
			Intgrl <= dst[11:0];
	end
	//code for rht_reg
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			rht_reg <= 12'h000;
		else if(!go)
			rht_reg <= 12'h000;
		else if(dst2rht)
			rht_reg <= dst[11:0];
	end
	
	//code for lft_reg
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n)
			lft_reg <= 12'h000;
		else if(!go)
			lft_reg <= 12'h000;
		else if(dst2lft)
			lft_reg <= dst[11:0];
	end


	//next state logic
	always @ (*) begin
		timer_en = 0;
		timer_rst = 0;
		start_conv = 0;
		//alu defaults
		sub = 0;
		multiply = 0;
		mult2 = 0;
		mult4 = 0;
		saturate = 0;
		src0sel = 0;
		src1sel = 0;
		dst = 16'h0000;
		int_rst = 1;
		int_enable = 0;
		IR_in_en = 0;
		IR_mid_en = 0;
		IR_out_en = 0;
		//chnnl = 3'b000;
		
		
		case(state)
			RESET: 	begin
					//reset all
					dst2Accum = 1'b0;
					dst2Err = 1'b0;
					dst2Icmp = 1'b0;
					dst2Int = 1'b0;
					dst2Pcmp = 1'b0;
					dst2lft = 1'b0;
					dst2rht = 1'b0;
					chnnl_cntr = 3'b000;
					if(go) begin
						//reset chnnl and accum
						n_state = CONV;
						chnnl = 3'b001;
						timer_rst = 1;
					end else
						n_state = RESET;
					end
			CONV:	begin
						//enable pwm sensors
						if(chnnl_cntr == 0) begin
							IR_in_en = pwm;
							IR_mid_en = 0;
							IR_out_en = 0;
						end
						else if(chnnl_cntr == 2) begin
							IR_in_en = 0;
							IR_mid_en = pwm;
							IR_out_en = 0;
						end
						else if(chnnl_cntr == 4) begin
							IR_in_en = 0;
							IR_mid_en = 0;
							IR_out_en = pwm;
						end
						//enable timer and wait 4096 clocks
						timer_en = 1;
						if(timer == 64'd4095) begin
							n_state = A2D_1;
							start_conv = 1;
						end else
							n_state = CONV;
					end
			A2D_1:	begin
						//wait until conversion is complete and reset timer and inc chnnl
						if(cnv_cmplt) begin
							n_state = ALU_1;
							timer_rst = 1;		//clear timer pre-ALU calculations 
//							chnnl_cntr = chnnl_cntr + 1;
						end else
							n_state = A2D_1;
					end
			ALU_1:	begin
						//update channel
						if(chnnl == 1)
							chnnl = 0;
						else if(chnnl == 4)
							chnnl = 2;
						else if(chnnl == 3)
							chnnl = 7;

						//enable timer
						timer_rst = 1'b0;
						timer_en = 1'b1;

						//perform calculations based off channel
						case(chnnl_cntr)
							//0: 					//chnnl(0) 2. Accum = Accum + IR_in_rht;
							3'b010: mult2 = 1'b1;	//chnnl(2) 4. Accum = Accum + IR_mid_rht * 2;
							3'b100: mult4 = 1'b1;	//chnnl(4) 6. Accum = Accum + IR_out_rht * 4;
						endcase
						dst2Accum = 1'b1;

						//incrememnt channel counter
						chnnl_cntr = chnnl_cntr + 1;

						//wait 32 clks
						if(timer == 64'h0000020) begin
							n_state = A2D_2;
							start_conv = 1;
						end else
							n_state = ALU_1;
					end
			A2D_2:	begin
						//wait until conversion is complete and reset timer and inc chnnl
						if(cnv_cmplt) begin
							n_state = ALU_2;
							timer_rst = 1;		//clear timer pre-ALU calculations 
						end else
							n_state = A2D_2;
					end
			ALU_2:	begin
						//update channel
						if(chnnl == 0)
							chnnl = 4;
						else if(chnnl == 2)
							chnnl = 3;
						else if(chnnl == 7)
							chnnl = 7;
						
						//perform calculations based off channel
						sub = 1'b1;
						case(chnnl_cntr)
							3'b010: dst2Accum = 1'b1;		//chnnl(1) 3. Accum = Accum - IR_in_lft;
							3'b100: begin			//chnnl(3) 5. Accum = Accum - IR_mid_lft * 2;
									mult2 = 1'b1;
									dst2Accum = 1'b1;
								end
							3'b110: begin			//chnnl(5) 7. Error = Accum - IR_out_lft * 4;
									mult4 = 1'b1;
									saturate = 1'b1;
									dst2Err = 1'b1;
								end
						endcase
						
						//check if seen 6 channels (0-5)
						if(chnnl_cntr == 3'b101) begin
							n_state = PI_CNTRL;
							chnnl_cntr = 3'b000;	//update for PI calc
						end
						else begin
							n_state = CONV;
							chnnl_cntr = chnnl_cntr + 1;
						end
					end
			PI_CNTRL: begin
						//do PI calculations with ALU and update chnnl
						//NOTE: chnnl is now being used to track PI math step
						n_state = PI_CNTRL; //default
						
						case(chnnl_cntr)
							3'b000: begin 	//8. Intgrl = Error >> 4 + Intgrl; *every 4 calc cycles
									src1sel = 3'b011;
									src0sel = 3'b001;
									mult4 = 1'b1;
									saturate = 1'b1;
									chnnl_cntr = 3'b001;
									if (int_dec == 2'b11) 
										dst2Int = 1'b1;
									end
							3'b001: begin 	//9. Icomp = Iterm * Intgrl;
									src1sel = 3'b010;
									src0sel = 3'b001;
									multiply = 1'b1;
									chnnl_cntr = 3'b010;
									dst2Icmp = 1'b1;
									end
							3'b010: begin	//10. Pcomp = Error * Pterm;
									src1sel = 3'b010;
									src0sel = 3'b100;
									multiply = 1'b1;
									chnnl_cntr = 3'b011;
									dst2Pcmp = 1'b1;
									end
							3'b011: begin 	//11. Accum = Fwd - Pcomp;
									src1sel = 3'b100;
									src0sel = 3'b011;
									sub = 1'b1;	
									chnnl_cntr = 3'b100;
									dst2Accum = 1'b1;
									end
							3'b100: begin 	//12. rht_reg = Accum - Icomp;
									src1sel = 3'b000;
									src0sel = 3'b011;
									saturate = 1'b1;
									sub = 1'b1;
									chnnl_cntr = 3'b101;
									dst2rht = 1'b1;
									end
							3'b101: begin 	//13. Accum = Fwd + Pcomp;
									src1sel = 3'b100;
									src0sel = 3'b011;
									chnnl_cntr = 3'b110;
									dst2Accum = 1'b1;
									end
							3'b110: begin 	//14. lft_reg = Accum + Icomp;
									src1sel = 3'b000;
									src0sel = 3'b010;
									saturate = 1'b1;
									chnnl_cntr = 3'b000;
									dst2lft = 1'b1;
									n_state = RESET;	//back to reset state
									end
						endcase
					end
		endcase
	end

endmodule
