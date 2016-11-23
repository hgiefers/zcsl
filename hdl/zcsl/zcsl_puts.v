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

module zcsl_puts
#(
	parameter PUTS = 1
)
(
	// Global Signals
	input clk,

	// Accelerator Buffer Interfaces (Read part only)
	output [0:3] ah_brlat,		// Read data ready latency
	output [0:511] ah_brdata,	// Read data
	output [0:7] ah_brpar,		// Read data parity	
	
	// PUT side
	input [0:PUTS-1] put_sel,
	input [0:PUTS*512-1] put_data
);


// ** Wire definitions **

// Staging PSL inputs

wire [0:PUTS-1] isel_i, isel_o;
wire [0:PUTS*512-1] idata_i, idata_o;

wire [0:PUTS-1] muxd_sel;
wire [0:PUTS*512-1] muxd_i;
wire [0:511] muxd_o;

wire [0:511] odata_i, odata_o;


// ** Routing & logic **
assign ah_brlat = 4'd3; // valid -> addr -> data -> pre-mux-reg -> post-mux-reg (at port)
assign ah_brpar = 8'd0; // TODO: Currently unused parity

assign isel_i = put_sel;
assign idata_i = put_data;

assign muxd_sel = isel_o;
assign muxd_i = idata_o;

assign odata_i = muxd_o;
assign ah_brdata = odata_o;


// ** Instances **
zcsl_dff #(.WIDTH(1))   IDFF_ISEL[0:PUTS-1] (.clk(clk), .i(isel_i), .o(isel_o));
zcsl_dff #(.WIDTH(512)) IDFF_IDATA[0:PUTS-1](.clk(clk), .i(idata_i), .o(idata_o));

zcsl_selector #(.WAYS(PUTS), .WIDTH(512)) IMUXD(.sel(muxd_sel), .i(muxd_i), .o(muxd_o));

zcsl_dff #(.WIDTH(512)) IDFF_ODATA(.clk(clk), .i(odata_i), .o(odata_o));


endmodule

