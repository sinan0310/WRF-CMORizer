#!/bin/bash
#SBATCH --job-name=pCMORizer_runctrl_allVarTypes_singleDomain
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
#SBATCH --threads-per-core=1
#SBATCH --time=08:00:00
#SBATCH --partition=dc-cpu
#SBATCH --mail-type=all
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --account=jjsc39
#SBATCH --disable-turbomode
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#SBATCH --constraint=largedata

# AUTHOR(S): Heimo TRUHETZ (HTr), Uni-Graz/WEGC, heimo.truhetz@uni-graz.at, Klaus GOERGEN (KGo), FZJ/IBG-3, k.goergen@fz-juelich.de
# VERSION: 2023-11-04
# USAGE="export Y=1998 && export DOM=d01 && sbatch --export=ALL,Y=$Y,DOM=$DOM --job-name=pCMORizer$Y$DOM pCMORizer_runctrl_allvars_single_domain.sh"
# PURPOSE: Run-control script for pCMORizer.f90, work on single domain and year, all types of variables at the same time, the harddisk may be free of data once more

source loadenv.JURECA-DC_2023_Intel-PSMPI.ini

set -ex

echo $SLURM_JOB_NAME

let Y=$Y
DOM=$DOM

# ADJUST
identifier="BB" # BB CA DA
#dir_data_in="/p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/simres"
dir_data_in="/p/largedata/jjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/simres"

# ADJUST, this is for cape and cin only, needs to be in line with the runctrl-namelists, different for d01 and d02
#dir_special_var="/p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized/CORDEX-FPSCONV/output/ALP-3/FZJ-IDL/SMHI-EC-EARTH/historical/r12i1p1/FZJ-IDL-WRF381DA/fpsconv-x1n2-v1/1hr"
dir_special_var="/p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_BB/postpro/CMORized/CORDEX-FPSCONV/output/ALP-3/FZJ/ECMWF-ERAINT/evaluation/r1i1p1/FZJ-WRF381BB/fpsconv-x1n2-v1/1hr"
#fn_special_var="_ALP-3_SMHI-EC-EARTH_historical_r12i1p1_FZJ-IDL-WRF381DA_fpsconv-x1n2-v1_1hr_"
fn_special_var="_ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-WRF381BB_fpsconv-x1n2-v1_1hr_"

dir_work=$(pwd)
mkdir -p ${dir_work}/${DOM}/${Y}
cd "${dir_work}/${DOM}/${Y}"

# ADJUST if you want to run the script for a single month, stage only input data of this month this month, see ln -sf below
let M=1
M=$(printf "%02d" $M)
Yn=$(date -u --date="$Y-01-01 1 year" '+%Y')
echo "current year, next year, (current month)" $Y $Yn $M

# ADJUST determine here which files with which pattern you want to link from where; alternative: use the input pathname and the ts te string filename patterns in runctrl.nml; the version here is more straightforward
ln -sf ${dir_data_in}/${DOM}/*/wrfout_${DOM}_${Y}* .
ln -sf ${dir_data_in}/${DOM}/*/wrfxtrm_${DOM}_${Y}* .

# ADJUST depending on the content of the outputs, one more file needs to be linked here in addition in order to being able to calculate the means (-12-31_23:30), here <year+1>-01-01_00:00 is needed
# ADJUST do not use this when just testing for a single month, the tool finds the additional file and does a processing, i.e. creates a new netCDF file and adds the data from the linked file below
#if [ "$Y" != "2005" ]
#then
  ln -sf ${dir_data_in}/${DOM}/*/wrfout_${DOM}_${Yn}0101* .
#fi

# ADJUST depending on the variables, set the nvar and link filenames and adjust the wall clock time
cp -f ../../runctrl.vars.*.nml .

# 4 different exe
cp -f ../../pCMORizer*.exe .
chmod a+x pCMORizer*.exe

# switch logging effectively OFF by redirecting to /dev/zero gains a little executtion speed
log="/dev/zero"

# std sfc
let nvar=39
cp -f ../../runctrl.current.nml_template_${DOM}_${identifier} runctrl.current.nml_${DOM}
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
sleep 2
srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_std_sfc_39vars.exe > $log 2>&1 &
sleep 30

# std presslev
let nvar=36
cp -f ../../runctrl.current.nml_template_${DOM}_${identifier} runctrl.current.nml_${DOM}
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
sleep 2
srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_std_presslev_36vars.exe > $log 2>&1 &
sleep 30

# std minmax
let nvar=2
cp -f ../../runctrl.current.nml_template_${DOM}_${identifier} runctrl.current.nml_${DOM}
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
sleep 2
srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_std_minmax_2vars.exe > $log 2>&1 &
sleep 30

## special serial variant
#let nvar=2
#cp -f ../../runctrl.current.nml_template_${DOM}_${identifier} runctrl.current.nml_${DOM}
#sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
#sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
#ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
#sleep 2
#srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_special_2vars.exe > $log 2>&1 &
#sleep 30

# special accelerated variant, months are processed in parallel
let nvar=2
for MM in `seq -w 1 12`; do
  cd ${dir_work}/${DOM}
  mkdir -p ${Y}_${MM}
  cd ${Y}_${MM}
	DD=`date --date="$Y/$MM/1 + 1 month - 1 day" "+%d"`
  cp -f ../../runctrl.current.nml_template_${DOM}_${identifier} runctrl.current.nml_${DOM}
  # not needed to do the individual aggregation, the filelist determines for the tool what to work on
  # yearly aggregation is still on -> this determines also the type of file which is created
  # not needed to concatenate anything if the timespan is long enough for the initial file to be created  before the next process wants to access
	sed -i "s/aggregation_individually = .F.,/aggregation_individually = .T.,/g" runctrl.current.nml_${DOM}
	sed -i "s/__YYYY__-01-01/$Y-$MM-01/g" runctrl.current.nml_${DOM}
	sed -i "s/__YYYY__-01-02/$Y-$MM-$DD/g" runctrl.current.nml_${DOM}
  sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
  ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
  ln -sf ${dir_data_in}/${DOM}/*/wrfout_${DOM}_${Y}${MM}* .
	cp -f ../../runctrl.vars.special.nml .
  cp -f ../../pCMORizer_special_2vars.exe .
  chmod a+x pCMORizer_special_2vars.exe
  sleep 2
  srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_special_2vars.exe > $log 2>&1 &
  sleep 10
done

wait

# special accelerated variant, months are concatenated
# find . -name "*${Yn}0101*" -delete
# 
declare -a var_arr=("cape" "cin")
for var in "${var_arr[@]}"; do
	cd ${dir_special_var}/${var}
	ncrcat -h ${var}${fn_special_var}${Y}*.nc tmp.nc
	[ $? -ne 0 ] && exit 1
	rm ${var}${fn_special_var}${Y}*.nc
	mv tmp.nc ${var}${fn_special_var}${Y}010100-${Y}123123.nc
done

# if not run as a single run, or as part of the launcher script, one can 
# recursively start the next year
#cd $dir_work
#export Y=${Yn} sbatch --export=ALL,Y=$Y,DOM=$DOM --job-name=pCMORizer$Y$DOM pCMORizer_runctrl_allvars_single_domain.sh
