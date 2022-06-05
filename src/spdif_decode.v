/*
Preamble
X: 11100010
Y: 11100100
Z: 11101000

BMC
0: 00 or 11
1: 01 or 10

Subframe
0        3 4             27        31
[Preamble] [LSB Sample MSB] [V|U|C|P]
V: Valid 1=valid
P: Parity make bits 4~31 have even 1

Frame
[Z + Left sample] [Y + Right sample]
[X + Left sample] [Y + Right sample]
[X + Left sample] [Y + Right sample]
...

*/

module spdif_decode (
  input wire clk, // 38.4MHz
  input wire spdif,
  output reg[23:0] sample_left,
  output reg[23:0] sample_right,
  output wire sample_ready,
  output reg fault
);
  localparam integer
    CLK_IN_FREQ = 38400000,
    BMC_FREQ    = 3072000;

  localparam integer
    LEN_MIN      = CLK_IN_FREQ * 2 / (4*BMC_FREQ) - 2,
    LEN_01       = CLK_IN_FREQ * 3 / (4*BMC_FREQ),
    LEN_PREAMBLE = CLK_IN_FREQ * 5 / (4*BMC_FREQ),
    LEN_MAX      = CLK_IN_FREQ * 6 / (4*BMC_FREQ) + 1;

  reg spdif_buf;
  reg spdif_delayed;
  wire spdif_changed = spdif_delayed != spdif_buf;
  always @(posedge clk) begin
    spdif_buf <= spdif;
    spdif_delayed <= spdif_buf;
  end

  reg[5:0] bit_counter;
  initial bit_counter = 0;
  always @(posedge clk) begin
    if (spdif_changed) begin
      bit_counter <= 0;
    end else begin
      // TODO: overflow?
      bit_counter <= bit_counter + 1;
    end
  end

  reg found_edge;
  reg bit_count_w1;
  reg bit_count_w2;
  reg bit_count_w3;
  reg bit_count_fault;
  initial found_edge = 0;
  always @(posedge clk) begin
    found_edge <= spdif_changed;
    if (spdif_changed) begin
      bit_count_w1 <= bit_counter >= LEN_MIN && bit_counter < LEN_01;
      bit_count_w2 <= bit_counter >= LEN_01 && bit_counter < LEN_PREAMBLE;
      bit_count_w3 <= bit_counter >= LEN_PREAMBLE && bit_counter < LEN_MAX;
      bit_count_fault <= bit_counter >= LEN_MAX;
    end
  end

  // ======= stage 1->2 {found_edge, bit_count_*} ===========

  localparam integer
    SYM_IDLE  = 0,
    SYM_PREAM = 1,
    SYM_X1 = 2,
    SYM_X2 = 3,
    SYM_Y1 = 4,
    SYM_Y2 = 5,
    SYM_Z1 = 6,
    SYM_Z2 = 7,
    SYM_BMC0 = 8,
    SYM_BMC1 = 9;

  reg[3:0] symbol_fsm;
  initial symbol_fsm = SYM_IDLE;
  always @(posedge clk) begin
    if (found_edge)
      case (symbol_fsm)
        SYM_IDLE:
          if (bit_count_w3) symbol_fsm <= SYM_PREAM;
          else              symbol_fsm <= SYM_IDLE;
        SYM_PREAM:
          if      (bit_count_w3) symbol_fsm <= SYM_X1;
          else if (bit_count_w2) symbol_fsm <= SYM_Y1;
          else if (bit_count_w1) symbol_fsm <= SYM_Z1;
          else                   symbol_fsm <= SYM_IDLE;
        SYM_X1:
          if (bit_count_w1) symbol_fsm <= SYM_X2;
          else              symbol_fsm <= SYM_IDLE;
        SYM_X2:
          if (bit_count_w1) symbol_fsm <= SYM_BMC0;
          else              symbol_fsm <= SYM_IDLE;
        SYM_Y1:
          if (bit_count_w1) symbol_fsm <= SYM_Y2;
          else              symbol_fsm <= SYM_IDLE;
        SYM_Y2:
          if (bit_count_w2) symbol_fsm <= SYM_BMC0;
          else              symbol_fsm <= SYM_IDLE;
        SYM_Z1:
          if (bit_count_w1) symbol_fsm <= SYM_Z2;
          else              symbol_fsm <= SYM_IDLE;
        SYM_Z2:
          if (bit_count_w3) symbol_fsm <= SYM_BMC0;
          else              symbol_fsm <= SYM_IDLE;
        SYM_BMC0:
          if (bit_count_w2)
            if (bmc_count != 0)
              symbol_fsm <= SYM_BMC0;
            else
              symbol_fsm <= SYM_IDLE;
          else if (bit_count_w1)
            symbol_fsm <= SYM_BMC1;
          else
            symbol_fsm <= SYM_IDLE;
        SYM_BMC1:
          if (bit_count_w1)
            if (bmc_count != 0)
              symbol_fsm <= SYM_BMC0;
            else
              symbol_fsm <= SYM_IDLE;
          else
            symbol_fsm <= SYM_IDLE;
      endcase
  end

  reg[28:0] subframe; // LSB is channel
  wire[23:0] subframe_audio = subframe[24:1];
  wire subframe_is_left = !subframe[0];
  // wire subframe_bit_valid = subframe[25];
  // wire subframe_bit_user = subframe[26];
  // wire subframe_bit_sidechannel = subframe[27];
  // wire subframe_bit_parity = subframe[28];
  always @(posedge clk) begin
    if (found_edge)
      case (symbol_fsm)
        SYM_X1:    subframe <= {1'b0, subframe[28:1]};
        SYM_Y1:    subframe <= {1'b1, subframe[28:1]};
        SYM_Z1:    subframe <= {1'b0, subframe[28:1]};
        SYM_BMC0:  subframe <= {bit_count_w1, subframe[28:1]};
        default: subframe <= subframe;
      endcase
  end

  reg symbol_fault;
  initial symbol_fault = 1;
  always @(posedge clk) begin
    if (subframe_valid)
      symbol_fault <= 0;
    else if (bit_count_fault)
      symbol_fault <= 1;
    else if (found_edge)
      case (symbol_fsm)
        SYM_IDLE:  if(!bit_count_w3) symbol_fault <= 1;
        SYM_PREAM: if(!(bit_count_w3 || bit_count_w2 || bit_count_w1)) symbol_fault <= 1;
        SYM_X1:    if(!bit_count_w1) symbol_fault <= 1;
        SYM_X2:    if(!bit_count_w1) symbol_fault <= 1;
        SYM_Y1:    if(!bit_count_w1) symbol_fault <= 1;
        SYM_Y2:    if(!bit_count_w2) symbol_fault <= 1;
        SYM_Z1:    if(!bit_count_w1) symbol_fault <= 1;
        SYM_Z2:    if(!bit_count_w3) symbol_fault <= 1;
        SYM_BMC0:  if(!(bit_count_w2 || bit_count_w1)) symbol_fault <= 1;
        SYM_BMC1:  if(!bit_count_w1) symbol_fault <= 1;
      endcase
  end

  reg[4:0] bmc_count;
  always @(posedge clk) begin
    if (found_edge)
      case (symbol_fsm)
        SYM_IDLE:
          bmc_count <= 27;
        SYM_BMC0:
          if (bit_count_w2)
            bmc_count <= bmc_count - 1;
        SYM_BMC1:
          bmc_count <= bmc_count - 1;
        default:
          bmc_count <= bmc_count;
      endcase
  end

  reg subframe_valid;
  initial
    subframe_valid = 0;
  always @(posedge clk) begin
    subframe_valid <= found_edge && bmc_count == 0 /*&& subframe_bit_valid subframe[26]*/;
  end

  reg subframe_valid_delayed;
  initial
    subframe_valid = 0;
  always @(posedge clk) begin
    subframe_valid_delayed <= subframe_valid && !parity_fault;
  end

  reg parity_fault;
  initial parity_fault = 0;
  always @(posedge clk) begin
    if (subframe_valid)
      parity_fault <= ^subframe[28:1];
  end

  reg frame_left_ok, frame_right_ok;
  initial begin
    frame_left_ok = 0;
    frame_right_ok = 0;
  end
  always @(posedge clk) begin
    if (frame_right_ok) begin
      frame_left_ok <= 0;
      frame_right_ok <= 0;
    end else if (subframe_valid_delayed) begin
      if (subframe_is_left)
        frame_left_ok <= 1;
      else if(frame_left_ok)
        frame_right_ok <= 1;
    end
  end

  // Outputs
  initial sample_left = 0;
  always @(posedge clk) begin
    if (subframe_valid && subframe_is_left)
      // if (subframe_bit_valid)
        sample_left <= subframe_audio;
      // else
      //   sample_left <= 0;
  end

  initial sample_right = 0;
  always @(posedge clk) begin
    if (subframe_valid && !subframe_is_left)
      // if (subframe_bit_valid)
        sample_right <= subframe_audio;
      // else
      //   sample_right <= 0;
  end

  assign sample_ready = frame_right_ok;

  initial fault = 0;
  always @(posedge clk) begin
    fault <= symbol_fault || parity_fault;
  end

endmodule
