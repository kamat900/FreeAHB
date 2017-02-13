# FreeAHB (Experimental)

Author: Revanth Kamaraj (revanth91kamaraj@gmail.com)

This repository currently provides an AHB 2.0 Master.

##Features of the AHB master:

- Bursts are done using a combination of INCR16/INCR8/INCR4 and INCR.
- Supports slaves with SPLIT/RETRY capability.

##To run simulations:

- Source the source_it.csh file in scripts. Set the paths in the script correctly.
- Execute the run_sim.csh file in scripts. A VVP file will be generated in the scratch folder. Execute it.

##NOTE: While the master design is complete, it should be treated as very experimental in its current form.
