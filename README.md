# FreeAHB (Experimental)

Author: Revanth Kamaraj (revanth91kamaraj@gmail.com)

This repository currently provides an AHB 2.0 Master.
Icarus Verilog 10.0 or higher is required to simulate the design.

## Features of the AHB master:

- Bursts are done using a combination of INCR16/INCR8/INCR4 and INCR.
- Supports slaves with SPLIT/RETRY capability.

## To run simulations:

- Source the source\_it.csh file in scripts. Set the paths in the script correctly.
- Execute the run\_sim.csh file in scripts. A VVP file will be generated in the scratch folder. Execute it using vvp.

NOTE: If you define X\_INJECTION, the bench will run with data being made x when invalid (dav=0) to ensure 
a more robust design test (x-injection). If you do not define X\_INJECTION, the bench will make data = 0 
when data valid = 0. It is recommended that you use x injection when testing the design for a more robust
test.

## NOTE: While the master design is complete, it should be treated as very experimental in its current form.
