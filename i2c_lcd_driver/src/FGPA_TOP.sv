module FPGA_TOP #(
	parameter integer P_CLOCK_FREQ = 27_000_000,
	parameter integer P_I2C_FREQ = 400_000,
	parameter logic [6:0] P_I2C_LCD_ADDRESS = 7'h27
)(
	input  logic i_clk,
	output logic o_lcd_busy,
	output logic o_lcd_done,
	output logic o_ack_error,
	inout  wire  io_sda,
	inout  wire  io_scl
);
    logic w_pll_out;
    logic w_pll_locked;
	logic r_start;
	logic r_started;

	always_ff @(posedge w_pll_out) begin
		if (!w_pll_locked) begin
			r_start   <= 1'b0;
			r_started <= 1'b0;
		end else begin
			if (!r_started) begin
				r_start   <= 1'b1;
				r_started <= 1'b1;
			end else begin
				r_start <= 1'b0;
			end
		end
	end
    
    Gowin_rPLL PLL(
        .clkout(w_pll_out), //output clkout
        .lock(w_pll_locked), //output lock
        .clkin(i_clk) //input clkin
    );

	I2C_LCD_CONTROLLER #(
		.P_CLOCK_FREQ     (P_CLOCK_FREQ),
		.P_I2C_FREQ       (P_I2C_FREQ),
		.P_I2C_LCD_ADDRESS(P_I2C_LCD_ADDRESS)
	) LCD_Hello_World (
		.i_clk      (w_pll_out),
		.i_rst_n    (w_pll_locked),
		.i_start    (r_start),
		.i_backlight(1'b1),
		.o_busy     (o_lcd_busy),
		.o_done     (o_lcd_done),
		.o_ack_error(o_ack_error),
		.io_sda     (io_sda),
		.io_scl     (io_scl)
	);

endmodule