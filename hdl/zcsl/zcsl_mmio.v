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

module zcsl_mmio
(
    // Global Signals
    input clk,

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

    // Control side
    output ctrl_stop,
    
    // Core side
    output core_valid,
    output core_rnw,
    output core_dw,
    input core_ack,
    output [0:23] core_addr,
    output [0:63] core_wr_data,
    input [0:63] core_rd_data,
    
    output touch_ack,
    input [0:63] touch_ea,
    
    input [0:3] cmd_debug_state,
    output trc_c1_ack,
    output trc_c2_ack,
    output trc_r_ack,
    output trc_bw_ack,
    input [0:63] trc_c1_data,
    input [0:63] trc_c2_data,
    input [0:63] trc_r_data,
    input [0:512+64-1] trc_bw_data
);


// ** Wire definitions **
wire mmval_q;
wire mmrnw_q;
wire mmdw_q;
wire mmcfg_q;
wire [0:23] mmad_q;
wire [0:63] mmdata_q;

wire mmack;
wire ah_mmack_q;


wire [0:63] afu_desc_x00;
wire [0:63] afu_desc_x08;
wire [0:63] afu_desc_x10;
wire [0:63] afu_desc_x18;
wire [0:63] afu_desc_x20;
wire [0:63] afu_desc_x28;
wire [0:63] afu_desc_x30;
wire [0:63] afu_desc_x38;
wire [0:63] afu_desc_x40;
wire [0:63] afu_desc_x48;

wire [0:3] afu_desc_mux_sel;
reg [0:63] afu_desc_mux_out;


wire [0:3] afu_mmio_mux_sel;
reg [0:63] afu_mmio_mux_out;

wire [0:63] data_mux_out;
reg [0:63] local_data_mux;

wire ctrl_valid;
wire ctrl_stop_i, ctrl_stop_o, ctrl_stop_o2;
wire ctrl_ack;

// ** Routing and Logic **



//------------------------------------------------------------------------------------------------------------------------------------------------------//
//  AFU Descriptor - see CAIA Spec for regsiter definitions
//------------------------------------------------------------------------------------------------------------------------------------------------------//
// Offset  | Description
//   x00   |  0:15 -  # ints / process           RW  -- this is minimum #
//         | 16:31 -  # of processes supported   RW  -- greater than 512 not allowed, writes bigger than this will not take effect
//         | 32:47 -  # of AFU Config Record     RO
//         | 48:63 -  Programming Model          RO
//   x08   | Reserved
//   x10   | Reserved
//   x18   | Reserved
//   x20   | AFU Config Record format and length
//   x28   | AFU Conrig Record Offset
//   x30   | Per process Problem State Area setup (control and length)
//   x38   | Per process Problem State Area offset
//   x40   | AFU Error buffer length
//   x48   | AFU Error Buffer Offset
//------------------------------------------------------------------------------------------------------------------------------------------------------//
assign afu_desc_x00[0:15]   = 16'h0001;     // num_ints_per_process // Number of interrupts required by the AFU for each process
assign afu_desc_x00[16:31]  = 16'h0001;     // num_of_processes
assign afu_desc_x00[32:47]  = 16'h0000;     // num_of_afu_CRs
assign afu_desc_x00[48]     = 1'b0;         //
assign afu_desc_x00[49:54]  = 6'b000000;    // Reserved, set to 0
assign afu_desc_x00[55]     = 1'b0;         //
assign afu_desc_x00[56:58]  = 3'b000;       // Reserved, set to 0
assign afu_desc_x00[59]     = 1'b1;         // Dedicated Process
assign afu_desc_x00[60]     = 1'b0;         // Reserved, set to 0
assign afu_desc_x00[61]     = 1'b0;         // AFU Directed Support
assign afu_desc_x00[62]     = 1'b0;         // Reserved, set to 0
assign afu_desc_x00[63]     = 1'b0;         // Shared Time Sliced Support


assign afu_desc_x08[0:63]   = 64'h0000000000000000; // Reserved, set to 0
assign afu_desc_x10[0:63]   = 64'h0000000000000000; // Reserved, set to 0
assign afu_desc_x18[0:63]   = 64'h0000000000000000; // Reserved, set to 0
assign afu_desc_x20[0:63]   = 64'h0000000000000000; // Configuration Record (CR) length (here: unused)
assign afu_desc_x28[0:63]   = 64'h0000000000000000; // Configuration Record (CR) offset (here: unused)

assign afu_desc_x30[0:7]    = 8'h01;                // PerProcessPSA_control[0:7]
assign afu_desc_x30[8:63]   = 56'h00000000000000;   // PerProcessPSA_length[8:63]

assign afu_desc_x38[0:63]   = 64'h0000000000000000; // PerProcessPSA_offset[0:63]
assign afu_desc_x40[0:63]   = 64'h0000000000000000; // Reserved[0:7], AFU_EB_len[8:63]
assign afu_desc_x48[0:63]   = 64'h0000000000000000; // AFU_EB_offset[0:63]

// Informative comment
// Access to descriptor space can be dual-word (64-bit) only
/*
ha_mmad[4:23] == 20'h00000; // x00
ha_mmad[4:23] == 20'h00008; // x20
ha_mmad[4:23] == 20'h0000A; // x28
ha_mmad[4:23] == 20'h0000C; // x30
ha_mmad[4:23] == 20'h0000E; // x38
ha_mmad[4:23] == 20'h00010; // x40
ha_mmad[4:23] == 20'h00012; // x48
*/

assign afu_desc_mux_sel = mmad_q[19:22]; // 4-bits for 10 double wide words

always@(afu_desc_mux_sel, afu_desc_x00, afu_desc_x08, afu_desc_x10, afu_desc_x18, afu_desc_x20, afu_desc_x28, afu_desc_x30, afu_desc_x38, afu_desc_x40, afu_desc_x48) begin
    case(afu_desc_mux_sel)
        4'h0 : afu_desc_mux_out = afu_desc_x00;
        4'h1 : afu_desc_mux_out = afu_desc_x08;
        4'h2 : afu_desc_mux_out = afu_desc_x10;
        4'h3 : afu_desc_mux_out = afu_desc_x18;
        4'h4 : afu_desc_mux_out = afu_desc_x20;
        4'h5 : afu_desc_mux_out = afu_desc_x28;
        4'h6 : afu_desc_mux_out = afu_desc_x30;
        4'h7 : afu_desc_mux_out = afu_desc_x38;
        4'h8 : afu_desc_mux_out = afu_desc_x40;
        4'h9 : afu_desc_mux_out = afu_desc_x48;
        default : afu_desc_mux_out = afu_desc_x00;
    endcase
end


// Acknowledge
assign mmack = core_ack | ctrl_ack | (mmcfg_q & mmval_q); // Acknowledge from core or a control command

assign ah_mmack     = ah_mmack_q;
assign ah_mmdatapar = 1'b0;


// Select descriptor or problem state register space
assign data_mux_out = mmcfg_q ? afu_desc_mux_out : ((mmad_q[0:19]==20'd0) ? local_data_mux : core_rd_data);


always@(mmad_q, cmd_debug_state, trc_c1_data, trc_c2_data, trc_r_data, trc_bw_data) begin
    case(mmad_q[19:22])
        4'h0 : local_data_mux = cmd_debug_state;
        4'h1 : local_data_mux = trc_c1_data;
        4'h2 : local_data_mux = trc_c2_data;
        4'h3 : local_data_mux = trc_r_data;
        4'h4 : local_data_mux = trc_bw_data[0*64:1*64-1];
        4'h5 : local_data_mux = trc_bw_data[1*64:2*64-1];
        4'h6 : local_data_mux = trc_bw_data[2*64:3*64-1];
        4'h7 : local_data_mux = trc_bw_data[3*64:4*64-1];
        4'h8 : local_data_mux = trc_bw_data[4*64:5*64-1];
        4'h9 : local_data_mux = trc_bw_data[5*64:6*64-1];
        4'hA : local_data_mux = trc_bw_data[6*64:7*64-1];
        4'hB : local_data_mux = trc_bw_data[7*64:8*64-1];
        4'hC : local_data_mux = trc_bw_data[8*64:9*64-1];
        default : local_data_mux = cmd_debug_state;
    endcase
end

assign trc_c1_ack = mmval_q & mmrnw_q & mmdw_q & (mmad_q[0:23]==24'h000002);
assign trc_c2_ack = mmval_q & mmrnw_q & mmdw_q & (mmad_q[0:23]==24'h000004);
assign trc_r_ack  = mmval_q & mmrnw_q & mmdw_q & (mmad_q[0:23]==24'h000006);
assign trc_bw_ack = mmval_q & mmrnw_q & mmdw_q & (mmad_q[0:23]==24'h000018);

// Control side logic
assign ctrl_valid = mmval_q & ~mmrnw_q & mmdw_q & (mmad_q[0:23]==24'd0); // A DW write to address==0 is a control operation
assign ctrl_stop_i = ctrl_valid & mmdata_q[63];
assign ctrl_stop = ctrl_stop_o2; // Delaying stop to avoid conflicts with mmack
assign ctrl_ack = mmval_q & mmdw_q & (mmad_q[0:18]==19'd0);

assign touch_ack = ctrl_valid & mmdata_q[62];


// Core interface
assign core_valid = mmval_q & ~mmcfg_q & ~(mmad_q[0:18]==19'd0);
assign core_rnw = mmrnw_q;
assign core_dw = mmdw_q;
assign core_addr = mmad_q;
assign core_wr_data = mmdata_q;



// ** Instances **

// Register all inputs
zcsl_dff #(.WIDTH(1))  IVAL(.clk(clk), .i(ha_mmval),   .o(mmval_q));
zcsl_dff #(.WIDTH(1))  IRNW(.clk(clk), .i(ha_mmrnw),   .o(mmrnw_q));
zcsl_dff #(.WIDTH(1))  IDW (.clk(clk), .i(ha_mmdw),    .o(mmdw_q));
zcsl_dff #(.WIDTH(1))  ICFG(.clk(clk), .i(ha_mmcfg),   .o(mmcfg_q));
zcsl_dff #(.WIDTH(24)) IAD (.clk(clk), .i(ha_mmad),    .o(mmad_q));
zcsl_dff #(.WIDTH(64)) IDIN(.clk(clk), .i(ha_mmdata),  .o(mmdata_q));

// Register all outputs
zcsl_dff #(.WIDTH(1))  IACK(.clk(clk), .i(mmack),         .o(ah_mmack_q));
zcsl_dff #(.WIDTH(64)) IDOU(.clk(clk), .i(data_mux_out),  .o(ah_mmdata));


// Control
zcsl_dff #(.WIDTH(1)) ISTOP(.clk(clk), .i(ctrl_stop_i),  .o(ctrl_stop_o));
zcsl_dff #(.WIDTH(1)) ISTOP2(.clk(clk), .i(ctrl_stop_o),  .o(ctrl_stop_o2));








endmodule

