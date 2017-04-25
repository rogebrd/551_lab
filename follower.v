module Follower(clk,RST_n,led,a2d_SS_n,SCLK,MISO,MOSI,rev_rht,
                rev_lft,fwd_rht,fwd_lft,IR_in_en,IR_mid_en,IR_out_en,
				in_transit,OK2Move,buzz,buzz_n,BC,RX);

				
  input clk,RST_n;			// 50MHz clock and asynch active low reset (unsynched)
  input MISO;				// SPI input (from ADC)
  input BC;				// serial barcode data input
  input OK2Move;			// from proximity sensor,  when high we can move
  input RX;				// UART input from Bluegiga module
  
  output [7:0] led;			// active high LEDs
  output a2d_SS_n,SCLK,MOSI;		// SPI signal outputs
  output rev_rht,fwd_rht;		// right motor PWM signals
  output rev_lft,fwd_lft;		// left motor PWM signals
  output IR_in_en,IR_mid_en,IR_out_en;	// Enables to IR sensors (PWM controlled)
  output buzz,buzz_n;			// Piezo buzzer drive (true & compliment)
  output in_transit;			// acts as enable to proximity sensor
  
  wire [10:0] lft, rht;				// signed 11-bit motor drive magnitudes
  wire [7:0] cmd;				// command from BLE112 to dig_core
  wire [7:0] ID;				// station ID from Barcode unit
  wire [7:0] dbg_data;				// debug data to send
  wire [11:0] A2D_res;				// result from A2D conversion
  wire [2:0] chnnl;				// A2D channel to convert
  wire cmd_rdy, clr_cmd_rdy, clr_ID_vld, ID_vld;
  wire cnv_cmplt, strt_cnv, dbg_tx, dbg_done;
  
  reg rst_ff_n,rst_n;
  reg OK2Move_ff1,OK2Move_ff2;
  
  //////////////////////////////////////////////////////
  // Sync deassertion of rst_n with negedge of clock //
  ////////////////////////////////////////////////////
  always @(negedge clk, negedge RST_n)
    if (!RST_n)
	  begin
	    rst_ff_n <= 1'b0;
	    rst_n <= 1'b0;
	  end
	else
	  begin
	    rst_ff_n <= 1'b1;
		rst_n <= rst_ff_n;
	  end

	  
  ////////////////////////////////
  //  Instantiate Digital Core //
  //////////////////////////////
  dig_core iCORE(.clk(clk),.rst_n(rst_n),.cmd_rdy(cmd_rdy),.cmd(cmd),.led(led),
			     .clr_cmd_rdy(clr_cmd_rdy),.lft(lft),.rht(rht),.buzz(buzz),
				 .buzz_n(buzz_n),.in_transit(in_transit),.OK2Move(OK2Move),.ID(ID),
				 .clr_ID_vld(clr_ID_vld),.ID_vld(ID_vld),.strt_cnv(strt_cnv),
				 .cnv_cmplt(cnv_cmplt),.chnnl(chnnl),.A2D_res(A2D_res),.go(go),
				 .IR_in_en(IR_in_en),.IR_mid_en(IR_mid_en),.IR_out_en(IR_out_en));

  //////////////////////////////////////////////////////
  //  Instantiate 1/2 Duplex UART (cmds from BLE112) //
  ////////////////////////////////////////////////////
  uart_rcv iCMD(.clk(clk),.rst_n(rst_n),.RX(RX),.rx_rdy(cmd_rdy),.rx_data(cmd),
             .clr_rx_rdy(clr_cmd_rdy));
		   		   
  ////////////////////////////////////
  //  Instantiate Motor Controller //
  //////////////////////////////////
  motor_cntrl iMTR(.clk(clk), .rst_n(rst_n), .lft(lft), .rht(rht), .fwd_lft(fwd_lft),
                   .rev_lft(rev_lft), .fwd_rht(fwd_rht), .rev_rht(rev_rht));
			  
  //////////////////////////////////
  //  Instantiate Barcode reader //
  ////////////////////////////////
  barcode iBC(.clk(clk),.rst_n(rst_n),.BC(BC),.ID_vld(ID_vld),.clr_ID_vld(clr_ID_vld),
              .ID(ID));
			  
  /////////////////////////////////
  //  Instantiate A2D Interface //
  ///////////////////////////////		
  A2D_intf iA2D(.clk(clk),.rst_n(rst_n),.strt_cnv(strt_cnv),.cnv_cmplt(cnv_cmplt),.chnnl(chnnl),
                .res(A2D_res),.a2d_SS_n(a2d_SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO));
		
endmodule
