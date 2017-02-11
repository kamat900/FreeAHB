#!/bin/csh
iverilog -f ${AHB_MASTER_HOME}/ahb_master/sources/ahb_master.f -f ${AHB_MASTER_HOME}/ahb_master/bench/ahb_master_test.f -g2012 -Wall -Winfloop -o $AHB_MASTER_HOME/ahb_master/sim/a.out -DSIM
