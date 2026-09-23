module BYTE_FIFO_32 (
	input  logic       i_clk,
	input  logic       i_rst_n,
	input  logic       i_write,
	input  logic [7:0] i_write_data,
	input  logic       i_read,
	output logic [7:0] o_read_data,
	output logic       o_empty,
	output logic       o_full,
	output logic       o_overflow
);

	logic [7:0] r_memory [0:31];
	logic [4:0] r_write_pointer;
	logic [4:0] r_read_pointer;
	logic [5:0] r_count;

	assign o_read_data = r_memory[r_read_pointer];
	assign o_empty     = r_count == 0;
	assign o_full      = r_count == 32;

	always_ff @(posedge i_clk) begin
		if (!i_rst_n) begin
			r_write_pointer <= '0;
			r_read_pointer  <= '0;
			r_count         <= '0;
			o_overflow      <= 1'b0;
		end else begin
			if (i_write && o_full)
				o_overflow <= 1'b1;

			case ({i_write && !o_full, i_read && !o_empty})
				2'b10: begin
					r_memory[r_write_pointer] <= i_write_data;
					r_write_pointer          <= r_write_pointer + 1'b1;
					r_count                  <= r_count + 1'b1;
				end

				2'b01: begin
					r_read_pointer <= r_read_pointer + 1'b1;
					r_count        <= r_count - 1'b1;
				end

				2'b11: begin
					r_memory[r_write_pointer] <= i_write_data;
					r_write_pointer          <= r_write_pointer + 1'b1;
					r_read_pointer           <= r_read_pointer + 1'b1;
				end

				default: begin
					r_count <= r_count;
				end
			endcase
		end
	end

endmodule