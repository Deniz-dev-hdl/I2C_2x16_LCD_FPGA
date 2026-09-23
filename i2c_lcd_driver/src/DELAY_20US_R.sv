module DELAY_20US_R #(
	parameter integer P_CLOCK_FREQ = 27_000_000
)(
	input  logic        i_clk,
	input  logic        i_rst_n,
	input  logic        i_start,
	input  logic [10:0] i_repeat_count,
	output logic        o_busy,
	output logic        o_done
);

	localparam integer P_CYCLES_20US = (P_CLOCK_FREQ + 49_999) / 50_000;
	localparam integer P_CYCLE_WIDTH = (P_CYCLES_20US <= 1) ? 1 : $clog2(P_CYCLES_20US);

	logic [P_CYCLE_WIDTH-1:0] r_cycle_counter;
	logic [10:0]              r_repeat_counter;
	logic [10:0]              r_repeat_limit;

	always_ff @(posedge i_clk) begin
		if (!i_rst_n) begin
			r_cycle_counter  <= '0;
			r_repeat_counter <= '0;
			r_repeat_limit   <= '0;
			o_busy           <= 1'b0;
			o_done           <= 1'b0;
		end else begin
			o_done <= 1'b0;

			if (!o_busy) begin
				r_cycle_counter  <= '0;
				r_repeat_counter <= '0;
				if (i_start) begin
					if ((i_repeat_count >= 1) && (i_repeat_count <= 1024)) begin
						r_repeat_limit <= i_repeat_count;
						o_busy         <= 1'b1;
					end else begin
						o_done <= 1'b1;
					end
				end
			end else begin
				if (r_cycle_counter == P_CYCLES_20US - 1) begin
					r_cycle_counter <= '0;
					if (r_repeat_counter + 1'b1 == r_repeat_limit) begin
						r_repeat_counter <= '0;
						o_busy           <= 1'b0;
						o_done           <= 1'b1;
					end else begin
						r_repeat_counter <= r_repeat_counter + 1'b1;
					end
				end else begin
					r_cycle_counter <= r_cycle_counter + 1'b1;
				end
			end
		end
	end

endmodule
