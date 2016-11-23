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

module zcsl_lag
#(
	parameter AW = 64,
	parameter SW = 32
)
(
	input clk,
	input reset,
	
	input i_v,
	output i_r,
	input [0:AW-1] i_base,
	input [0:SW-1] i_size,
	
	output o_v,
	input o_r,
	output o_e,
	output [0:AW-1] o_addr
);



// ** Wire definitions **

wire start;

// No. of cachelines
wire [0:SW-6-1] ncl;

// Cacheline counter
wire cntcl_enable;
wire [0:SW-6-1] cntcl_i, cntcl_o;

// Address counter
wire cntad_enable;
wire [0:AW-1] cntad_i, cntad_o;

// Address reg
wire addr_enable;
wire [0:AW-1] addr_i, addr_o;

// Valid reg
wire valid_enable;
wire valid_i, valid_o;

// End reg
wire end_enable;
wire end_i, end_o;

// Busy reg
wire busy_enable;
wire busy_i, busy_o;


// ** Routing & logic **

assign start = i_v & i_r;


// No. of cachelines
assign ncl = {1'b0, i_size[0:SW-7-1]} + { {SW-7 {1'b0}}, |i_size[SW-7:SW-1]};


// Cacheline counter
assign cntcl_enable = start | (~o_v | (o_v & o_r));
assign cntcl_i = start ? ncl : cntcl_o-{ {SW-7  {1'b0}}, 1'b1 };

// Address counter
assign cntad_enable = start | (~o_v | (o_v & o_r));
assign cntad_i = start ? i_base : cntad_o + { {AW-8 {1'b0}}, 8'd128 };

// Address reg
assign addr_enable = ~o_v | (o_v & o_r);
assign addr_i = cntad_o;
assign o_addr = addr_o;

// Valid reg
assign valid_enable = ~o_v | (o_v & o_r);
assign valid_i = (busy_o | o_v) & ~o_e;
assign o_v = valid_o;

// End reg
assign end_enable = ~o_v | (o_v & o_r);
assign end_i = (cntcl_o=={ {SW-7 {1'b0}}, 1'b1 });
assign o_e = end_o;

// Busy reg
assign busy_enable = start | (o_v & o_r & o_e);
assign busy_i = start;
assign i_r = ~busy_o;

// ** Instances **


// Cacheline counter
zcsl_dffea #(.WIDTH(SW-6)) ICNTCL(.clk(clk), .reset(reset), .enable(cntcl_enable), .i(cntcl_i), .o(cntcl_o));

// Address counter
zcsl_dffea #(.WIDTH(AW)) ICNTAD(.clk(clk), .reset(reset), .enable(cntad_enable), .i(cntad_i), .o(cntad_o));

// Address reg
zcsl_dffea #(.WIDTH(AW)) IADDR(.clk(clk), .reset(reset), .enable(addr_enable), .i(addr_i), .o(addr_o));

// Valid reg
zcsl_dffea #(.WIDTH(1)) IVALID(.clk(clk), .reset(reset), .enable(valid_enable), .i(valid_i), .o(valid_o));

// End reg
zcsl_dffea #(.WIDTH(1)) IEND(.clk(clk), .reset(reset), .enable(end_enable), .i(end_i), .o(end_o));

// Busy reg
zcsl_dffea #(.WIDTH(1)) IBUSY(.clk(clk), .reset(reset), .enable(busy_enable), .i(busy_i), .o(busy_o));

endmodule

