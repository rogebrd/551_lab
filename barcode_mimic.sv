module barcode_mimic(clk,rst_n,period,send,station_ID,BC_done,BC);

  input clk,rst_n;			// clock and active low asynch reset
  input [21:0] period;		// period used for transmission, can be a somewhat random #
  input send;				// asserted for 1 clock to initiate a transmission
  input [7:0] station_ID;	// code to transmit
  output reg BC;			// serial barcode output
  output reg BC_done;		// indicates when barcode tranmission is complete (useful for testbenches)
  
  typedef enum reg[1:0] {IDLE,STRT_BIT,WAIT_FULL,TX} state_t;
  state_t state, nxt_state;
  
  wire [21:0] period_preturb;
  
  logic [16:0] preturb_mag;		// random variation of period
  reg [7:0] shft_reg;
  reg [21:0] period_cnt;
  reg [3:0] bit_cnt;
  
  //////////////////////////////////
  // Following are outputs of SM //
  ////////////////////////////////
  logic shift;
  logic sending;		// asserted when transmission in progress
  logic set_BC,clr_BC;	// these control the BC output flop
  logic set_BC_done;	// asserted by SM when BC transmission complete
  
  wire quarter_period,half_period,qrt3_period,full;
  
  ////////////////////////////////////////////////////////////
  // buffer station_ID to send in shift register upon send //
  //////////////////////////////////////////////////////////
  always_ff @(posedge clk)
    if (send)
	  shft_reg <= station_ID;
	else if (shift)
	  shft_reg <= {shft_reg[6:0],1'b1};
	  
  ///////////////////////////
  // Infer period counter //
  /////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  period_cnt <= 22'h00000;
	else if (full)
	  period_cnt <= 22'h000000;
	else if (sending)
	  period_cnt <= period_cnt + 1;
	  
  ///////////////////////////////////////////////////////
  // Now for random variation in period with each bit //
  /////////////////////////////////////////////////////
  always @(negedge shift, negedge rst_n)
    if (!rst_n)
	  preturb_mag = 17'h00000;
	else
      preturb_mag = {$random} % (period>>5);		// add a +/- variation equal to 1/32 the value of period

  assign period_preturb = (preturb_mag[0]) ? (period + preturb_mag) : (period - preturb_mag);
  assign quarter_period = (period_cnt=={2'b00,period_preturb[21:2]}) ? 1'b1: 1'b0;
  assign half_period = (period_cnt=={1'b0,period_preturb[21:1]}) ? 1'b1: 1'b0;
  assign qrt3_period = (period_cnt==({1'b0,period_preturb[21:1]}+{2'b00,period_preturb[21:2]})) ? 1'b1: 1'b0;
  assign full = (period_cnt==period_preturb) ? 1'b1 : 1'b0;
  
  ///////////////////////////////////////////////////////////
  // Infer bit counter used to determine when we are done //
  /////////////////////////////////////////////////////////
  always_ff @(posedge clk)
    if (send)
	  bit_cnt <= 4'b0000;
	else if (shift)
	  bit_cnt <= bit_cnt + 1;
	  
  //////////////////////////////////////////////////////
  // BC_done will be implemented with set/reset flop //
  ////////////////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  BC_done <= 1'b0;
	else if (set_BC_done)
	  BC_done <= 1'b1;
	else if (send)
	  BC_done <= 1'b0;
	  
  ///////////////////////////////////////////////////////////////
  // BC output will be formed by a flop to ensure glitch free //
  /////////////////////////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  BC <= 1'b1;
	else if (set_BC)
	  BC <= 1'b1;
	else if (clr_BC)
	  BC <= 1'b0;
	  
  ////////////////////////
  // Infer state flops //
  //////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  state <= IDLE;
	else
	  state <= nxt_state;
	  
  ///////////////////////////////////////////
  // SM output and state transition logic //
  /////////////////////////////////////////
  always_comb begin
    shift = 0;
	sending = 1;
	set_BC = 0;
	clr_BC = 0;
	set_BC_done = 0;
	nxt_state = IDLE;
	
	case (state)
	  IDLE : begin
	    sending = 0;				// only state in which not sending
	    if (send)
		  begin
		    nxt_state = STRT_BIT;
			clr_BC = 1;
		  end
	  end
	  STRT_BIT : begin
	    if (half_period)
		  begin
		    nxt_state = WAIT_FULL;
			set_BC = 1;
		  end
		else
		  nxt_state = STRT_BIT;
	  end
	  WAIT_FULL : begin
	    if (full)
		  if (bit_cnt==4'b1000)
		    begin
			  nxt_state = IDLE;
			  set_BC_done = 1;
			end
		  else
		    begin
		      nxt_state = TX;
			  clr_BC = 1;
		    end
		else
		  nxt_state = WAIT_FULL;
	  end
	  TX : begin
	    if (!shft_reg[7])
		  if (qrt3_period)
			begin
			  set_BC = 1;
			  shift = 1;
			  nxt_state = WAIT_FULL;
			end
		  else nxt_state = TX;
		else
		  if (quarter_period)
			begin
			  set_BC = 1;
			  shift = 1;
			  nxt_state = WAIT_FULL;
			end
		  else nxt_state = TX;
	  end
	endcase 
  end
	  
 endmodule