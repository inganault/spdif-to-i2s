/*
https://wavedrom.com/editor.html
{signal: [
  {name: 'LRCLK', wave: 'hl......|.h......|.l.'},
  {name: 'BCLK' , wave: 'p..P....|........|...', phase:0.5},
  {name: 'DATA' , wave: 'x.333333|33444444|443', data: ['L15','L14','L13','L12','L11','','L1','L0','R15','R14','R13','R12','R11','','R1','R0','L31']},
]}
*/

module i2s_tx_16 (
  input wire clk,
  input wire strobe,
  input wire[15:0] sample_left,
  input wire[15:0] sample_right,
  output wire next_sample,
  output reg lrclk,
  output reg data
);
  // Counter
  reg[5:1] div;
  initial
    div = 0;
  always @(posedge clk)
    if(strobe)
      div <= div + 1;

  // LR Clock
  initial lrclk = 1;
  always @(posedge clk)
    if(strobe)
      lrclk <= div[5];

  // Next sample signal
  reg need_sample;
  initial
    need_sample = 0;
  always @(posedge clk) begin
    if (div == 0)
      need_sample <= 1;
    else
      need_sample <= 0;
  end
  assign next_sample = need_sample && strobe;

  // Shift Register
  reg[31:0] shiftreg;
  initial
    shiftreg = 0;
  always @(posedge clk)
    if(strobe) begin
      if (div == 0)
        shiftreg <= {sample_left, sample_right};
      else
        shiftreg <= {shiftreg[30:0], 1'b0};
    end

  // Data
  initial
    data = 0;
  always @(posedge clk)
    if(strobe)
      data <= shiftreg[31];

endmodule
