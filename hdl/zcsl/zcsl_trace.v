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

module zcsl_trace
#(
	parameter LOG_DEPTH = 9
)
(
	input clk,
	input reset,
	
	// Command interface
	input ah_cvalid,
	input [0:7] ah_ctag,
	input [0:12] ah_com,
	input [0:63] ah_cea,
	
	// Response interface
	input ha_rvalid,
	input [0:7] ha_rtag,
	input [0:7] ha_response,
	
	// Accelerator Buffer Interfaces (Write part only)
	input ha_bwvalid,			// A write data transfer is present
	input [0:7] ha_bwtag,		// Accelerator ID of the write
	input [0:5] ha_bwad,		// half line index of write data
	input [0:511] ha_bwdata,	// Write data
	
	// MMIO
	input mm_c1_ack,
	input mm_c2_ack,
	input mm_r_ack,
	input mm_bw_ack,
	output [0:63] mm_c1_data,
	output [0:63] mm_c2_data,
	output [0:63] mm_r_data,
	output [0:512+64-1] mm_bw_data
);



// ** Wire definitions **

wire fifoc1_wr_ena, fifoc1_rd_ack, fifoc1_empty, fifoc1_full;
wire [0:(8+13)-1] fifoc1_wr_data, fifoc1_rd_data;

wire fifoc2_wr_ena, fifoc2_rd_ack, fifoc2_empty, fifoc2_full;
wire [0:64-1] fifoc2_wr_data, fifoc2_rd_data;

wire fifor_wr_ena, fifor_rd_ack, fifor_empty, fifor_full;
wire [0:(8+8)-1] fifor_wr_data, fifor_rd_data;

wire fifobw_wr_valid, fifobw_wr_ready, fifobw_rd_valid, fifobw_rd_ready;
wire [0:(8+512+1)-1] fifobw_wr_data, fifobw_rd_data;


// ** Routing & logic **

assign fifoc1_wr_ena = ah_cvalid;
assign fifoc1_wr_data = {ah_com, ah_ctag};
assign fifoc1_rd_ack = ~fifoc1_full | mm_c1_ack;
assign mm_c1_data = { {64-8-13 {1'b0}} , fifoc1_rd_data};


assign fifoc2_wr_ena = ah_cvalid;
assign fifoc2_wr_data = ah_cea;
assign fifoc2_rd_ack = ~fifoc2_full | mm_c2_ack;
assign mm_c2_data = fifoc2_rd_data;



assign fifor_wr_ena = ha_rvalid;
assign fifor_wr_data = {ha_rtag, ha_response};
assign fifor_rd_ack = ~fifor_full | mm_r_ack;
assign mm_r_data = { {64-8-8 {1'b0}} , fifor_rd_data};



assign fifobw_wr_valid = ha_bwvalid;
assign fifobw_wr_data = {ha_bwtag, ha_bwad[5], ha_bwdata};
assign fifobw_rd_ready = ~fifobw_wr_ready | mm_bw_ack;
assign mm_bw_data = {fifobw_rd_data[0:8], {64-8-1 {1'b0}}, fifobw_rd_data[9:512+8+1-1] };

// ** Instances **


// FIFO for Command interface
zcsl_fifo
	#(.LOG_DEPTH(LOG_DEPTH), .WIDTH(8+13))
IFIFO_CMD1
(
	.clk(clk), .reset(reset),	
	.wr_valid(fifoc1_wr_ena), .wr_data(fifoc1_wr_data),
	.rd_ready(fifoc1_rd_ack), .rd_data(fifoc1_rd_data),
	.wr_ready(fifoc1_full), .rd_valid(fifoc1_empty)	
);

zcsl_fifo
	#(.LOG_DEPTH(LOG_DEPTH), .WIDTH(64))
IFIFO_CMD2
(
	.clk(clk), .reset(reset),	
	.wr_valid(fifoc2_wr_ena), .wr_data(fifoc2_wr_data),
	.rd_ready(fifoc2_rd_ack), .rd_data(fifoc2_rd_data),
	.wr_ready(fifoc2_full), .rd_valid(fifoc2_empty)	
);


// FIFO for Response interface
zcsl_fifo
	#(.LOG_DEPTH(LOG_DEPTH), .WIDTH(8+8))
IFIFO_RSP
(
	.clk(clk), .reset(reset),	
	.wr_valid(fifor_wr_ena), .wr_data(fifor_wr_data),
	.rd_ready(fifor_rd_ack), .rd_data(fifor_rd_data),
	.wr_ready(fifor_full), .rd_valid(fifor_empty)
);


// FIFO for Buffer Write interface
zcsl_fifo
	#(.LOG_DEPTH(LOG_DEPTH), .WIDTH(8+512+1))
IFIFO_BW
(
	.clk(clk), .reset(reset),	
	.wr_valid(fifobw_wr_valid), .wr_data(fifobw_wr_data),
	.rd_ready(fifobw_rd_ready), .rd_data(fifobw_rd_data),
	.wr_ready(fifobw_wr_ready), .rd_valid(fifobw_rd_valid)
);

endmodule

