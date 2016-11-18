// ============================================================================
// This is the top module. Also contains pipeline control logic. You can set
// data bus to either 32-bit or 64-bit by setting BUS_WDT to either 32 or 64.
//
// STILL WORKING ON THIS. NOT READY YET.
//
// ----------------------------------------------------------------------------
// MIT License.
// (C)2016 Revanth Kamaraj.
// ============================================================================

`default_nettype none

module ahb_master #(BUS_WDT = 32) // Set either 32 or 64.
(
        // =====================================
        // AHB signals. 
        // =====================================
        input   wire                    i_hclk,
        input   wire                    i_hreset_n,

        input   wire                    i_hready,
        input   wire                    i_hgrant,
        input   wire [BUS_WDT-1:0]      i_hrdata,
        input   wire [1:0]              i_hresp,

        output  wire [BUS_WDT-1:0]      o_hwdata,
        output  wire [31:0]             o_haddr,
        output  wire [1:0]              o_htrans,
        output  wire [1:0]              o_hburst,
        output  wire [1:0]              o_hsize,
        output  wire [3:0]              o_hprot,
        output  wire                    o_hwrite,
        output  wire                    o_hlock,
        output  wire                    o_hbusreq,

        // =====================================
        // UI
        // =====================================
        input   wire [BUS_WDT-1:0]      i_xfer_data,
        input   wire                    i_xfer_dav,
        input   wire [1:0]              i_xfer_phase, //01 and 10 are active.
        input   wire                    i_xfer_write,
        input   wire [3:0]              i_xfer_prot,
        input   wire                    i_xfer_lock,
        input   wire                    i_xfer_almost_empty,

        output  reg                     o_xfer_adv,   // Advance UI.        
        output  wire [BUS_WDT-1:0]      o_xfer_data,
        output  wire                    o_xfer_dav
);

// Still working on this. Not ready yet.

endmodule
