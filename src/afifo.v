////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	afifo.v
//
// Project:	afifo, A formal proof of Cliff Cummings' asynchronous FIFO
//
// Purpose:	This file defines the behaviour of an asynchronous FIFO.
//		It was originally copied from a paper by Clifford E. Cummings
//	of Sunburst Design, Inc.  Since then, many of the variable names have
//	been changed and the logic has been rearranged.  However, the
//	fundamental logic remains the same.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// The Verilog logic for this project comes from the paper by Clifford E.
// Cummings, of Sunburst Design, Inc, titled: "Simulation and Synthesis
// Techniques for Asynchronous FIFO Design".  This paper may be found at
// sunburst-design.com.
//
// Minor edits to that logic have been made by Gisselquist Technology, LLC.
// Gisselquist Technology, LLC, asserts no copywrite or ownership of these
// minor edits.
//
//
//
// The formal properties within this project, contained between the
// `ifdef FORMAL line and its corresponding `endif, are owned by Gisselquist
// Technology, LLC, and Copyrighted as such.  Hence, the following copyright
// statement regarding these properties:
//
// Copyright (C) 2018, Gisselquist Technology, LLC
//
// These properties are free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//

`default_nettype	none
//
//
module afifo(i_wclk, i_wrst_n, i_wr, i_wdata, o_wfull,
		i_rclk, i_rrst_n, i_rd, o_rdata, o_rempty);
	parameter	DSIZE = 2,
			ASIZE = 4;
	localparam	DW = DSIZE,
			AW = ASIZE;
	input	wire			i_wclk, i_wrst_n, i_wr;
	input	wire	[DW-1:0]	i_wdata;
	output	reg			o_wfull;
	input	wire			i_rclk, i_rrst_n, i_rd;
	output	reg	[DW-1:0]	o_rdata;
	output	reg			o_rempty;

	wire	[AW-1:0]	waddr, raddr;
	wire			wfull_next, rempty_next;
	reg	[AW:0]		wgray, wbin, wq2_rgray, wq1_rgray,
				rgray, rbin, rq2_wgray, rq1_wgray;
	//
	wire	[AW:0]		wgraynext, wbinnext;
	wire	[AW:0]		rgraynext, rbinnext;

	(* ram_block *)
	reg	[DW-1:0]	mem	[0:((1<<AW)-1)];

	/////////////////////////////////////////////
	//
	//
	// Write logic
	//
	//
	/////////////////////////////////////////////

	//
	// Cross clock domains
	//
	// Cross the read Gray pointer into the write clock domain
	initial	{ wq2_rgray,  wq1_rgray } = 0;
	always @(posedge i_wclk or negedge i_wrst_n)
	if (!i_wrst_n)
		{ wq2_rgray, wq1_rgray } <= 0;
	else
		{ wq2_rgray, wq1_rgray } <= { wq1_rgray, rgray };



	// Calculate the next write address, and the next graycode pointer.
	assign	wbinnext  = wbin + { {(AW){1'b0}}, ((i_wr) && (!o_wfull)) };
	assign	wgraynext = (wbinnext >> 1) ^ wbinnext;

	assign	waddr = wbin[AW-1:0];

	// Register these two values--the address and its Gray code
	// representation
	initial	{ wbin, wgray } = 0;
	always @(posedge i_wclk or negedge i_wrst_n)
	if (!i_wrst_n)
		{ wbin, wgray } <= 0;
	else
		{ wbin, wgray } <= { wbinnext, wgraynext };

	assign	wfull_next = (wgraynext == { ~wq2_rgray[AW:AW-1],
				wq2_rgray[AW-2:0] });

	//
	// Calculate whether or not the register will be full on the next
	// clock.
	initial	o_wfull = 0;
	always @(posedge i_wclk or negedge i_wrst_n)
	if (!i_wrst_n)
		o_wfull <= 1'b0;
	else
		o_wfull <= wfull_next;

	//
	// Write to the FIFO on a clock
	always @(posedge i_wclk)
	if ((i_wr)&&(!o_wfull))
		mem[waddr] <= i_wdata;

	////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////
	//
	//
	// Read logic
	//
	//
	////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////
	//
	//

	//
	// Cross clock domains
	//
	// Cross the write Gray pointer into the read clock domain
	initial	{ rq2_wgray,  rq1_wgray } = 0;
	always @(posedge i_rclk or negedge i_rrst_n)
	if (!i_rrst_n)
		{ rq2_wgray, rq1_wgray } <= 0;
	else
		{ rq2_wgray, rq1_wgray } <= { rq1_wgray, wgray };


	// Calculate the next read address,
	assign	rbinnext  = rbin + { {(AW){1'b0}}, ((i_rd)&&(!o_rempty)) };
	// and the next Gray code version associated with it
	assign	rgraynext = (rbinnext >> 1) ^ rbinnext;

	// Register these two values, the read address and the Gray code version
	// of it, on the next read clock
	//
	initial	{ rbin, rgray } = 0;
	always @(posedge i_rclk or negedge i_rrst_n)
	if (!i_rrst_n)
		{ rbin, rgray } <= 0;
	else
		{ rbin, rgray } <= { rbinnext, rgraynext };

	// Memory read address Gray code and pointer calculation
	assign	raddr = rbin[AW-1:0];

	// Determine if we'll be empty on the next clock
	assign	rempty_next = (rgraynext == rq2_wgray);

	initial o_rempty = 1;
	always @(posedge i_rclk or negedge i_rrst_n)
	if (!i_rrst_n)
		o_rempty <= 1'b1;
	else
		o_rempty <= rempty_next;

	//
	// Read from the memory--a clockless read here, clocked by the next
	// read FLOP in the next processing stage (somewhere else)
	//
	// assign	o_rdata = mem[raddr];

	// Use readclock
	always @(posedge i_rclk)
		o_rdata <= mem[raddr];

endmodule
