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


module zcsl_irq
#(
	parameter IRQ_ID = 1
)
(
	input clk,
	input reset,
	input irq_v,
	output irq_r,
	output irq_done,
	
	// Command
	output irq_req,
	input irq_ack,
	output [0:10] irq_num, // Valid values 1-2043
	input [0:7] cmd_tag,
		
	
	// Response Interface to PSL
	input ha_rvalid,            //A response is present
	input [0:7] ha_rtag,        //Accelerator generated request ID
	input [0:7] ha_response,    //response code
	input [0:8] ha_rcredits,    //twos compliment number of credits
	input ha_rtagpar
	
);




wire ha_rvalid_q;
wire [0:7] ha_rtag_q;
wire [0:7] ha_response_q;
wire [0:8] ha_rcredits_q;
wire ha_rtagpar_q;

wire irq_capt_i, irq_capt_o, irq_capt_enable;
wire irq_sent_i, irq_sent_o, irq_sent_enable;
wire [0:7] irq_tag_i, irq_tag_o;
wire irq_tag_enable;
wire irq_served_i, irq_served_o;
wire resp_valid_c;


// Assign outputs
assign irq_r		= ~irq_capt_o;
assign irq_req		= irq_capt_o & ~irq_sent_o;
assign irq_num		= IRQ_ID;
assign irq_done	= irq_served_o & irq_sent_o;


// Wiring
assign irq_capt_enable = ~irq_capt_o | irq_served_o;
assign irq_capt_i = irq_v;

assign irq_sent_enable = ~irq_sent_o | irq_served_o;
assign irq_sent_i = irq_ack;

assign irq_tag_enable = irq_ack;
assign irq_tag_i = cmd_tag;

assign resp_valid_c = (ha_response_q==8'd0) ? ha_rvalid_q : 1'b0;
assign irq_served_i = (ha_rtag_q==irq_tag_o) ? resp_valid_c : 1'b0;


// ** Instances **
// Staging PSL inputs
zcsl_dff #(.WIDTH(1))  IRVALID (.clk(clk), .i(ha_rvalid),      .o(ha_rvalid_q));
zcsl_dff #(.WIDTH(8))  IRTAG   (.clk(clk), .i(ha_rtag),        .o(ha_rtag_q));
zcsl_dff #(.WIDTH(8))  IRESP   (.clk(clk), .i(ha_response),    .o(ha_response_q));
zcsl_dff #(.WIDTH(9))  IRCREDIT(.clk(clk), .i(ha_rcredits),    .o(ha_rcredits_q));
zcsl_dff #(.WIDTH(1))  IRTAGPAR(.clk(clk), .i(ha_rtagpar),     .o(ha_rtagpar_q));

zcsl_dffea #(.WIDTH(1)) IIRQ_CAPT(.clk(clk), .reset(reset), .enable(irq_capt_enable), .i(irq_capt_i), .o(irq_capt_o));
zcsl_dffea #(.WIDTH(1)) IIRQ_SENT(.clk(clk), .reset(reset), .enable(irq_sent_enable), .i(irq_sent_i), .o(irq_sent_o));
zcsl_dffea #(.WIDTH(8)) IIRQ_TAG(.clk(clk), .reset(reset), .enable(irq_tag_enable), .i(irq_tag_i), .o(irq_tag_o));
zcsl_dffa #(.WIDTH(1)) IIRQ_SERVED(.clk(clk), .reset(reset), .i(irq_served_i), .o(irq_served_o));



endmodule
