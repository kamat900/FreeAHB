// ============================================================================
// This is the core AHB pipeline.
// => ADDRESS_GENERATOR_UNIT => DATA_OUT => DATA_IN =>
//    (AGU)                     (DO)        (DI) 
//
// Set WDT to either 32 or 64. That sets the data bus width. When synthesized
// for ASIC, tools can efficiently infer clock gating. Helps for FPGA too. 
// ----------------------------------------------------------------------------
// MIT License.
// (C)2016 Revanth Kamaraj.
// ============================================================================

`default_nettype none

module ahb_pipeline #(parameter WDT = 32'd32) // Bus width = 32-bit by default.
                                              // Set either 32-bit or 64-bit.
(
        // ==================================
        // AHB Inputs. 
        // ==================================
       
        input   wire            i_hclk,
        input   wire            i_hreset_n,

        input   wire            i_hready,
        input   wire            i_hgrant,
        input   wire [WDT-1:0]  i_hrdata,

        // =================================
        // Pipeline inputs.
        // =================================

        input   wire            i_hwrite,
        input   wire [WDT-1:0]  i_hwdata,
        input   wire [31:0]     i_haddr,
        input   wire [1:0]      i_htrans,
        input   wire [1:0]      i_hburst,
        input   wire [1:0]      i_hsize,
        input   wire [3:0]      i_hprot,
        input   wire            i_hlock,
        input   wire            i_hbusreq,

        // =================================
        // Pipeline registers / AHB Outputs.
        // =================================

        output  reg  [WDT-1:0]  o_agu_hwdata,
        output  reg  [31:0]     o_agu_haddr,
        output  reg  [1:0]      o_agu_htrans,
        output  reg  [1:0]      o_agu_hburst,
        output  reg  [1:0]      o_agu_hsize,
        output  reg  [3:0]      o_agu_hprot,
        output  reg             o_agu_hwrite,
        output  reg             o_agu_hlock,
        output  reg             o_agu_hbusreq,

        output  reg  [WDT-1:0]  o_di_data,
        output  reg             o_di_dav,

        output  reg  [WDT-1:0]  o_do_hwdata,
        output  reg  [1:0]      o_do_htrans,
        output  reg  [1:0]      o_do_hburst,
        output  reg  [1:0]      o_do_hsize,
        output  reg  [3:0]      o_do_hprot,
        output  reg             o_do_hlock,
        output  reg  [31:0]     o_do_haddr,
        output  reg             o_do_hwrite
);

localparam [1:0] IDLE = 2'd0;
localparam [1:0] BUSY = 2'd1;

// Pipeline anti-stall signal, hwdata anti-stall signal, di_data_en anti-stall.
wire adv = i_hready && i_hgrant;

wire do_hwdata_en=adv                 && 
                  o_do_hwrite         && 
                  o_do_htrans != IDLE && 
                  o_do_htrans != BUSY;

wire di_data_en = adv                   && 
                  !o_do_hwrite          && 
                  o_do_htrans != IDLE   && 
                  o_do_htrans != BUSY;

// Address Generation Unit Stage.
always @ (posedge i_hclk or negedge i_hreset_n)
begin: agu
        if ( !i_hreset_n )
        begin
                o_agu_hwdata    <=      {WDT{1'd0}};
                o_agu_haddr     <=      {WDT{1'd0}};
                o_agu_htrans    <=      2'd0;
                o_agu_hburst    <=      2'd0;
                o_agu_hsize     <=      2'd0;
                o_agu_hprot     <=      4'd0;
                o_agu_hwrite    <=      1'd1;
                o_agu_hlock     <=      1'd0;
                o_agu_hbusreq   <=      1'd0;
        end               
        else if ( adv )
        begin
                o_agu_hwdata    <=   i_hwdata;    
                o_agu_haddr     <=   i_haddr;     
                o_agu_htrans    <=   i_htrans;    
                o_agu_hburst    <=   i_hburst;    
                o_agu_hsize     <=   i_hsize;     
                o_agu_hprot     <=   i_hprot;     
                o_agu_hwrite    <=   i_hwrite;    
                o_agu_hlock     <=   i_hlock;     
                o_agu_hbusreq   <=   i_hbusreq;   
        end 
end

// Data Out Stage.
always @ (posedge i_hclk or negedge i_hreset_n)
begin: _do
        if ( !i_hreset_n )
        begin
                o_do_haddr     <=      {WDT{1'd0}};
                o_do_htrans    <=      2'd0;
                o_do_hburst    <=      2'd0;
                o_do_hsize     <=      2'd0;
                o_do_hprot     <=      4'd0;
                o_do_hwrite    <=      1'd1;
                o_do_hlock     <=      1'd0;
        end
        else if ( adv )
        begin
                o_do_haddr     <=   o_agu_haddr;     
                o_do_htrans    <=   o_agu_htrans;    
                o_do_hburst    <=   o_agu_hburst;    
                o_do_hsize     <=   o_agu_hsize;     
                o_do_hprot     <=   o_agu_hprot;     
                o_do_hwrite    <=   o_agu_hwrite;    
                o_do_hlock     <=   o_agu_hlock;     
        end
end

// Data Out Stage.
always @ (posedge i_hclk or negedge i_hreset_n)
begin: _do_hwdata
        if ( !i_hreset_n )
        begin
                o_do_hwdata     <= {WDT{1'd0}};
        end
        else if ( do_hwdata_en )
        begin
                o_do_hwdata     <= o_agu_hwdata;
        end
end

// Data In Stage.
always @ (posedge i_hclk or negedge i_hreset_n)
begin: di
        if ( !i_hreset_n )
        begin
                o_di_data      <=       {WDT{1'd0}};
        end
        else if ( di_data_en )
        begin
                o_di_data       <=      i_hrdata;
        end
end

// Data In Stage.
always @ (posedge i_hclk or negedge i_hreset_n)
begin: di_dav
        if ( !i_hreset_n ) 
        begin
                o_di_dav <= 1'd0;
        end
        else
        begin               
                o_di_dav <= di_data_en;
        end
end

endmodule
