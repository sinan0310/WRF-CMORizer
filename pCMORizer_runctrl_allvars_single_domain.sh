#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
#SBATCH --threads-per-core=1
###SBATCH --time=12:00:00
#SBATCH --time=00:15:00
#SBATCH --partition=dc-cpu
###SBATCH --partition=dc-cpu-devel
#SBATCH --mail-type=all
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --account=jjsc39
#SBATCH --disable-turbomode
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
###SBATCH --constraint=largedata

# USAGE="export Y=1998 && export DOM=d01 && sbatch --export=ALL,Y=$Y,DOM=$DOM --job-name=pCMORizer$Y$DOM pCMORizer_runctrl_allvars_single_domain.sh"

source loadenv.JURECA-DC_2020_Intel-PSMPI.ini

set -ex

echo $SLURM_JOB_NAME

let Y=$Y
DOM=$DOM

dir_work=$(pwd)
mkdir -p ${dir_work}/${DOM}/${Y}
cd "${dir_work}/${DOM}/${Y}"

# ADJUST if you want to run the script for a single month, stage only input data of this month this month, see ln -sf below
#let M=1
#M=$(printf "%02d" $M)

Yn=$(date -u --date="$Y-01-01 1 year" '+%Y')

#echo "current year, next year, (current month)" $Y $Yn $M
echo "current year, next year" $Y $Yn

# ADJUST determine here which files with which pattern you want to link from where; alternative: use the input pathname and the ts te string filename patterns in runctrl.nml; the version here is more straightforward
#ln -sf /p/largedata/jjsc39/jjsc3900/sim/CORDEX-FPSCONV_EUR-15-ALP-3_SMHI-EC-EARTH_historical_r12_FZJ-IDL-WRF381DA_v00aJurecaDcCpuProdPrjTt19952005/simres/${DOM}/*/wrfout_${DOM}_${Y}* .
#ln -sf /p/largedata/jjsc39/jjsc3900/sim/CORDEX-FPSCONV_EUR-15-ALP-3_SMHI-EC-EARTH_historical_r12_FZJ-IDL-WRF381DA_v00aJurecaDcCpuProdPrjTt19952005/simres/${DOM}/*/wrfxtrm_${DOM}_${Y}* .
ln -sf /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/simres/${DOM}/*/wrfout_${DOM}_${Y}* .
ln -sf /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/simres/${DOM}/*/wrfxtrm_${DOM}_${Y}* .

# ADJUST depending on the content of the outputs, one more file needs to be linked here in addition in order to being able to calculate the means (-12-31_23:30), here <year+1>-01-01_00:00 is needed
# ADJUST do not use this when just testing for a single month, the tool finds the additional file and does a processing, i.e. creates a new netCDF file and adds the data from the linked file below
if [ "$Y" != "2005" ]
then
  #ln -sf /p/largedata/jjsc39/jjsc3900/sim/CORDEX-FPSCONV_EUR-15-ALP-3_SMHI-EC-EARTH_historical_r12_FZJ-IDL-WRF381DA_v00aJurecaDcCpuProdPrjTt19952005/simres/${DOM}/*/wrfout_${DOM}_${Yn}0101* .
  ln -sf /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/simres/${DOM}/*/wrfout_${DOM}_${Yn}0101* .
fi

# ADJUST depending on the variables, set the nvar and link filenames and adjust the wall clock time
cp -f ../../runctrl.vars.*.nml .

# 4 different exe
cp -f ../../pCMORizer . #*.exe .
chmod a+x pCMORizer #_*.exe

# switch logfile OFF by redirecting to /dev/zero gains a little executtion speed
log="/dev/zero"

# std sfc
let nvar=39
cp -f ../../runctrl.current.nml_template_${DOM}_DA runctrl.current.nml_${DOM}
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
sleep 2
#srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_std_sfc_39vars.exe > $log 2>&1 &
srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer > $log 2>&1 &
sleep 30

## std presslev
#let nvar=36
#cp -f ../../runctrl.current.nml_template_${DOM}_DA runctrl.current.nml_${DOM}
#sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
#sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
#ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
#sleep 2
#srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_std_presslev_36vars.exe > $log 2>&1 &
#sleep 30
#
## std minmax
#let nvar=2
#cp -f ../../runctrl.current.nml_template_${DOM}_DA runctrl.current.nml_${DOM}
#sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
#sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
#ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
#sleep 2
#srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_std_minmax_2vars.exe > $log 2>&1 &
#sleep 30
#
## special
#let nvar=2
#cp -f ../../runctrl.current.nml_template_${DOM}_DA runctrl.current.nml_${DOM}
#sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
#sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
#ln -sf runctrl.current.nml_${DOM} runctrl.current.nml
#sleep 2
#srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_special_2vars.exe > $log 2>&1 &
#sleep 30

wait
