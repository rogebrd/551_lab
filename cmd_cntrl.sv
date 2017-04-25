module cmd_cntrl(cmd, cmd_rdy, clr_cmd_rdy, in_transit, OK2Move, go, buzz, buzz_n, ID, ID_vld, clr_ID_vld, clk, rst_n);

input [7:0] cmd;
input cmd_rdy;
input OK2Move;
input [7:0] ID;
input ID_vld;
input clk, rst_n;
output reg clr_cmd_rdy;
output reg in_transit;
output go;
output reg buzz;
output buzz_n;
output reg clr_ID_vld;

reg [5:0] dest_ID;
reg buzz_en;
reg [15:0] buzz_cnt;

// State descriptions:
// IDLE - Robot is not currently moving
// TRANSIT - Robot is currently moving
typedef enum reg {IDLE, TRANSIT} state_t;
state_t state, next_state;

// SM outputs
logic set_in_transit;
logic clr_in_transit;
logic capture_ID;

// Infer state flops
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) state <= IDLE;
	else state <= next_state;
end

always_comb begin
	// Default SM outputs and 'next_state'
	clr_cmd_rdy = 1'b0;
	clr_ID_vld = 1'b0;
	set_in_transit = 1'b0;
	clr_in_transit = 1'b0;
	capture_ID = 1'b0;
	next_state = IDLE;

	case (state)
		IDLE: begin
			// "Go" command received. Latch destination ID
			if (cmd_rdy && (cmd[7:6] == 2'b01)) begin
				clr_cmd_rdy = 1'b1;
				set_in_transit = 1'b1;
				capture_ID = 1'b1;
				next_state = TRANSIT;
			end
			// Otherwise stay in default IDLE state
		end
		TRANSIT: begin
			// New "go" command received. Update destination ID
			if (cmd_rdy && (cmd[7:6] == 2'b01)) begin
				clr_cmd_rdy = 1'b1;
				capture_ID = 1'b1;
				next_state = TRANSIT;
			end
			// "Stop" command received
			else if (cmd_rdy && (cmd[7:6] == 2'b00)) begin
				clr_cmd_rdy = 1'b1;
				clr_in_transit = 1'b1;
			end
			// Barcode ID received, but not our destination. Keep moving
			else if (ID_vld && (ID != dest_ID)) begin
				clr_ID_vld = 1'b1;
				next_state = TRANSIT;
			end
			// Arrived at the destination. Stop
			else if (ID_vld && (ID == dest_ID)) begin
				clr_ID_vld = 1'b1;
				clr_in_transit = 1'b1;
			end
			// Otherwise
			else next_state = TRANSIT;
		end
	endcase
end

assign go = in_transit && OK2Move;
assign buzz_en = in_transit && !OK2Move;
assign buzz_n = ~buzz;

// buzzer counter
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) buzz_cnt <= 16'h0000;
	else if (buzz_cnt >= 16'h30D4) buzz_cnt <= 16'h0000;
	else if (buzz_en) buzz_cnt <= buzz_cnt + 1'b1;
	else buzz_cnt <= buzz_cnt;
end

// buzzer oscillator
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) buzz <= 1'b0;
	else if (buzz_cnt >= 16'h30D4) buzz <= ~buzz;
	else buzz <= buzz;
end

// 'in_transit' control logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) in_transit <= 1'b0;
	else if (clr_in_transit) in_transit <= 1'b0;
	else if (set_in_transit) in_transit <= 1'b1;
	else in_transit <= in_transit;
end

// 'dest_ID' control logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) dest_ID <= 1'b0;
	else if (capture_ID) dest_ID <= cmd[5:0];
	else dest_ID <= dest_ID;
end

endmodule
