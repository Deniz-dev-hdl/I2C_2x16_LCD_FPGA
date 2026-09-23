module LCD_UART_TERMINAL #(
	parameter integer P_CLOCK_FREQ = 27_000_000,
	parameter integer P_I2C_FREQ = 400_000,
	parameter integer P_UART_BAUD_RATE = 115_200,
	parameter logic [6:0] P_I2C_LCD_ADDRESS = 7'h27
)(
	input  logic i_clk,
	input  logic i_rst_n,
	input  logic i_uart_rx,
	input  logic i_backlight,
	output logic o_ready,
	output logic o_busy,
	output logic o_uart_overflow,
	output logic o_ack_error,
	inout  wire  io_sda,
	inout  wire  io_scl
);

	typedef enum logic [3:0] {
		S_IDLE,
		S_INIT_DISPATCH,
		S_READY,
		S_READ_FIFO,
		S_DECODE,
		S_LCD_START,
		S_LCD_WAIT_BUSY,
		S_LCD_WAIT_DONE,
		S_DELAY_START,
		S_DELAY_WAIT_BUSY,
		S_DELAY_WAIT_DONE
	} terminal_state;

	typedef enum logic [2:0] {
		A_INIT,
		A_CHARACTER,
		A_CURSOR,
		A_CLEAR
	} after_delay_state;

	terminal_state    r_state;
	after_delay_state r_after_delay;

	logic [7:0]  w_uart_data;
	logic        w_uart_valid;

	logic [7:0]  w_fifo_data;
	logic        w_fifo_empty;
	logic        w_fifo_full;
	logic        r_fifo_read;

	logic [3:0]  r_init_step;
	logic [7:0]  r_character;
	logic        r_row;
	logic [3:0]  r_column;

	logic [7:0]  r_lcd_data;
	logic        r_lcd_is_data;
	logic        r_lcd_mode_8;
	logic        r_lcd_start;
	logic        w_lcd_busy;

	logic        r_delay_start;
	logic [10:0] r_delay_count;
	logic        w_delay_busy;
	logic        w_delay_done;

	logic [7:0]  w_init_data;
	logic        w_init_mode_8;
	logic [10:0] w_init_delay;

	UART_RX #(
		.P_CLOCK_FREQ(P_CLOCK_FREQ),
		.P_BAUD_RATE (P_UART_BAUD_RATE)
	) UART_Receiver (
		.i_clk       (i_clk),
		.i_rst_n     (i_rst_n),
		.i_uart_rx   (i_uart_rx),
		.o_data      (w_uart_data),
		.o_data_valid(w_uart_valid)
	);

	BYTE_FIFO_32 UART_FIFO (
		.i_clk        (i_clk),
		.i_rst_n      (i_rst_n),
		.i_write      (w_uart_valid),
		.i_write_data (w_uart_data),
		.i_read       (r_fifo_read),
		.o_read_data  (w_fifo_data),
		.o_empty      (w_fifo_empty),
		.o_full       (w_fifo_full),
		.o_overflow   (o_uart_overflow)
	);

	I2C_LCD_DRIVER #(
		.P_CLOCK_FREQ     (P_CLOCK_FREQ),
		.P_I2C_FREQ       (P_I2C_FREQ),
		.P_I2C_LCD_ADDRESS(P_I2C_LCD_ADDRESS)
	) LCD_Driver (
		.i_clk              (i_clk),
		.i_rst_n            (i_rst_n),
		.i_data             (r_lcd_data),
		.i_is_command       (r_lcd_is_data),
		.i_backlight        (i_backlight),
		.i_is_command_4_or_8(r_lcd_mode_8),
		.i_start            (r_lcd_start),
		.o_busy             (w_lcd_busy),
		.o_ack_error        (o_ack_error),
		.io_sda             (io_sda),
		.io_scl             (io_scl)
	);

	DELAY_20US_R #(
		.P_CLOCK_FREQ(P_CLOCK_FREQ)
	) Delay_Instance (
		.i_clk         (i_clk),
		.i_rst_n       (i_rst_n),
		.i_start       (r_delay_start),
		.i_repeat_count(r_delay_count),
		.o_busy        (w_delay_busy),
		.o_done        (w_delay_done)
	);

	always_comb begin
		w_init_data   = 8'h00;
		w_init_mode_8 = 1'b0;
		w_init_delay  = 11'd2;

		case (r_init_step)
			4'd0:  w_init_delay = 11'd1024;
			4'd1:  w_init_delay = 11'd1024;
			4'd2:  w_init_delay = 11'd512;
			4'd3:  begin
				w_init_data   = 8'h30;
				w_init_mode_8 = 1'b1;
				w_init_delay  = 11'd250;
			end
			4'd4:  begin
				w_init_data   = 8'h30;
				w_init_mode_8 = 1'b1;
				w_init_delay  = 11'd5;
			end
			4'd5:  begin
				w_init_data   = 8'h30;
				w_init_mode_8 = 1'b1;
				w_init_delay  = 11'd5;
			end
			4'd6:  begin
				w_init_data   = 8'h20;
				w_init_mode_8 = 1'b1;
				w_init_delay  = 11'd5;
			end
			4'd7: begin
				w_init_data  = 8'h28;
				w_init_delay = 11'd2;
			end
			4'd8: begin
				w_init_data  = 8'h08;
				w_init_delay = 11'd2;
			end
			4'd9: begin
				w_init_data  = 8'h01;
				w_init_delay = 11'd100;
			end
			4'd10: begin
				w_init_data  = 8'h06;
				w_init_delay = 11'd2;
			end
			4'd11: begin
				w_init_data  = 8'h0C;
				w_init_delay = 11'd2;
			end
			default: begin
				w_init_data   = 8'h00;
				w_init_mode_8 = 1'b0;
				w_init_delay  = 11'd2;
			end
		endcase
	end

	always_ff @(posedge i_clk) begin
		if (!i_rst_n) begin
			r_state         <= S_IDLE;
			r_after_delay   <= A_INIT;
			r_fifo_read     <= 1'b0;
			r_init_step     <= 4'd0;
			r_character     <= 8'h00;
			r_row           <= 1'b0;
			r_column        <= 4'd0;
			r_lcd_data      <= 8'h00;
			r_lcd_is_data   <= 1'b0;
			r_lcd_mode_8    <= 1'b0;
			r_lcd_start     <= 1'b0;
			r_delay_start   <= 1'b0;
			r_delay_count   <= 11'd1;
			o_ready         <= 1'b0;
			o_busy          <= 1'b1;
		end else begin
			r_fifo_read   <= 1'b0;
			r_lcd_start   <= 1'b0;
			r_delay_start <= 1'b0;

			case (r_state)
				S_IDLE: begin
					o_ready     <= 1'b0;
					o_busy      <= 1'b1;
					r_init_step <= 4'd0;
					r_row       <= 1'b0;
					r_column    <= 4'd0;
					r_state     <= S_INIT_DISPATCH;
				end

				S_INIT_DISPATCH: begin
					if (r_init_step <= 4'd2) begin
						r_delay_count <= w_init_delay;
						r_after_delay <= A_INIT;
						r_state       <= S_DELAY_START;
					end else begin
						r_lcd_data    <= w_init_data;
						r_lcd_is_data <= 1'b0;
						r_lcd_mode_8  <= w_init_mode_8;
						r_delay_count <= w_init_delay;
						r_after_delay <= A_INIT;
						r_state       <= S_LCD_START;
					end
				end

				S_READY: begin
					o_ready <= 1'b1;
					o_busy  <= 1'b0;

					if (!w_fifo_empty) begin
						r_character <= w_fifo_data;
						r_fifo_read <= 1'b1;
						o_busy      <= 1'b1;
						r_state     <= S_READ_FIFO;
					end
				end

				S_READ_FIFO: begin
					r_state <= S_DECODE;
				end

				S_DECODE: begin
					if ((r_character >= 8'h20) && (r_character <= 8'h7E)) begin
						r_lcd_data    <= r_character;
						r_lcd_is_data <= 1'b1;
						r_lcd_mode_8  <= 1'b0;
						r_delay_count <= 11'd2;
						r_after_delay <= A_CHARACTER;
						r_state       <= S_LCD_START;
					end else if (r_character == 8'h0D) begin
						r_column      <= 4'd0;
						r_lcd_data    <= r_row ? 8'hC0 : 8'h80;
						r_lcd_is_data <= 1'b0;
						r_lcd_mode_8  <= 1'b0;
						r_delay_count <= 11'd2;
						r_after_delay <= A_CURSOR;
						r_state       <= S_LCD_START;
					end else if (r_character == 8'h0A) begin
						r_row         <= ~r_row;
						r_column      <= 4'd0;
						r_lcd_data    <= r_row ? 8'h80 : 8'hC0;
						r_lcd_is_data <= 1'b0;
						r_lcd_mode_8  <= 1'b0;
						r_delay_count <= 11'd2;
						r_after_delay <= A_CURSOR;
						r_state       <= S_LCD_START;
					end else if (r_character == 8'h08) begin
						if (r_column != 0) begin
							r_column      <= r_column - 1'b1;
							r_lcd_data    <= (r_row ? 8'hC0 : 8'h80) + r_column - 1'b1;
							r_lcd_is_data <= 1'b0;
							r_lcd_mode_8  <= 1'b0;
							r_delay_count <= 11'd2;
							r_after_delay <= A_CURSOR;
							r_state       <= S_LCD_START;
						end else begin
							r_state <= S_READY;
						end
					end else if (r_character == 8'h0C) begin
						r_lcd_data    <= 8'h01;
						r_lcd_is_data <= 1'b0;
						r_lcd_mode_8  <= 1'b0;
						r_delay_count <= 11'd100;
						r_after_delay <= A_CLEAR;
						r_state       <= S_LCD_START;
					end else begin
						r_state <= S_READY;
					end
				end

				S_LCD_START: begin
					r_lcd_start <= 1'b1;
					r_state     <= S_LCD_WAIT_BUSY;
				end

				S_LCD_WAIT_BUSY: begin
					if (w_lcd_busy)
						r_state <= S_LCD_WAIT_DONE;
				end

				S_LCD_WAIT_DONE: begin
					if (!w_lcd_busy)
						r_state <= S_DELAY_START;
				end

				S_DELAY_START: begin
					r_delay_start <= 1'b1;
					r_state       <= S_DELAY_WAIT_BUSY;
				end

				S_DELAY_WAIT_BUSY: begin
					if (w_delay_busy)
						r_state <= S_DELAY_WAIT_DONE;
				end

				S_DELAY_WAIT_DONE: begin
					if (w_delay_done) begin
						case (r_after_delay)
							A_INIT: begin
								if (r_init_step == 4'd11) begin
									o_ready <= 1'b1;
									o_busy  <= 1'b0;
									r_state <= S_READY;
								end else begin
									r_init_step <= r_init_step + 1'b1;
									r_state     <= S_INIT_DISPATCH;
								end
							end

							A_CHARACTER: begin
								if (r_column == 4'd15) begin
									r_column      <= 4'd0;
									r_row         <= ~r_row;
									r_lcd_data    <= r_row ? 8'h80 : 8'hC0;
									r_lcd_is_data <= 1'b0;
									r_lcd_mode_8  <= 1'b0;
									r_delay_count <= 11'd2;
									r_after_delay <= A_CURSOR;
									r_state       <= S_LCD_START;
								end else begin
									r_column <= r_column + 1'b1;
									r_state  <= S_READY;
								end
							end

							A_CURSOR: begin
								r_state <= S_READY;
							end

							A_CLEAR: begin
								r_row    <= 1'b0;
								r_column <= 4'd0;
								r_state  <= S_READY;
							end

							default: begin
								r_state <= S_READY;
							end
						endcase
					end
				end

				default: begin
					r_state <= S_IDLE;
				end
			endcase
		end
	end

endmodule