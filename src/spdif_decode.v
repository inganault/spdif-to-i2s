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
  localparam
    CLK_IN_FREQ = 38400000,
    BMC_FREQ    = 3072000;

  localparam
    LEN_MIN      = CLK_IN_FREQ * 2 / (4*BMC_FREQ) - 2,
    LEN_01       = CLK_IN_FREQ * 3 / (4*BMC_FREQ),
    LEN_PREAMBLE = CLK_IN_FREQ * 5 / (4*BMC_FREQ),
    LEN_MAX      = CLK_IN_FREQ * 6 / (4*BMC_FREQ) + 1; // This will reject 44100 Hz

  reg spdif_buf;
  reg spdif_delayed;
  wire spdif_changed = spdif_delayed != spdif_buf;
  always @(posedge clk) begin
    spdif_buf <= spdif;
    spdif_delayed <= spdif_buf;
  end

  reg[4:0] bit_counter;
  wire bit_count_fault = bit_counter >= LEN_MAX;

  initial bit_counter = 0;
  always @(posedge clk) begin
    if (spdif_changed) begin
      bit_counter <= 0;
    end else begin
      if(!bit_count_fault)
        bit_counter <= bit_counter + 1;
      else
        bit_counter <= bit_counter;
    end
  end

  reg found_edge;
  reg bit_count_w1;
  reg bit_count_w2;
  reg bit_count_w3;
  initial found_edge = 0;
  always @(posedge clk) begin
    found_edge <= spdif_changed || bit_count_fault; // Add bit_count_fault to trigger FSM reset
    if (spdif_changed) begin
      bit_count_w1 <= bit_counter >= LEN_MIN && bit_counter < LEN_01; // [LEN_MIN, LEN_01+1)
      bit_count_w2 <= bit_counter >= LEN_01 && bit_counter < LEN_PREAMBLE;
      bit_count_w3 <= bit_counter >= LEN_PREAMBLE && bit_counter < LEN_MAX;
    end
  end

  // ======= stage 1->2 {found_edge, bit_count_*} ===========

  localparam
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

  integer symbol_fsm;
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

  reg[27:0] subframe;
  wire[23:0] subframe_audio = subframe[23:0];
  // wire subframe_bit_valid = subframe[24];
  // wire subframe_bit_user = subframe[25];
  // wire subframe_bit_sidechannel = subframe[26];
  // wire subframe_bit_parity = subframe[27];
  always @(posedge clk) begin
    if (found_edge)
      if (symbol_fsm == SYM_BMC0)
        subframe <= {bit_count_w1, subframe[27:1]};
      else
        subframe <= subframe;
  end

  reg subframe_is_left;
  always @(posedge clk) begin
    if (found_edge)
      case (symbol_fsm)
        SYM_X1:  subframe_is_left <= 1;
        SYM_Y1:  subframe_is_left <= 0;
        SYM_Z1:  subframe_is_left <= 1;
        default: subframe_is_left <= subframe_is_left;
      endcase
  end

  reg symbol_fault;
  initial symbol_fault = 1;
  always @(posedge clk) begin
    if (subframe_valid)
      symbol_fault <= 0;
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
    subframe_valid <= found_edge && bmc_count == 0;
  end

  reg subframe_valid_delayed;
  initial
    subframe_valid = 0;
  always @(posedge clk) begin
    subframe_valid_delayed <= subframe_valid && !parity_fault;
  end

  reg parity_fault;
  always @(posedge clk) begin
    if (subframe_valid)
      parity_fault <= ^subframe[27:0];
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
  // Note: My PC output valid bit as 0, so just ignore it

  always @(posedge clk) begin
    if (subframe_valid && subframe_is_left)
      // if (subframe_bit_valid)
        sample_left <= subframe_audio;
      // else
      //   sample_left <= 0;
  end

  always @(posedge clk) begin
    if (subframe_valid && !subframe_is_left)
      // if (subframe_bit_valid)
        sample_right <= subframe_audio;
      // else
      //   sample_right <= 0;
  end

  assign sample_ready = frame_right_ok;

  always @(posedge clk) begin
    fault <= symbol_fault || parity_fault;
  end

endmodule
