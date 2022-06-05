`timescale 10ns / 1ns
module tb;
  reg   clk;
  reg   reset;
  reg[31:0]   counter;

  initial begin
    $dumpfile("test_bench.vcd");
    $dumpvars(0, tb);

    clk = 1'b0;
    counter = 31'd0;
    reset = 1;
  end
  always begin
    #1
    clk = !clk;
    counter = counter + 1'b1;
    if(counter >= 3)
      reset = 0;
    if(counter >= 1000) begin
      $finish; // end simulation
    end
  end

  wire clk_d5;
  wire clk_d125;
  clkdiv5 clkdiv(
    .reset(reset),
    .clk_in(clk),
    .clk_out(clk_d5)
    );
  clkdiv25 clkdiv2(
    .clk_in(clk_d5),
    .clk_out(clk_d125)
    );

  initial begin
    $monitor("t=%3d\n",$time);
  end

endmodule
