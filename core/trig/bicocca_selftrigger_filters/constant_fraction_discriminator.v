`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 1, 2022, 5:51:46 PM
// Design Name: filtering_and_selftrigger
// Module Name: constant_fraction_discriminator.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module constant_fraction_discriminator(
    input wire clk,
	input wire reset,
    input wire enable,
    input wire signed[15:0] x,
    input wire signed[13:0] threshold,
    output wire trigger,
    output wire signed[15:0] y
);
    
	parameter shift_delay = 19;
    
    reg reset_reg, enable_reg;
    reg trigger_threshold, trigger_crossover, trigger_reg, increment_trigger_duration;

    reg signed [15:0] in_reg;
    reg signed [15:0] y_1, y_2;
    reg signed [17:0] in_mult;
    reg [11:0] counter_crossover, counter_threshold;

	wire signed [15:0] w1;

	wire signed [17:0] mult1;
	//wire signed [17:0] mult2;
	wire counter_crossover_signal;

	always @(posedge clk) begin
	   reset_reg <= reset;
	   enable_reg <= enable;
	end

	always @(posedge clk) begin
		if(reset_reg) begin
			in_reg <= 0;
		end else if(enable_reg) begin
			in_reg <= x;
            in_mult <= mult1>>>1;
			y_1 <= in_mult[17:2] - w1;
			y_2 <= y_1;
			trigger_reg <= (trigger_threshold && trigger_crossover);
		end
	end

	generate genvar i;
		for(i=0; i<=15; i=i+1) begin : srlc32e_i_inst
				SRLC32E #(
				   .INIT(32'h00000000),    // Initial contents of shift register
				   .IS_CLK_INVERTED(1'b0)  // Optional inversion for CLK
				)SRLC32E_inst (
			   .Q(w1[i]),     // 1-bit output: SRL Data
			   .Q31(), // 1-bit output: SRL Cascade Data
			   .A(shift_delay),     // 5-bit input: Selects SRL depth
			   .CE(enable_reg),   // 1-bit input: Clock enable
			   .CLK(clk), // 1-bit input: Clock
			   .D(in_reg[i])      // 1-bit input: SRL Data
			);
		end
	endgenerate

	//////////////////// TRIGGER CONDITIONS. ///////////////////////
    // threshold condition. DAPHNE signals have negative rising edge.
	always @(posedge clk) begin
	    if (reset_reg || counter_crossover_signal || counter_threshold[11]) begin
			trigger_threshold <= 1'b0;
			increment_trigger_duration <= 1'b0;
		end else if(enable_reg) begin
			if (($signed(in_reg) < -($signed(threshold))) || trigger_threshold) begin
				trigger_threshold <= 1'b1;
				if (($signed(in_reg) < -($signed(threshold<<3)))) begin 
			     	increment_trigger_duration <= 1'b1;
			    end
			end
		end
	end
    // threshold counter to wait for zero crossing, can be put is the process above 
    // but decided to separate it in another process block, just to make it more clear.
    // currently fixed at 128 cycles or samples.
    // Verified according to simulations.
	always @(posedge clk) begin
	    if (reset_reg || counter_crossover_signal) begin
	        counter_crossover <= 12'b0;
		end else if(enable_reg && trigger_crossover) begin
			counter_crossover <= counter_crossover + 1'b1;
		end
	end

	always @(posedge clk) begin
	    if (reset_reg || ~trigger_threshold) begin
	        counter_threshold <= 12'b0;
		end else if(enable_reg && trigger_threshold) begin
			counter_threshold <= counter_threshold + 1'b1;
		end
	end

    // zero crossing condition. 
	always @(posedge clk) begin
	    if (reset_reg || counter_crossover_signal) begin
	        trigger_crossover <= 1'b0;
		end else if(enable_reg && trigger_threshold && (counter_threshold >= 4)) begin
			if (($signed(y_1) >= $signed(16'd0)) && ($signed(y_2) < $signed(16'd0))) begin
			     trigger_crossover <= 1'b1;
			end
		end
	end
    
    assign counter_crossover_signal = (increment_trigger_duration == 1'b0) ?   counter_crossover[6] : 
             (increment_trigger_duration == 1'b1) ?   (counter_crossover[9] && counter_crossover[6]):
             1'bx;

    assign y = y_1;
    assign mult1 = {in_reg,2'b0};
    //assign mult2 = 18'b010011001100110011;
    assign trigger = trigger_reg;

endmodule