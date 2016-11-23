/*
 * Copyright International Business Machines Corporation 2016
 *
 * Printed in the United States of America June 2016
 *
 * IBM, the IBM logo, and ibm.com are trademarks or registered trademarks of
 * International Business Machines Corp.,
 * registered in many jurisdictions worldwide. Other product and service names
 * might be trademarks of IBM or other companies. A current list of IBM trademarks
 * is available on the Web at “Copyright and trademark information” at
 * www.ibm.com/legal/copytrade.shtml.
 *
 * Other company, product, and service names may be trademarks or service marks of
 * others.
 *
 * All information contained in this document is subject to change without notice.
 * The products described in this document are NOT intended for use in applications
 * such as implantation, life support, or other hazardous uses where malfunction
 * could result in death, bodily injury, or catastrophic property damage. The
 * information contained in this document does not affect or change IBM product
 * specifications or warranties. Nothing in this document shall operate as an
 * express or implied license or indemnity under the intellectual property rights
 * of IBM or third parties. All information contained in this document was obtained
 * in specific environments, and is presented as an illustration. The results
 * obtained in other operating environments may vary.
 * While the information contained herein is believed to be accurate, such
 * information is preliminary, and should not be relied upon for accuracy or
 * completeness, and no representations or warranties of accuracy or completeness
 * are made.
 *
 * Note: This document contains information on products in the design, sampling
 * and/or initial production phases of development. This information is subject to
 * change without notice. Verify with your IBM field applications engineer that you
 * have the latest version of this document before finalizing a design.
 * This document is intended for development of technology products compatible with
 * Power Architecture. You may use this document, for any purpose (commercial or
 * personal) and make modifications and distribute; however, modifications to this
 * document may violate Power Architecture and should be carefully considered. Any
 * distribution of this document or its derivative works shall include this Notice
 * page including but not limited to the IBM warranty disclaimer and IBM liability
 * limitation. No other licenses, expressed or implied, estoppel or otherwise to
 * any intellectual property rights is granted by this document.
 *
 * THE INFORMATION CONTAINED IN THIS DOCUMENT IS PROVIDED ON AN “AS IS” BASIS.
 * IBM makes no representations or warranties, either express or implied, including
 * but not limited to, warranties of merchantability, fitness for a particular
 * purpose, or non-infringement, or that any practice or implementation of the IBM
 * documentation will not infringe any third party patents, copyrights, trade
 * secrets, or other rights. In no event will IBM be liable for damages arising
 * directly or indirectly from any use of the information contained in this
 * document.
 *
 * IBM Systems and Technology Group
 * 2070 Route 52, Bldg. 330
 * Hopewell Junction, NY 12533-6351
 * The IBM home page can be found at ibm.com.
 */

// IBM Research - Zurich
// Zurich CAPI Streaming Layer
// Raphael Polig <pol@zurich.ibm.com>
// Heiner Giefers <hgi@zurich.ibm.com>

`timescale 1 ps / 1 ps

module zcsl_core_fft
#(
	parameter GETS = 2,
	parameter PUTS = 1,
	parameter IRQS = 2,
	parameter WIDTH = 512,
	parameter PIPE_WIDTH = 128
)
(
	// Global Signals
	input clk,
	input reset,

	// MMIO side
	input mm_valid,
	input mm_rnw,
	input mm_dw,
	output mm_ack,
	input [0:23] mm_addr,
	input [0:63] mm_wr_data,
	output [0:63] mm_rd_data,
	
	output done,

	// GET side
	output [0:1] get_v,
	input [0:1] get_r,
	output [0:1] get_e,
	output [0:2*64-1] get_addr,
	input [0:1] get_data_v,
	output [0:1] get_data_r,
	input [0:1] get_data_e,
	input [0:2*WIDTH-1] get_data_d,

	// PUT side
	output put_v,
	input put_r,
	output put_e,
	input put_done,
	output [0:63] put_addr,
	output put_data_v,
	input put_data_r,
	output put_data_e,
	output [0:511] put_data_d
);


// ** Wire definitions **



// WED pointer queue
wire wedptr_wr_valid;
wire wedptr_wr_ready;
wire [0:63] wedptr_wr_data;
wire wedptr_rd_valid;
wire wedptr_rd_ready;
wire [0:63] wedptr_rd_data;

// WED FROM queue
wire wedf_wr_valid;
wire wedf_wr_ready;
wire [0:32+32+64-1] wedf_wr_data;
wire wedf_rd_valid;
wire wedf_rd_ready;
wire [0:32+32+64-1] wedf_rd_data;
wire [0:31] wedf_size;
wire [0:31] wedf_flags;
wire [0:63] wedf_ptr;

// WED TO queue
wire wedt_wr_valid;
wire wedt_wr_ready;
wire [0:32+32+64-1] wedt_wr_data;
wire wedt_rd_valid;
wire wedt_rd_ready;
wire [0:32+32+64-1] wedt_rd_data;
wire [0:31] wedt_size;
wire [0:31] wedt_flags;
wire [0:63] wedt_ptr;

// DATA queue
wire data_wr_valid;
wire data_wr_ready;
wire [0:WIDTH+1-1] data_wr_data;
wire data_rd_valid;
wire data_rd_ready;
wire [0:WIDTH+1-1] data_rd_data;


wire data1_wr_valid;
wire data1_wr_ready;
wire [0:WIDTH+1-1] data1_wr_data;
wire data1_rd_valid;
wire data1_rd_ready;
wire [0:WIDTH+1-1] data1_rd_data;



// ** Routing and Logic **
assign mm_ack = mm_valid;

assign done = put_done;

// WED request
assign get_v[0] = wedptr_rd_valid;
assign get_e[0] = 1'b1;
assign wedptr_rd_ready = get_r[0];
assign get_addr[0:63] = wedptr_rd_data;


// WED pointer queue
assign wedptr_wr_valid = mm_valid & ~mm_rnw & mm_dw & (mm_addr==24'h20); //24'h20
assign wedptr_wr_data =  mm_wr_data;

// WED FROM queue
assign wedf_wr_valid = get_data_v[0] & get_data_r[0] & ~get_data_e[0];
assign get_data_r[0] = wedf_wr_ready;
assign wedf_wr_data = get_data_d[0:32+32+64-1];
zcsl_endian_swap#(.BYTES(4))ISWPWEDFFLAG(.i(wedf_rd_data[0:31]), .o(wedf_flags));
zcsl_endian_swap#(.BYTES(4))ISWPWEDFSIZE(.i(wedf_rd_data[32:63]), .o(wedf_size));
zcsl_endian_swap#(.BYTES(8))ISWPWEDFPTR(.i(wedf_rd_data[64:127]), .o(wedf_ptr));

// WED TO queue
assign wedt_wr_valid = get_data_v[0] & get_data_r[0] & ~get_data_e[0];
assign wedt_wr_data = {get_data_d[0:32+32-1], get_data_d[32+32+64:32+32+64+64-1]};
zcsl_endian_swap#(.BYTES(4))ISWPWEDTFLAG(.i(wedt_rd_data[0:31]), .o(wedt_flags));
zcsl_endian_swap#(.BYTES(4))ISWPWEDTSIZE(.i(wedt_rd_data[32:63]), .o(wedt_size));
zcsl_endian_swap#(.BYTES(8))ISWPWEDTPTR(.i(wedt_rd_data[64:127]), .o(wedt_ptr));


zcsl_lag
#(
	64,
	32
)
IAGGET
(
	clk,
	reset,
	
	wedf_rd_valid,
	wedf_rd_ready,
	wedf_ptr,
	wedf_size,
	
	get_v[1],
	get_r[1],
	get_e[1],
	get_addr[64:127]
);



wire lag_put_r;
assign lag_put_r = put_r & put_data_r;

zcsl_lag_put
#(
	64,
	32,
	32
)
IAGPUT
(
	clk,
	reset,
	
	wedt_rd_valid,
	wedt_rd_ready,
	wedt_ptr,
	wedt_size,
	wedt_flags,
	
	put_v,
	put_r,
	put_e,
	put_addr
);



// DATA queue
assign data_wr_valid = get_data_v[1];
assign get_data_r[1] = data_wr_ready;
assign data_wr_data = {get_data_d[WIDTH:1023], get_data_e[1]};

assign put_data_v = data_rd_valid;
assign data_rd_ready = put_data_r;
assign put_data_e = data_rd_data[WIDTH];
assign put_data_d = data_rd_data[0:511];



// WED pointer queue
zcsl_fifo
#(
	.WIDTH(64),
	.LOG_DEPTH(10)
)
IWEDPTRQUEUE
(
	.clk(clk),
	.reset(reset),
	.wr_valid(wedptr_wr_valid),
	.wr_ready(wedptr_wr_ready),
	.wr_data(wedptr_wr_data),
	.rd_valid(wedptr_rd_valid),
	.rd_ready(wedptr_rd_ready),
	.rd_data(wedptr_rd_data)
);


// WED FROM queue
zcsl_fifo
#(
	.WIDTH(32+32+64),
	.LOG_DEPTH(9)
)
IWEDFQUEUE
(
	.clk(clk),
	.reset(reset),
	.wr_valid(wedf_wr_valid),
	.wr_ready(wedf_wr_ready),
	.wr_data(wedf_wr_data),
	.rd_valid(wedf_rd_valid),
	.rd_ready(wedf_rd_ready),
	.rd_data(wedf_rd_data)
);

// WED TO queue
zcsl_fifo
#(
	.WIDTH(32+32+64),
	.LOG_DEPTH(9)
)
IWEDTQUEUE
(
	.clk(clk),
	.reset(reset),
	.wr_valid(wedt_wr_valid),
	.wr_ready(wedt_wr_ready),
	.wr_data(wedt_wr_data),
	.rd_valid(wedt_rd_valid),
	.rd_ready(wedt_rd_ready),
	.rd_data(wedt_rd_data)
);


// DATA queue
zcsl_fifo
#(
	.WIDTH(WIDTH+1),
	.LOG_DEPTH(12)
)
IDATAQUEUE
(
	.clk(clk),
	.reset(reset),
	.wr_valid(data_wr_valid),
	.wr_ready(data_wr_ready),
	.wr_data(data_wr_data),
	.rd_valid(data1_rd_valid),
	.rd_ready(data1_rd_ready),
	.rd_data(data1_rd_data)
);


// DATA queue
wire data2_wr_valid;
wire data2_wr_ready;
wire data2_wr_end;
wire [0:WIDTH-1] data2_wr_data;
wire data2_rd_valid;
wire data2_rd_ready;
wire [0:PIPE_WIDTH-1] data2_rd_data;
wire data2_rd_end;


wire data3_wr_valid;
wire data3_wr_ready;
wire data3_wr_end;
wire [0:PIPE_WIDTH-1] data3_wr_data;
wire data3_rd_valid;
wire data3_rd_ready;
wire [0:WIDTH-1] data3_rd_data;
wire data3_rd_end;

wire data4_wr_valid;
wire data4_wr_ready;
wire data4_wr_end;
wire [0:PIPE_WIDTH-1] data4_wr_data;
wire data4_rd_valid;
wire data4_rd_ready;
wire [0:PIPE_WIDTH-1] data4_rd_data;
wire data4_rd_end;



assign data2_wr_valid = data1_rd_valid;
assign data1_rd_ready = data2_wr_ready;
assign data2_wr_data = data1_rd_data[0:511];
assign data2_wr_end = data1_rd_data[WIDTH];



wire [0:3] chunk_sel;
assign chunk_sel = 4'b1111;
zcsl_sequencer
#( .IN_WIDTH(WIDTH), .OUT_WIDTH(PIPE_WIDTH) )
IDATASEQ
(
	.clk(clk),
	.reset(reset),
	.i_v(data2_wr_valid),
	.i_e(data2_wr_end),
	.i_r(data2_wr_ready),
	.i_d(data2_wr_data),
	.i_c(chunk_sel),
	.o_r(data2_rd_ready),
	.o_v(data2_rd_valid),
	.o_e(data2_rd_end),
	.o_d(data2_rd_data)
);




assign data4_wr_valid = data2_rd_valid;
assign data2_rd_ready = data4_wr_ready;
assign data4_wr_data = data2_rd_data;
assign data4_wr_end = data2_rd_end;


zcsl_streaming_fft
#(.WIDTH(PIPE_WIDTH) )
IFFT
(
	.clk(clk),
	.reset(reset),
	.i_v(data4_wr_valid),
	.i_e(data4_wr_end),
	.i_r(data4_wr_ready),
	.i_d(data4_wr_data),
	.o_r(data4_rd_ready),
	.o_v(data4_rd_valid),
	.o_e(data4_rd_end),
	.o_d(data4_rd_data)
);


assign data3_wr_valid = data4_rd_valid;
assign data4_rd_ready = data3_wr_ready;
assign data3_wr_data = data4_rd_data;
assign data3_wr_end = data4_rd_end;

zcsl_packer
#( .IN_WIDTH(PIPE_WIDTH), .OUT_WIDTH(WIDTH) )
IDATAPACL
(
	.clk(clk),
	.reset(reset),
	.i_v(data3_wr_valid),
	.i_e(data3_wr_end),
	.i_r(data3_wr_ready),
	.i_d(data3_wr_data),
	.o_r(data3_rd_ready),
	.o_v(data3_rd_valid),
	.o_e(data3_rd_end),
	.o_d(data3_rd_data)
);

assign data1_wr_valid = data3_rd_valid;
assign data3_rd_ready = data1_wr_ready;
assign data1_wr_data = {data3_rd_data, data3_rd_end} ;


zcsl_fifo
#(
	.WIDTH(WIDTH+1),
	.LOG_DEPTH(4)
)
IDATAQUEUE1
(
	.clk(clk),
	.reset(reset),
	.wr_valid(data1_wr_valid),
	.wr_ready(data1_wr_ready),
	.wr_data(data1_wr_data),
	.rd_valid(data_rd_valid),
	.rd_ready(data_rd_ready),
	.rd_data(data_rd_data)
);

endmodule

