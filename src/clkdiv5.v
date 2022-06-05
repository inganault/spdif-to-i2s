// Divide clock by 5
/*
It might be better implmented without ring counter.

https://wavedrom.com/editor.html
{signal: [
  {name: 'clk_in'      , wave: 'p....................'},
  {name: 'main_ctr[1]' , wave: '01....0....1....0....'},
  {name: 'main_ctr[2]' , wave: '0.1....0....1....0...'},
  {name: 'main_ctr[3]' , wave: '0..1....0....1....0..'},
  {name: 'main_ctr[4]' , wave: '0...1....0....1....0.'},
  {name: 'main_ctr[5]' , wave: '0....1....0.....1....'},
  {name: 'half_ctr'    , wave: '10....1....0....1....0', phase: 0.5},
  {name: 'clk_out_slow', wave: 'hl.nh.l.nh.l.nh.l.nh.l', phase: 0.5},
  {name: 'clk_out'     , wave: 'l.h..l.h..l.h..l.h..l'},
]}
*/
module clkdiv5 #(
  parameter integer ACCURATE_NEG_EDGE = 0
) (
  input wire reset,
  input wire clk_in,
  output wire clk_out
);
	reg[5:1] main_ctr;
	reg half_ctr;
	initial begin
		main_ctr = 0;
		half_ctr = 0;
	end

	always @(posedge clk_in) begin
		if (reset)
			main_ctr <= 0;
		else
			main_ctr <= {main_ctr[4:1], !main_ctr[5]};
	end
	always @(negedge clk_in) begin
		half_ctr <= main_ctr[5];
	end

	assign clk_out = ACCURATE_NEG_EDGE ? (main_ctr[3] ^ half_ctr) : (main_ctr[2] ^ main_ctr[5]);

endmodule