#!/bin/csh
# Execute this. Do not source it.
iverilog -f ${AHB_MASTER_HOME}/sources/ahb_master.f -f ${AHB_MASTER_HOME}/bench/ahb_master_test.f -g2012 -Wall -Winfloop -o $AHB_MASTER_SCRATCH_DIR/a.out -DSIM && cd $AHB_MASTER_SCRATCH_DIR && vvp a.out
