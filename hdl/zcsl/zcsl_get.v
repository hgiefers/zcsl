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

module zcsl_get
(
	// Global Signals
	input clk,
	input reset,

	// Accelerator Buffer Interfaces (Write part only)
	input ha_bwvalid,			// A write data transfer is present
	input [0:7] ha_bwtag,		// Accelerator ID of the write
	input [0:5] ha_bwad,		// half line index of write data
	input [0:511] ha_bwdata,	// Write data
	input [0:7] ha_bwpar,		// Write data parity
	input ha_bwtagpar,			// Write tag parity

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
	
	// GET side
	input get_v,
	output get_r,
	input get_e,
	input [0:63] get_addr,
	input [0:6] get_size, // 0 for 128B, 1-> 1B, 2->2B, 4->4B, ... 64->64B
	output get_data_v,
	input get_data_r,
	output get_data_e,
	output [0:511] get_data_d
);


// ** Wire definitions **
localparam RAMD_AW = 7+1;
localparam RAMD_DW = 512+1;

localparam RAMB_AW = 7;
localparam RAMB_DW = 7+1+1;

localparam RAMR_AW = 7;
localparam RAMR_DW = 7+1+1;

// Staging PSL inputs
wire ha_bwvalid_q;
wire [0:511] ha_bwdata_q;
wire [0:7] ha_bwtag_q;
wire [0:5] ha_bwad_q;
wire ha_rvalid_q;
wire [0:7] ha_rtag_q;
wire [0:7] ha_response_q;
wire [0:8] ha_rcredits_q;
wire [0:1] ha_rcachestate_q;
wire [0:12] ha_rcachepos_q;
wire ha_rtagpar_q;

// Decode positive response
wire response_valid;
wire response_valid_q;

// Index counter
wire cnti_enable;
wire [0:RAMR_DW-1] cnti_i, cnti_o;

// Data index counter
wire cntdi_enable;
wire [0:RAMD_AW+1-1] cntdi_i, cntdi_o;

// Fill level counter
wire cntfl_enable;
wire [0:RAMD_AW+1-1] cntfl_i, cntfl_o;

// Decode response index
wire decri_enable;
wire [0:6] decri_i;
wire [0:127] decri_o;

// Decode data index
wire decdi_enable;
wire [0:6] decdi_i;
wire [0:127] decdi_o;

// Decode command tag
wire decct_enable;
wire [0:6] decct_i;
wire [0:127] decct_o;

// Decode response tag
wire decrt_enable;
wire [0:6] decrt_i;
wire [0:127] decrt_o;
wire [0:127] decrt_o_q;

// Decode buffer tag
wire decbt_enable;
wire [0:6] decbt_i;
wire [0:127] decbt_o;
wire [0:127] decbt_o_q;

// Fence mask
wire [0:127] fmsk_enable;
wire [0:127] fmsk_i, fmsk_o;

// Response mask
wire [0:127] rmsk_enable;
wire [0:127] rmsk_i, rmsk_o;

// Data valid flag
wire valid_enable;
wire valid_i, valid_o;

// DATA RAM
wire ramd_wr_ena;
wire [0:RAMD_AW-1] ramd_wr_addr;
wire [0:RAMD_DW-1] ramd_wr_data;
wire [0:RAMD_AW-1] ramd_rd_addr;
wire [0:RAMD_DW-1] ramd_rd_data;
wire ramd_rd_data_enable;
wire [0:RAMD_DW-1] ramd_rd_data_q;

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




// ** Routing & logic **

assign cmd_valid = get_v & ~cntfl_o[1]; // Do not submit more cmds than free slots
assign cmd_cache = 1'b0;
assign cmd_ea = get_addr;

// GET side
assign get_r = cmd_ack;
assign get_data_v = valid_o;
assign get_data_e = ramd_rd_data_q[512];
assign get_data_d = ramd_rd_data_q[0:511];

assign response_valid = ha_rvalid & (ha_response==8'd0);

// Index counter
assign cnti_enable = cmd_ack;
assign cnti_i = cnti_o + 8'd1;

// Data index counter
assign cntdi_enable = valid_i & valid_enable;//get_data_v & get_data_r;
assign cntdi_i = cntdi_enable ? cntdi_o + 8'd1 : cntdi_o;

// Fill level counter
assign cntfl_enable = (valid_i & valid_enable & cntdi_o[RAMD_AW]) | cmd_ack;
assign cntfl_i = (cmd_ack & ~(valid_i & valid_enable & cntdi_o[RAMD_AW])) ? cntfl_o+9'd1 : ((~cmd_ack & (valid_i & valid_enable & cntdi_o[RAMD_AW])) ? cntfl_o-9'd1 : cntfl_o);

// Decode response index
assign decri_enable = |decrt_o_q; //|(fmsk_o & decrt_o_q);// pol new
assign decri_i = ramr_rd_data[0:6];

// Decode data index
assign decdi_enable = 1'b1;
assign decdi_i = cntdi_o[0:RAMD_AW-1];

// Decode command tag
assign decct_enable = cmd_ack;
assign decct_i = cmd_tag[1:7];

// Decode reponse tag
assign decrt_enable = response_valid_q;
assign decrt_i = ha_rtag_q[1:7];

// Decode buffer tag
assign decbt_enable = ha_bwvalid; // Can be 1? // was Q
assign decbt_i = ha_bwtag[1:7]; // was Q

// Fence mask
assign fmsk_enable = decct_o | decrt_o_q;//decct_o | (decrt_o_q & fmsk_o);// pol new
assign fmsk_i = (decct_o | fmsk_o) & ~decrt_o_q;

// Response mask
assign rmsk_enable = decri_o | (decdi_o & {128 {cntdi_o[RAMD_AW]}});
assign rmsk_i = (decri_o | rmsk_o) & ~(decdi_o & {128 {cntdi_o[RAMD_AW] & valid_enable}});

// Data valid flag
assign valid_enable = (get_data_v & get_data_r) | ~get_data_v;
//assign valid_i = |(rmsk_o & decdi_o);
assign valid_i = rmsk_o[cntdi_o[1:RAMD_AW-1]];


// DATA RAM
assign ramd_wr_ena = |decbt_o_q; // pol new //|(fmsk_o & decbt_o_q);
assign ramd_wr_addr = {ramb_rd_data[0:6], ha_bwad_q[5]};
assign ramd_wr_data = {ha_bwdata_q, (ramb_rd_data[7] & ha_bwad_q[5])}; // TODO: Enhance end flag to support read of half cachelines
assign ramd_rd_addr = cntdi_i;
assign ramd_rd_data_enable = (get_data_v & get_data_r) | ~get_data_v;

// INDEX RAM for buffer
assign ramb_wr_ena = cmd_ack;
assign ramb_wr_addr = cmd_tag[1:7];
assign ramb_wr_data = {cnti_o, get_e, 1'b0}; // Reserved bit for half cacheline reads
assign ramb_rd_addr = ha_bwtag[1:7]; // Unstaged signal to avoid double staging data

// INDEX RAM for response
assign ramr_wr_ena = cmd_ack;
assign ramr_wr_addr = cmd_tag[1:7];
assign ramr_wr_data = {cnti_o, get_e, 1'b0}; // Reserved bit for half cacheline reads
assign ramr_rd_addr = ha_rtag_q[1:7]; // Unstaged signal to have immediate lookup index


// ** Instances **
// Staging PSL inputs
zcsl_dff #(.WIDTH(1))   IDFF_BWVALID(.clk(clk), .i(ha_bwvalid), .o(ha_bwvalid_q));
zcsl_dff #(.WIDTH(512)) IDFF_BWDATA (.clk(clk), .i(ha_bwdata),  .o(ha_bwdata_q));
zcsl_dff #(.WIDTH(8))   IDFF_BWTAG  (.clk(clk), .i(ha_bwtag),   .o(ha_bwtag_q));
zcsl_dff #(.WIDTH(6))   IDFF_BWAD   (.clk(clk), .i(ha_bwad),    .o(ha_bwad_q));

zcsl_dff #(.WIDTH(1))  IRVALID (.clk(clk), .i(ha_rvalid),      .o(ha_rvalid_q));
zcsl_dff #(.WIDTH(8))  IRTAG   (.clk(clk), .i(ha_rtag),        .o(ha_rtag_q));
zcsl_dff #(.WIDTH(8))  IRESP   (.clk(clk), .i(ha_response),    .o(ha_response_q));
zcsl_dff #(.WIDTH(9))  IRCREDIT(.clk(clk), .i(ha_rcredits),    .o(ha_rcredits_q));
zcsl_dff #(.WIDTH(2))  IRCSTATE(.clk(clk), .i(ha_rcachestate), .o(ha_rcachestate_q));
zcsl_dff #(.WIDTH(13)) IRCPOS  (.clk(clk), .i(ha_rcachepos),   .o(ha_rcachepos_q));
zcsl_dff #(.WIDTH(1))  IRTAGPAR(.clk(clk), .i(ha_rtagpar),     .o(ha_rtagpar_q));

zcsl_dff #(.WIDTH(128))  IDECTBQ(.clk(clk), .i(decbt_o & fmsk_o),     .o(decbt_o_q));// pol new
zcsl_dff #(.WIDTH(128))  IDECTRQ(.clk(clk), .i(decrt_o & fmsk_o),     .o(decrt_o_q));// pol new

// Decode positive response
zcsl_dff #(.WIDTH(1))  IRSPVAL(.clk(clk), .i(response_valid),  .o(response_valid_q));

// Index counter
zcsl_dffea #(.WIDTH(RAMR_DW)) ICNTI(.clk(clk), .reset(reset), .enable(cnti_enable), .i(cnti_i), .o(cnti_o));

// Data index counter
zcsl_dffea #(.WIDTH(RAMD_AW+1)) ICNTDI(.clk(clk), .reset(reset), .enable(cntdi_enable), .i(cntdi_i), .o(cntdi_o));

// Fill level counter
zcsl_dffea #(.WIDTH(RAMD_AW+1)) ICNTFL(.clk(clk), .reset(reset), .enable(cntfl_enable), .i(cntfl_i), .o(cntfl_o));

// Decode response index
zcsl_decode#(.WIDTH(7)) IDECRI(.enable(decri_enable), .i(decri_i), .o(decri_o));

// Decode data index
zcsl_decode#(.WIDTH(7)) IDECDI(.enable(decdi_enable), .i(decdi_i), .o(decdi_o));

// Decode command tag
zcsl_decode#(.WIDTH(7)) IDECCT(.enable(decct_enable), .i(decct_i), .o(decct_o));

// Decode reponse tag
zcsl_decode#(.WIDTH(7)) IDECRT(.enable(decrt_enable), .i(decrt_i), .o(decrt_o));

// Decode buffer tag
zcsl_decode#(.WIDTH(7)) IDECBT(.enable(decbt_enable), .i(decbt_i), .o(decbt_o));

// Fence mask
zcsl_dffea #(.WIDTH(1)) IFMSK[0:127](.clk(clk), .reset(reset), .enable(fmsk_enable), .i(fmsk_i), .o(fmsk_o));

// Response mask
zcsl_dffea #(.WIDTH(1)) IRMSK[0:127](.clk(clk), .reset(reset), .enable(rmsk_enable), .i(rmsk_i), .o(rmsk_o));

// Data valid flag
zcsl_dffea #(.WIDTH(1)) IVALID(.clk(clk), .reset(reset), .enable(valid_enable), .i(valid_i), .o(valid_o));

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
zcsl_dffea #(.WIDTH(RAMD_DW)) IRAMDRDQ(.clk(clk), .reset(reset), .enable(ramd_rd_data_enable), .i(ramd_rd_data), .o(ramd_rd_data_q));

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

/*
always@(posedge(clk)) begin
	
	if(ramb_wr_ena) begin
		$display("@%d: TAG %x,  DI=%d", $time, cmd_tag, cnti_o);
	
	end
end
*/

endmodule

