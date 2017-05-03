module ADC128S(clk,rst_n,SS_n,SCLK,MISO,MOSI);

  //////////////////////////////////////////////////|
  // Model of a National Semi Conductor ADC128S    ||
  // 12-bit A2D converter.  NOTE: this model reads ||
  // the file analog.dat.  This file contains      ||
  // 8192*8 = 65536 entries of 12-bit numbers that ||
  // represent the analog data for the 8 channels. ||
  // The first location is for CH0, the 8th addr   ||
  // specifies CH7, the 9th specifies the 2nd data ||
  // set for CH0 ....                              ||
  //////////////////////////////////////////////////

  input clk,rst_n;		// clock and active low asynch reset
  input SS_n;			// active low slave select
  input SCLK;			// Serial clock
  input MOSI;			// serial data in from master
  
  output MISO;			// serial data out to master
  
  reg [11:0] analog_mem[0:65535];	// holds representation of analog data for CH0 - CH7 for 8192 sets.
  
  typedef enum reg[1:0] {IDLE,INIT_LD,WAIT16} state_t;
  ///////////////////////////////////////////////
  // Registers needed in design declared next //
  /////////////////////////////////////////////
  state_t state,nstate;
  reg [15:0] shft_reg;		// main SPI shift register
  reg [4:0] cntr;			// counter to keep track of position in transaction
  reg [15:0] ptr;			// address pointer into array that contains analog values
  reg [2:0] channel;		// pointer to last channel specified for A2D conversion to be performed on.
  reg SCLK_ff1,SCLK_ff2;	// used for falling edge detection of SCLK
  
  /////////////////////////////////////////////
  // SM outputs delcared as type logic next //
  ///////////////////////////////////////////
  logic ld_shft_reg, shift, clr_cnt, en_cnt;
  logic update_ch, inc_ptr;
  
  wire [15:0] shft_data;
  wire SCLK_fall;
  
  //// Implement falling edge detection of SCLK ////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  begin
	    SCLK_ff1 <= 1'b1;
	    SCLK_ff2 <= 1'b1;
	  end
	else
	  begin
	    SCLK_ff1 <= SCLK;
		SCLK_ff2 <= SCLK_ff1;
	  end  
  /////////////////////////////////////////////////////
  // If SCLK_ff2 is still high, but SCLK_ff1 is low //
  // then a negative edge of SCLK has occurred.    //
  //////////////////////////////////////////////////
  assign SCLK_fall = ~SCLK_ff1 & SCLK_ff2;

  //// Infer counter for position in transaction ////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  cntr <= 5'h00;
	else if (clr_cnt)
	  cntr <= 5'h00;
	else if (en_cnt)
	  cntr <= cntr + 1;

  //// Infer address pointer next ////	  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  ptr <= 16'h0000;
	else if (inc_ptr)
	  ptr <= ptr + 1;

  //// Infer main SPI shift register ////
  always_ff @(posedge clk)
    if (ld_shft_reg)
	  shft_reg <= shft_data;
	else if (shift)
	  shft_reg <= {shft_reg[14:0],MOSI};
	  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  channel <= 3'b000;
	else if (update_ch)
	  channel <= shft_reg[13:11];
  
  //// Infer state register next ////
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
	  state <= IDLE;
	else
	  state <= nstate;

  //////////////////////////////////////
  // Implement state tranisiton logic //
  /////////////////////////////////////
  always_comb
    begin
      //////////////////////
      // Default outputs //
      ////////////////////
	  ld_shft_reg = 0;
      shift = 0;
      clr_cnt = 0;
      en_cnt = 0;
      update_ch = 0;
      inc_ptr = 0;
      nstate = IDLE;	  

      case (state)
        IDLE : begin
          if (!SS_n) begin
		    clr_cnt = 1;
            nstate = INIT_LD;
          end
        end
        INIT_LD : begin
          if (SCLK_fall) 
            begin
              ld_shft_reg = 1;
              nstate = WAIT16;
            end
		  else if (SS_n)
		    nstate = IDLE;
          else nstate = INIT_LD;
        end
		WAIT16 : begin
		  en_cnt = SCLK_fall | &cntr[3:0];
		  inc_ptr = &cntr;		// every two 16-bit transactions increment pointer
		  shift = SCLK_fall;
		  if (&cntr[3:0])
		    begin
		      update_ch = 1;
		      nstate =INIT_LD;
			end
		  else if (SS_n)
		    nstate = IDLE;
		  else
		    nstate = WAIT16;
		end
      endcase
    end

  ///// MISO is shift_reg[15] with a tri-state ///////////
  assign MISO = (SS_n) ? 1'bz : shft_reg[15];
  
  initial
    $readmemh("analog.dat",analog_mem);		// read in representation of analog data
	
  assign shft_data = {4'b0000,analog_mem[ptr*8+channel]};

endmodule  
  