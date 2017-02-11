#!/bin/csh
iverilog -f ${AHB_MASTER_HOME}/sources/ahb_master.f -f ${AHB_MASTER_HOME}/bench/ahb_master_test.f -g2012 -Wall -Winfloop -o $AHB_MASTER_HOME/sim/a.out -DSIM
