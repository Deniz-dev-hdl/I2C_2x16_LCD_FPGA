module FPGA_TOP #(
	parameter integer P_CLOCK_FREQ = 27_000_000,
	parameter integer P_I2C_FREQ = 400_000,
	parameter integer P_UART_BAUD_RATE = 115_200,
	parameter logic [6:0] P_I2C_LCD_ADDRESS = 7'h27
)(
	input  logic i_clk,
	input  logic i_uart_rx,
	output logic o_lcd_ready,
	output logic o_lcd_busy,
	output logic o_uart_overflow,
	output logic o_ack_error_led,
	inout  wire  io_sda,
	inout  wire  io_scl
);

	logic w_pll_out;
    logic w_pll_locked;

	    Gowin_rPLL PLL(
        .clkout(w_pll_out), //output clkout
        .lock(w_pll_locked), //output lock
        .clkin(i_clk) //input clkin
    );

	LCD_UART_TERMINAL #(
		.P_CLOCK_FREQ     (P_CLOCK_FREQ),
		.P_I2C_FREQ       (P_I2C_FREQ),
		.P_UART_BAUD_RATE (P_UART_BAUD_RATE),
		.P_I2C_LCD_ADDRESS(P_I2C_LCD_ADDRESS)
	) LCD_Terminal (
		.i_clk          (w_pll_out),
		.i_rst_n        (w_pll_locked),
		.i_uart_rx      (i_uart_rx),
		.i_backlight    (1'b1),
		.o_ready        (o_lcd_ready),
		.o_busy         (o_lcd_busy),
		.o_uart_overflow(o_uart_overflow),
		.o_ack_error    (o_ack_error_led),
		.io_sda         (io_sda),
		.io_scl         (io_scl)
	);

endmodule