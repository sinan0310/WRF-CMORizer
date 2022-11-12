#!/bin/bash

for i in {1996..2005} ; do

  export Y=$i && sbatch --export=ALL,Y=$Y --job-name=pCMORizerWRF$Y WRF_CMORizer.sh.lw2

done
