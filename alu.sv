module alu (dst, Accum, Pcomp, Pterm, Icomp, Error, Intgrl, Iterm, Fwd, A2D_res,
             src0sel, src1sel, mult2, mult4, sub, multiply, saturate);

input [15:0] Accum, Pcomp;
input [11:0] Icomp, Error, Intgrl;
input [13:0] Pterm;
input [11:0] Iterm, Fwd, A2D_res;
input [2:0] src0sel, src1sel;
input mult2, mult4, multiply, sub, saturate;

output [15:0] dst;

wire [15:0] pre_src0, pre_src1, scaled_src0;

wire signed [16:0] sum;
wire [15:0] satSum12, src0;
wire signed [14:0] src0_sgn, src1_sgn;
wire signed [29:0] result_sgn;
wire [15:0] satSum15;


  //select signal 1
  localparam Accum2Src1   = 3'b000;
  localparam Iterm2Src1   = 3'b001;
  localparam Err2Src1     = 3'b010;
  localparam ErrDiv22Src1 = 3'b011;
  localparam Fwd2Src1     = 3'b100;
  
  assign pre_src1[15:0] = (src1sel == Accum2Src1)   ? Accum:
  		          (src1sel == Iterm2Src1)   ? {4'b0000, Iterm}:
		          (src1sel == Err2Src1)     ? {{4{Error[11]}}, Error}:
		          (src1sel == ErrDiv22Src1) ? {{8{Error[11]}}, Error[11:4]}:
		          (src1sel == Fwd2Src1)     ? {4'b0000, Fwd}:
		        			      16'h0000;
   
  //select signal 0
  localparam A2D2Src0     = 3'b000;
  localparam Intgrl2Src0  = 3'b001;
  localparam Icomp2Src0   = 3'b010;
  localparam Pcomp2Src0   = 3'b011;
  localparam Pterm2Src0   = 3'b100;

  assign pre_src0[15:0] = (src0sel == A2D2Src0)    ? {4'b0000,A2D_res}:
		          (src0sel == Intgrl2Src0) ? {{4{Intgrl[11]}},Intgrl}:
		          (src0sel == Icomp2Src0)  ? {{4{Icomp[11]}},Icomp}:
		          (src0sel == Pcomp2Src0)  ? Pcomp:
		          (src0sel == Pterm2Src0)  ? {2'b00,Pterm}:
		          			     16'h0000;
 
  //scale source 0
  assign scaled_src0 = (mult2 == 1'b1)  ? pre_src0 * 2:
		       (mult4 == 1'b1)  ? pre_src0 * 4:
  		          	          pre_src0;


  //handling subtraction functionality
  assign src0 = (sub == 1'b1) ? ~scaled_src0:
		 scaled_src0;


  //add prepped values
  assign sum = pre_src1 + src0 + sub;

  //12-bit saturation logic
  assign satSum12 = ((saturate == 1'b1) && (sum[15] == 1'b0) && (sum[14:11] != 4'b0000)) ? 16'h07FF:
		    ((saturate == 1'b1) && (sum[15] == 1'b1) && (sum[14:11] != 4'b1111)) ? 16'hF800:
		    							      sum[15:0];
 
  
  //clip source signals 
  assign src0_sgn = src0[14:0];
  assign src1_sgn = pre_src1[14:0];

  //implement signed 15x15 multiplier
  assign result_sgn = src0_sgn * src1_sgn;

  //15-bit saturation logic
  assign satSum15 = ((result_sgn[29] == 1'b1) && (result_sgn[28:26] != 3'b111)) ? 16'hC000:
		    ((result_sgn[29] == 1'b0) && (result_sgn[28:26] != 3'b000)) ? 16'h3FFF:
		  				 result_sgn[27:12];

  //output selection
  assign dst = (multiply == 1'b1) ? satSum15:
	      			    satSum12;
endmodule
