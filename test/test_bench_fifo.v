`timescale 1ns / 1ns
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
    #13 // 38.4MHz
    clk = !clk;
    counter = counter + 1'b1;
    if(counter >= 3)
      reset = 0;
    if(counter >= 10000) begin
      $finish; // end simulation
    end
  end

  reg write, read;
  initial begin
    write = 0;
    read = 0;
  end
  always begin
    #26
    #26
    read = 1;
    #26
    read = 0;
    #26
    write = 1;
    #26
    write = 0;
    #26
    write = 1;
    #26
    write = 0;
  end

  // always begin
  //   #26
  //   #26
  //   read = 1;
  //   #26
  //   read = 0;
  //   #26
  //   write = 1;
  //   #26
  //   write = 0;
  //   #26
  //   read = 1;
  //   #26
  //   read = 0;
  //   #26
  //   write = 1;
  //   read = 1;
  //   #26
  //   write = 0;
  //   read = 0;
  //   #26
  //   write = 1;
  //   #26
  //   write = 0;
  //   #26
  //   write = 1;
  //   read = 1;
  //   #26
  //   write = 0;
  //   read = 0;
  // end
  fifo16x3 fifo(
    .clk(clk),
    .resetn(1'b1),
    .write(write),
    .write_data(counter[15:0]),
    .read(read)
    );

  initial begin
    $monitor("t=%3d\n",$time);
  end

endmodule
