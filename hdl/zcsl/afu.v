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

module afu
(
    // Accelerator Command Interface
    output ah_cvalid,           // A valid command is present
    output [0:7] ah_ctag,       // request id
    output [0:12] ah_com,       // command PSL will execute
    //output [0:2] ah_cpad,       // prefetch attributes
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


// ** Routing & logic **


// ** Instances **



// Wrapped toplevel
zcsl_top IAFU (
    .ah_cvalid(ah_cvalid),
    .ah_ctag(ah_ctag),
    .ah_ctagpar(ah_ctagpar),
    .ah_com(ah_com),
    .ah_compar(ah_compar),
    .ah_cabt(ah_cabt),
    .ah_cea(ah_cea),
    .ah_ceapar(ah_ceapar),
    .ah_cch(ah_cch),
    .ah_csize(ah_csize),
    .ha_croom(ha_croom),
    .ha_brvalid(ha_brvalid),
    .ha_brtag(ha_brtag),
    .ha_brtagpar(ha_brtagpar),
    .ha_brad(ha_brad),
    .ah_brlat(ah_brlat),
    .ah_brdata(ah_brdata),
    .ah_brpar(ah_brpar),
    .ha_bwvalid(ha_bwvalid),
    .ha_bwtag(ha_bwtag),
    .ha_bwtagpar(ha_bwtagpar),
    .ha_bwad(ha_bwad),
    .ha_bwdata(ha_bwdata),
    .ha_bwpar(ha_bwpar),
    .ha_rvalid(ha_rvalid),
    .ha_rtag(ha_rtag),
    .ha_rtagpar(ha_rtagpar),
    .ha_response(ha_response),
    .ha_rcredits(ha_rcredits),
    .ha_rcachestate(ha_rcachestate),
    .ha_rcachepos(ha_rcachepos),
    .ha_mmval(ha_mmval),
    .ha_mmcfg(ha_mmcfg),
    .ha_mmrnw(ha_mmrnw),
    .ha_mmdw(ha_mmdw),
    .ha_mmad(ha_mmad),
    .ha_mmadpar(ha_mmadpar),
    .ha_mmdata(ha_mmdata),
    .ha_mmdatapar(ha_mmdatapar),
    .ah_mmack(ah_mmack),
    .ah_mmdata(ah_mmdata),
    .ah_mmdatapar(ah_mmdatapar),
    .ha_jval(ha_jval),
    .ha_jcom(ha_jcom),
    .ha_jcompar(ha_jcompar),
    .ha_jea(ha_jea),
    .ha_jeapar(ha_jeapar),
    .ah_jrunning(ah_jrunning),
    .ah_jdone(ah_jdone),
    .ah_jcack(ah_jcack),
    .ah_jerror(ah_jerror),
    .ah_jyield(ah_jyield),
    .ah_tbreq(ah_tbreq),
    .ah_paren(ah_paren),
    .ha_pclock(ha_pclock)
  );



endmodule

