module I2C_LCD_CONTROLLER #(
	parameter integer P_CLOCK_FREQ = 27_000_000,
	parameter integer P_I2C_FREQ = 400_000,
	parameter logic [6:0] P_I2C_LCD_ADDRESS = 7'h27
)(
	input  logic i_clk,
	input  logic i_rst_n,
	input  logic i_start,
	input  logic i_backlight,
	output logic o_busy,
	output logic o_done,
	output logic o_ack_error,
	inout  wire  io_sda,
	inout  wire  io_scl
);

	typedef enum logic [3:0] {
		S_IDLE,
		S_DISPATCH,
		S_WAIT_LCD_BUSY,
		S_WAIT_LCD_DONE,
		S_WAIT_DELAY_BUSY,
		S_WAIT_DELAY_DONE,
		S_DONE
	} control_state;

	control_state r_state;

	logic        r_start_prev;
	logic [4:0]  r_step;
	logic        r_lcd_start;
	logic [7:0]  w_lcd_data;
	logic        w_lcd_is_data;
	logic        w_lcd_mode_8;
	logic        w_lcd_busy;
	logic        r_delay_start;
	logic [10:0] w_delay_count;
	logic        w_delay_busy;
	logic        w_delay_done;
	logic        w_start_rising_edge;

	assign w_start_rising_edge = ~r_start_prev & i_start;

	always_comb begin
		w_lcd_data    = 8'h00;
		w_lcd_is_data = 1'b0;
		w_lcd_mode_8  = 1'b0;
		w_delay_count = 11'd2;

		case (r_step)
			5'd0:  w_delay_count = 11'd1024;
			5'd1:  w_delay_count = 11'd1024;
			5'd2:  w_delay_count = 11'd512;
			5'd3:  begin w_lcd_data = 8'h30; w_lcd_mode_8 = 1'b1; w_delay_count = 11'd250; end
			5'd4:  begin w_lcd_data = 8'h30; w_lcd_mode_8 = 1'b1; w_delay_count = 11'd5; end
			5'd5:  begin w_lcd_data = 8'h30; w_lcd_mode_8 = 1'b1; w_delay_count = 11'd5; end
			5'd6:  begin w_lcd_data = 8'h20; w_lcd_mode_8 = 1'b1; w_delay_count = 11'd5; end
			5'd7:  w_lcd_data = 8'h28;
			5'd8:  w_lcd_data = 8'h08;
			5'd9:  begin w_lcd_data = 8'h01; w_delay_count = 11'd100; end
			5'd10: w_lcd_data = 8'h06;
			5'd11: w_lcd_data = 8'h0C;
			5'd12: begin w_lcd_data = 8'h48; w_lcd_is_data = 1'b1; end
			5'd13: begin w_lcd_data = 8'h65; w_lcd_is_data = 1'b1; end
			5'd14: begin w_lcd_data = 8'h6C; w_lcd_is_data = 1'b1; end
			5'd15: begin w_lcd_data = 8'h6C; w_lcd_is_data = 1'b1; end
			5'd16: begin w_lcd_data = 8'h6F; w_lcd_is_data = 1'b1; end
			5'd17: begin w_lcd_data = 8'h20; w_lcd_is_data = 1'b1; end
			5'd18: begin w_lcd_data = 8'h57; w_lcd_is_data = 1'b1; end
			5'd19: begin w_lcd_data = 8'h6F; w_lcd_is_data = 1'b1; end
			5'd20: begin w_lcd_data = 8'h72; w_lcd_is_data = 1'b1; end
			5'd21: begin w_lcd_data = 8'h6C; w_lcd_is_data = 1'b1; end
			5'd22: begin w_lcd_data = 8'h64; w_lcd_is_data = 1'b1; end
			default: begin
				w_lcd_data    = 8'h00;
				w_lcd_is_data = 1'b0;
				w_lcd_mode_8  = 1'b0;
				w_delay_count = 11'd2;
			end
		endcase
	end

	I2C_LCD_DRIVER #(
		.P_CLOCK_FREQ     (P_CLOCK_FREQ),
		.P_I2C_FREQ       (P_I2C_FREQ),
		.P_I2C_LCD_ADDRESS(P_I2C_LCD_ADDRESS)
	) LCD_Driver (
		.i_clk              (i_clk),
		.i_rst_n            (i_rst_n),
		.i_data             (w_lcd_data),
		.i_is_command       (w_lcd_is_data),
		.i_backlight        (i_backlight),
		.i_is_command_4_or_8(w_lcd_mode_8),
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
		.i_repeat_count(w_delay_count),
		.o_busy        (w_delay_busy),
		.o_done        (w_delay_done)
	);

	always_ff @(posedge i_clk) begin
		if (!i_rst_n) begin
			r_state       <= S_IDLE;
			r_start_prev  <= 1'b0;
			r_step        <= 5'd0;
			r_lcd_start   <= 1'b0;
			r_delay_start <= 1'b0;
			o_busy        <= 1'b0;
			o_done        <= 1'b0;
		end else begin
			r_start_prev  <= i_start;
			r_lcd_start   <= 1'b0;
			r_delay_start <= 1'b0;

			case (r_state)
				S_IDLE: begin
					o_busy <= 1'b0;
					o_done <= 1'b0;
					if (w_start_rising_edge) begin
						r_step    <= 5'd0;
						o_busy    <= 1'b1;
						r_state   <= S_DISPATCH;
					end
				end

				S_DISPATCH: begin
					if (r_step <= 5'd2) begin
						r_delay_start <= 1'b1;
						r_state       <= S_WAIT_DELAY_BUSY;
					end else begin
						r_lcd_start <= 1'b1;
						r_state     <= S_WAIT_LCD_BUSY;
					end
				end

				S_WAIT_LCD_BUSY: begin
					if (w_lcd_busy)
						r_state <= S_WAIT_LCD_DONE;
				end

				S_WAIT_LCD_DONE: begin
					if (!w_lcd_busy) begin
						r_delay_start <= 1'b1;
						r_state       <= S_WAIT_DELAY_BUSY;
					end
				end

				S_WAIT_DELAY_BUSY: begin
					if (w_delay_busy)
						r_state <= S_WAIT_DELAY_DONE;
				end

				S_WAIT_DELAY_DONE: begin
					if (w_delay_done) begin
						if (r_step == 5'd22) begin
							o_busy  <= 1'b0;
							o_done  <= 1'b1;
							r_state <= S_DONE;
						end else begin
							r_step  <= r_step + 1'b1;
							r_state <= S_DISPATCH;
						end
					end
				end

				S_DONE: begin
					o_busy <= 1'b0;
					o_done <= 1'b1;
					if (!i_start)
						r_state <= S_IDLE;
				end

				default: begin
					r_state <= S_IDLE;
					o_busy  <= 1'b0;
					o_done  <= 1'b0;
				end
			endcase
		end
	end

endmodule
