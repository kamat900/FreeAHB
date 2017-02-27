/////////////////////////////////////////////////////
// A simulation model of the AHB slave. This model
// can generate only OKAY responses.
// <----- NOT FOR SYNTHESIS ------------->
/////////////////////////////////////////////////////

// synthesis translate_off
`ifdef SIM

module ahb_slave_sim #(parameter DATA_WDT = 32) (

input                   i_hclk,
input                   i_hreset_n,
input [2:0]             i_hburst,
input [1:0]             i_htrans,
input [31:0]            i_hwdata,
input                   i_hsel,
input [31:0]            i_haddr,
input                   i_hwrite,
output reg [31:0]       o_hrdata,

input                   i_hready,
output reg              o_hready,
output    [1:0]         o_hresp

);

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

// 4GB of memory.
reg [7:0] mem [(2^32)-1:0];

// Pipeline registers.
reg write, read;
reg [31:0] addr;
reg [DATA_WDT-1:0] data;

assign o_hresp = OKAY;

// First stage.
always @ (posedge (i_hclk && o_hready && i_hready) or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
        begin
                read  <= 1'd0;
                write <= 1'd0;
        end
        else
        begin
                if ( i_hsel && (i_htrans == SEQ || i_htrans == NONSEQ) )        
                begin
                        write <= i_hwrite;
                        addr  <= i_haddr;
                end
                else
                begin
                        write <= 1'd0;
                end
        end
end

// Read structure.
always @ (posedge (i_hclk && o_hready && i_hready) or negedge i_hreset_n)
begin
        if ( i_hsel && (i_htrans == SEQ || i_htrans == NONSEQ) && !i_hwrite )
        begin
                $display($time, "%m :: Reading data %x from address %x", mem[i_haddr], i_haddr);
                o_hrdata <= mem [i_haddr];
        end 
end

// Second stage.
always @ (posedge (i_hclk && o_hready) or negedge i_hreset_n)
begin
        if ( write ) 
        begin
                $display($time, "%m :: Writing data %x to address %x...", i_hwdata, addr);
                mem [addr] <= i_hwdata; 
        end
end

// HREADY generator.
always @ (negedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
                o_hready <= 1'd0;    
        else
                o_hready <= $random;
end        

endmodule

`endif
// synthesis translate_on
