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

module zcsl_streaming_fft
#(
	parameter WIDTH = 128
)
(
	input clk,
	input reset,

	// INPUT
	input i_v,
	input i_e,
	output i_r,
	input [0:WIDTH-1] i_d,


	// OUTPUT
	input o_r,
	output o_v,
	output o_e,
	output [0:WIDTH-1] o_d
);

// FOR SPIRAL 4k FFT
// Latency: 5503
// Gap:     2048
localparam LOG_FFT = 12;
localparam FFT_LATENCY = 5503;
localparam FFT_CHUNK = 2048;
localparam LOG_FFT_CHUNK = 11;
localparam IN_FIFO_LOG_DEPTH = 12; //Two FFTs sets
// Need to buffer all samples in pipe plus one fft
// = ceil(FFT_LATENCY/FFT_CHUNK)+1 = 4 => 2048 * 4 = 2^13
localparam OUT_FIFO_LOG_DEPTH = 13; 
localparam OUT_FIFO_SPACE_REQ = 2**OUT_FIFO_LOG_DEPTH - (FFT_LATENCY + FFT_CHUNK);
localparam COUNTERSIZE = 16;


wire [0:COUNTERSIZE-1] fifoin_cnt, fifoout_cnt, fifoout_cnt_free, fifoout_cnt_avail;
wire fifoin_i_r, fifoin_i_v, fifoin_o_r, fifoin_o_v;
wire [0:WIDTH] fifoin_i_d, fifoin_o_d;
wire fifoout_i_r, fifoout_i_v, fifoout_o_r, fifoout_o_v;
wire [0:WIDTH] fifoout_i_d, fifoout_o_d;
wire fft_out_buffer_ready, fft_in_buffer_ready;
wire next_fft_ready, fft_running, fft_done;
wire [0:LOG_FFT_CHUNK] sample_cnt_i, sample_cnt_o;
wire sample_cnt_enable;


assign fifoin_i_d = {i_d, i_e};
assign fifoin_i_v = i_v;
assign fifoin_o_r = fft_running;	
assign i_r = fifoin_i_r;


assign o_d = fifoout_o_d[1:WIDTH];
assign o_e = fifoout_o_d[0];
assign o_v = fifoout_o_v;
assign fifoout_o_r = o_r;


assign fifoout_cnt_avail = 2**OUT_FIFO_LOG_DEPTH;
assign fifoout_cnt_free =  fifoout_cnt_avail - fifoout_cnt;
assign fft_in_buffer_ready  = (fifoin_cnt>=FFT_CHUNK) ? 1'b1 : 1'b0;
assign fft_out_buffer_ready = (fifoout_cnt_free>=OUT_FIFO_SPACE_REQ) ? 1'b1 : 1'b0;

	
zcsl_fifo_wdcnt
#(	.WIDTH(WIDTH+1), .LOG_DEPTH(IN_FIFO_LOG_DEPTH), .CNT_WIDTH(COUNTERSIZE) )
IFIFOIN
(
	.clk(clk),
	.reset(reset),
	.wr_valid(fifoin_i_v),
	.wr_ready(fifoin_i_r),
	.wr_data(fifoin_i_d),
	.rd_valid(fifoin_o_v),
	.rd_ready(fifoin_o_r),
	.rd_data(fifoin_o_d),
	.wd_cnt(fifoin_cnt)
);


assign next_fft_ready = fft_in_buffer_ready & fft_out_buffer_ready & ~fft_running;
assign fft_running = |sample_cnt_o;
assign fft_done = sample_cnt_o[0];

assign sample_cnt_i = (fft_done==1'b1) ? 0 : sample_cnt_o + 1;
assign sample_cnt_enable = next_fft_ready | fft_running;
zcsl_dffea #(.WIDTH(LOG_FFT_CHUNK+1)) ISAMPLE_CNT(.clk(clk), .reset(reset), .enable(sample_cnt_enable), .i(sample_cnt_i), .o(sample_cnt_o));


////////////////////////
/////// F F T //////////
////////////////////////
wire [0:31] X0,X1,X2,X3;
wire [0:31] Y0,Y1,Y2,Y3;
wire shr_e_i, shr_e_o;

wire shr_v_i, shr_v_o;
wire next, next_out;



zcsl_endian_swap #(.BYTES(4)) ISWPX0(.i(fifoin_o_d[0:31]), .o(X0));
zcsl_endian_swap #(.BYTES(4)) ISWPX1(.i(fifoin_o_d[32:63]), .o(X1));
zcsl_endian_swap #(.BYTES(4)) ISWPX2(.i(fifoin_o_d[64:95]), .o(X2));
zcsl_endian_swap #(.BYTES(4)) ISWPX3(.i(fifoin_o_d[96:127]), .o(X3));


zcsl_endian_swap #(.BYTES(4)) ISWPY0(.i(Y0), .o(fifoout_i_d[1:32]));
zcsl_endian_swap #(.BYTES(4)) ISWPY1(.i(Y1), .o(fifoout_i_d[33:64]));
zcsl_endian_swap #(.BYTES(4)) ISWPY2(.i(Y2), .o(fifoout_i_d[65:96]));
zcsl_endian_swap #(.BYTES(4)) ISWPY3(.i(Y3), .o(fifoout_i_d[97:128]));

assign shr_e_i = fifoin_o_d[WIDTH];
assign shr_v_i = fft_running;

zcsl_shrea
#( .WIDTH(1), .LENGTH(FFT_LATENCY) )
ISHR_E
(
	.clk(clk),
	.reset(reset),
	.enable(1'b1),
	.i(shr_e_i),
	.o(shr_e_o)
);

zcsl_shrea
#( .WIDTH(1), .LENGTH(FFT_LATENCY) )
ISHR_V
(
	.clk(clk),
	.reset(reset),
	.enable(1'b1),
	.i(shr_v_i),
	.o(shr_v_o)
);

dft_top IFFTCORE (.clk(clk), .reset(reset), .next(next_fft_ready), .next_out(next_out), .X0(X0),.Y0(Y0),.X1(X1),.Y1(Y1),.X2(X2),.Y2(Y2),.X3(X3),.Y3(Y3));

////////////////////////
////////////////////////
////////////////////////


assign fifoout_i_v = shr_v_o;
assign fifoout_i_d[0] = shr_e_o;



zcsl_fifo_wdcnt
#(	.WIDTH(WIDTH+1), .LOG_DEPTH(OUT_FIFO_LOG_DEPTH), .CNT_WIDTH(COUNTERSIZE) )
IFIFOOUT
(
	.clk(clk),
	.reset(reset),
	.wr_valid(fifoout_i_v),
	.wr_ready(fifoout_i_r),
	.wr_data(fifoout_i_d),
	.rd_valid(fifoout_o_v),
	.rd_ready(fifoout_o_r),
	.rd_data(fifoout_o_d),
	.wd_cnt(fifoout_cnt)
);





endmodule

