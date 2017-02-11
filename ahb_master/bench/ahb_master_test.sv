module ahb_master_test;

parameter DATA_WDT = 32;
parameter BEAT_WDT = 32;

        // Clock and reset
        bit                    i_hclk;
        bit                    i_hreset_n;

        // AHB signals. Please see spec for more info.
        logic [31:0]           o_haddr;
        logic [2:0]            o_hburst;
        logic [1:0]            o_htrans;
        logic[DATA_WDT-1:0]    o_hwdata;
        logic                  o_hwrite;
        logic [2:0]            o_hsize;
        bit   [DATA_WDT-1:0]   i_hrdata;
        bit                    i_hready;
        bit   [1:0]            i_hresp;
        bit                    i_hgrant;
        logic                  o_hbusreq;

        // User interface.
        logic                 o_next;   // UI must change only if this is 1.
        bit     [DATA_WDT-1:0]i_data;   // Data to write. Can change during burst if o_next = 1.
        bit                   i_dav;    // Data to write valid. Can change during burst if o_next = 1.
        bit      [31:0]       i_addr;   // Base address of burst.
        bit      [2:0]        i_size;   // Size of transfer. Like hsize.
        bit                   i_wr;     // Write to AHB bus.
        bit                   i_rd;     // Read from AHB bus.
        bit     [BEAT_WDT-1:0]i_min_len;// Minimum guaranteed length of burst.
        bit                   i_cont;   // Current transfer continues previous one.
        logic[DATA_WDT-1:0]   o_data;   // Data got from AHB is presented here.
        logic[31:0]           o_addr;   // Corresponding address is presented here.
        logic                 o_dav;    // Used as o_data valid indicator.

ahb_master #(.DATA_WDT(DATA_WDT), .BEAT_WDT(BEAT_WDT)) DUT (.*); 

always #10 i_hclk++;

always @ (posedge i_hclk)
begin
        if ( o_hbusreq )
                i_hgrant <= 1'd1;
        else
                i_hgrant <= 1'd0;
end

initial
begin
        $dumpfile("ahb_master.vcd");
        $dumpvars;

        i_hresp  <= 0;
        i_hready <= 1;
        i_hgrant <= 1;

        i_hreset_n <= 1'd0;
        d(1);
        i_hreset_n <= 1'd1;

        // We can change inputs.
        i_min_len <= 20;
        i_rd      <= 1'd1;

        wait_for_next;       

        i_cont    <= 1'd1; 

        d(2000);
        $finish;
end

task wait_for_next;
        while(o_next !== 1)
        begin
                d(1);
        end
endtask

task d(int x);
        repeat(x) 
                @(posedge i_hclk);
endtask

endmodule
