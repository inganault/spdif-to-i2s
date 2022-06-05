// Divide clock by 25
module clkdiv25 (
  input wire clk_in,
  output wire clk_out,
  output reg clk_out_strobe
);
	reg[3:0] counter;
	reg phase;
	reg delay;
	reg half; // phase delayed by half cycle

	initial begin
		counter = 0;
		half = 0;
		phase = 0;
		delay = 0;
	end

	always @(posedge clk_in) begin
		if (counter >= (12-1) || delay) begin
			counter <= 0;
			delay <= phase;
			if (!delay)
				phase <= !phase;
			else
				phase <= phase;
		end else begin
			counter <= counter+1;
		end
	end

	initial clk_out_strobe = 0;
	always @(posedge clk_in) begin
		clk_out_strobe <= counter == (12-2) && !phase;
	end

	always @(negedge clk_in) begin
		half <= phase;
	end
	assign clk_out = phase || half;

endmodule
