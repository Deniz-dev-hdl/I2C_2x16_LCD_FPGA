module I2C_LCD_DRIVER #(
	parameter integer P_CLOCK_FREQ = 27_000_000,
	parameter integer P_I2C_FREQ = 400_000,
	parameter logic [6:0] P_I2C_LCD_ADDRESS = 7'h27
)(
	input  logic       i_clk,
	input  logic       i_rst_n,
	input  logic [7:0] i_data,
	input  logic       i_is_command,
	input  logic       i_backlight,
	input  logic       i_is_command_4_or_8,
	input  logic       i_start,
	output logic       o_busy,
	output logic       o_ack_error,
	inout  wire        io_sda,
	inout  wire        io_scl
);

	localparam integer P_5US_DELAY = (P_CLOCK_FREQ + 199_999) / 200_000;
	localparam integer P_DELAY_WIDTH = (P_5US_DELAY <= 1) ? 1 : $clog2(P_5US_DELAY);

	typedef enum logic [3:0] {
		S_IDLE,
		S_WRITE_ADDRESS_1,
		S_WRITE_DATA_1,
		S_WRITE_ADDRESS_2,
		S_WRITE_DATA_2,
		S_WRITE_ADDRESS_3,
		S_WRITE_DATA_3,
		S_WRITE_ADDRESS_4,
		S_WRITE_DATA_4,
		S_DONE
	} main_state;

	main_state r_main_state;

	logic                     r_ena;
	logic [6:0]               r_address;
	logic                     r_rw;
	logic [7:0]               r_data_buffer;
	logic [7:0]               r_data_in;
	logic [7:0]               w_data_out;
	logic                     r_start_prev;
	logic                     r_is_command;
	logic                     r_backlight;
	logic                     r_command_4_or_8;
	logic                     w_busy;
	logic                     r_busy_prev;
	logic                     w_ack_error;
	logic [P_DELAY_WIDTH-1:0] r_delay_counter;
	logic                     r_delay_start;
	logic                     r_delay_done;
	logic                     w_start_rising_edge;
	logic                     w_busy_rising_edge;
	logic                     w_busy_falling_edge;

	assign w_start_rising_edge = ~r_start_prev & i_start;
	assign w_busy_rising_edge  = ~r_busy_prev & w_busy;
	assign w_busy_falling_edge = r_busy_prev & ~w_busy;
	assign o_ack_error         = w_ack_error;

	i2c_master #(
		.input_clk(P_CLOCK_FREQ),
		.bus_clk  (P_I2C_FREQ)
	) I2C_Instance (
		.clk      (i_clk),
		.reset_n  (i_rst_n),
		.ena      (r_ena),
		.addr     (r_address),
		.rw       (r_rw),
		.data_wr  (r_data_in),
		.busy     (w_busy),
		.data_rd  (w_data_out),
		.ack_error(w_ack_error),
		.sda      (io_sda),
		.scl      (io_scl)
	);

	always_ff @(posedge i_clk) begin
		if (!i_rst_n) begin
			r_delay_counter <= '0;
			r_delay_done    <= 1'b0;
		end else if (r_delay_start) begin
			if (P_5US_DELAY <= 1) begin
				r_delay_counter <= '0;
				r_delay_done    <= 1'b1;
			end else if (r_delay_counter == P_5US_DELAY - 1) begin
				r_delay_counter <= r_delay_counter;
				r_delay_done    <= 1'b1;
			end else begin
				r_delay_counter <= r_delay_counter + 1'b1;
				r_delay_done    <= 1'b0;
			end
		end else begin
			r_delay_counter <= '0;
			r_delay_done    <= 1'b0;
		end
	end

	always_ff @(posedge i_clk) begin
		if (!i_rst_n) begin
			r_ena            <= 1'b0;
			r_address        <= P_I2C_LCD_ADDRESS;
			r_rw             <= 1'b0;
			r_data_buffer    <= 8'h00;
			r_data_in        <= 8'h00;
			r_start_prev     <= 1'b0;
			r_busy_prev      <= 1'b0;
			r_is_command     <= 1'b0;
			r_backlight      <= 1'b0;
			r_command_4_or_8 <= 1'b0;
			r_delay_start    <= 1'b0;
			o_busy           <= 1'b0;
			r_main_state     <= S_IDLE;
		end else begin
			r_start_prev <= i_start;
			r_busy_prev  <= w_busy;

			case (r_main_state)
				S_IDLE: begin
					r_ena         <= 1'b0;
					r_delay_start <= 1'b0;
					o_busy        <= 1'b0;
					if (w_start_rising_edge) begin
						r_data_buffer    <= i_data;
						r_is_command     <= i_is_command;
						r_backlight      <= i_backlight;
						r_command_4_or_8 <= i_is_command_4_or_8;
						o_busy           <= 1'b1;
						r_main_state     <= S_WRITE_ADDRESS_1;
					end
				end

				S_WRITE_ADDRESS_1: begin
					r_data_in <= {r_data_buffer[7:4], r_backlight, 1'b1, 1'b0, r_is_command};
					r_ena     <= 1'b1;
					if (w_busy_rising_edge) begin
						r_ena        <= 1'b0;
						r_main_state <= S_WRITE_DATA_1;
					end
				end

				S_WRITE_DATA_1: begin
					if (w_busy_falling_edge)
						r_main_state <= S_WRITE_ADDRESS_2;
				end

				S_WRITE_ADDRESS_2: begin
					r_data_in <= {r_data_buffer[7:4], r_backlight, 1'b0, 1'b0, r_is_command};
					r_ena     <= 1'b1;
					if (w_busy_rising_edge) begin
						r_ena        <= 1'b0;
						r_main_state <= S_WRITE_DATA_2;
					end
				end

				S_WRITE_DATA_2: begin
					if (w_busy_falling_edge)
						r_delay_start <= 1'b1;
					if (r_delay_done) begin
						r_delay_start <= 1'b0;
						if (r_command_4_or_8)
							r_main_state <= S_DONE;
						else
							r_main_state <= S_WRITE_ADDRESS_3;
					end
				end

				S_WRITE_ADDRESS_3: begin
					r_data_in <= {r_data_buffer[3:0], r_backlight, 1'b1, 1'b0, r_is_command};
					r_ena     <= 1'b1;
					if (w_busy_rising_edge) begin
						r_ena        <= 1'b0;
						r_main_state <= S_WRITE_DATA_3;
					end
				end

				S_WRITE_DATA_3: begin
					if (w_busy_falling_edge)
						r_main_state <= S_WRITE_ADDRESS_4;
				end

				S_WRITE_ADDRESS_4: begin
					r_data_in <= {r_data_buffer[3:0], r_backlight, 1'b0, 1'b0, r_is_command};
					r_ena     <= 1'b1;
					if (w_busy_rising_edge) begin
						r_ena        <= 1'b0;
						r_main_state <= S_WRITE_DATA_4;
					end
				end

				S_WRITE_DATA_4: begin
					if (w_busy_falling_edge)
						r_delay_start <= 1'b1;
					if (r_delay_done) begin
						r_delay_start <= 1'b0;
						r_main_state  <= S_DONE;
					end
				end

				S_DONE: begin
					r_ena         <= 1'b0;
					r_delay_start <= 1'b0;
					o_busy        <= 1'b0;
					r_main_state  <= S_IDLE;
				end

				default: begin
					r_ena         <= 1'b0;
					r_delay_start <= 1'b0;
					o_busy        <= 1'b0;
					r_main_state  <= S_IDLE;
				end
			endcase
		end
	end

endmodule
