`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 1, 2022, 5:51:46 PM
// Design Name: filtering_and_selftrigger
// Module Name: moving_integrator_filter.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module moving_integrator_filter(
	input wire clk,
	input wire reset, 
	input wire enable, 
	input wire signed [15:0] x,
    output wire signed [15:0] y,
    output wire signed [15:0] x_delayed,
    output wire signed [15:0] sub
);
    
	parameter k = 31;
    
    reg reset_reg, enable_reg;
    reg signed [15:0] in_reg;
	reg signed [15:0] y_1_32, y_1_64, y_out_32, y_out_64, x_out_aux0, x_out_aux1, x_out_aux2, x_out_aux3, sub_reg;
	reg signed [15:0] wm_32, wm_64;
    
    wire signed [15:0] w2, w3;
	wire signed [21:0] w1, w4;
	//wire signed [24:0] mult1;
	//wire signed [17:0] mult2;


	always @(posedge clk) begin 
		if(reset) begin
			reset_reg <= 1'b1;
			enable_reg <= 1'b0;
		end else if (enable) begin
			reset_reg <= 1'b0;
			enable_reg <= 1'b1;
		end else begin 
			reset_reg <= 1'b0;
			enable_reg <= 1'b0;
		end
	end

	always @(posedge clk) begin
		if(reset_reg) begin
			y_1_32 <= 0;
			y_1_64 <= 0;
			in_reg <= 0;
			x_out_aux0 <= 0;
			x_out_aux1 <= 0;
			x_out_aux2 <= 0;
			x_out_aux3 <= 0;
			sub_reg <= 0;
		end else if(enable_reg) begin
			wm_32 <= {w1[21],w1[19:5]};
			wm_64 <= {w4[21],w4[20:6]};
			y_out_32 <= wm_32 + $signed(4);
			y_out_64 <= wm_64 + $signed(2);
			x_out_aux0 <= w2;
			x_out_aux1 <= x_out_aux0;
			x_out_aux2 <= x_out_aux1;
			x_out_aux3 <= x_out_aux2;
			sub_reg <= x_out_aux3 - y_out_64;
			y_1_32 <= w1;
			y_1_64 <= w4;
			in_reg <= x;
		end
	end

	generate genvar i;
		for(i=0; i<=15; i=i+1) begin : srlc32e_i_inst
				SRLC32E #(
				   .INIT(32'h00000000),    // Initial contents of shift register
				   .IS_CLK_INVERTED(1'b0)  // Optional inversion for CLK
					) 
					SRLC32E_inst_1 (
				   .Q(w2[i]),     // 1-bit output: SRL Data
				   .Q31(), // 1-bit output: SRL Cascade Data
				   .A(k),     // 5-bit input: Selects SRL depth
				   .CE(enable_reg),   // 1-bit input: Clock enable
				   .CLK(clk), // 1-bit input: Clock
				   .D(in_reg[i])      // 1-bit input: SRL Data
				);
			    SRLC32E #(
				   .INIT(32'h00000000),    // Initial contents of shift register
				   .IS_CLK_INVERTED(1'b0)  // Optional inversion for CLK
					) 
					SRLC32E_inst_2 (
				   .Q(w3[i]),     // 1-bit output: SRL Data
				   .Q31(), // 1-bit output: SRL Cascade Data
				   .A(k),     // 5-bit input: Selects SRL depth
				   .CE(enable_reg),   // 1-bit input: Clock enable
				   .CLK(clk), // 1-bit input: Clock
				   .D(w2[i])      // 1-bit input: SRL Data
				);
		end
	endgenerate

	assign w1 = in_reg + y_1_32 - w2;
	assign w4 = in_reg + y_1_64 - w3;
	//assign mult1 = w1;
	//assign mult2 = 18'b000010100011110110;
    assign y = y_out_32;
    assign x_delayed = x_out_aux3;
    assign sub = sub_reg;

endmodule