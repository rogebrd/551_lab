module uart_rcv(clk, rst_n, RX, rx_data, rx_rdy, clr_rx_rdy);

// Define state type
typedef enum reg {IDLE, RECIEVE} STATE;

// Inputs / outputs
input clk, rst_n, RX, clr_rx_rdy;
output [7:0] rx_data;
output reg rx_rdy;

// Internal nodes
reg [9:0] shift;
reg shift_en;
reg [11:0] baud;
reg baud_rst, baud_en;
reg [3:0] index;
reg index_rst, index_en;
reg rx_rdy_set, rx_rdy_clear;
STATE state, next_state;

////////////////////////////////////////////////////////////////////////////////
// Shift regisgter
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) shift <= 10'h000;
	else if (shift_en) shift <= {RX, shift[9:1]};
	else shift <= shift;
end

////////////////////////////////////////////////////////////////////////////////
// Baud counter
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) baud <= 12'h000;
	else if (baud_rst) baud <= 12'h000;
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
// cmd
assign rx_data = shift[8:1];

////////////////////////////////////////////////////////////////////////////////
// State flops
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) state <= IDLE;
	else state <= next_state;
end 

////////////////////////////////////////////////////////////////////////////////
// rx_rdy
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) rx_rdy <= 1'b0;
	else if (rx_rdy_set) rx_rdy = 1'b1;
	else if (rx_rdy_clear) rx_rdy = 1'b0;
	else rx_rdy <= rx_rdy;
end 

////////////////////////////////////////////////////////////////////////////////
// Next state logic
always_comb begin
	next_state = IDLE;
	shift_en = 0;
	baud_rst = 0;
	baud_en = 0;
	index_rst = 0;
	index_en = 0;
	rx_rdy_set = 0;
	rx_rdy_clear = 0;
	case(state)
		IDLE	:	begin
					if (!RX) begin
						next_state = RECIEVE;
						baud_rst = 1;
						index_rst = 1;
						rx_rdy_clear = 1;
					end
					else if (clr_rx_rdy) rx_rdy_clear = 1;
					else next_state = IDLE;
				end
		RECIEVE	:	begin
					if (index == 4'h0) begin
						if (baud >= 12'h516) begin
							next_state = RECIEVE;
							shift_en = 1;
							baud_rst = 1;
							index_en = 1;		
						end
						else begin 
							next_state = RECIEVE;
							baud_en = 1;
						end
					end
					else if (index > 4'h0) begin
						if (baud >= 12'hA2B) begin
							shift_en = 1;
							baud_rst = 1;
							if (index >= 4'h9) begin
								next_state = IDLE;
								rx_rdy_set = 1'b1;
							end
							else begin
								next_state = RECIEVE;
								index_en = 1;	
							end	
						end
						else begin 
							next_state = RECIEVE;
							baud_en = 1;
						end
					end
				end
	endcase
end

endmodule
