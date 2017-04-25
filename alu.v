module alu(Accum, Pcomp, Icomp, Pterm, Iterm, Fwd, A2D_res, Error, 
	Intgrl, src0sel, src1sel, multiply, sub, mult2, mult4, saturate, dst);

////////////////////////////////////////////////////////////////////////////////
// Raw inputs to the ALU
input [15:0] Accum, Pcomp;
input [13:0] Pterm;
input [11:0] Icomp, Error, Intgrl;
input [11:0] Iterm, Fwd, A2D_res;
input [2:0] src0sel, src1sel;
input multiply, sub, mult2, mult4, saturate;

// Output from the ALU
output reg [15:0] dst;

// Intermediate nodes in ALU
reg [15:0] pre_src0;
reg [15:0] scaled_src0;
reg [15:0] src0;
reg [15:0] src1;
wire signed [14:0] src0_sign;
wire signed [14:0] src1_sign;
wire [15:0] preSatSum;
reg [15:0] satSum;
wire signed [29:0] preSatProd;
reg [15:0] satProd;

// Params for src0 select
localparam A2D2Src0 = 3'b000;
localparam Intgrl2Src0 = 3'b001;
localparam Icomp2Src0 = 3'b010;
localparam Pcomp2Src0 = 3'b011;
localparam Pterm2Src0 = 3'b100;

// Params for src1 select
localparam Accum2Src1 = 3'b000;
localparam Iterm2Src1 = 3'b001;
localparam Err2Src1 = 3'b010;
localparam ErrDiv22Src1 = 3'b011;
localparam Fwd2Src1 = 3'b100;

////////////////////////////////////////////////////////////////////////////////
// Builds up pre_src0
always @(A2D_res, Intgrl, Icomp, Pcomp, Pterm, src0sel) begin
	case (src0sel)
		Accum2Src1	: pre_src0 = {4'b0000, A2D_res};
		Iterm2Src1	: pre_src0 = {{4{Intgrl[11]}},Intgrl};
		Err2Src1	: pre_src0 = {{4{Icomp[11]}},Icomp};
		ErrDiv22Src1	: pre_src0 = Pcomp;
		Fwd2Src1	: pre_src0 = {2'b00,Pterm};
		default		: pre_src0 = 16'h0000;
	endcase
end

////////////////////////////////////////////////////////////////////////////////
// Builds up scaled_src0
always @(mult2, mult4, pre_src0) begin
	if (mult4)
		scaled_src0 = pre_src0 << 2;
	else if (mult2)
		scaled_src0 = pre_src0 << 1;
	else 
		scaled_src0 = pre_src0;
end

////////////////////////////////////////////////////////////////////////////////
// Builds up src0
always @(sub, scaled_src0) begin
	if (sub)
		src0 = ~scaled_src0;
	else 
		src0 = scaled_src0;
end

////////////////////////////////////////////////////////////////////////////////
// Builds up src1
always @(Accum, Iterm, Error, Fwd, src1sel) begin
	case (src1sel)
		A2D2Src0	: src1 = Accum;
		Intgrl2Src0	: src1 = {4'b0000,Iterm};
		Icomp2Src0	: src1 = {{4{Error[11]}},Error};
		Pcomp2Src0	: src1 = {{8{Error[11]}},Error[11:4]};
		Pterm2Src0	: src1 = {4'b0000,Fwd};
		default		: src1 = 16'h0000;
	endcase
end

////////////////////////////////////////////////////////////////////////////////
// Adds src0 and src1
assign preSatSum = src1 + src0 + sub;

////////////////////////////////////////////////////////////////////////////////
// Saturates sum
always @(preSatSum, saturate) begin
	if (saturate) begin
		if (preSatSum[15] == 1'b1) begin // negative result
			if (preSatSum[14:11] == 4'b1111) // value small enough to represent in 12 bits; don't saturate
				satSum = preSatSum; 
			else // must saturate
				satSum = 16'hF800;
		end
		else begin // positive result
			if (preSatSum[14:11] == 4'b0000) // value small enough to represent in 12 bits; don't saturate
				satSum = preSatSum; 
			else // must saturate
			satSum = 16'h07FF;
		end
	end
	else begin
		satSum = preSatSum;
	end
end

////////////////////////////////////////////////////////////////////////////////
// Multiplies src0 and src1
assign src1_sign = src1[14:0];
assign src0_sign = src0[14:0];
assign preSatProd = src1_sign * src0_sign;

////////////////////////////////////////////////////////////////////////////////
// Saturate product
always @(preSatProd) begin 
	if (preSatProd[29] == 1'b1) begin // negative result
		if (preSatProd[28:26] == 3'b111) // value small enough to represent in 16 bits; don't saturate
			satProd = preSatProd[27:12];
		else // must saturate
			satProd = 16'hC000;
	end
	else begin// positive result
		if (preSatProd[28:26] == 3'b000) // value small enough to represent in 16 bits; don't saturate
			satProd = preSatProd[27:12];
		else // must saturate
			satProd = 16'h3FFF;
	end
end

////////////////////////////////////////////////////////////////////////////////
// Select either sum or product
always @(multiply, satProd, satSum) begin
	if (multiply)
		dst = satProd;
	else
		dst = satSum;	
end

endmodule
