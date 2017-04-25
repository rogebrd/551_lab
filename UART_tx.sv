module uart_tx(clk, rst_n, tx, strt_tx, tx_data, tx_done);

// Define state type
typedef enum reg {IDLE, TRANSMIT} STATE;

// Inputs / outputs
input clk, rst_n, strt_tx;
input [7:0] tx_data;
output reg tx, tx_done;

// Internal nodes
reg [9:0] shift;
reg shift_load, shift_en;
reg [11:0] baud;
reg baud_rst, baud_en;
reg [3:0] index;
reg index_rst, index_en;
STATE state, next_state;

////////////////////////////////////////////////////////////////////////////////
// Shift regisgter
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) shift <= 10'hFF;
	else if (shift_load) shift <= {1'b1 ,tx_data, 1'b0};
	else if (shift_en) shift <= {1'b1, shift[9:1]};
	else shift <= shift;
end

////////////////////////////////////////////////////////////////////////////////
// Baud counter
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) baud <= 12'h00;
	else if (baud_rst) baud <= 12'h00;
	else if (baud_en) baud <= baud + 1;
	else baud <= baud;
end

////////////////////////////////////////////////////////////////////////////////
// Index counter
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) index <= 4'h0;
	else if (index_rst) index <= 4'h0;
	else if (index_en) index <= index + 1;
	else index <= index;
end

////////////////////////////////////////////////////////////////////////////////
// tx line
assign tx = shift[0];

////////////////////////////////////////////////////////////////////////////////
// State flops
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) state <= IDLE;
	else state <= next_state;
end 

////////////////////////////////////////////////////////////////////////////////
// Next state logic
always_comb begin
	next_state = IDLE;
	shift_load = 0;
	shift_en = 0;
	baud_rst = 0;
	baud_en = 0;
	index_rst = 0;
	index_en = 0;
	tx_done = 1;
	case (state)
		IDLE		:begin
					if (strt_tx) begin
						next_state = TRANSMIT;
						shift_load = 1;
						baud_rst = 1;
						index_rst = 1;
					end
					else next_state = IDLE;
				end
		TRANSMIT	:begin
					if (baud >= 12'hA2B) begin
						baud_rst = 1;
						shift_en = 1;
						if (index >= 4'h9) begin
							index_rst = 1;
							if (strt_tx) begin
								next_state = TRANSMIT;
								shift_load = 1;
								baud_rst = 1;
								index_rst = 1;
								tx_done = 1;
							end
							else begin
								next_state = IDLE;
							end
						end
						else begin
							next_state = TRANSMIT;
							index_en = 1;
							tx_done = 0;
						end
					end
					else begin 
						next_state = TRANSMIT;
						baud_en = 1;
						tx_done = 0;
					end
				end
	endcase
end

endmodule
