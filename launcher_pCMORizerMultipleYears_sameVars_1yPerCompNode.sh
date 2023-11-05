#!/bin/bash

for i in {1996..2005} ; do

  #echo $i
  # classic
  #export Y=$i && sbatch --export=ALL,Y=$Y --job-name=pCMORizer$Y pCMORizer_runctrl.sh
  # launch d01 and d02 at the same time
  #export Y=$i && export DOM=d01 && sbatch --export=ALL,Y=$Y,DOM=$DOM --job-name=pCMORizer$Y$DOM pCMORizer_runctrl_allvars_single_domain.sh
  export Y=$i && export DOM=d02 && sbatch --export=ALL,Y=$Y,DOM=$DOM --job-name=pCMORizer$Y$DOM pCMORizer_runctrl_allvars_single_domain.sh

done
