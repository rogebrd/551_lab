module SPI_mstr(clk, rst_n, wrt, cmd, done, rd_data, SCLK, SS_n, MOSI, MISO);

// enum for states
typedef enum reg [2:0] {WAITING, PREP, LOW, HIGH, BACK_PORCH} STATE;

// inputs / outputs
input [15:0] cmd;
input clk, rst_n, wrt, MISO;
output reg [15:0] rd_data;
output reg done, SCLK, MOSI, SS_n;

// internal wiring
reg shift_en_tx, shift_en_rx, shift_load;
reg [5:0] count, count_start;
reg count_en, count_load;
reg [5:0] current_bit;
reg next_bit, first_bit;
reg [15:0] tx_data;
STATE state, next_state;

////////////////////////////////////////////////////////////////////////////////
// 16-bit shift registers

// rx register
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) rd_data <= 16'h0000;
	else if (shift_load) rd_data <= 16'h0000;
	else if (shift_en_rx) rd_data <= {rd_data[14:0], MISO};
	else rd_data <= rd_data;
end
// tx register
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) tx_data <= 16'h0000;
	else if (shift_load) tx_data <= cmd;
	else if (shift_en_tx) tx_data <= {tx_data[14:0], 1'b0};
	else tx_data <= tx_data;
end

////////////////////////////////////////////////////////////////////////////////
// MOSI definition
assign MOSI = tx_data[15];

////////////////////////////////////////////////////////////////////////////////
// 6-bit count-down register for waiting a set amount of clocks
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) count <= 6'h00;
	else if (count_load) count <= count_start;
	else if (count_en) count <= count - 1;
	else count <= count;
end

////////////////////////////////////////////////////////////////////////////////
// 6-bit count-down register for keeping track of which bit the transaction is on
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) current_bit <= 6'h00;
	else if (first_bit) current_bit <= 6'h20;
	else if (next_bit) current_bit <= current_bit - 1;
	else current_bit <= current_bit;
end

////////////////////////////////////////////////////////////////////////////////
// state flops
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) state <= WAITING;
	else state <= next_state;
end

////////////////////////////////////////////////////////////////////////////////
// next state / output logic
always_comb begin
	done = 0;
	SCLK = 1;
	SS_n = 0;
	next_state = WAITING;
	count_start = 6'h00;
	count_load = 0;
	count_en = 0;
	shift_load = 0;
	shift_en_tx = 0;
	shift_en_rx = 0;
	next_bit = 0;
	first_bit = 0;
	case (state)
		// Waiting for wrt to be asserted
		WAITING		:begin
					if (wrt) begin
						shift_load = 1;
						first_bit = 1;
						count_start = 6'h02;
						count_load = 1;
						next_state = PREP;
					end
					else begin
						next_state = WAITING;
						SS_n = 1;
					end
				end
		// Delaying the first negative edge of SCLK by 2 cycles of clk
		PREP		:begin
					if (count == 0) begin
						next_state = LOW;
						count_start = 6'h20;
						count_load = 1;
					end
					else begin
						next_state = PREP;
						count_en = 1;
					end
				end
		// Low period of SCLK, simply wait for 32 clk cycles
		LOW		:begin
					SCLK = 0;
					if (count == 0) begin
						next_state = HIGH;
						shift_en_rx = 1;
						next_bit = 1'b1;
						count_start = 6'h20;
						count_load = 1;
					end
					else begin
						next_state = LOW;
						count_en = 1;
					end
				end
		// High period of SCLK; move to next bit after two cycles of clk; move to
		// BACK_PORCH if this is the last bit; move to LOW after 32 clk cyles otherwise
		HIGH		:begin
					SCLK = 1;
					if (current_bit == 8'h00) begin
						next_state = BACK_PORCH;
						count_start = 6'h10;
						count_load = 1;
					end
					else if (count == 0) begin
						next_state = LOW;
						shift_en_tx = 1;
						count_start = 6'h20;
						count_load = 1;
					end
					else begin
						next_state = HIGH;
						count_en = 1;
					end
				end
		// Delaying rise of SS_n for 16 cycles of clk after last bit; assert done when finished
		BACK_PORCH	:begin
					if (count == 0) begin
						next_state = WAITING;
						done = 1;
					end
					else begin
						next_state = BACK_PORCH;
						count_en = 1;
					end
				end
	endcase
end

endmodule
