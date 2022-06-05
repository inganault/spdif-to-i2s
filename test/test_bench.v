`timescale 1ns / 1ns
module tb;
  reg   clk;
  reg   reset;
  reg[31:0]   counter;

  integer spdif_counter;
  reg spdif_data[1:3000];
  reg spdif;

  initial begin
    spdif_counter = 0;
    spdif = 0;
    $readmemb("../test/spdif.txt", spdif_data);
  end
  always begin
    #162 // 1/(48000*64)/2
    spdif_counter = spdif_counter + 1;
    spdif = spdif_data[spdif_counter];
  end

  initial begin
    $dumpfile("test_bench.vcd");
    $dumpvars(0, tb);

    clk = 1'b0;
    counter = 31'd0;
    reset = 1;
  end
  always begin
    #13 // 38.4MHz
    clk = !clk;
    counter = counter + 1'b1;
    if(counter >= 3)
      reset = 0;
    if(counter >= 10000) begin
      $finish; // end simulation
    end
  end

  spdif_decode spdif_decode(
    .clk(clk),
    .spdif(spdif)
    );

  wire clk_bclk;
  clkdiv25 clk_bclk_divider (
    .clk_in(clk),
    .clk_out(clk_bclk),
    .clk_out_strobe(bclk_strobe)
    );

  i2s_tx_16 i2s_tx(
    .clk(clk),
    .strobe(bclk_strobe),
    .sample_left(16'b10101010_11111111),
    .sample_right(16'b0)
    );

  initial begin
    $monitor("t=%3d\n",$time);
  end

endmodule
