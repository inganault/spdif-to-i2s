/*
https://wavedrom.com/editor.html
{signal: [
  {name: 'LRCLK', wave: 'hl......|.h......|.l.'},
  {name: 'BCLK' , wave: 'p..P....|........|...', phase:0.5},
  {name: 'DATA' , wave: 'x.333333|33444444|443', data: ['L31','L30','L29','L28','L27','','L1','L0','R31','R30','R29','R28','R27','','R1','R0','L31']},
]}
*/

module i2s_tx_16 (
  input wire bclk,
  input wire[15:0] sample_left,
  input wire[15:0] sample_right,
  output reg next_sample,
  output reg lrclk,
  output reg data
);
  // Counter
  reg[5:1] div;
  initial
    div = 0;
  always @(posedge bclk) begin
    div <= div+1;
  end
  // LR Clock
  initial lrclk = 1;
  always @(posedge bclk)
    lrclk <= div[5];

  // Next sample signal
  initial
    next_sample = 0;
  always @(posedge bclk) begin
    if (div == 0)
      next_sample <= 1;
    else
      next_sample <= 0;
  end

  // Shift Register
  reg[31:0] shiftreg;
  initial
    shiftreg = 0;
  always @(posedge bclk) begin
    if (div == 0)
      shiftreg <= {sample_left, sample_right};
    else
      shiftreg <= {shiftreg[30:0], 1'b0};
  end

  // Data
  initial
    data = 0;
  always @(posedge bclk)
    data = shiftreg[31];

endmodule


module i2s_tx_32 (
  input wire bclk,
  input wire[23:0] sample_left,
  input wire[23:0] sample_right,
  output reg next_sample,
  output reg lrclk,
  output reg data
);
  // Counter
  reg[6:1] div;
  initial
    div = 0;
  always @(posedge bclk) begin
    div <= div+1;
  end
  // LR Clock
  initial lrclk = 1;
  always @(posedge bclk)
    lrclk <= div[6];

  // Next sample signal
  initial
    next_sample = 0;
  always @(posedge bclk) begin
    if (div == 0)
      next_sample <= 1;
    else
      next_sample <= 0;
  end

  // Shift Register
  reg[63:0] shiftreg;
  initial
    shiftreg = 0;
  always @(posedge bclk) begin
    if (div == 0)
      shiftreg <= {sample_left, 8'b0, sample_right, 8'b0};
    else
      shiftreg <= {shiftreg[62:0], 1'b0};
  end

  // Data
  initial
    data = 0;
  always @(posedge bclk)
    data = shiftreg[63];

endmodule
