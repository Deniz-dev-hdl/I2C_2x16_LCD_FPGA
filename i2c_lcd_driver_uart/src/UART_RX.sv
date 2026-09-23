module UART_RX #(
	parameter integer P_CLOCK_FREQ = 27_000_000,
	parameter integer P_BAUD_RATE  = 115_200
)(
	input  logic       i_clk,
	input  logic       i_rst_n,
	input  logic       i_uart_rx,
	output logic [7:0] o_data,
	output logic       o_data_valid
);

	localparam integer P_CLKS_PER_BIT = (P_CLOCK_FREQ + (P_BAUD_RATE / 2)) / P_BAUD_RATE;
	localparam integer P_COUNTER_WIDTH = (P_CLKS_PER_BIT <= 1) ? 1 : $clog2(P_CLKS_PER_BIT);

	typedef enum logic [1:0] {
		S_IDLE,
		S_START,
		S_DATA,
		S_STOP
	} uart_state;

	uart_state r_state;

	logic                       r_rx_meta;
	logic                       r_rx_sync;
	logic [P_COUNTER_WIDTH-1:0] r_clock_counter;
	logic [2:0]                 r_bit_index;
	logic [7:0]                 r_data;

	always_ff @(posedge i_clk) begin
		if (!i_rst_n) begin
			r_rx_meta <= 1'b1;
			r_rx_sync <= 1'b1;
		end else begin
			r_rx_meta <= i_uart_rx;
			r_rx_sync <= r_rx_meta;
		end
	end

	always_ff @(posedge i_clk) begin
		if (!i_rst_n) begin
			r_state         <= S_IDLE;
			r_clock_counter <= '0;
			r_bit_index     <= '0;
			r_data          <= 8'h00;
			o_data          <= 8'h00;
			o_data_valid    <= 1'b0;
		end else begin
			o_data_valid <= 1'b0;

			case (r_state)
				S_IDLE: begin
					r_clock_counter <= '0;
					r_bit_index     <= '0;

					if (!r_rx_sync)
						r_state <= S_START;
				end

				S_START: begin
					if (r_clock_counter == (P_CLKS_PER_BIT / 2) - 1) begin
						r_clock_counter <= '0;

						if (!r_rx_sync)
							r_state <= S_DATA;
						else
							r_state <= S_IDLE;
					end else begin
						r_clock_counter <= r_clock_counter + 1'b1;
					end
				end

				S_DATA: begin
					if (r_clock_counter == P_CLKS_PER_BIT - 1) begin
						r_clock_counter       <= '0;
						r_data[r_bit_index]   <= r_rx_sync;

						if (r_bit_index == 3'd7) begin
							r_bit_index <= '0;
							r_state     <= S_STOP;
						end else begin
							r_bit_index <= r_bit_index + 1'b1;
						end
					end else begin
						r_clock_counter <= r_clock_counter + 1'b1;
					end
				end

				S_STOP: begin
					if (r_clock_counter == P_CLKS_PER_BIT - 1) begin
						r_clock_counter <= '0;
						r_state         <= S_IDLE;

						if (r_rx_sync) begin
							o_data       <= r_data;
							o_data_valid <= 1'b1;
						end
					end else begin
						r_clock_counter <= r_clock_counter + 1'b1;
					end
				end

				default: begin
					r_state <= S_IDLE;
				end
			endcase
		end
	end

endmodule