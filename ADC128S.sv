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
  
  reg [11:0] analog_mem[0:7];	// holds representation of analog data for CH0 - CH7 for 8192 sets.
  
  wire [15:0] A2D_data,cmd;
  wire rdy_rise;
	
  typedef enum reg {FIRST,SECOND} state_t;
  
  state_t state,nxt_state;
  
  ///////////////////////////////////////////////
  // Registers needed in design declared next //
  /////////////////////////////////////////////
  reg rdy_ff;				// used for edge detection on rdy
  reg [12:0] ptr;			// combined with channel to form pointer into analog_mem
  reg [2:0] channel;		// pointer to last channel specified for A2D conversion to be performed on.
  
  /////////////////////////////////////////////
  // SM outputs declared as type logic next //
  ///////////////////////////////////////////
  logic update_ch, inc_ptr;

  ////////////////////////////////
  // Instantiate SPI interface //
  //////////////////////////////
  SPI_ADC128S iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                 .MOSI(MOSI),.A2D_data(A2D_data),.cmd(cmd),.rdy(rdy));

  //// ptr is pointer to next data ////
  /// set...next set of 8 channels ////  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  ptr <= 13'h0000;
	else if (inc_ptr)
	  ptr <= ptr + 1;
	  
  //// channel pointer ////	  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  channel <= 3'b000;
	else if (update_ch)
	  channel <= cmd[13:11];
	  
  //// Infer state register next ////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  state <= FIRST;
	else
	  state <= nxt_state;
	  
  //// positive edge detection on rdy ////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  rdy_ff <= 1'b0;
	else
	  rdy_ff <= rdy;
  assign rdy_rise = rdy & ~rdy_ff;
  

  //////////////////////////////////////
  // Implement state tranisiton logic //
  /////////////////////////////////////
  always_comb
    begin
      //////////////////////
      // Default outputs //
      ////////////////////
      update_ch = 0;
	  inc_ptr = 0;
      nxt_state = FIRST;	  

      case (state)
        FIRST : begin
          if (rdy_rise) begin
		    update_ch = 1;
            //nxt_state = SECOND;
            nxt_state = FIRST;
          end
        end
		SECOND : begin		
		  if (rdy_rise) begin
		    inc_ptr = 1;
			nxt_state = FIRST;
		  end else
		    nxt_state = SECOND;
		end
      endcase
    end
  
  initial
    $readmemh("analog.dat",analog_mem);		// read in representation of analog data
	
  assign A2D_data = {4'b0000,analog_mem[channel]};

endmodule  
  