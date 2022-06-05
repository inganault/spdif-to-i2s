module top (
  // 12MHz oscillator
  input wire gpio_20,
  // SPDIF
  input wire gpio_23,
  // I2S outputs
  output wire gpio_47,
  output wire gpio_26,
  output wire gpio_27,
  // Status
  output wire led_red  , // Red
  output wire led_blue , // Blue
  output wire led_green,  // Green
  // Debug
  output wire gpio_2,
  output wire gpio_46
);

  wire  clk_12m;
  wire  clk_pll;
  wire  clk_384;
  wire  clk_bclk;

  reg   spdif;
  wire  i2s_lrclk;
  wire  i2s_bclk;
  wire  i2s_data;

  SB_IO #(
    .PIN_TYPE(6'b000001), // Simple input
    .PULLUP(1'b0)
  ) io_pin_20 (
    .PACKAGE_PIN(gpio_20),
    .D_IN_0(clk_12m)
  );
  // SB_GB_IO #(
  //   .PIN_TYPE(6'b000001), // Simple input
  //   .PULLUP(1'b0)
  // ) io_pin_20 (
  //   .PACKAGE_PIN(gpio_20),
  //   .GLOBAL_BUFFER_OUTPUT(clk_12m)
  // );

  /**
   * PLL configuration
   *
   * This Verilog module was generated automatically
   * using the icepll tool from the IceStorm project.
   * Use at your own risk.
   *
   * Given input frequency:        12.000 MHz
   * Requested output frequency:  192.000 MHz
   * Achieved output frequency:   192.000 MHz
   */
  wire  locked;
  SB_PLL40_CORE #(
                .FEEDBACK_PATH("SIMPLE"),
                .DIVR(4'b0000),         // DIVR =  0
                .DIVF(7'b0111111),      // DIVF = 63
                .DIVQ(3'b010),          // DIVQ =  2
                .FILTER_RANGE(3'b001)   // FILTER_RANGE = 1
        ) pll (
                .LOCK(locked),
                .RESETB(1'b1),
                .BYPASS(1'b0),
                .REFERENCECLK(clk_12m),
                .PLLOUTCORE(clk_pll)
                );

  wire clk_384_int;
  clkdiv5 clk_384_divider (
    .reset(!locked),
    .clk_in(clk_pll),
    .clk_out(clk_384_int)
    );
  SB_GB clk_384_gb (
    .USER_SIGNAL_TO_GLOBAL_BUFFER(clk_384_int),
    .GLOBAL_BUFFER_OUTPUT(clk_384)
    );

  wire clk_bclk_int;
  clkdiv25 clk_bclk_divider (
    .clk_in(clk_384),
    .clk_out(clk_bclk_int)
    );
  SB_GB clk_bclk_gb (
    .USER_SIGNAL_TO_GLOBAL_BUFFER(clk_bclk_int),
    .GLOBAL_BUFFER_OUTPUT(clk_bclk)
    );

  // next-pnr cannot use gpio 23 together with gpio 25
  SB_IO #(
    .PIN_TYPE(6'b000000), // Registered input
    .PULLUP(1'b0)
  ) io_pin_23 (
    .PACKAGE_PIN(gpio_23),
    .INPUT_CLK(clk_384),
    .D_IN_0(spdif)
  );

  // TODO: put output in falling edge instead of inverted bclk
  SB_IO #(
    .PIN_TYPE(6'b010100), // Registered output
    .PULLUP(1'b0)
  ) io_pin_25 (
    .PACKAGE_PIN(gpio_47),
    .OUTPUT_CLK(clk_bclk),
    .D_OUT_0(i2s_lrclk),
  );
  assign i2s_bclk = !clk_bclk;
  SB_IO #(
    .PIN_TYPE(6'b011000), // Simple output
    .PULLUP(1'b0)
  ) io_pin_26 (
    .PACKAGE_PIN(gpio_26),
    .D_OUT_0(i2s_bclk),
  );
  SB_IO #(
    .PIN_TYPE(6'b010100), // Registered output
    .PULLUP(1'b0)
  ) io_pin_27 (
    .PACKAGE_PIN(gpio_27),
    .OUTPUT_CLK(clk_bclk),
    .D_OUT_0(i2s_data),
  );

  wire [23:0] sample_left;
  wire [23:0] sample_right;
  wire spdif_write;
  wire spdif_fault;
  spdif_decode spdif_decode(
    .clk(clk_384),
    .spdif(spdif),
    .sample_left(sample_left),
    .sample_right(sample_right),
    .sample_ready(spdif_write),
    .fault(spdif_fault)
    );

  reg [23:0] sample_mix;
  initial sample_mix = 0;
  always @(posedge clk_384) begin
    if (spdif_write)
      sample_mix <= ({sample_left[23],sample_left} + {sample_right[23],sample_right}) >>> 1;
      // sample_mix <= sample_left;
    else
      sample_mix <= sample_mix;
  end

  reg spdif_write_mixed;
  initial spdif_write_mixed = 0;
  always @(posedge clk_384)
    spdif_write_mixed <= spdif_write;

  wire fifo_full;
  afifo #(
    .DSIZE(16),
    .ASIZE(2) // 2^3 = 4 block
  )sample_fifo(
      .i_wclk(clk_384),
      .i_wrst_n(1'b1),
      .i_wr(spdif_write_mixed),
      .i_wdata(sample_mix[23:8]),
      .o_wfull(fifo_full),
      .i_rclk(clk_bclk),
      .i_rrst_n(1'b1),
      .i_rd(next_sample),
      .o_rdata(fifo_read),
      .o_rempty(fifo_empty)
    );

  reg[2:0] fault_cdc;
  initial fault_cdc = 1;
  always @(posedge clk_bclk)
    fault_cdc <= {spdif_fault, fault_cdc[2:1]};
  wire i2s_fault = fault_cdc[0];

  wire[15:0] fifo_read;
  wire fifo_empty;

  wire next_sample;

  reg next_sample_delayed;
  initial next_sample_delayed = 0;
  always @(posedge clk_bclk)
    next_sample_delayed <= next_sample;

  reg[15:0] sample_buf;
  initial sample_buf = 0;
  always @(posedge clk_bclk) begin // Probably read back at wrong clock
    if(next_sample_delayed)
      if(!fifo_empty)
        sample_buf <= fifo_read;
      else
        if (i2s_fault)
          sample_buf <= 0;
        else
          sample_buf <= sample_buf;
    else
      sample_buf <= sample_buf;
  end

  // i2s_tx i2s_tx_32(
  //   .bclk(clk_bclk),
  //   .sample_left(sample_buf),
  //   .sample_right(24'b0),
  //   .next_sample(next_sample),
  //   .lrclk(i2s_lrclk),
  //   .data(i2s_data),
  //   );
  i2s_tx_16 i2s_tx(
    .bclk(clk_bclk),
    .sample_left(sample_buf),
    .sample_right(16'b0),
    .next_sample(next_sample),
    .lrclk(i2s_lrclk),
    .data(i2s_data),
    );

  reg[12:1] led_green_hold;
  initial led_green_hold = 0;
  always @(posedge clk_384) begin
    if (spdif_write)
      led_green_hold <= 4095;
    else if (led_green_hold > 0)
      led_green_hold <= led_green_hold -1;
    else
      led_green_hold <= 0;
  end

  reg[2:0] fifo_empty_cdc;
  initial fifo_empty_cdc = 1;
  always @(posedge clk_384)
    fifo_empty_cdc <= {fifo_empty, fifo_empty_cdc[2:1]};

  reg led_green_plus_fifo;
  always @(posedge clk_384) begin
    led_green_plus_fifo <= led_green_hold && (fifo_empty_cdc[0] || fifo_full);
  end

  reg[11:1] led_pwm;
  initial led_pwm = 0;
  always @(posedge clk_384) begin
    led_pwm <= led_pwm + 1;
  end

  SB_RGBA_DRV #(
    .RGB0_CURRENT("0b000001"),
    // .RGB1_CURRENT("0b001111"),
    .RGB1_CURRENT("0b000000"),
    .RGB2_CURRENT("0b000111"),
    .CURRENT_MODE("0b1"), // Half current mode
  ) rgb_driver (
    .RGBLEDEN(1'b1),
    .RGB0PWM (led_green_plus_fifo && (led_pwm[11:8] == 0)),
    .RGB1PWM (1'b0),
    .RGB2PWM (spdif_fault && (led_pwm[11:8] == 0)),
    .CURREN  (1'b1),
    .RGB0    (led_green), // Actual Hardware connection
    .RGB1    (led_blue ),
    .RGB2    (led_red  )
  );


  SB_IO #(
    .PIN_TYPE(6'b011000), // Simple output
    .PULLUP(1'b0)
  ) io_pin_2 (
    .PACKAGE_PIN(gpio_2),
    .D_OUT_0(spdif_write),
  );
  SB_IO #(
    .PIN_TYPE(6'b011000), // Simple output
    .PULLUP(1'b0)
  ) io_pin_46 (
    .PACKAGE_PIN(gpio_46),
    .D_OUT_0(next_sample),
  );
endmodule
