// ============================================================================
// This is the top module. Also contains pipeline control logic. You can set
// data bus to either 32-bit or 64-bit by setting BUS_WDT to either 32 or 64.
//
// WARNING: This design is still very *experimental*. Use it at your own risk.
//
// ----------------------------------------------------------------------------
// MIT License.
// (C)2016 Revanth Kamaraj.
// ============================================================================

`default_nettype none

module ahb_master 
        #( 
                parameter [31:0] BUS_WDT   = 32, 
                parameter [3:0]  MASTER_ID = 4 
        ) 
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
        input   wire [3:0]              i_hmaster,

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
        input   wire [BUS_WDT-1:0]      i_xfer_wdata,
        input   wire [31:0]             i_xfer_addr,
        input   wire [1:0]              i_xfer_size,
        input   wire                    i_xfer_dav,
        input   wire                    i_xfer_trig,
        input   wire                    i_xfer_en,
        input   wire                    i_xfer_write,
        input   wire [3:0]              i_xfer_prot,
        input   wire                    i_xfer_lock,
        input   wire                    i_xfer_full,

        output  wire                    o_xfer_adv,   // Advance UI Combo.        
        output  wire [BUS_WDT-1:0]      o_xfer_rdata,
        output  wire                    o_xfer_rdav,
        output  wire                    o_xfer_ok_to_shutdown
);

localparam [1:0] INCR   = 2'd1;
localparam [1:0] IDLE   = 2'd0;
localparam [1:0] BUSY   = 2'd1;
localparam [1:0] NONSEQ = 2'd2;
localparam [1:0] SEQ    = 2'd3;
localparam [1:0] RETRY  = 2'd2;
localparam [1:0] SPLIT  = 2'd3;

// =========================
// Pipeline inputs.
// =========================

reg                     hwrite;
reg [BUS_WDT-1:0]       hwdata;
reg [31:0]              haddr;
reg [1:0]               htrans;
reg [1:0]               hsize;
reg [3:0]               hprot;
reg                     hlock;
reg                     hbusreq;

// ==========================
// Backtrack taps.
// ==========================

wire [31:0]     do_haddr;
wire [1:0]      do_htrans;
wire [1:0]      do_hsize;
wire [3:0]      do_hprot;
wire            do_hwrite;
wire            do_hlock;
wire            dontsleep; // Not really a backtrack tap but just included.
wire            agu_hbusreq;

// ==========================
// Registers.
// ==========================

reg backtrack_ff;
reg nready_ff;

// ==========================
// Assign
// ==========================
assign o_hburst = INCR;

wire nready =     ( i_xfer_write && !i_xfer_dav   ) || 
                  (!i_xfer_write && !i_xfer_full  );

assign  o_xfer_adv =    i_hready                 && 
                        (i_hmaster == MASTER_ID) && 
                        !backtrack_ff            &&
                        i_hresp != SPLIT         && 
                        i_hresp != RETRY;

assign  o_xfer_ok_to_shutdown = (o_htrans == IDLE && do_htrans == IDLE && 
                                                                !dontsleep);

// Bus request generation.
assign        o_hbusreq = agu_hbusreq | i_xfer_en; 

// ==========================
// Pipeline instance.
// ==========================

ahb_pipeline #(
.WDT(BUS_WDT)
) 
        u_ahb_pipeline 
(
// Clock and reset.
.i_hclk         (       i_hclk          ),
.i_hreset_n     (       i_hreset_n      ),

// AHB Inputs.
.i_hready       (       i_hready        ),
.i_hgrant       (       i_hgrant        ),
.i_hrdata       (       i_hrdata        ),
.i_hresp        (       i_hresp         ),

// Pipeline inputs.
.i_hwrite       (       hwrite          ),
.i_hwdata       (       hwdata          ),
.i_haddr        (       haddr           ),
.i_htrans       (       htrans          ),
.i_hsize        (       hsize           ),
.i_hprot        (       hprot           ),
.i_hlock        (       hlock           ),
.i_hbusreq      (       hbusreq         ),

// AHB Outputs.
.o_agu_hwdata   (                       ), // UNCONNECTED
.o_agu_haddr    (       o_haddr         ),
.o_agu_htrans   (       o_htrans        ),
.o_agu_hsize    (       o_hsize         ),
.o_agu_hprot    (       o_hprot         ),
.o_agu_hwrite   (       o_hwrite        ),
.o_agu_hlock    (       o_hlock         ),
.o_agu_hbusreq  (       agu_hbusreq     ),

// Backtrack taps.
.o_do_hwdata    (       o_hwdata        ),
.o_do_haddr     (       do_haddr        ),
.o_do_htrans    (       do_htrans       ),
.o_do_hsize     (       do_hsize        ), 
.o_do_hprot     (       do_hprot        ),
.o_do_hwrite    (       do_hwrite       ),
.o_do_hlock     (       do_hlock        ),

// Data Outputs.
.o_di_data      (       o_xfer_rdata    ),
.o_di_dav       (       o_xfer_rdav     ),

// Dontsleep
.o_dontsleep    (       dontsleep       )
);

// =============================
// Combinational logic
// =============================
always @*
begin
        if ( !i_xfer_en && o_xfer_ok_to_shutdown )
        begin
                haddr  = o_haddr;
                hwrite = o_hwrite;
                hwdata = o_hwdata;
                htrans = IDLE;
                hsize  = o_hsize;
                hprot  = o_hprot;
                hbusreq = 1'd0;
                hlock   = 1'd0;
        end
        else if ( i_hresp == RETRY || i_hresp == SPLIT || backtrack_ff )
        begin
                haddr   =       do_haddr;
                hwrite  =       do_hwrite;
                hlock   =       do_hlock;
                hwdata  =       o_hwdata;
                htrans  =       NONSEQ;
                hsize   =       do_hsize;
                hprot   =       do_hprot;
                hbusreq =       1'd1;
        end
        else if ( i_xfer_trig )
        begin
                haddr   =       i_xfer_addr;                
                hwrite  =       i_xfer_write;
                hlock   =       i_xfer_lock;
                hwdata  =       i_xfer_wdata;
                htrans  =       nready ? IDLE : NONSEQ;
                hsize   =       i_xfer_size;
                hprot   =       i_xfer_prot;
                hbusreq =       1'd1;
        end
        else
        begin
                haddr   =       o_haddr +  (nready == 1'd1 ? 32'd0 : 
                                          do_hsize == 2'd0 ? 32'd1 :
                                          do_hsize == 2'd1 ? 32'd2 :
                                          do_hsize == 2'd2 ? 32'd4 : 
                                                             32'd8 );
                hwrite  =       do_hwrite;
                hwdata  =       o_hwdata;
                htrans  =       nready ? BUSY : 
                                        nready_ff ? NONSEQ : 
                                        (o_haddr[31:10] != haddr[31:10]) ? 
                                        NONSEQ : SEQ;

                hwdata  =       i_xfer_wdata;
                hsize   =       do_hsize;
                hlock   =       do_hlock;
                hprot   =       do_hprot;
                hbusreq =       1'd1;
        end
end

// ===============================
// Sequential Logic.
// ===============================
always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
        begin
                backtrack_ff <= 1'd0;
        end
        else if ( ( i_hresp == RETRY || i_hresp == SPLIT ) && 
                    i_hready && i_hgrant )
        begin
                backtrack_ff <= 1'd1;
        end
        else if ( i_hready && i_hgrant )
        begin
                backtrack_ff <= 1'd0;
        end
end

always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if(!i_hreset_n)
        begin
                nready_ff <= 1'd0;
        end
        else if ( i_hready && i_hgrant )
        begin
                nready_ff <= nready;
        end
end

endmodule
