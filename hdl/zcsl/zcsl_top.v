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

module zcsl_top
(
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

    // Accelerator Buffer Interfaces
    input ha_brvalid,           // A read transfer is present
    input [0:7] ha_brtag,       // Accelerator generated ID for read
    input [0:5] ha_brad,        // half line index of read data
    output [0:3] ah_brlat,      // Read data ready latency
    output [0:511] ah_brdata,   // Read data
    output [0:7] ah_brpar,      // Read data parity
    input ha_bwvalid,           // A write data transfer is present
    input [0:7] ha_bwtag,       // Accelerator ID of the write
    input [0:5] ha_bwad,        // half line index of write data
    input [0:511] ha_bwdata,    // Write data
    input [0:7] ha_bwpar,       // Write data parity
    input ha_brtagpar,          // Read tag parity
    input ha_bwtagpar,          // Write tag parity

    // Response Interface to PSL
    input ha_rvalid,            //A response is present
    input [0:7] ha_rtag,        //Accelerator generated request ID
    input [0:7] ha_response,    //response code
    input [0:8] ha_rcredits,    //twos compliment number of credits
    input [0:1] ha_rcachestate, //Resultant Cache State
    input [0:12] ha_rcachepos,  //Cache location id
    input ha_rtagpar,

    // MMIO Interface
    input ha_mmval,             // A valid MMIO is present
    input ha_mmrnw,             // 1 = read, 0 = write
    input ha_mmdw,              // 1 = doubleword, 0 = word
    input [0:23] ha_mmad,       // mmio address
    input [0:63] ha_mmdata,     // Write data
    input ha_mmcfg,             // mmio is to afu descriptor space
    output ah_mmack,            // Write is complete or Read is valid pulse
    output [0:63] ah_mmdata,    // Read data
    input ha_mmadpar,
    input ha_mmdatapar,
    output ah_mmdatapar,

    // Accelerator Control Interface
    input ha_jval,              // A valid job control command is present
    input [0:7] ha_jcom,        // Job control command opcode
    input [0:63] ha_jea,        // Save/Restore address
    output ah_jrunning,         // Accelerator is running level
    output ah_jdone,            // Accelerator is finished pulse
    output ah_jcack,            // Accelerator is with context llcmd pulse
    output [0:63] ah_jerror,    // Accelerator error code. 0 = success
    output ah_tbreq,            // Timebase request pulse
    output ah_jyield,           // Accelerator wants to stop
    input ha_jeapar,
    input ha_jcompar,
    output ah_paren,            // 1 = AFU provides parity generation
    input ha_pclock
    

);

// ** Wire definitions **
localparam GETS = 2;
localparam PUTS = 1;
localparam IRQS = 1;

wire clk;

// MMIO
wire mm_ctrl_stop;
wire mm_touch_ack;
wire [0:63] mm_touch_ea;
wire mm_core_valid;
wire mm_core_rnw;
wire mm_core_dw;
wire mm_core_ack;
wire [0:23] mm_core_addr;
wire [0:63] mm_core_wr_data;
wire [0:63] mm_core_rd_data;
wire [0:3] mm_cmd_debug_state;
wire mm_trc_c1_ack;
wire mm_trc_c2_ack;
wire mm_trc_r_ack;
wire mm_trc_bw_ack;
wire [0:63] mm_trc_c1_data;
wire [0:63] mm_trc_c2_data;
wire [0:63] mm_trc_r_data;
wire [0:512+64-1] mm_trc_bw_data;


// CTRL
wire ctrl_cmd_start;		// Cmd start pulse
wire ctrl_core_start;		// Core start pulse
wire [0:63] ctrl_core_wed;	// Core WED address
wire ctrl_core_done;		// Core done pulse
wire ctrl_core_reset;		// Reset pulse (2 cycles to avoid timing problems)
wire ctrl_mm_stop;


// CMD
wire cmd_rvalid;
wire cmd_reset;
wire cmd_start;
wire [0:GETS-1] cmd_gets_req;
wire [0:GETS-1] cmd_gets_cache;
wire [0:GETS*64-1] cmd_gets_ea;
wire [0:GETS-1] cmd_gets_ack;
wire [0:PUTS-1] cmd_puts_req;
wire [0:PUTS-1] cmd_puts_cache;
wire [0:PUTS*64-1] cmd_puts_ea;
wire [0:PUTS-1] cmd_puts_ack;
wire [0:IRQS-1] cmd_irqs_req;
wire [0:IRQS*11-1] cmd_irqs_num;// Valid values 1-2043
wire [0:IRQS-1] cmd_irqs_ack;
wire [0:7] cmd_eng_tag;
wire cmd_touch_ack;
wire [0:63] cmd_touch_ea;
wire [0:3] cmd_debug_state;


// PUTS
wire [0:PUTS-1] puts_sel;
wire [0:PUTS*512-1] puts_data;

// GET(s) with equal word width
wire [0:GETS-1] gets_cmd_valid;
wire [0:GETS-1] gets_cmd_cache;
wire [0:GETS-1] gets_cmd_ack;
wire [0:GETS*64-1] gets_cmd_ea;
wire [0:7] gets_cmd_tag;
wire [0:GETS-1] gets_v;
wire [0:GETS-1] gets_r;
wire [0:GETS-1] gets_e;
wire [0:GETS*64-1] gets_addr;
wire [0:GETS*7-1] gets_size = {GETS {7'd0}};
wire [0:GETS-1] gets_data_v;
wire [0:GETS-1] gets_data_r;
wire [0:GETS-1] gets_data_e;
wire [0:GETS*512-1] gets_data_d;


// PUT Unit(s)
wire [0:PUTS*512-1] put_ah_brdata;
wire [0:PUTS*8-1] put_ah_brpar;

wire [0:PUTS-1] put_sel;
wire [0:PUTS-1] put_cmd_valid;
wire [0:PUTS-1] put_cmd_cache;
wire [0:PUTS-1] put_cmd_ack;
wire [0:PUTS*64-1] put_cmd_ea;
wire [0:PUTS*8-1] put_cmd_tag;

wire [0:PUTS-1] put_v;
wire [0:PUTS-1] put_r;
wire [0:PUTS-1] put_e;
wire [0:PUTS*64-1] put_addr;
wire [0:PUTS-1] put_data_v;
wire [0:PUTS-1] put_data_r;
wire [0:PUTS-1] put_data_e;
wire [0:PUTS*512-1] put_data_d;
wire [0:PUTS-1] put_done;


// TRACE Array
wire trc_c1_ack;
wire trc_c2_ack;
wire trc_r_ack;
wire trc_bw_ack;
wire [0:63] trc_c1_data;
wire [0:63] trc_c2_data;
wire [0:63] trc_r_data;
wire [0:512+64-1] trc_bw_data;

// CORE
wire core_mm_valid;
wire core_mm_rnw;
wire core_mm_dw;
wire core_mm_ack;
wire [0:23] core_mm_addr;
wire [0:63] core_mm_wr_data;
wire [0:63] core_mm_rd_data;

wire core_done;

wire [0:1] core_get_v;
wire [0:1] core_get_r;
wire [0:1] core_get_e;
wire [0:2*64-1] core_get_addr;
wire [0:1] core_get_data_v;
wire [0:1] core_get_data_r;
wire [0:1] core_get_data_e;
wire [0:2*512-1] core_get_data_d;

wire core_put_v;
wire core_put_r;
wire core_put_e;
wire core_put_done;
wire [0:63] core_put_addr;
wire core_put_data_v;
wire core_put_data_r;
wire core_put_data_e;
wire [0:511] core_put_data_d;



wire irq_irq_v;
wire irq_irq_r;
wire irq_irq_done;
wire irq_irq_req;
wire irq_irq_ack;
wire [0:10] irq_irq_num;
wire [0:7] irq_cmd_tag;

// ** Routing & logic **

assign clk = ha_pclock;



// MMIO
// TODO(pol): Tie downs for no core
assign mm_touch_ea = cmd_touch_ea;
assign mm_cmd_debug_state = cmd_debug_state;


// CTRL
assign ctrl_mm_stop = mm_ctrl_stop;

// TODO(pol): Tie downs for no core
assign ctrl_core_done = core_done;


// CMD
assign cmd_reset = ctrl_core_reset; // TODO: Separate resets for core and ZCSL?
assign cmd_start = ctrl_cmd_start;
assign cmd_touch_ack = mm_touch_ack;



assign gets_v = core_get_v;
assign gets_e = core_get_e;
assign core_get_r = gets_r;
assign gets_addr = core_get_addr;
assign gets_data_r = core_get_data_r;
assign core_get_data_v = gets_data_v;
assign core_get_data_e = gets_data_e;
assign core_get_data_d = gets_data_d;

// PUTS
assign puts_sel = put_sel;
assign puts_data = put_ah_brdata;

// PUT Unit(s)
assign cmd_puts_req = put_cmd_valid;
assign cmd_puts_cache = put_cmd_cache;
assign put_cmd_ack = cmd_puts_ack;
assign cmd_puts_ea = put_cmd_ea;
assign put_cmd_tag = cmd_eng_tag;

assign put_v = core_put_v;
assign core_put_r = put_r;
assign put_e = core_put_e;
assign put_addr = core_put_addr;
assign put_data_v = core_put_data_v;
assign core_put_data_r = put_data_r;
assign put_data_e = core_put_data_e;
assign put_data_d = core_put_data_d;
assign core_put_done = irq_irq_done;

// TRACE Array
assign trc_c1_ack = mm_trc_c1_ack;
assign trc_c2_ack = mm_trc_c2_ack;
assign trc_r_ack = mm_trc_r_ack;
assign trc_bw_ack = mm_trc_bw_ack;
assign mm_trc_c1_data = trc_c1_data;
assign mm_trc_c2_data = trc_c2_data;
assign mm_trc_r_data = trc_r_data;
assign mm_trc_bw_data = trc_bw_data;


// CORE
assign core_mm_valid = mm_core_valid;
assign core_mm_rnw = mm_core_rnw;
assign core_mm_dw = mm_core_dw;
assign mm_core_ack = core_mm_ack;
assign core_mm_addr = mm_core_addr;
assign core_mm_wr_data = mm_core_wr_data;
assign mm_core_rd_data = core_mm_rd_data;

assign cmd_gets_req = gets_cmd_valid;
assign cmd_gets_cache = gets_cmd_cache;
assign cmd_gets_ea = gets_cmd_ea;
assign gets_cmd_ack = cmd_gets_ack;
assign gets_cmd_tag = cmd_eng_tag;

//assign cmd_puts_req = {PUTS {1'b0}};
//assign cmd_puts_cache = {PUTS {1'b0}};
//assign cmd_puts_ea = {PUTS {64'd0}};
assign cmd_irqs_req =  irq_irq_req; //{IRQS {1'b0}};
assign cmd_irqs_num =  irq_irq_num; //{IRQS {11'd0}};




assign irq_irq_v = put_done;
// TODO consume irq_irq_r;
assign irq_irq_ack = cmd_irqs_ack;
assign irq_cmd_tag = cmd_eng_tag;




// ** Instances **



// Control Unit
zcsl_ctrl
ICTRL
(
    .clk(clk),
    .ha_jval(ha_jval),
    .ha_jcom(ha_jcom),
    .ha_jea(ha_jea),
    .ah_jrunning(ah_jrunning),
    .ah_jdone(ah_jdone),
    .ah_jcack(ah_jcack),
    .ah_jerror(ah_jerror),
    .ah_tbreq(ah_tbreq),
    .ah_jyield(ah_jyield),
    .ha_jeapar(ha_jeapar),
    .ha_jcompar(ha_jcompar),
    .ah_paren(ah_paren),
    .mm_stop(ctrl_mm_stop),
    .cmd_start(ctrl_cmd_start),
    .core_start(ctrl_core_start),
    .core_wed(ctrl_core_wed),
    .core_done(ctrl_core_done),
    .core_reset(ctrl_core_reset)
);


// MMIO Unit
zcsl_mmio
IMMIO
(
    .clk(clk),
    .ha_mmval(ha_mmval),
    .ha_mmrnw(ha_mmrnw),
    .ha_mmdw(ha_mmdw),
    .ha_mmad(ha_mmad),
    .ha_mmdata(ha_mmdata),
    .ha_mmcfg(ha_mmcfg),
    .ah_mmack(ah_mmack),
    .ah_mmdata(ah_mmdata),
    .ha_mmadpar(ha_mmadpar),
    .ha_mmdatapar(ha_mmdatapar),
    .ah_mmdatapar(ah_mmdatapar),
    .ctrl_stop(mm_ctrl_stop),
    .touch_ack(mm_touch_ack),
    .touch_ea(mm_touch_ea),
    .core_valid(mm_core_valid),
    .core_rnw(mm_core_rnw),
    .core_dw(mm_core_dw),
    .core_ack(mm_core_ack),
    .core_addr(mm_core_addr),
    .core_wr_data(mm_core_wr_data),
    .core_rd_data(mm_core_rd_data),
    .cmd_debug_state(mm_cmd_debug_state),
    .trc_c1_ack(mm_trc_c1_ack),
    .trc_c2_ack(mm_trc_c2_ack),
    .trc_r_ack(mm_trc_r_ack),
    .trc_bw_ack(mm_trc_bw_ack),
    .trc_c1_data(mm_trc_c1_data),
    .trc_c2_data(mm_trc_c2_data),
    .trc_r_data(mm_trc_r_data),
    .trc_bw_data(mm_trc_bw_data)
    
);


// CMD Unt
zcsl_cmd
#(
	.GETS(GETS),
	.PUTS(PUTS),
	.IRQS(IRQS)
)
ICMD
(
	.clk(clk),
	.reset(cmd_reset),
	.start(cmd_start),
	.ah_cvalid(ah_cvalid),
	.ah_ctag(ah_ctag),
	.ah_com(ah_com),
	// output [0:2] ah_cpad,       // prefetch attributes
	.ah_cabt(ah_cabt),
	.ah_cea(ah_cea),
	.ah_cch(ah_cch),
	.ah_csize(ah_csize),
	.ha_croom(ha_croom),
	.ah_ctagpar(ah_ctagpar),
	.ah_compar(ah_compar),
	.ah_ceapar(ah_ceapar),
	.ha_rvalid(ha_rvalid),
	.ha_rtag(ha_rtag),
	.ha_response(ha_response),
	.ha_rcredits(ha_rcredits),
	.ha_rcachestate(ha_rcachestate),
	.ha_rcachepos(ha_rcachepos),
	.ha_rtagpar(ha_rtagpar),
	.rvalid(cmd_rvalid),
	.gets_req(cmd_gets_req),
	.gets_cache(cmd_gets_cache),
	.gets_ea(cmd_gets_ea),
	.gets_ack(cmd_gets_ack),
	.puts_req(cmd_puts_req),
	.puts_cache(cmd_puts_cache),
	.puts_ea(cmd_puts_ea),
	.puts_ack(cmd_puts_ack),
	.irqs_req(cmd_irqs_req),
	.irqs_num(cmd_irqs_num),// Valid values 1-2043
	.irqs_ack(cmd_irqs_ack),
	.eng_tag(cmd_eng_tag),
	.touch_ack(cmd_touch_ack),
	.touch_ea(cmd_touch_ea),
	.debug_state(cmd_debug_state)

);

// PUTS Mux
zcsl_puts
#(
	.PUTS(PUTS)
)
IPUTS
(
	.clk(clk),
	.ah_brlat(ah_brlat),
	.ah_brdata(ah_brdata),
	.ah_brpar(ah_brpar),
	.put_sel(puts_sel),
	.put_data(puts_data)
);


// GET Unit(s)
zcsl_get
IGET[0:GETS-1]
(
	.clk(clk),
	.reset(cmd_reset),
	.ha_bwvalid(ha_bwvalid),
	.ha_bwtag(ha_bwtag),
	.ha_bwad(ha_bwad),
	.ha_bwdata(ha_bwdata),
	.ha_bwpar(ha_bwpar),
	.ha_bwtagpar(ha_bwtagpar),
//	.ha_rvalid(ha_rvalid),
	.ha_rvalid(cmd_rvalid),
	.ha_rtag(ha_rtag),
	.ha_response(ha_response),
	.ha_rcredits(ha_rcredits),
	.ha_rcachestate(ha_rcachestate),
	.ha_rcachepos(ha_rcachepos),
	.ha_rtagpar(ha_rtagpar),
	.cmd_valid(gets_cmd_valid),
	.cmd_cache(gets_cmd_cache),
	.cmd_ack(gets_cmd_ack),
	.cmd_ea(gets_cmd_ea),
	.cmd_tag(gets_cmd_tag),
	.get_v(gets_v),
	.get_r(gets_r),
	.get_e(gets_e),
	.get_addr(gets_addr),
	.get_size(gets_size),
	.get_data_v(gets_data_v),
	.get_data_r(gets_data_r),
	.get_data_e(gets_data_e),
	.get_data_d(gets_data_d)
);


// PUT Unit(s)
zcsl_put
IPUT[0:PUTS-1]
(
	.clk(clk),
	.reset(cmd_reset),
	.ha_brvalid(ha_brvalid),
	.ha_brtag(ha_brtag),
	.ha_brad(ha_brad),
//	output [0:3] ah_brlat,
	.ah_brdata(put_ah_brdata),
	.ah_brpar(put_ah_brpar),
	.sel(put_sel),
//	.ha_rvalid(ha_rvalid),
	.ha_rvalid(cmd_rvalid),
	.ha_rtag(ha_rtag),
	.ha_response(ha_response),
	.ha_rcredits(ha_rcredits),
	.ha_rcachestate(ha_rcachestate),
	.ha_rcachepos(ha_rcachepos),
	.ha_rtagpar(ha_rtagpar),
	.cmd_valid(put_cmd_valid),
	.cmd_cache(put_cmd_cache),
	.cmd_ack(put_cmd_ack),
	.cmd_ea(put_cmd_ea),
	.cmd_tag(put_cmd_tag),
	.put_v(put_v),
	.put_r(put_r),
	.put_e(put_e),
	.put_addr(put_addr),
	.put_data_v(put_data_v),
	.put_data_r(put_data_r),
	.put_data_e(put_data_e),
	.put_data_d(put_data_d),
	.put_done(put_done)
);


// TRACE Array
zcsl_trace
#(
	.LOG_DEPTH(9)
)
ITRACE
(
	.clk(clk),
	.reset(cmd_reset),
	.ah_cvalid(ah_cvalid),
	.ah_ctag(ah_ctag),
	.ah_com(ah_com),
	.ah_cea(ah_cea),
	.ha_rvalid(ha_rvalid),
	.ha_rtag(ha_rtag),
	.ha_response(ha_response),
	.ha_bwvalid(ha_bwvalid),
	.ha_bwtag(ha_bwtag),
	.ha_bwad(ha_bwad),
	.ha_bwdata(ha_bwdata),
	
	.mm_c1_ack(trc_c1_ack),
	.mm_c2_ack(trc_c2_ack),
	.mm_r_ack(trc_r_ack),
	.mm_bw_ack(trc_bw_ack),
	.mm_c1_data(trc_c1_data),
	.mm_c2_data(trc_c2_data),
	.mm_r_data(trc_r_data),
	.mm_bw_data(trc_bw_data)
);



// CORE Unit
zcsl_core_fft
#(
	.GETS(GETS),
	.PUTS(PUTS),
	.IRQS(IRQS)
)
ICORE
(
	.clk(clk),
	.reset(cmd_reset),
	.mm_valid(core_mm_valid),
	.mm_rnw(core_mm_rnw),
	.mm_dw(core_mm_dw),
	.mm_ack(core_mm_ack),
	.mm_addr(core_mm_addr),
	.mm_wr_data(core_mm_wr_data),
	.mm_rd_data(core_mm_rd_data),
	.done(core_done),
	.get_v(core_get_v),
	.get_r(core_get_r),
	.get_e(core_get_e),
	.get_addr(core_get_addr),
	.get_data_v(core_get_data_v),
	.get_data_r(core_get_data_r),
	.get_data_e(core_get_data_e),
	.get_data_d(core_get_data_d),
	
	.put_v(core_put_v),
	.put_r(core_put_r),
	.put_e(core_put_e),
	.put_done(core_put_done),
	.put_addr(core_put_addr),
	.put_data_v(core_put_data_v),
	.put_data_r(core_put_data_r),
	.put_data_e(core_put_data_e),
	.put_data_d(core_put_data_d)
);


zcsl_irq
#(
	.IRQ_ID(1)
)
IIRQ
(
	.clk(clk),
	.reset(cmd_reset),
	.irq_v(irq_irq_v),
	.irq_r(irq_irq_r),
	.irq_done(irq_irq_done),
	.irq_req(irq_irq_req),
	.irq_ack(irq_irq_ack),
	.irq_num(irq_irq_num),
	.cmd_tag(irq_cmd_tag),
	.ha_rvalid(ha_rvalid),
	.ha_rtag(ha_rtag),
	.ha_response(ha_response),
	.ha_rcredits(ha_rcredits),
	.ha_rtagpar(ha_rtagpar)
	
);




endmodule

