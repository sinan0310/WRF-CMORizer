#!/bin/bash

#SBATCH --job-name="pCMORizer_check_integrity"
#SBATCH --nodes=1
#SBATCH --ntasks=128
#SBATCH --ntasks-per-node=128
#SBATCH --threads-per-core=1
#SBATCH --time=01:00:00
#SBATCH --disable-turbomode
#SBATCH --output=tmp.pCMORizer_check_integrity.out.%j
#SBATCH --error=tmp.pCMORizer_check_integrity.err.%j
#SBATCH --partition=dc-cpu-devel
#SBATCH --account=jjsc39

# AUTHOR(S): Klaus GOERGEN (KGo), FZJ/IBG-3, k.goergen@fz-juelich.de
# VERSION: 2023-11-11
# INVOCATION EXAMPLE: "sbatch ./$0 /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized/CORDEX-FPSCONV /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized_2_was_thought_to_be_OK/CORDEX-FPSCONV"
# INVOCATION FOR TESTING (see manual adjustments in the code): ./$0 <root_dir_of_CMORized_output>
# PURPOSE: after CMORization check integrity of 1hr output (CMORizer OK?, I/O OK?, filesystem OK?), using ntasks in parallel, load all threads and then wait until current batch hs finished; by reading and checking statistics, check also the internal file structure; do not abort but warn if bad file is encountered
# USAGE: CMORized data root dir as parameter; multiple root dirs are possible; adjust the RegEx in the for loop according to your needs; check the standard out or scheduler output for results; optionally check statistics; manually erase the tmp-dir afterwards
# REQUIREMENTS: sh, CDO, adjust sbatch settings to your environment

source loadenv.JURECA-DC_2023_Intel-PSMPI.ini

inFiles=$@
echo "${inFiles[@]}"
#declare -i MAX_PARALLEL=128
declare -i MAX_PARALLEL=${SLURM_NTASKS}
echo "MAX_PARALLEL: $MAX_PARALLEL"
declare -i tmp_parallel_counter=0
declare -i tmp_file_counter=0

#dirLog=$(pwd)/tmp.pCMORizer_check_integrity.logs.$(date +%Y%m%d%H%M%S)
dirLog=$(pwd)/tmp.${SLURM_JOB_NAME}.logs.${SLURM_JOB_ID}
mkdir -p $dirLog

function calcStats(){
  cdo info $1 > "${dirLog}/$(basename $1).cdo_info_ouput.txt"
  if [[ $? -ne 0 ]] ; then
    echo "WARNING: cdo failed (perhaps corrupted file): $1"
    return 1
  fi
}

date
for inFile in $(find ${inFiles[@]} -type f -wholename "*1hr/*/*.nc" | sort)
#for inFile in $(find ${inFiles[@]} -type f -wholename "*1hr/*/*.nc" | sort | grep -E "rsds_")
#for inFile in $(find ${inFiles[@]} -type f -wholename "*1hr/*/*.nc" | sort | grep -E "2002" | grep -E "rsds_")
do
  echo "DEBUG: inFile ${inFile}"
  calcStats ${inFile} &
  (( tmp_parallel_counter++ ))
  (( tmp_file_counter++ ))
  if [ $tmp_parallel_counter -ge $MAX_PARALLEL ]; then
    wait
    tmp_parallel_counter=0
    date
  fi
done

wait

echo "========================================"
echo "total number of nc files checked = ${tmp_file_counter}"
echo "========================================"
echo "files which have NaN and for how many fields (timesteps):"
for inFile in $dirLog/* ; do 
  n_nan=$(grep -i -c "nan" $inFile)
  if [[ $n_nan -ge 1 ]] ; then
    echo "${inFile}: ${n_nan}"
  fi
done
echo "========================================"
echo "per file indicate where (which timstep) exactly the NaNs occur"
for inFile in $dirLog/* ; do 
  echo "--------------------"
  echo $inFile
  grep -i "nan" $inFile
done

exit 0
