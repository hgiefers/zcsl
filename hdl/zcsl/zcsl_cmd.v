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

module zcsl_cmd
#(
	parameter GETS = 2,
	parameter PUTS = 2,
	parameter IRQS = 2
)
(
	input clk,
	
	// From ZCSL control block
	input reset,
	input start,
	
	// Accelerator Command Interface
	output ah_cvalid,           // A valid command is present
	output [0:7] ah_ctag,       // request id
	output [0:12] ah_com,       // command PSL will execute
	// output [0:2] ah_cpad,       // prefetch attributes
	output [0:2] ah_cabt,       // abort if translation intr is generated
	output [0:63] ah_cea,       // Effective byte address for command
	output [0:15] ah_cch,       // Context Handle
	output [0:11] ah_csize,     // Number of bytes
	input [0:7] ha_croom,       // Commands PSL is prepared to accept
	output ah_ctagpar,
	output ah_compar,
	output ah_ceapar,

	// Response Interface to PSL
	input ha_rvalid,            //A response is present
	input [0:7] ha_rtag,        //Accelerator generated request ID
	input [0:7] ha_response,    //response code
	input [0:8] ha_rcredits,    //twos compliment number of credits
	input [0:1] ha_rcachestate, //Resultant Cache State
	input [0:12] ha_rcachepos,  //Cache location id
	input ha_rtagpar,
	
	output rvalid,
	
	// GETs
	input  [0:GETS-1] gets_req,
	input  [0:GETS-1] gets_cache,
	input  [0:GETS*64-1] gets_ea,
	output [0:GETS-1] gets_ack,
	
	// PUTs
	input  [0:PUTS-1] puts_req,
	input  [0:PUTS-1] puts_cache,
	input  [0:PUTS*64-1] puts_ea,
	output [0:PUTS-1] puts_ack,
	
	// IRQs
	input  [0:IRQS-1] irqs_req,
	input  [0:IRQS*11-1] irqs_num,// Valid values 1-2043
	output [0:IRQS-1] irqs_ack,
	
	//
	output [0:7] eng_tag,
	
	input touch_ack,
	output [0:63] touch_ea,
	
	output [0:3] debug_state

);

// ** Wire definitions **
genvar m;
localparam WAYS = GETS+PUTS+IRQS;
localparam RAMW = 13+64+12; // Command + Effective Address + Size

// Statemachine
reg [0:3] state = 4'h0;
localparam IDLE=0, RUNNING=1, PAGED=2, RESTART=3, RESTART_WAIT=4, TOUCH=5, TOUCH_WAIT=6, REPLAY=7, REPLAY_WAIT=8, ERROR=9;
reg fsm_ctrl = 1'b1;
reg fsm_cvalid = 1'b0;
wire fsm_cvalid_q;
reg [0:12] fsm_com = 13'd0;
reg [0:63] fsm_ea = 64'd0;
wire [0:7] fsm_tag, fsm_tag_q;
reg fsm_fcnt_rst = 1'b0;
reg fsm_rply = 1'b0;
reg fsm_touchwait = 1'b0;

// Staging PSL inputs
wire [0:7] ha_croom_q;
wire ha_rvalid_q;
wire [0:7] ha_rtag_q;
wire [0:7] ha_response_q;
wire [0:8] ha_rcredits_q;
wire [0:1] ha_rcachestate_q;
wire [0:12] ha_rcachepos_q;
wire ha_rtagpar_q;

// Staging PSL outputs
wire ah_cvalid_i, ah_cvalid_o;
wire [0:63] ah_cea_i, ah_cea_o;
wire [0:12] ah_com_i, ah_com_o;
wire [0:7] ah_ctag_i, ah_ctag_o;

// Credit control
wire croom_enable;
wire [0:7] croom_i, croom_o;
wire credit_enable;
wire [0:7] credit_i, credit_o;
wire credit_stop;

// Selectors
wire [0:WAYS-1] mux_ea_sel;
wire [0:WAYS*64-1] mux_ea_i;
wire [0:63] mux_ea_o;
wire [0:4] mux_com_sel;
wire [0:5*13-1] mux_com_i;
wire [0:12] mux_com_o;

// Arbiter
wire [0:WAYS-1] arb_i_r;
wire [0:WAYS-1] arb_i_v;
wire [0:WAYS-1] arb_i_h = {WAYS {1'b0}};
wire arb_o_r;
wire arb_o_v;
wire [0:WAYS-1] arb_o_s;
wire arb_o_h;

wire [0:WAYS-1] arb_ack_i, arb_ack_o;
wire arb_o_v_q;

// Bucket
wire bkt_i_return;
wire bkt_i_accept;
wire [0:6] bkt_i_token;
wire bkt_o_valid;
wire bkt_o_accept;
wire [0:6] bkt_o_token;

// RAM
wire ram_wr_ena;
wire [0:7] ram_wr_addr;
wire [0:RAMW-1] ram_wr_data;
wire [0:7] ram_rd_addr;
wire [0:RAMW-1] ram_rd_data;

// FIFO
wire fifo_wr_valid;
wire fifo_wr_ready;
wire [0:7] fifo_wr_data;
wire fifo_rd_valid;
wire fifo_rd_ready;
wire [0:7] fifo_rd_data;

wire fcnt_enable;
wire [0:6] fcnt_i, fcnt_o;
wire rcnt_enable;
wire [0:6] rcnt_i, rcnt_o;

wire paged_enable;
wire paged_i, paged_o;
wire touched_enable;
wire touched_i, touched_o;
wire irqd_enable;
wire irqd_i, irqd_o;

wire req_get;
wire req_getc;
wire req_put;
wire req_putc;
wire req_irq;

wire [0:7] eng_tag_i;

// ** Routing & logic **
assign debug_state = state;


assign rvalid = ha_rvalid & (state!=RESTART_WAIT);

// Credit control
assign croom_enable = start;
assign croom_i = ha_croom_q;

assign credit_enable = ah_cvalid | ha_rvalid_q | reset;
assign credit_i = reset ? 8'd0 : (ah_cvalid ? credit_o+{7'b000000, ~ha_rvalid_q} : credit_o-8'd1);
assign credit_stop = credit_o >= croom_o-8'd1; // > 8'd63;


// Select current engine
assign mux_ea_sel = arb_i_r & arb_i_v;

assign mux_com_sel = {(req_get & ~req_getc), (req_get & req_getc), (req_put & ~req_putc), (req_put & req_putc), req_irq};
assign mux_com_i = {13'h0A00, 13'h0A50, 13'h0D00, 13'h0D60, 13'h0000};


// Ouput staging latches
assign ah_cvalid_i =  (fsm_ctrl | fsm_cvalid_q) ? (fsm_cvalid_q & ~credit_stop) : (arb_o_v & arb_o_r & ~credit_stop);// TODO: Check this arb_o_v signal
assign ah_cea_i = (fsm_ctrl | fsm_cvalid_q) ? fsm_ea : mux_ea_o;
assign ah_com_i = (fsm_ctrl | fsm_cvalid_q) ? fsm_com : mux_com_o;
assign ah_ctag_i = (fsm_ctrl | fsm_cvalid_q) ? fsm_tag_q : {1'b0, bkt_o_token};

assign ah_cvalid = ah_cvalid_o;
assign ah_cea = ah_cea_o;
assign ah_com = ah_com_o;
assign ah_ctag = ah_ctag_o;


// Arbiter control
assign arb_o_r = bkt_o_valid & ~credit_stop & ~fsm_ctrl & ~fsm_cvalid_q;
assign eng_tag_i = {1'b0, bkt_o_token};


// Bucket
assign bkt_i_return = ha_rvalid_q & ~ha_rtag_q[0] & (ha_response_q==8'd0) & (state!=RESTART_WAIT);
assign bkt_i_token = ha_rtag_q[1:7];
assign bkt_o_accept = arb_o_v & ~credit_stop; // TODO: Check this arb_o_v signal




// Trace outgoing commands to RAM
assign ram_wr_ena = ah_cvalid & (state!=RESTART_WAIT); // Do not capture restart command
assign ram_wr_addr = ah_ctag;
assign ram_wr_data = {ah_com, ah_cea, ah_csize};
assign ram_rd_addr = fifo_rd_data;


// FIFO
assign fifo_wr_valid = ha_rvalid_q & (ha_response_q!=8'd0) & (state!=RESTART_WAIT);
assign fifo_wr_data = ha_rtag_q;
assign fifo_rd_ready = fsm_rply & ~credit_stop;
assign fsm_tag = fifo_rd_data;

assign fcnt_enable = (ha_rvalid_q & (ha_response_q!=8'd0)) | fsm_fcnt_rst;
assign fcnt_i = fsm_fcnt_rst ? 7'd0 : fcnt_o + 7'd1;

assign rcnt_enable = fsm_fcnt_rst | (fsm_rply & ~credit_stop);
assign rcnt_i = fsm_fcnt_rst ? fcnt_o : rcnt_o - 7'd1;


assign paged_enable = fsm_fcnt_rst | (ha_rvalid_q & (ha_response_q==8'd10));
assign paged_i = fsm_fcnt_rst ? 1'b0 : 1'b1;

assign touched_enable = (fsm_touchwait & touch_ack) | ~fsm_touchwait;
assign touched_i = fsm_touchwait ? touch_ack : 1'b0;

assign irqd_enable = (fsm_touchwait & (ha_rvalid_q & (ha_response_q==8'd0))) | ~fsm_touchwait;
assign irqd_i = fsm_touchwait ? 1'b1 : 1'b0;


assign touch_ea = ram_rd_data[13:13+64-1];


// Tie downs
assign ah_csize		= 12'h080; // Always operate on full cachelines (128 Bytes - 1024 bits)
assign ah_ctagpar	= 1'b0; // No parity provided -> tie low
assign ah_compar	= 1'b0; // No parity provided -> tie low
assign ah_ceapar	= 1'b0; // No parity provided -> tie low
assign ah_cch		= 16'b0000; // Context handle only used in AFU directed mode
assign ah_cabt		= 3'b000; // translation ordering behavior. Strict. Maybe try different.
//assign ah_cpad		= 3'b000; // ??? Not documented in spec 0.9908


assign arb_ack_i = arb_i_v & arb_i_r;


generate
	if(GETS>0) begin
		assign arb_i_v[0:GETS-1] = gets_req[0:GETS-1] & ~gets_ack;
		assign gets_ack = arb_ack_o[0:GETS-1]; //arb_i_v[0:GETS-1] & arb_i_r[0:GETS-1];
		assign mux_ea_i[0:GETS*64-1] = gets_ea;
		assign req_get = |(gets_req & arb_i_r[0:GETS-1]);
		assign req_getc = |(gets_cache & arb_i_r[0:GETS-1]);
	end else begin
		assign req_get = 1'b0;
		assign req_getc = 1'b0;
	end
	if(PUTS>0) begin
		assign arb_i_v[GETS:GETS+PUTS-1] = puts_req[0:PUTS-1] & ~puts_ack;
		assign puts_ack = arb_ack_o[GETS:GETS+PUTS-1]; //arb_i_v[GETS:GETS+PUTS-1] & arb_i_r[GETS:GETS+PUTS-1];
		assign mux_ea_i[GETS*64:(GETS+PUTS)*64-1] = puts_ea;
		assign req_put = |(puts_req & arb_i_r[GETS:GETS+PUTS-1]);
		assign req_putc = |(puts_cache & arb_i_r[GETS:GETS+PUTS-1]);
	end else begin
		assign req_put = 1'b0;
		assign req_putc = 1'b0;
	end
	if(IRQS>0) begin
		assign arb_i_v[GETS+PUTS:GETS+PUTS+IRQS-1] = irqs_req[0:IRQS-1] & ~irqs_ack;
		assign irqs_ack = arb_ack_o[GETS+PUTS:GETS+PUTS+IRQS-1]; //arb_i_v[GETS+PUTS:GETS+PUTS+IRQS-1] & arb_i_r[GETS+PUTS:GETS+PUTS+IRQS-1];
		for (m = 0; m < IRQS; m = m + 1) begin : u
			assign mux_ea_i[(GETS+PUTS+m)*64:(GETS+PUTS+m+1)*64-1] = {53'd0, irqs_num[m*11:(m+1)*11-1]};
		end
		assign req_irq = |(irqs_req & arb_i_r[GETS+PUTS:GETS+PUTS+IRQS-1]);
	end else begin
		assign req_irq = 1'b0;
	end
endgenerate


// ** Instances **
// Staging PSL inputs
zcsl_dff #(.WIDTH(8))  ICROOM  (.clk(clk), .i(ha_croom),       .o(ha_croom_q));
zcsl_dff #(.WIDTH(1))  IRVALID (.clk(clk), .i(ha_rvalid),      .o(ha_rvalid_q));
zcsl_dff #(.WIDTH(8))  IRTAG   (.clk(clk), .i(ha_rtag),        .o(ha_rtag_q));
zcsl_dff #(.WIDTH(8))  IRESP   (.clk(clk), .i(ha_response),    .o(ha_response_q));
zcsl_dff #(.WIDTH(9))  IRCREDIT(.clk(clk), .i(ha_rcredits),    .o(ha_rcredits_q));
zcsl_dff #(.WIDTH(2))  IRCSTATE(.clk(clk), .i(ha_rcachestate), .o(ha_rcachestate_q));
zcsl_dff #(.WIDTH(13)) IRCPOS  (.clk(clk), .i(ha_rcachepos),   .o(ha_rcachepos_q));
zcsl_dff #(.WIDTH(1))  IRTAGPAR(.clk(clk), .i(ha_rtagpar),     .o(ha_rtagpar_q));

// Staging PSL output
zcsl_dff #(.WIDTH(1))  ICVALID(.clk(clk), .i(ah_cvalid_i),     .o(ah_cvalid_o));
zcsl_dff #(.WIDTH(64)) ICEA   (.clk(clk), .i(ah_cea_i),        .o(ah_cea_o));
zcsl_dff #(.WIDTH(13)) ICOM   (.clk(clk), .i(ah_com_i),        .o(ah_com_o));
zcsl_dff #(.WIDTH(8))  ICTAG  (.clk(clk), .i(ah_ctag_i),       .o(ah_ctag_o));


zcsl_dff #(.WIDTH(8))  IFSMTAG  (.clk(clk), .i(fsm_tag),       .o(fsm_tag_q));
zcsl_dff #(.WIDTH(1))  IFSMVALID(.clk(clk), .i(fsm_cvalid),     .o(fsm_cvalid_q));

// Credit control
zcsl_dffea #(.WIDTH(8)) IROOM(.clk(clk), .reset(reset), .enable(croom_enable), .i(croom_i), .o(croom_o));
zcsl_dffea #(.WIDTH(8)) ICREDIT(.clk(clk), .reset(reset), .enable(credit_enable), .i(credit_i), .o(credit_o));

// Selectors
zcsl_selector #(.WAYS(WAYS), .WIDTH(64)) IMUXEA(.sel(mux_ea_sel), .i(mux_ea_i), .o(mux_ea_o));
zcsl_selector #(.WAYS(5), .WIDTH(13)) IMUXCOM(.sel(mux_com_sel), .i(mux_com_i), .o(mux_com_o));

// Arbiter
zcsl_arbrr #(.WAYS(WAYS)) IARB(.clk(clk), .reset(reset), .i_r(arb_i_r), .i_v(arb_i_v), .i_h(arb_i_h), .o_r(arb_o_r), .o_v(arb_o_v), .o_s(arb_o_s), .o_h(arb_o_h));
zcsl_dff #(.WIDTH(WAYS))  IARBACK(.clk(clk), .i(arb_ack_i),     .o(arb_ack_o));
zcsl_dff #(.WIDTH(8))  IENGTAG(.clk(clk), .i(eng_tag_i),     .o(eng_tag));


// Bucket
zcsl_bucket
#(
	.WIDTH(7)
)
IBKT
(
	.clk(clk),
	.reset(reset),
	.i_return(bkt_i_return),
	.i_accept(bkt_i_accept),
	.i_token(bkt_i_token),
	.o_valid(bkt_o_valid),
	.o_accept(bkt_o_accept),
	.o_token(bkt_o_token)
);


// RAM
zcsl_ram_1r1w
#(
	.DW(RAMW),
	.AW(8)
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


// FIFO
zcsl_fifo
#(
	.WIDTH(8),
	.LOG_DEPTH(6) // There can only be a max of 64 commands in flight
)
IFIFO
(
	.clk(clk),
	.reset(reset),
	.wr_valid(fifo_wr_valid),
	.wr_ready(fifo_wr_ready),
	.wr_data(fifo_wr_data),
	.rd_valid(fifo_rd_valid),
	.rd_ready(fifo_rd_ready),
	.rd_data(fifo_rd_data)
);
zcsl_dffea #(.WIDTH(7))  IFCNT  (.clk(clk), .reset(reset), .enable(fcnt_enable), .i(fcnt_i), .o(fcnt_o));
zcsl_dffea #(.WIDTH(7))  IRCNT  (.clk(clk), .reset(reset), .enable(rcnt_enable), .i(rcnt_i), .o(rcnt_o));

// Capture "paged" event
zcsl_dffea #(.WIDTH(1))  IPAGED  (.clk(clk), .reset(reset), .enable(paged_enable), .i(paged_i), .o(paged_o));

// Capture "touched" event
zcsl_dffea #(.WIDTH(1))  ITOUCHED  (.clk(clk), .reset(reset), .enable(touched_enable), .i(touched_i), .o(touched_o));
zcsl_dffea #(.WIDTH(1))  IIRQD  (.clk(clk), .reset(reset), .enable(irqd_enable), .i(irqd_i), .o(irqd_o));



// ** Output definitions depending on state
always@(state or ram_rd_data) begin
	case(state)
		RUNNING: begin
			fsm_ctrl		= 1'b0;
			fsm_cvalid		= 1'b0;
			fsm_com			= ram_rd_data[0:12];
			fsm_ea			= ram_rd_data[13:13+64-1];
			fsm_fcnt_rst		= 1'b0;
			fsm_rply		= 1'b0;
			fsm_touchwait		= 1'b0;
		end
		RESTART: begin
			fsm_ctrl		= 1'b1;
			fsm_cvalid		= 1'b1;
			fsm_com			= 13'h0001;
			fsm_ea			= 64'd1;
			fsm_fcnt_rst		= 1'b1;
			fsm_rply		= 1'b0;
			fsm_touchwait		= 1'b0;
		end
		RESTART_WAIT: begin
			fsm_ctrl		= 1'b1;
			fsm_cvalid		= 1'b0;
			fsm_com			= 13'h0001;
			fsm_ea			= 64'd1;
			fsm_fcnt_rst		= 1'b0;
			fsm_rply		= 1'b0;
			fsm_touchwait		= 1'b0;
		end
		TOUCH: begin
			fsm_ctrl		= 1'b1;
			fsm_cvalid		= 1'b1;
			fsm_com			= 13'h0000;
			fsm_ea			= 64'd1;
			fsm_fcnt_rst		= 1'b0;
			fsm_rply		= 1'b0;
			fsm_touchwait		= 1'b0;
		end
		TOUCH_WAIT: begin
			fsm_ctrl		= 1'b1;
			fsm_cvalid		= 1'b0;
			fsm_com			= ram_rd_data[0:12];
			fsm_ea			= ram_rd_data[13:13+64-1];
			fsm_fcnt_rst		= 1'b0;
			fsm_rply		= 1'b0;
			fsm_touchwait		= 1'b1;
		end
		REPLAY: begin
			fsm_ctrl		= 1'b1;
			fsm_cvalid		= 1'b1;
			fsm_com			= ram_rd_data[0:12];
			fsm_ea			= ram_rd_data[13:13+64-1];
			fsm_fcnt_rst		= 1'b0;
			fsm_rply		= 1'b1;
			fsm_touchwait		= 1'b0;
		end
		default: begin // IDLE
			fsm_ctrl		= 1'b1;
			fsm_cvalid		= 1'b0;
			fsm_com			= ram_rd_data[0:12];
			fsm_ea			= ram_rd_data[13:13+64-1];
			fsm_fcnt_rst		= 1'b0;
			fsm_rply		= 1'b0;
			fsm_touchwait		= 1'b0;
		end
	endcase
end



// ** Transitions
always@(posedge(clk) or posedge(reset)) begin
	if (reset) begin
		state <= IDLE;
	end else begin
		case(state)
			IDLE:
				if(start)
					state <= RUNNING;
				else
					state <= IDLE;
			RUNNING:
				if(ha_rvalid_q & (ha_response_q==8'd10))
					state <= PAGED;
				else if(ha_rvalid_q & (ha_response_q!=8'd0))
					state <= ERROR;
				else
					state <= RUNNING;
			PAGED:
				if(credit_o==8'd0)
					state <= RESTART;
				else
					state <= PAGED;
			RESTART:
				state <= RESTART_WAIT;
			RESTART_WAIT:
				if(ha_rvalid_q & (ha_response_q==8'd0))
					state <= REPLAY;// WAS TOUCH
				else if(ha_rvalid_q & (ha_response_q!=8'd0))
					state <= ERROR;
				else
					state <= RESTART_WAIT;
			TOUCH:
				state <= TOUCH_WAIT;
			TOUCH_WAIT:
				if(touched_o & irqd_o)
					state <= REPLAY;
				else
					state <= TOUCH_WAIT;
			REPLAY:
				if((rcnt_o==6'd1) & (paged_o | (ha_rvalid_q & (ha_response_q==8'd10))) )
					state <= PAGED;
				else if((rcnt_o==6'd1) & ~paged_o)
					state <= RUNNING;
				else
					state <= REPLAY;
			
			default:
				state <= IDLE;
			
		endcase
	end
end

/*
always@(state) begin
	$display("@%d: CMD STATE %d", $time, state);	
end
*/

endmodule

