//////////////////////////////////////////////////////////////////////
// Product              : AHB Master
// Spec                 : AMBA 2.0 AHB section
// License              : MIT license
// Microarchitecture    : 3 stage pipeline.       
// Target               : ASIC/FPGA
// Author               : Revanth Kamaraj
//////////////////////////////////////////////////////////////////////
// This RTL describes a generic AHB master with support for single and
// burst transfers. Split/retry pipeline rollback is also supported.
// The entire design is driven by a single clock i.e., AHB clock. A global
// asynchronous active low reset is provided.
//////////////////////////////////////////////////////////////////////
// NOTE: THE DESIGN IS IN AN EXPERIMENTAL STATE.
//////////////////////////////////////////////////////////////////////

module ahb_master #(parameter DATA_WDT = 32, parameter BEAT_WDT = 32) (
        ///////////////////////////////////
        // AHB interface.
        ///////////////////////////////////

        input                   i_hclk,
        input                   i_hreset_n,
        output reg [31:0]       o_haddr,
        output reg [2:0]        o_hburst,
        output reg [1:0]        o_htrans,
        output reg[DATA_WDT-1:0]o_hwdata,
        output reg              o_hwrite,
        output reg [2:0]        o_hsize,
        input     [DATA_WDT-1:0]i_hrdata,
        input                   i_hready,
        input      [1:0]        i_hresp,
        input                   i_hgrant,
        output reg              o_hbusreq,

        ////////////////////////////
        // User interface.
        ////////////////////////////

        output reg              o_next,   // UI must change only if this is 1.
        input     [DATA_WDT-1:0]i_data,   // Data to write. Can change during burst if o_next = 1.
        input                   i_dav,    // Data to write valid. Can change during burst if o_next = 1.
        input      [31:0]       i_addr,   // Base address of burst.
        input      [2:0]        i_size,   // Size of transfer. Like hsize.
        input                   i_wr,     // Write to AHB bus.
        input                   i_rd,     // Read from AHB bus.
        input     [BEAT_WDT-1:0]i_min_len,// Minimum guaranteed length of burst.
        input                   i_cont,   // Current transfer continues previous one.
        output reg[DATA_WDT-1:0]o_data,   // Data got from AHB is presented here.
        output reg[31:0]        o_addr,   // Corresponding address is presented here.
        output reg              o_dav     // Used as o_data valid indicator.
); 

//
// NOTE: You can change UI signals at any time if the unit is IDLING.
// To set the unit to IDLE mode, make i_cont = 0, i_rd = 0 and i_wr = 0
// on o_next = 1.
//

/////////////////////////////////////////
// Localparams
/////////////////////////////////////////

//
// SINGLE, WRAPs are currently UNUSED.
// Single transfers are treated as bursts of 
// length 1 which is acceptable.
//
localparam [1:0] IDLE   = 0;
localparam [1:0] BUSY   = 1;
localparam [1:0] NONSEQ = 2;
localparam [1:0] SEQ    = 3;
localparam [1:0] OKAY   = 0;
localparam [1:0] ERROR  = 1;
localparam [1:0] SPLIT  = 2;
localparam [1:0] RETRY  = 3;
localparam [2:0] SINGLE = 0;//Unused. Done as a burst of 1.
localparam [2:0] INCR   = 1;
localparam [2:0] WRAP4  = 2;
localparam [2:0] INCR4  = 3;
localparam [2:0] WRAP8  = 4;
localparam [2:0] INCR8  = 5;
localparam [2:0] WRAP16 = 6;
localparam [2:0] INCR16 = 7;
localparam [2:0] BYTE   = 0;
localparam [2:0] HWORD  = 1;
localparam [2:0] WORD   = 2; // 32-bit
localparam [2:0] DWORD  = 3; // 64-bit
localparam [2:0] BIT128 = 4; 
localparam [2:0] BIT256 = 5; 
localparam [2:0] BIT512 = 6;
localparam [2:0] BIT1024 = 7;

// Abbreviations.
localparam D = DATA_WDT-1;
localparam B = BEAT_WDT-1;

////////////////////////////////////////////
// Flip-flops.
////////////////////////////////////////////

reg [4:0]  burst_ctr; // Small counter to keep track number of transfers left in a burst.
reg [B:0]  beat_ctr;  // Counter to keep track of number of words left.

// Pipeline flip-flops.
reg [1:0]  gnt;        
reg [2:0]  hburst;      // Only for stage 1. 
reg [D:0]  hwdata [1:0];
reg [31:0] haddr  [1:0];
reg [1:0]  htrans [1:0];
reg [1:0]  hwrite;     
reg [2:0]  hsize  [1:0];

// Tracks if we are in a pending state. 
reg        pend_split;

/////////////////////////////////////////////
// Signal aliases.
/////////////////////////////////////////////

wire spl_ret_cyc_1 = gnt[1] && !i_hready && (i_hresp == ERROR || i_hresp == SPLIT);
wire rd_wr         = i_rd || (i_wr && i_dav);
wire b1k           = (haddr[0] + (rd_wr << i_size)) >> 10 != haddr[0][31:10];

//////////////////////////////////////////////
// Misc. logic.
//////////////////////////////////////////////

// Output drivers.
always @* {o_haddr, o_hburst, o_htrans, o_hwdata, o_hwrite, o_hsize} <= 
          {haddr[0], hburst, htrans[0], hwdata[1], hwrite[0], hsize[0]};

//UI must change only if this is 1.
always @* o_next = (i_hready && i_hgrant && !pend_split);

///////////////////////////////////
// Grant tracker.
///////////////////////////////////

always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
                gnt <= 2'd0;
        else if ( spl_ret_cyc_1 )
                gnt <= 2'd0;
        else if ( i_hready )
                gnt <= {gnt[0], i_hgrant};
end

///////////////////////////////////////////
// Bus request
//////////////////////////////////////////

always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
                o_hbusreq <= 1'd0;
        else
                o_hbusreq <= i_rd | i_wr;
end

///////////////////////////////////////////
// Address phase. Stage I.
///////////////////////////////////////////

always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
        begin
                htrans[0]  <= IDLE;
                pend_split <= 1'd0;
        end
        else if ( spl_ret_cyc_1 )
        begin
                htrans[0] <= IDLE;
                pend_split <= 1'd1;
        end
        else if ( i_hready && i_hgrant )
        begin
                pend_split <= 1'd0;

                if ( pend_split )
                begin
                        {hwdata[0], hwrite[0], hsize[0]} <= {hwdata[1], hwrite[1], hsize[1]};

                        haddr[0]  <= haddr[1];
                        hburst    <= compute_hburst(beat_ctr == 0 ? 0 : beat_ctr + 1);
                        htrans[0] <= NONSEQ;
                        burst_ctr <= compute_burst_ctr(beat_ctr == 0 ? 0 : beat_ctr + 1);
                        beat_ctr  <= beat_ctr + 1;
                end
                else
                begin
                        {hwdata[0], hwrite[0], hsize[0]} <= {i_data, i_wr, i_size}; 

                        if ( !i_cont )
                        begin
                                haddr[0]  <= i_addr;
                                hburst    <= compute_hburst(i_min_len - rd_wr);
                                htrans[0] <= rd_wr ? NONSEQ : IDLE;
                                beat_ctr  <= i_min_len - rd_wr;
                                burst_ctr <= compute_burst_ctr(i_min_len - rd_wr);
                        end
                        else if ( !gnt[0] || (burst_ctr == 0 && o_hburst != INCR) )
                        begin
                                haddr[0]  <= haddr[0] + (rd_wr << i_size);
                                hburst    <= compute_hburst(beat_ctr ? beat_ctr - rd_wr : 0);
                                htrans[0] <= rd_wr ? NONSEQ : IDLE;
                                burst_ctr <= compute_burst_ctr(beat_ctr ? beat_ctr - rd_wr : 0); 
                                beat_ctr  <= beat_ctr ? beat_ctr - rd_wr : 0;
                        end
                        else
                        begin
                                haddr[0]  <= haddr[0] + (rd_wr << i_size);
                                htrans[0] <= rd_wr ? (b1k ? NONSEQ : SEQ) : BUSY;
                                hburst[0] <= b1k ? INCR : hburst[0];
                                burst_ctr <= burst_ctr ? burst_ctr - rd_wr : 0;
                                beat_ctr  <= beat_ctr  ? beat_ctr  - rd_wr : 0;
                        end
                end 
        end
end

////////////////////////////////////////
// HWDATA phase. Stage II.
////////////////////////////////////////

always @ (posedge i_hclk)
begin
        if ( i_hready && gnt[0] )
                {hwdata[1], haddr[1], hwrite[1], hsize[1], htrans[1]} <= 
                {hwdata[0], haddr[0], hwrite[0], hsize[0], htrans[0]};                 
end

///////////////////////////////////////
// HRDATA phase. Stage III.
///////////////////////////////////////

always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
                o_dav <= 1'd0;
        else if ( gnt[1] && i_hready && (htrans[1] == SEQ || htrans[1] == NONSEQ) )
        begin
                o_dav  <= !hwrite[1];
                o_data <= i_hrdata;
                o_addr <= haddr[1];
        end
        else
                o_dav <= 1'd0;
end

////////////////////////////
// Functions.
////////////////////////////

function [2:0] compute_hburst (input [B:0] val);
        compute_hburst =        (val >= 15) ? INCR16 :
                                (val >= 7)  ? INCR8 :
                                (val >= 3)  ? INCR4 : INCR;
endfunction

function [4:0] compute_burst_ctr(input [4:0] val);
        compute_burst_ctr =     (val >= 15) ? 5'd15 :
                                (val >= 7)  ? 5'd7  :
                                (val >= 3)  ? 5'd3  : 0;
endfunction

/////////////////////////////// DEBUG ONLY ////////////////////////////////////

`ifdef SIM

initial
begin
        $display($time,"DEBUG MODE ENABLED! PLEASE MONITOR CAPS SIGNALS IN VCD...");
end

`ifndef STRING
        `define STRING reg [256*8-1:0]
`endif

`STRING HBURST;
`STRING HTRANS;
`STRING HSIZE;
`STRING HRESP;

always @*
begin
        case(o_hburst)
        INCR:   HBURST = "INCR";
        INCR4:  HBURST = "INCR4";
        INCR8:  HBURST = "INCR8";
        INCR16: HBURST = "INCR16";
        default:HBURST = "<----?????--->";
        endcase 

        case(o_htrans)
        SINGLE: HTRANS = "SINGLE";
        BUSY:   HTRANS = "BUSY";  
        SEQ:    HTRANS = "SEQ";   
        NONSEQ: HTRANS = "NONSEQ";
        default:HTRANS = "<----?????--->";
        endcase 

        case(i_hresp)
        OKAY:   HRESP = "OKAY";
        ERROR:  HRESP = "ERROR";
        SPLIT:  HRESP = "SPLIT";
        RETRY:  HRESP = "RETRY";
        endcase

        case(o_hsize)
        BYTE    : HSIZE = "8BIT";
        HWORD   : HSIZE = "16BIT";
        WORD    : HSIZE = "32BIT"; // 32-bit
        DWORD   : HSIZE = "64BIT"; // 64-bit
        BIT128  : HSIZE = "128BIT"; 
        BIT256  : HSIZE = "256BIT"; 
        BIT512  : HSIZE = "512BIT";
        BIT1024 : HSIZE = "1024BIT";
        default : HSIZE = "<---?????--->";
        endcase
end

`endif

endmodule
