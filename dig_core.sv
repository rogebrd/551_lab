module dig_core(clk,rst_n,cmd_rdy,cmd,clr_cmd_rdy,lft,rht,buzz,buzz_n,
                in_transit,OK2Move,ID,clr_ID_vld,ID_vld,cnv_cmplt,strt_cnv,
				chnnl,A2D_res,IR_in_en, IR_mid_en, go,IR_out_en,led);
										 			
  input clk,rst_n;			// 50MHz clock and active low asynch reset
  input cmd_rdy;			// indicates command from BLE112 is ready
  input [7:0] cmd;			// command from BLE112
  input OK2Move;			// input from proximity sensor
  input [7:0] ID;			// station ID from BC unit
  input ID_vld;				// indicates ID value from BC unit is valid
  input cnv_cmplt;			// indicates A2D conversion is ready
  input [11:0] A2D_res;			// result of A2D conversion of IR sensor
  
  output clr_cmd_rdy;					// used to knock down cmd_rdy signal after command processed
  output [10:0] lft,rht;				// 11-bit signed left and right motor controls
  output buzz,buzz_n;					// optional piezo buzzer
  output in_transit;					// forms enable to proximity sensor
  output clr_ID_vld;					// used to knock down ID_vld once station ID digested
  output strt_cnv;					// used to initiate a Round Robing conversion on IR sensors
  output [2:0] chnnl;					// channel to perform A2D conversion on
  output IR_in_en,IR_mid_en,IR_out_en;			// PWM based enables to various IR sensors
  output [7:0] led;					// Active high drive to array of 8 LEDs
  output go;						// Go signal to motion controller
  
  wire clr_cmd_rdy,buzz,buzz_n,in_transit,clr_ID_vld;
  wire go;
  
  ////////////////////////////////////
  // Instantiate Command & Control //
  //////////////////////////////////
  cmd_cntrl iCMD(.clk(clk), .rst_n(rst_n), .OK2Move(OK2Move), .go(go), .cmd_rdy(cmd_rdy),
                 .cmd(cmd), .clr_cmd_rdy(clr_cmd_rdy), .buzz(buzz), .buzz_n(buzz_n),
				 .in_transit(in_transit), .ID(ID), .clr_ID_vld(clr_ID_vld), .ID_vld(ID_vld));

  ////////////////////////////////////
  // Instantiate Motion Controller //
  //////////////////////////////////
  motion_cntrl iMTN(.clk(clk),.rst_n(rst_n),.go(go),.strt_cnv(strt_cnv),.chnnl(chnnl),.cnv_cmplt(cnv_cmplt),
                    .A2D_res(A2D_res),.IR_in_en(IR_in_en),.IR_mid_en(IR_mid_en),.IR_out_en(IR_out_en),
					.LEDs(led),.lft(lft),.rht(rht));				
					

endmodule
  