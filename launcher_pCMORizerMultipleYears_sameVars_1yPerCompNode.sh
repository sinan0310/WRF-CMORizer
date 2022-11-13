#!/bin/bash

for i in {1996..2005} ; do

  export Y=$i && sbatch --export=ALL,Y=$Y --job-name=pCMORizer$Y pCMORizer_runctrl.sh

done
