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
// Module Author: Andrew Martin

`timescale 1 ps / 1 ps

module zcsl_arbrr
#(
	parameter WAYS = 1
)
(
	input clk,
	input reset,
	
	output [0:WAYS-1] i_r,
	input [0:WAYS-1] i_v,
	input [0:WAYS-1] i_h,

	input o_r,
	output o_v,
	output [0:WAYS-1] o_s,
	output o_h
);

// ** Wire definitions

generate

if(WAYS==1) begin
	assign o_v = i_v;
	assign i_r = o_r;
	
	assign o_s = 1'b0;
	assign o_h = 1'b0;
end else begin

	wire act;
	wire [0:WAYS-2] st_in;
	wire [0:WAYS-1] st;
	wire [0:WAYS*2-2] arb_in, arb_out;
	wire [0:WAYS*2-1] arb_kill;
	wire [0:WAYS-1] i_kill;
	wire [0:WAYS-1] i_nxt_st;


	// ** Routing and Logic
	assign act = o_r & o_v;  // update state if we have an accepted valid input request 

	// state: tencoded:  1111, 0111, 0011, 0001, 0000
	// on less bit than ways needed since lsb always on.
	assign st[WAYS-1] = 1'b1;
	   
	/* use tcoded state to qualify the input valids, and then repeat the input valids unqualified. No need to repreat the last input*/
	assign arb_in[0:WAYS-1] = i_v & st;
	assign arb_in[WAYS:(WAYS*2)-2] = i_v[0:WAYS-2];   
	   
	assign arb_kill[0] = 1'b0;
	assign arb_kill[1:WAYS*2-1-1] = arb_in[0:WAYS*2-1-2] | arb_kill[0:WAYS*2-1-2];
	assign arb_kill[WAYS*2-1] = 1'b1;

	assign arb_out =  arb_in & ~arb_kill[0:WAYS*2-2];//TODO: Check! Or 1:WAYS*2-1

	assign o_s    = arb_out [0:WAYS-1] | {arb_out [WAYS:WAYS*2-2],1'b0};
	   
	assign i_nxt_st[0:WAYS-1] = arb_kill[WAYS-1] ? arb_kill[0:WAYS-1] : {arb_kill[WAYS:WAYS*2-1]};

	assign i_kill = (st & arb_kill[0:WAYS-1]) | (~st & arb_kill[WAYS:(WAYS*2)-1]);
	   
	// kill: 01111, 00111, 00011, 00001, 00000
	// by happy coincidence, this is just what we want for next state
	assign st_in = (i_h[0:WAYS-2] & i_v[0:WAYS-2]) | i_nxt_st[0:WAYS-2];

	// accept input if output is accepted and its not killed
	assign i_r = {WAYS{o_r}} & ~i_kill;

	// we allways accept something   
	assign o_v = | i_v;
	   
	assign o_h = arb_kill[WAYS-1];


	// ** Instances
	zcsl_dffea#(.WIDTH(WAYS-1)) IRR_ST(.clk(clk), .reset(reset), .enable(act), .i(st_in), .o(st[0:WAYS-2]));

end

endgenerate

endmodule

