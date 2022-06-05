/*
Bad synchronous fifo
*/

module fifo16x3 (
  input wire clk,
  input wire resetn,
  input wire write,
  input wire[15:0] write_data,
  input wire read,
  output reg[15:0] read_data,
  output wire empty,
  output wire full
);
  localparam integer AWIDTH = 2;
  localparam integer ASIZE = (1<<AWIDTH);

  reg[AWIDTH-1:0] head;
  reg[AWIDTH-1:0] tail;
  
  (* ram_block *)
  reg [15:0]  mem [0:ASIZE-1];

  initial head = 0;
  always @(posedge clk or negedge resetn) begin : proc_head
    if(!resetn)
      head <= 0;
    else
      if (write && !full)
        head <= head + 1;
      else
        head <= head;
  end

  always @(posedge clk) begin : proc_write
    if (write && !full)
      mem[head] <= write_data;
  end

  initial tail = 0;
  always @(posedge clk or negedge resetn) begin : proc_tail
    if(!resetn)
      tail <= 0;
    else
      if (read && !empty)
        tail <= tail + 1;
      else
        tail <= tail;
  end
  always @(posedge clk) begin : proc_read
    read_data <= mem[tail];
  end

  // TODO: change full & empty to register
  assign full = ((head + 1)&(ASIZE-1)) == (tail&(ASIZE-1));

  assign empty = head == tail;

endmodule
