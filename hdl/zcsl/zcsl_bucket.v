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

module zcsl_bucket
#(
	parameter WIDTH = 1
)
(
	input clk,
	input reset,
	
	input i_return,
	output i_accept,
	input [0:WIDTH-1] i_token,
	
	output o_valid,
	input o_accept,
	output [0:WIDTH-1] o_token
);


// ** Wire definitions **
wire fp_done_enable;
wire fp_done_i, fp_done_o;
wire rd_addr_enable;
wire [0:WIDTH-1] rd_addr_i, rd_addr_o;
wire wr_addr_enable;
wire [0:WIDTH-1] wr_addr_i, wr_addr_o;
wire tok_count_enable;
wire [0:WIDTH+1-1] tok_count_i, tok_count_o; // # of token given out
wire wr_delay_i, wr_delay_o;

wire ram_wr_ena;
wire [0:WIDTH-1] ram_wr_addr;
wire [0:WIDTH-1] ram_wr_data;
wire [0:WIDTH-1] ram_rd_addr;
wire [0:WIDTH-1] ram_rd_data;


// ** Routing & logic **

assign fp_done_enable = fp_done_i & ~fp_done_o;
assign fp_done_i = (rd_addr_o=={WIDTH {1'b1}}) & o_valid & o_accept;

assign rd_addr_enable = o_valid & o_accept;
assign rd_addr_i = rd_addr_enable ? rd_addr_o + { {WIDTH-1 {1'b0}}, 1'b1 } : rd_addr_o;

assign wr_addr_enable = i_return & i_accept;
assign wr_addr_i = wr_addr_o + { {WIDTH-1 {1'b0}}, 1'b1 };

assign tok_count_enable = wr_delay_o ^ rd_addr_enable;
assign tok_count_i = tok_count_o + (wr_delay_o ? -{ {WIDTH {1'b0}}, 1'b1 } : { {WIDTH {1'b0}}, 1'b1 });

assign wr_delay_i = wr_addr_enable;


//assign i_accept = (tok_count_o<{WIDTH {1'b1}});
//assign o_valid = (tok_count_o>{WIDTH {1'b0}});
assign i_accept = (tok_count_o!={WIDTH+1 {1'b0}});
assign o_valid = ~tok_count_o[0];


assign o_token = fp_done_o ? ram_rd_data : ram_rd_addr;



assign ram_wr_ena = wr_addr_enable;
assign ram_wr_addr = wr_addr_o;
assign ram_wr_data = i_token;
assign ram_rd_addr = rd_addr_i;// Too much delay?


// ** Instances **


zcsl_dffea #(.WIDTH(1))     IFP_DONE(.clk(clk), .reset(reset), .enable(fp_done_enable), .i(fp_done_i), .o(fp_done_o));
zcsl_dffea #(.WIDTH(WIDTH)) IRD_ADDR(.clk(clk), .reset(reset), .enable(rd_addr_enable), .i(rd_addr_i), .o(rd_addr_o));
zcsl_dffea #(.WIDTH(WIDTH)) IWR_ADDR(.clk(clk), .reset(reset), .enable(wr_addr_enable), .i(wr_addr_i), .o(wr_addr_o));
zcsl_dffea #(.WIDTH(WIDTH+1)) ITOK_COUNT(.clk(clk), .reset(reset), .enable(tok_count_enable), .i(tok_count_i), .o(tok_count_o));
zcsl_dff #(.WIDTH(1))     IWR_DEL(.clk(clk), .i(wr_delay_i), .o(wr_delay_o));


zcsl_ram_1r1w
#(
	.DW(WIDTH),
	.AW(WIDTH)
)
IRAM
(
	.clk(clk),
	.wr_ena(ram_wr_ena),
	.wr_addr(ram_wr_addr),
	.wr_data(ram_wr_data),
	.rd_addr(ram_rd_addr),
	.rd_data(ram_rd_data)
);

endmodule

