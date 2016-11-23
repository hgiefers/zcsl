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

module zcsl_put
#(
	parameter WIDTH = 1
)
(
	// Global Signals
	input clk,
	input reset,

	// Accelerator Buffer Interfaces (Read part only)
	input ha_brvalid,			// A read transfer is present
	input [0:7] ha_brtag,		// Accelerator generated ID for read
	input [0:5] ha_brad,		// half line index of read data
//	output [0:3] ah_brlat,		// Read data ready latency
	output [0:511] ah_brdata,	// Read data
	output [0:7] ah_brpar,		// Read data parity
	
	output sel,			// Indicates whether the BRTAG belongs to this PUT unit

	// Response Interface to PSL
	input ha_rvalid,            //A response is present
	input [0:7] ha_rtag,        //Accelerator generated request ID
	input [0:7] ha_response,    //response code
	input [0:8] ha_rcredits,    //twos compliment number of credits
	input [0:1] ha_rcachestate, //Resultant Cache State
	input [0:12] ha_rcachepos,  //Cache location id
	input ha_rtagpar,

	
	// Command
	output cmd_valid,
	output cmd_cache,
	input cmd_ack,
	output [0:63] cmd_ea,
	input [0:7] cmd_tag,
	
	// PUT side
	input put_v,
	output put_r,
	input put_e,
	input [0:63] put_addr,
	input put_data_v,
	output put_data_r,
	input put_data_e,
	input [0:511] put_data_d,
	output put_done
);


// ** Wire definitions **
localparam FIFOEA_LOG_DEPTH = 7;
localparam FIFOEA_WIDTH = 64+1; // ea + end flag

localparam RAMD_AW = 7+1;
localparam RAMD_DW = 512;

localparam RAMB_AW = 7;
localparam RAMB_DW = 7;

localparam FIFOR_LOG_DEPTH = 7;
localparam FIFOR_WIDTH = 7+1; // tag + end flag

localparam RAMR_AW = 7; // tag
localparam RAMR_DW = 7+1; // index + end flag

// Staging PSL inputs
wire ha_brvalid_q;
wire [0:7] ha_brtag_q;
wire [0:5] ha_brad_q;

wire ha_rvalid_q;
wire [0:7] ha_rtag_q;
wire [0:7] ha_response_q;
wire [0:8] ha_rcredits_q;
wire [0:1] ha_rcachestate_q;
wire [0:12] ha_rcachepos_q;
wire ha_rtagpar_q;

wire sel_i, sel_o;
wire sel2_i, sel2_o;

wire putdone_i, putdone_o;

// Register output data
wire [0:511] odata_i, odata_o;

// Fence mask
wire [0:127] fmsk_s, fmsk_r, fmsk_o;
wire fhit_i, fhit_o;

// Response mask
wire [0:127] rmsk_s, rmsk_r, rmsk_o;

// End mask
wire [0:127] emsk_s, emsk_r, emsk_o;

// Data write counter
wire cntdw_enable;
wire [0:RAMD_AW-1] cntdw_i, cntdw_o;

// Data read counter
wire cntdr_enable;
wire [0:RAMD_AW-1] cntdr_i, cntdr_o;

// Data fill counter
wire cntdf_enable;
wire [0:RAMD_AW-1] cntdf_i, cntdf_o;

// Data unsubmitted counter
wire cntdu_enable;
wire [0:RAMD_AW-1] cntdu_i, cntdu_o;

// Data unsubmitted counter
wire cntrs_enable;
wire [0:6] cntrs_i, cntrs_o;

// Decode command tag
wire decct_enable;
wire [0:6] decct_i;
wire [0:127] decct_o;

// Decode response tag
wire decrt_enable;
wire [0:6] decrt_i;
wire [0:127] decrt_o;

// Decode response index
wire decri_enable;
wire [0:6] decri_i;
wire [0:127] decri_o;

// Decode buffer tag
wire decbt_enable;
wire [0:6] decbt_i;
wire [0:127] decbt_o;

// Decode queue tag
wire decqt_enable;
wire [0:6] decqt_i;
wire [0:127] decqt_o;

// EA FIFO
wire fifoea_wr_valid;
wire fifoea_wr_ready;
wire [0:FIFOEA_WIDTH-1] fifoea_wr_data;
wire fifoea_rd_valid;
wire fifoea_rd_ready;
wire [0:FIFOEA_WIDTH-1] fifoea_rd_data;

// DATA RAM
wire ramd_wr_ena;
wire [0:RAMD_AW-1] ramd_wr_addr;
wire [0:RAMD_DW-1] ramd_wr_data;
wire [0:RAMD_AW-1] ramd_rd_addr;
wire [0:RAMD_DW-1] ramd_rd_data;

// INDEX RAM for buffer
wire ramb_wr_ena;
wire [0:RAMB_AW-1] ramb_wr_addr;
wire [0:RAMB_DW-1] ramb_wr_data;
wire [0:RAMB_AW-1] ramb_rd_addr;
wire [0:RAMB_DW-1] ramb_rd_data;


// INDEX RAM for response
wire ramr_wr_ena;
wire [0:RAMR_AW-1] ramr_wr_addr;
wire [0:RAMR_DW-1] ramr_wr_data;
wire [0:RAMR_AW-1] ramr_rd_addr;
wire [0:RAMR_DW-1] ramr_rd_data;
wire [0:RAMR_DW-1] ramr_rd_data_q;


// 
wire cmd_end;
wire rsp_end;

// ** Routing & logic **
assign ah_brpar = 8'd0;
assign cmd_cache = 1'b0;

assign sel_i = |(decbt_o & fmsk_o);
assign sel2_i = sel_o;
assign sel = sel2_i;

// Register output data
assign odata_i = ramd_rd_data;
assign ah_brdata = odata_i;

// Fence mask
assign fmsk_s = decct_o;
assign fmsk_r = decrt_o & fmsk_o;

// Fence hit
assign fhit_i = |(fmsk_o & decrt_o);

// Response mask
assign rmsk_s = decri_o;
assign rmsk_r = decqt_o;

// End mask
assign emsk_s = decri_o & {128 {ramr_rd_data_q[7]}};
assign emsk_r = decqt_o;
assign putdone_i = |(rmsk_o & emsk_o & decqt_o);
assign put_done = putdone_o;

// Data write counter
assign cntdw_enable = put_data_v & put_data_r;
assign cntdw_i = cntdw_o + 8'd1;

// Data read counter
assign cntdr_enable = cmd_ack;
assign cntdr_i = cntdr_o + 8'd2; // One command reads two half-cachelines

// Data fill counter
assign cntdf_enable = (put_data_v & put_data_r) | cntrs_enable;
assign cntdf_i = (put_data_v & put_data_r & ~cntrs_enable) ? cntdf_o + 8'd1 : ((put_data_v & put_data_r & cntrs_enable) ? cntdf_o - 8'd1 : ( ( (~put_data_v | ~put_data_r) & cntrs_enable) ? cntdf_o - 8'd2 : cntdf_o) );
assign put_data_r = ~cntdf_o[0];

// Data fill counter
assign cntdu_enable = (put_data_v & put_data_r) | fifoea_rd_ready;
assign cntdu_i = (put_data_v & put_data_r & ~fifoea_rd_ready) ? cntdu_o + 8'd1 : ((put_data_v & put_data_r & fifoea_rd_ready) ? cntdu_o - 8'd1 : ( ( (~put_data_v | ~put_data_r) & fifoea_rd_ready) ? cntdu_o - 8'd2 : cntdf_o) );

// Data response counter
assign cntrs_enable = |(rmsk_o & decqt_o);
assign cntrs_i = cntrs_o + 7'd1;

// Decode command tag
assign decct_enable = cmd_ack;
assign decct_i = cmd_tag[1:7];

// Decode response tag
assign decrt_enable = ha_rvalid_q & (ha_response_q==8'd0);
assign decrt_i = ha_rtag_q[1:7];

// Decode response index
assign decri_enable = fhit_o;
assign decri_i = ramr_rd_data_q[0:6];

// Decode buffer tag
assign decbt_enable = ha_brvalid_q;
assign decbt_i = ha_brtag_q[1:7];

// Decode queue tag
assign decqt_enable = 1'b1;
assign decqt_i = cntrs_o;

// EA FIFO
assign fifoea_wr_valid = put_v;
assign put_r = fifoea_wr_ready;
assign fifoea_wr_data = {put_addr, put_e};
assign fifoea_rd_ready = cmd_ack;
assign cmd_valid = fifoea_rd_valid & (cntdu_o[0:7]>8'd1); // TODO: Data dependency? Too many put_v vs. too few put_data_v
assign cmd_ea = fifoea_rd_data[0:63];
assign cmd_end = fifoea_rd_data[64];

// DATA RAM
assign ramd_wr_ena = put_data_v & put_data_r;
assign ramd_wr_addr = cntdw_o;
assign ramd_wr_data = put_data_d;
assign ramd_rd_addr = {ramb_rd_data, 1'b0} + { 7'd0, ha_brad_q[5]};//{ramb_rd_data[0:7], ha_brad_q[5]};

// INDEX RAM for buffer
assign ramb_wr_ena = cmd_ack;
assign ramb_wr_addr = cmd_tag[1:7];
assign ramb_wr_data = cntdr_o[0:RAMD_AW-2];// TODO: Check again
assign ramb_rd_addr = ha_brtag[1:7];

// INDEX RAM for response
assign ramr_wr_ena = cmd_ack;
assign ramr_wr_addr = cmd_tag[1:7];
assign ramr_wr_data = {cntdr_o[0:RAMD_AW-2], cmd_end};
assign ramr_rd_addr = ha_rtag[1:7];
//wire [0:RAMR_DW-1] ramr_rd_data;

// TODO: THIS IS JUST FOR WORKING PURPOSES!!!!! FIX THIS!!!!
//assign fifor_rd_ready = |(rmsk_o & decqt_o);
//assign put_done = fifor_rd_data[8] & fifor_rd_valid & fifor_rd_ready;
//assign fifor_rd_ready = |(rmsk_o & decqt_o);
//assign put_done = ramr_rd_data[0:RAMD_AW-1] & fifor_rd_valid & fifor_rd_ready;
//assign fifor_rd_ready = 1'b1;



// ** Instances **
// Staging PSL inputs
zcsl_dff #(.WIDTH(1))   IDFF_BRVALID(.clk(clk), .i(ha_brvalid), .o(ha_brvalid_q));
zcsl_dff #(.WIDTH(8))   IDFF_BRTAG  (.clk(clk), .i(ha_brtag),   .o(ha_brtag_q));
zcsl_dff #(.WIDTH(6))   IDFF_BRAD   (.clk(clk), .i(ha_brad),    .o(ha_brad_q));

zcsl_dff #(.WIDTH(1))  IRVALID (.clk(clk), .i(ha_rvalid),      .o(ha_rvalid_q));
zcsl_dff #(.WIDTH(8))  IRTAG   (.clk(clk), .i(ha_rtag),        .o(ha_rtag_q));
zcsl_dff #(.WIDTH(8))  IRESP   (.clk(clk), .i(ha_response),    .o(ha_response_q));
zcsl_dff #(.WIDTH(9))  IRCREDIT(.clk(clk), .i(ha_rcredits),    .o(ha_rcredits_q));
zcsl_dff #(.WIDTH(2))  IRCSTATE(.clk(clk), .i(ha_rcachestate), .o(ha_rcachestate_q));
zcsl_dff #(.WIDTH(13)) IRCPOS  (.clk(clk), .i(ha_rcachepos),   .o(ha_rcachepos_q));
zcsl_dff #(.WIDTH(1))  IRTAGPAR(.clk(clk), .i(ha_rtagpar),     .o(ha_rtagpar_q));


zcsl_dff #(.WIDTH(1))   IDFF_SEL   (.clk(clk), .i(sel_i),    .o(sel_o));
zcsl_dff #(.WIDTH(1))   IDFF_SEL2  (.clk(clk), .i(sel2_i),   .o(sel2_o));

zcsl_dff #(.WIDTH(1))   IDFF_PUTDONE  (.clk(clk), .i(putdone_i),   .o(putdone_o));

// Register output data
zcsl_dff #(.WIDTH(512))   IDFF_ODATA(.clk(clk), .i(odata_i),    .o(odata_o));

// Fence mask
zcsl_srffa #(.WIDTH(128)) IFMSK(.clk(clk), .reset(reset), .s(fmsk_s), .r(fmsk_r), .o(fmsk_o));

// Fence hit
zcsl_dff #(.WIDTH(1))  IFHIT(.clk(clk), .i(fhit_i), .o(fhit_o));

// Response mask
zcsl_srffa #(.WIDTH(128)) IRMSK(.clk(clk), .reset(reset), .s(rmsk_s), .r(rmsk_r), .o(rmsk_o));

// End mask
zcsl_srffa #(.WIDTH(128)) IEMSK(.clk(clk), .reset(reset), .s(emsk_s), .r(emsk_r), .o(emsk_o));

// Data write counter
zcsl_dffea #(.WIDTH(RAMD_AW)) ICNTDW(.clk(clk), .reset(reset), .enable(cntdw_enable), .i(cntdw_i), .o(cntdw_o));

// Data read counter
zcsl_dffea #(.WIDTH(RAMD_AW)) ICNTDR(.clk(clk), .reset(reset), .enable(cntdr_enable), .i(cntdr_i), .o(cntdr_o));

// Data fill counter
zcsl_dffea #(.WIDTH(RAMD_AW)) ICNTDF(.clk(clk), .reset(reset), .enable(cntdf_enable), .i(cntdf_i), .o(cntdf_o));

// Data unsubmitted counter
zcsl_dffea #(.WIDTH(RAMD_AW)) ICNTDU(.clk(clk), .reset(reset), .enable(cntdu_enable), .i(cntdu_i), .o(cntdu_o));

// Data response counter
zcsl_dffea #(.WIDTH(RAMD_AW)) ICNTRS(.clk(clk), .reset(reset), .enable(cntrs_enable), .i(cntrs_i), .o(cntrs_o));

// Decode command tag
zcsl_decode#(.WIDTH(7)) IDECCT(.enable(decct_enable), .i(decct_i), .o(decct_o));

// Decode reponse tag
zcsl_decode#(.WIDTH(7)) IDECRT(.enable(decrt_enable), .i(decrt_i), .o(decrt_o));

// Decode reponse index
zcsl_decode#(.WIDTH(7)) IDECRI(.enable(decri_enable), .i(decri_i), .o(decri_o));

// Decode buffer tag
zcsl_decode#(.WIDTH(7)) IDECBT(.enable(decbt_enable), .i(decbt_i), .o(decbt_o));

// Decode queue tag
zcsl_decode#(.WIDTH(7)) IDECQT(.enable(decqt_enable), .i(decqt_i), .o(decqt_o));

// EA FIFO
zcsl_fifo
#(
	.WIDTH(FIFOEA_WIDTH),
	.LOG_DEPTH(FIFOEA_LOG_DEPTH)
)
IFIFOEA
(
	.clk(clk),
	.reset(reset),
	.wr_valid(fifoea_wr_valid),
	.wr_ready(fifoea_wr_ready),
	.wr_data(fifoea_wr_data),
	.rd_valid(fifoea_rd_valid),
	.rd_ready(fifoea_rd_ready),
	.rd_data(fifoea_rd_data)
);

// DATA RAM
zcsl_ram_1r1w
#(
	.DW(RAMD_DW),
	.AW(RAMD_AW)
)
IRAMD
(
	.clk(clk),
	.wr_ena(ramd_wr_ena),
	.wr_addr(ramd_wr_addr),
	.wr_data(ramd_wr_data),
	.rd_addr(ramd_rd_addr),
	.rd_data(ramd_rd_data)
);

// INDEX RAM for buffer
zcsl_ram_1r1w
#(
	.DW(RAMB_DW),
	.AW(RAMB_AW)
)
IRAMB
(
	.clk(clk),
	.wr_ena(ramb_wr_ena),
	.wr_addr(ramb_wr_addr),
	.wr_data(ramb_wr_data),
	.rd_addr(ramb_rd_addr),
	.rd_data(ramb_rd_data)
);


// INDEX RAM for response
zcsl_ram_1r1w
#(
	.DW(RAMR_DW),
	.AW(RAMR_AW)
)
IRAMR
(
	.clk(clk),
	.wr_ena(ramr_wr_ena),
	.wr_addr(ramr_wr_addr),
	.wr_data(ramr_wr_data),
	.rd_addr(ramr_rd_addr),
	.rd_data(ramr_rd_data)
);
zcsl_dff #(.WIDTH(RAMR_DW))  IRAMR_RDQ(.clk(clk), .i(ramr_rd_data),     .o(ramr_rd_data_q));


integer ocmds = 0;
integer irsps = 0;

always@(posedge(clk)) begin
	
	if(cmd_ack) begin
		ocmds = ocmds+1;
		$display("@%d: PUT CMDs %d", $time, ocmds);
	//	$display("@%d: CMD TAG %x", $time, cmd_tag);	
	end
	
	if(|(decrt_o & fmsk_o)) begin
		irsps = irsps+1;
		$display("@%d: PUT RSPs %d", $time, irsps);
	//	$display("@%d: RSP TAG %x", $time, ha_rtag_q);	
	end
	
	//if(put_data_v & put_data_r) begin
	//	$display("@%d: PUT DATA %x", $time, put_data_d);	
	//end
	
	//if(sel) begin
	//	$display("@%d: BR DATA %x", $time, ah_brdata);	
	//end
	
end


endmodule

