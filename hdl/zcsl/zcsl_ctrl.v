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

module zcsl_ctrl
(
	// Global Signals
	input clk,

	// Accelerator Control Interface
	input ha_jval,				// A valid job control command is present
	input [0:7] ha_jcom,		// Job control command opcode
	input [0:63] ha_jea,		// Save/Restore address
	output ah_jrunning,			// Accelerator is running level
	output ah_jdone,			// Accelerator is finished pulse
	output ah_jcack,			// Accelerator is with context llcmd pulse
	output [0:63] ah_jerror,	// Accelerator error code. 0 = success
	output ah_tbreq,			// Timebase request pulse
	output ah_jyield,			// Accelerator wants to stop
	input ha_jeapar,			// Parity for ha_jea
	input ha_jcompar,			// Parity for ha_jcom
	output ah_paren,			// 1 = AFU provides parity generation,
	
	// MMIO Side
	input mm_stop,
	
	// CMD Side
	output cmd_start,
	
	// Core Interface
	output core_start,			// Core start pulse
	output [0:63] core_wed,		// Core WED address
	input core_done,			// Core done pulse
	output core_reset			// Reset pulse (2 cycles to avoid timing problems)
);

// ** General comments
// jcom codes
// 0x90  = Start, jea contains WED address. jrunning should transition to 1
// 0x80  = Reset

// ** Wire definitions
wire local_reset;
wire mm_stop_q;

// Stage input signals for timing
wire jval_q;
wire [0:7] jcom_q;

// Status register if AFU is ON
wire afu_on_enable, afu_on_i, afu_on_o;

// Delay registers for local reset
wire rst_i, rst_o;
wire rst2_i, rst2_o;
wire rst3_i, rst3_o;

// Core controls
wire core_done_q;
wire cs_i, cs_o;
wire wed_enable;
wire [0:63] wed_i, wed_o;


// ** Routing and Logic
assign local_reset = rst2_o;

assign ah_jcack		= 1'b0;
assign ah_jerror	= 64'h0000000000000000;
assign ah_tbreq		= 1'b0;
assign ah_jyield	= 1'b0;
assign ah_paren		= 1'b0;

// Outputs
assign ah_jdone    = rst3_o | core_done_q | mm_stop_q; // Acknowledge reset and done
assign core_reset  = rst_o | rst2_o; // Trigger reset
assign ah_jrunning = afu_on_o & ~core_done & ~mm_stop;
assign core_start  = cs_o;
assign core_wed    = wed_o;

// Status register if AFU is ON
assign afu_on_i      = ((jcom_q==8'h90) & jval_q) & ~core_done & ~mm_stop;
assign afu_on_enable = (((jcom_q==8'h90) | (jcom_q==8'h80) ) & jval_q) | core_done | mm_stop;

// Delay registers for local reset
assign rst_i  = (jcom_q==8'h80) & jval_q;
assign rst2_i = rst_o;
assign rst3_i = rst2_o;

// Core controls
assign wed_enable = jval_q & (jcom_q==8'h90);
assign wed_i      = ha_jea;
assign cs_i       = jval_q & (jcom_q==8'h90);

// CMD Side
assign cmd_start = cs_i;


// ** Instances
// Stage input signals for timing
zcsl_dff #(.WIDTH(1)) IJCOM(.clk(clk), .i(ha_jval), .o(jval_q));
zcsl_dff #(.WIDTH(8)) IJVAL(.clk(clk), .i(ha_jcom), .o(jcom_q));

// Status register if AFU is ON
zcsl_dffea #(.WIDTH(1)) IAFUON(.clk(clk), .reset(local_reset), .enable(afu_on_enable), .i(afu_on_i), .o(afu_on_o));

// Delay registers for local reset
zcsl_dff #(.WIDTH(1)) IRST (.clk(clk), .i(rst_i),  .o(rst_o));
zcsl_dff #(.WIDTH(1)) IRST2(.clk(clk), .i(rst2_i), .o(rst2_o));
zcsl_dff #(.WIDTH(1)) IRST3(.clk(clk), .i(rst3_i), .o(rst3_o));

// Core controls
zcsl_dff #(.WIDTH(1)) ICORESTART(.clk(clk), .i(cs_i), .o(cs_o));
zcsl_dff #(.WIDTH(1)) ICOREDONE(.clk(clk), .i(core_done), .o(core_done_q));
zcsl_dffea #(.WIDTH(64)) IWED(.clk(clk), .reset(local_reset), .enable(wed_enable), .i(wed_i), .o(wed_o));


zcsl_dff #(.WIDTH(1)) IMMSTOP(.clk(clk), .i(mm_stop), .o(mm_stop_q));


endmodule
