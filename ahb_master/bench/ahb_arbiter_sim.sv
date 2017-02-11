////////////////////////////////////////////////
// A simulation model of an AHB arbiter.
// <-------- FOR SIMULATION ONLY. ------------>
////////////////////////////////////////////////

// synthesis translate_off
`ifdef SIM

module ahb_arbiter_sim (

input                   i_hclk,
input                   i_hreset_n,
input  [15:0]           i_hbusreq,      // Master 0 always asserts hbusreq.
input                   i_hready,
input  [1:0]            i_hresp, // Currently unused.
output bit [15:0]       o_hgrant,
output bit [3:0]        o_hmaster

);

always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
        begin
                o_hgrant <= 1'd1; // Master 0 is always granted.
        end
        else if ( i_hbusreq[15:1] )
        begin: blk1
                bit done;
                integer i;

                o_hgrant <= 1'd0;
                done = 0;

                for(i=15;i>=0;i=i-1)
                begin
                        if ( i_hbusreq[i] && !done )
                        begin
                                o_hgrant[i] <= 1'd1;
                                done = 1;
                        end
                end
        end
        else
                o_hgrant <= 1'd1; // Master 0 is granted.
end

always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
                o_hmaster <= 0;
        else if ( i_hready )
        begin: bk2
                integer i;

                for(i=15;i>=0;i=i-1)
                begin
                        if ( o_hgrant[i] == 1'd1 )
                        begin
                                o_hmaster <= i;
                        end
                end
        end
end

endmodule

`endif
// synthesis translate_on
