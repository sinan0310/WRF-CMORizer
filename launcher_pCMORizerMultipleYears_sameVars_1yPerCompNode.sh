#!/bin/bash

# start each year on a seperate compute node
for i in {1996..2005} ; do

  # launch d01 and d02 at the same time on same compute node, but only one set of vars -- previous default
  #export Y=$i && sbatch --export=ALL,Y=$Y --job-name=pCMORizer$Y pCMORizer_runctrl_singleVarTypes_two_domains.sh

  # launch d01 and d02 at the same time on different compute nodes and all vars at the same time
  #export Y=$i && export DOM=d01 && sbatch --export=ALL,Y=$Y,DOM=$DOM --job-name=pCMORizer$Y$DOM pCMORizer_runctrl_allvars_single_domain.sh
  export Y=$i && export DOM=d02 && sbatch --export=ALL,Y=$Y,DOM=$DOM --job-name=pCMORizer$Y$DOM pCMORizer_runctrl_allvars_single_domain.sh

done
