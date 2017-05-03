module motion_cntrl_tb();

	reg go, cnv_cmplt;
	reg [11:0] A2D_res;
	wire start_conv, IR_in_en, IR_mid_en, IR_out_en;
	wire [2:0] chnnl;
	wire [7:0] LEDs;
	wire [10:0] lft, rht;
	
	reg clk, rst_n;
	reg [2:0] c;
	
	motion_cntrl iDUT(.clk(clk), .rst_n(rst_n), .go(go), .cnv_cmplt(cnv_cmplt), 
		.A2D_res(A2D_res), .start_conv(start_conv), .chnnl(chnnl), .IR_in_en(IR_in_en),
		.IR_mid_en(IR_mid_en), .IR_out_en(IR_out_en), .LEDs(LEDs), .lft(lft), .rht(rht));
	
	


	initial begin
		clk = 1;
		rst_n = 0;
		#5
		rst_n = 1;
		#5
		go = 0;
		cnv_cmplt = 0;
		A2D_res = 12'hAAA;
		
		#10
		go = 1;			//chnnl = 0, Accum = 0
		
		for (c = 3'b000; c < 3'b110; c = c + 1'b1) begin
			//go = 0;
			
			#50000		//wait for timer to preform calculations
			cnv_cmplt = 1;
			
			#5
			cnv_cmplt = 0;
			
			#350		//wait for timer to start A2D conversions
			cnv_cmplt = 1;
						//perform calculations based on calculations
						//then when chnnl = 6, PI control regs update else repeat
		end
		$stop;
	end

	always
		#5 clk = ~clk;



endmodule
