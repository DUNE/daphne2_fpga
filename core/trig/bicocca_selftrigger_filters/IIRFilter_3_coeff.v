`timescale 1ns / 10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: January 5, 2026, 9:26:00 PM
// Design Name: IIR filters 4 coeff
// Module Name: IIRFilter_4_coeff.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////

module IIRFilter_3_coeff #(
    parameter n1_i = 18'h0,
    parameter n2_i = 18'h0,
    parameter n3_i = 18'h0,
    parameter d1_i = 18'h0,
    parameter d2_i = 18'h0,
    parameter d3_i = 18'h0
)(
    input  wire              clk,
    input  wire              reset,
    input  wire              enable,
    input  wire signed [15:0] x,
    output wire signed [15:0] y
);

    reg  signed [17:0] n1, n2, n3, d1, d2, d3;
    reg  signed [15:0] x_i, en_mux;
    reg                enable_reg, reset_reg;

    wire signed [47:0] w1, w2, w3, w4;
    wire signed [47:0] w5, w6; // w7, w8;

    //wire signed [47:0] w1_i, w2_i, w3_i, w4_i;
    //wire signed [47:0] w5_i, w6_i; // w7_i, w8_i;

    wire signed [47:0] w1s_i;
    wire signed [47:0] w2s_i;
    wire signed [47:0] w3s_i;
    //wire signed [24:0] w4s_i;

    wire signed [24:0] x_ii, y_i;

    reg  signed [47:0] w1s;
    reg  signed [47:0] w2s;
    reg  signed [47:0] w3s;
    //reg signed [24:0] w4s;

    initial begin
        reset_reg  <= 1'b0;
        enable_reg <= 1'b0;

        n1 <= n1_i;
        n2 <= n2_i;
        n3 <= n3_i;
        //n4 <= {3'b,15'b};

        d1 <= d1_i;
        d2 <= d2_i;
        d3 <= d3_i;
        //d4 <= {3'b,15'b};

        x_i <= 16'b0;

        w1s <= 47'b0;
        w2s <= 47'b0;
        w3s <= 47'b0;
        //w4s <= 25'b0;

        en_mux <= 16'b0;
    end

    always @(posedge clk) begin
        reset_reg  <= reset;
        enable_reg <= enable;
    end

    always @(posedge clk) begin
        if (reset_reg) begin
            // These coefficients correspond to the PMT 1st compensator filter
            n1 <= n1_i;
            n2 <= n2_i;
            n3 <= n3_i;
            //n4 <= {3'b,15'b};

            d1 <= d1_i;
            d2 <= d2_i;
            d3 <= d3_i;
            //d4 <= {3'b,15'b};

            w1s <= 47'b0;
            w2s <= 47'b0;
            w3s <= 47'b0;
            //w4s <= 25'b0;
        end else if (enable_reg) begin
            x_i <= x;

            w1s <= w1s_i;
            w2s <= w2s_i;
            w3s <= w3s_i;
            //w4s <= w4s_i;
        end
    end

    always @(posedge clk) begin
        if (enable_reg) begin
            en_mux <= y_i[24:9];
        end else begin
            en_mux <= x;
        end
    end

    assign x_ii = {x_i, 9'b0};

    assign w1 = n1 * x_ii;
    //assign w1 = w1_i[39:15];

    assign w2 = d1 * y_i;
    //assign w2 = w2_i[39:15];

    assign w3 = n2 * x_ii;
    //assign w3 = w3_i[39:15];

    assign w4 = d2 * y_i;
    //assign w4 = w4_i[39:15];

    assign w5 = n3 * x_ii;
    //assign w5 = w5_i[39:15];

    assign w6 = d3 * y_i;
    //assign w6 = w6_i[39:15];

    //assign w7_i = a4*x_ii;
    //assign w7 = w7_i[39:15];
    //assign w8_i = b4*y_i;
    //assign w8 = w8_i[39:15];

    //assign w4s_i = w7 + w8;

    assign w3s_i = w5 + w6; // + w4s;
    assign w2s_i = w3 + w4 + w3s;
    assign w1s_i = w1 + w2 + w2s;

    assign y_i = x_ii + w1s[39:15];
    assign y   = en_mux;

endmodule