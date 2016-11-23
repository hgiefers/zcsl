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


module zcsl_sequencer
#(
	parameter IN_WIDTH = 128,
	parameter OUT_WIDTH = 32,
	parameter CHUNKS = IN_WIDTH/OUT_WIDTH
)
(
	input clk,
	input reset,

	// INPUT
	input i_v,
	input i_e,
	output i_r,
	input [0:IN_WIDTH-1] i_d,
	input [0:CHUNKS-1] i_c,


	// OUTPUT
	input o_r,
	output o_v,
	output o_e,
	output [0:OUT_WIDTH-1] o_d
);

// ** Wire declaration
wire c_ena;
wire [0:CHUNKS-1] c_i_d, c_o_d;

wire d_ena;
wire [0:CHUNKS*OUT_WIDTH-1] d_i_d, d_o_d;

wire e_ena, e_i_d, e_o_d;

wire [0:CHUNKS*OUT_WIDTH-1] shft_d;

wire accept;
wire empty;
wire last;


// ** Routing
assign accept = i_r & i_v;
assign empty = ~(|c_o_d[0:CHUNKS-1]);
assign last = ~(|c_o_d[1:CHUNKS-1]) & c_o_d[0];

assign i_r = (last & o_r) | empty; // either empty or last data out gets accepted

assign c_ena = accept | (~empty & o_r);
assign d_ena = accept | (~empty & o_r);
assign e_ena = accept;

assign e_i_d = i_e;

assign c_i_d = {c_o_d[1:CHUNKS-1], 1'b0} | (i_c & {CHUNKS {accept}}); //{CHUNKS {accept}};


assign d_i_d = accept ? i_d : shft_d;
assign shft_d = {d_o_d[OUT_WIDTH:CHUNKS*OUT_WIDTH-1], {OUT_WIDTH {1'b0}} };

assign o_v = ~empty;
assign o_d = d_o_d[0:OUT_WIDTH-1];
assign o_e = e_o_d & last;



// ** Instances

zcsl_dffea #(.WIDTH(1))         ICTRL[0:CHUNKS-1](.clk(clk), .reset(reset), .enable(c_ena), .i(c_i_d), .o(c_o_d));
zcsl_dffea #(.WIDTH(OUT_WIDTH)) IDATA[0:CHUNKS-1](.clk(clk), .reset(reset), .enable(d_ena), .i(d_i_d), .o(d_o_d));
zcsl_dffea #(.WIDTH(1))         IEND             (.clk(clk), .reset(reset), .enable(e_ena), .i(e_i_d), .o(e_o_d));


endmodule 
