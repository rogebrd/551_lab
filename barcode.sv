module barcode(clk, rst_n, BC, clr_ID_vld, ID, ID_vld);

input clk, rst_n;	// Clock and active low asynch reset
input BC;		// Signal from barcode IR sensor; high when not over a barcode, i.e., idle
input clr_ID_vld;	// Asserted by digital core to knock down 'ID_vld'
output reg [7:0] ID;	// 8-bit ID presented to digital core by this module
output reg ID_vld;	// Asserted by this module when 8-bit station ID has been read

reg BC_intermediate;	// Flops for double-flopping the 'BC' signal
reg BC_sync;		// 'BC_sync' can only change at negative clock edges

// State descriptions:
// IDLE - In this state before start bit is encountered, i.e., before 'BC_sync' transitions from high 
//        to low
// START - In this state for the duration of the start bit. Once every clock cycle, increment 
//         'half_period' register
// DETECT_FALL - Wait for the next falling edge of 'BC_sync'
// DELAY - Wait for time specified by contents of 'half_period', then samples and transitions to 
//         either DETECT_RISE or DONE depending on if there are more bits to read
// DETECT_RISE - Wait for the next rising edge of 'BC_sync'
// DONE - Reset the clocks and transition to IDLE once 'BC_sync' goes high
typedef enum reg[2:0] {IDLE, START, DETECT_FALL, DELAY, DETECT_RISE, DONE} state_t;
state_t state, next_state;

reg [21:0] half_period;		// Keeps track of how long half the duration of a bit period is
reg [21:0] timer;		// A timer that counts from 0 to the value in 'half_period'; 
				// module samples upon expiration of 'timer'
reg [2:0] bit_count;		// Keeps track of how many bits have been sampled. Upon reset, contains 0

// SM outputs
logic inc_half_period;		// These six signals control the above three regs by dictating when 
logic rst_half_period;		// they should increment and reset
logic inc_timer;
logic rst_timer;
logic inc_bit_count;
logic rst_bit_count;

logic sample;			// This signal indicates when the module should sample 'BC_sync'

logic rst_ID_vld;		// These two signals control behavior of 'ID_vld'
logic set_ID_vld;

// Double-flop the 'BC' signal to produce 'BC_sync'. Use "negedge clk" because we want 'BC_sync' to change 
// at negative clock edges only. The reason we do this is because in the state machine, there are times when 
// we want to check 'BC_sync' to see if it has gone low/high yet; these checks happen at positive clock edges, 
// so if 'BC_sync' changes at positive clock edges, then we've got a problem
always_ff @(negedge clk, negedge rst_n) begin
	if (!rst_n) begin
		BC_intermediate <= 1'b1;
		BC_sync <= 1'b1;
	end
	else begin
		BC_intermediate <= BC;
		BC_sync <= BC_intermediate;
	end
end

// Infer state flops
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) state <= IDLE;
	else state <= next_state;
end

// SM output and transition logic
always_comb begin
	// Default SM outputs and next_state
	inc_half_period = 1'b0;
	rst_half_period = 1'b0;
	inc_timer = 1'b0;
	rst_timer = 1'b0;
	inc_bit_count = 1'b0;
	rst_bit_count = 1'b0;
	sample = 1'b0;
	rst_ID_vld = 1'b0;
	set_ID_vld = 1'b0;
	next_state = IDLE;

	case (state)
		IDLE: begin
			if (clr_ID_vld) rst_ID_vld = 1'b1;
			if (!BC_sync) begin
				// Deassert 'ID_vld' to prevent the old barcode from being read. 
				// This is only needed in the event 'clr_ID_vld' is not asserted before 
				// the next barcode starts (this should not happen)
				rst_ID_vld = 1'b1;
				// Begin counting the number of clock cycles 
				// that half a bit period should be
				inc_half_period = 1'b1;
				next_state = START;
			end
		end
		START: begin
			if (!BC_sync) begin
				// Still in first half of the start bit
				inc_half_period = 1'b1;
				next_state = START;
			end
			else
				// Past the first half of the start bit. Wait 
				// for a falling edge in 'BC_sync'
				next_state = DETECT_FALL;
		end
		DETECT_FALL: begin
			if (BC_sync)
				// Keep waiting for that falling edge
				next_state = DETECT_FALL;
			else begin
				// Begin counting for the duration of half of the 
				// start bit
				inc_timer = 1'b1;
				next_state = DELAY;
			end
		end
		DELAY: begin
			if (timer < half_period) begin
				// Keep waiting for the duration of half of the 
				// start bit
				inc_timer = 1'b1;
				next_state = DELAY;
			end
			else begin
				// Half the duration of start bit has elapsed. Sample 
				// 'BC_sync' and reset 'timer'
				sample = 1'b1;
				rst_timer = 1'b1;
				// At this point, if 'bit_count' is x, then the module will have 
				// sampled 'BC_sync' x+1 times after the upcoming posedge clk. Therefore, 
				// once 'bit_count' is 7, we know we'll have sampled 8 times
				if (bit_count < 4'h7) begin
					// Keep sampling 'BC_sync'
					inc_bit_count = 1'b1;
					next_state = DETECT_RISE;
				end
				else
					// We'll have sampled 'BC_sync' 8 times after the next posedge 
					// clk, so transition to DONE
					next_state = DONE;
			end
		end
		DETECT_RISE: begin
			if (!BC_sync)
				// Keep waiting for a rising edge in 'BC_sync'
				next_state = DETECT_RISE;
			else
				// Now begin waiting for a falling edge in 'BC_sync'
				next_state = DETECT_FALL;
		end
		default: begin
			// Reset the regs and transition to IDLE
			rst_half_period = 1'b1;
			rst_bit_count = 1'b1;
			// Assert 'ID_vld' only if two most significant bits are 2'b00
			if (ID[7:6] == 2'b00) set_ID_vld = 1'b1;
			if (BC_sync) next_state = IDLE;
			else next_state = DONE;
		end
	endcase
end

// 'half_period' control logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) half_period <= 1'b0;
	else if (rst_half_period) half_period <= 1'b0;
	else if (inc_half_period) half_period <= half_period + 1'b1;
end

// 'timer' control logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) timer <= 1'b0;
	else if (rst_timer) timer <= 1'b0;
	else if (inc_timer) timer <= timer + 1'b1;
end

// 'bit_count' control logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) bit_count <= 1'b0;
	else if (rst_bit_count) bit_count <= 1'b0;
	else if (inc_bit_count) bit_count <= bit_count + 1'b1;
end

// Sampling logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) ID <= 1'b0;
	else if (sample) ID <= {ID[6:0], BC_sync};	// To sample, left shift ID and place 'BC_sync' in LSB
end

// 'ID_vld' logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) ID_vld <= 1'b0;
	else if (rst_ID_vld) ID_vld <= 1'b0;
	else if (set_ID_vld) ID_vld <= 1'b1;
end

endmodule
