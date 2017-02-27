/******************************************************************************
 * Title                : AHB 2.0 Master
 *
 * License              : MIT license
 *
 * Target               : ASIC/FPGA
 *
 * Author               : Revanth Kamaraj
 *
 * This RTL describes a generic AHB master with support for single and
 * burst transfers. Split/retry pipeline rollback is also supported.
 * The entire design is driven by a single clock i.e., AHB clock. A global
 * asynchronous active low reset is provided.
 *
 * ------->       NOTE: THE DESIGN IS IN AN EXPERIMENTAL STATE.   <----------
 *****************************************************************************
 *
 * MIT License
 * 
 * Copyright (C) 2017 Revanth Kamaraj
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *******************************************************************************/

module ahb_master #(parameter DATA_WDT = 32, parameter BEAT_WDT = 32) (

        /************************
         * AHB interface.
         ************************/
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

        /************************
         * User interface.
         ************************/

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

/*
 * NOTE: You can change UI signals at any time if the unit is IDLING.
 *
 * NOTE: o_next is a combinational signal.
 *
 * NOTE: When reset is released, the signals on the UI should represent an
 * IDLING state. From there onwards, you can change the UI at any time but once
 * you change it, further changes can be made only if o_next = 1. You could
 * perhaps connect o_next to read_enable of a FIFO.
 *
 * To go to IDLE, you must follow this...
 *      To set the unit to IDLE mode, make 
 *              i_cont = 0, i_rd = 0 and i_wr = 0 (or) 
 *              i_wr = 1 and i_dav = 0.
 * on o_next = 1. As mentioned above, you change UI signals without having
 * o_next = 1 but once changed you must change them again only when o_next = 1.
 *
 * NOTE: The first UI request of a burst must have valid data provided in case
 * of a write.  You CANNOT start a burst with the first UI request having
 * wr = 1 and dav = 0.
 *
 * NOTE: Most UI inputs should be held constant during a burst.
 */

/********************
 * Localparams
 ********************/

/*
 * SINGLE, WRAPs are currently UNUSED.
 * Single transfers are treated as bursts of length 1 which is acceptable.
 */
localparam [1:0] IDLE   = 0;
localparam [1:0] BUSY   = 1;
localparam [1:0] NONSEQ = 2;
localparam [1:0] SEQ    = 3;
localparam [1:0] OKAY   = 0;
localparam [1:0] ERROR  = 1;
localparam [1:0] SPLIT  = 2;
localparam [1:0] RETRY  = 3;
localparam [2:0] SINGLE = 0; /* Unused. Done as a burst of 1. */
localparam [2:0] INCR   = 1;
localparam [2:0] WRAP4  = 2;
localparam [2:0] INCR4  = 3;
localparam [2:0] WRAP8  = 4;
localparam [2:0] INCR8  = 5;
localparam [2:0] WRAP16 = 6;
localparam [2:0] INCR16 = 7;
localparam [2:0] BYTE   = 0;
localparam [2:0] HWORD  = 1;
localparam [2:0] WORD   = 2; /* 32-bit */
localparam [2:0] DWORD  = 3; /* 64-bit */
localparam [2:0] BIT128 = 4; 
localparam [2:0] BIT256 = 5; 
localparam [2:0] BIT512 = 6;
localparam [2:0] BIT1024 = 7;

/* Abbreviations. */
localparam D = DATA_WDT-1;
localparam B = BEAT_WDT-1;

/******************
 * Flip-flops.
 ******************/

reg [4:0]  burst_ctr;       // Small counter to keep track of current burst count.
reg [B:0]  beat_ctr;        // Counter to keep track of word/beat count.

/* Pipeline flip-flops. */ 
reg [1:0]  gnt;        
reg [2:0]  hburst;      // Only for stage 1. 
reg [D:0]  hwdata [1:0];
reg [31:0] haddr  [1:0];
reg [1:0]  htrans [1:0];
reg [1:0]  hwrite;     
reg [2:0]  hsize  [1:0];
reg [B:0]  beat;        // Only for stage 2.

/* Tracks if we are in a pending state. */
reg        pend_split;

/***********************
 * Signal aliases.
 ***********************/ 

/* Detects the first cycle of split and retry. */
wire spl_ret_cyc_1 = gnt[1] && !i_hready && (i_hresp == RETRY || i_hresp == SPLIT);

/* Inputs are valid only if there is a read or if there is a write with valid data. */
wire rd_wr         = i_rd || (i_wr && i_dav);

/* Detects that 1k boundary condition will be crossed on next address */
wire b1k_spec      = (haddr[0] + (1 << i_size)) >> 10 != haddr[0][31:10];

/*******************
 * Misc. logic.
 *******************/ 

/* Output drivers. */
always @* {o_haddr, o_hburst, o_htrans, o_hwdata, o_hwrite, o_hsize} = 
          {haddr[0], hburst, htrans[0], hwdata[1], hwrite[0], hsize[0]};

/* UI must change only if this is 1. */
always @* o_next = (i_hready && i_hgrant && !pend_split);

/***********************
 * Grant tracker.
 ***********************/
/* Passes grant throughout  the pipeline. */
always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
                gnt <= 2'd0;
        else if ( spl_ret_cyc_1 )
                gnt <= 2'd0; /* A split retry cycle 1 will invalidate the pipeline. */
        else if ( i_hready )
                gnt <= {gnt[0], i_hgrant};
end

/**************************
 * Bus request
 **************************/ 
always @ (posedge i_hclk or negedge i_hreset_n)
begin
        /* Request bus when doing reads/writes else do not request bus */
        if ( !i_hreset_n )
                o_hbusreq <= 1'd0;
        else
                o_hbusreq <= i_rd | i_wr;
end

/******************************
 * Address phase. Stage I.
 ******************************/
always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
        begin
                /* Signal IDLE on reset. */
                htrans[0]  <= IDLE;
                pend_split <= 1'd0;
        end
        else if ( spl_ret_cyc_1 ) /* Split retry cycle I */
        begin
                htrans[0] <= IDLE;
                pend_split <= 1'd1;
        end
        else if ( i_hready && i_hgrant )
        begin
                pend_split <= 1'd0; /* Any pending split will be cleared */

                if ( pend_split )
                begin
                        /* If there's a pending split, perform a pipeline rollback */

                        {hwdata[0], hwrite[0], hsize[0]} <= {hwdata[1], hwrite[1], hsize[1]};

                        haddr[0]  <= haddr[1];
                        hburst    <= compute_hburst   (beat, haddr[1], hsize[1]);
                        htrans[0] <= NONSEQ;
                        burst_ctr <= compute_burst_ctr(beat, haddr[1], hsize[1]);
                        beat_ctr  <= beat;
                end
                else
                begin
                        {hwdata[0], hwrite[0], hsize[0]} <= {i_data, i_wr, i_size}; 

                        if ( !i_cont && !rd_wr ) /* Signal IDLE. */
                        begin
                                htrans[0] <= IDLE;
                        end
                        else if ( (!i_cont && rd_wr) || !gnt[0] || (burst_ctr == 1 && o_hburst != INCR) 
                                     || htrans[0] == IDLE || b1k_spec )
                        begin
                                /* We need to recompute the burst type here */

                                haddr[0]  <= !i_cont ? i_addr : haddr[0] + (rd_wr << i_size);
                                hburst    <= compute_hburst   (!i_cont ? i_min_len : beat_ctr,    
                                                               !i_cont ? i_addr : haddr[0] + (rd_wr << i_size) , i_size);
                                htrans[0] <= rd_wr ? NONSEQ : IDLE;

                                burst_ctr <= compute_burst_ctr(!i_cont ? i_min_len : beat_ctr - rd_wr, 
                                                               !i_cont ? i_addr : haddr[0] + (rd_wr << i_size) , i_size); 

                                beat_ctr  <= !i_cont ? i_min_len : ((hburst == INCR) ? beat_ctr : beat_ctr - rd_wr); 
                        end
                        else
                        begin
                                /* We are in a normal burst. No need to change HBURST. */

                                haddr[0]  <= haddr[0] + ((htrans[0] != BUSY) << i_size);
                                htrans[0] <= rd_wr ? SEQ : BUSY;
                                burst_ctr <= o_hburst == INCR ? burst_ctr : (burst_ctr - rd_wr);
                                beat_ctr  <= o_hburst == INCR ? beat_ctr  : (beat_ctr  - rd_wr);
                        end
                end 
        end
end

/******************************
 * HWDATA phase. Stage II.
 ******************************/
always @ (posedge i_hclk)
begin
        if ( i_hready && gnt[0] )
                {hwdata[1], haddr[1], hwrite[1], hsize[1], htrans[1], beat} <= 
                {hwdata[0], haddr[0], hwrite[0], hsize[0], htrans[0], beat_ctr};                 
end

/********************************
 * HRDATA phase. Stage III.
 ********************************/
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

/*****************************
 * Functions.
 *****************************/
function [2:0] compute_hburst (input [B:0] val, input [31:0] addr, input [2:0] sz);
begin
        compute_hburst =        (val >= 16 && no_cross(addr, 15, sz)) ? INCR16 :
                                (val >= 8  && no_cross(addr, 7, sz))  ? INCR8 :
                                (val >= 4  && no_cross(addr, 3, sz))  ? INCR4 : INCR;

        $display($time, "val = %d, addr = %d, sz = %d, compute_hburst = %d", val, addr, sz, compute_hburst);
end
endfunction

function [4:0] compute_burst_ctr(input [B:0] val, input [31:0] addr, input [2:0] sz);
begin
        compute_burst_ctr =     (val >= 16 && no_cross(addr, 15, sz)) ? 5'd16 :
                                (val >= 8  && no_cross(addr, 7, sz))  ? 5'd8  :
                                (val >= 4 && no_cross(addr, 3, sz))   ? 5'd4  : 5'd0;

        $display($time, "val = %d, addr = %d, sz = %d, compute_burst_ctr = %d", val, addr, sz, compute_burst_ctr);
end
endfunction

function no_cross(input [31:0] addr, input [31:0] val, input [2:0] sz);
        if ( addr + (val << (1 << sz )) >> 10 != addr[31:10] )
                no_cross = 1'd0; // Crossed!
        else
                no_cross = 1'd1; // Not crossed
endfunction

/////////////////////////////// END OF RTL. START OF DEBUG CODE /////////////////////////////////////////////////////

/*******************************************************************************************************************
 *              NOTE : CODE BELOW IS FOR DEBUG ONLY. DO NOT DEFINE SIM WHEN SYNTHESIZING THE DESIGN
 ******************************************************************************************************************/
`ifdef SIM // Define SIM only during verification.

wire [31:0] beat_ctr_nxt = !i_cont ? (i_min_len - rd_wr) : ((hburst == INCR) ? beat_ctr : beat_ctr - rd_wr);

initial
begin
        $display($time,"DEBUG MODE ENABLED! PLEASE MONITOR CAPITAL SIGNALS IN VCD...");
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
        SINGLE: HTRANS = "IDLE";
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
        default: HRESP = "<---?????---->";
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
