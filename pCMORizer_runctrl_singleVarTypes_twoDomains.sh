#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
#SBATCH --threads-per-core=1
#SBATCH --time=06:30:00
#SBATCH --partition=dc-cpu
#SBATCH --mail-type=all
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --account=jjsc39
#SBATCH --disable-turbomode
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
####SBATCH --constraint=largedata

# USAGE="export Y=1998 && sbatch --export=ALL,Y=$Y --job-name=pCMORizer$Y pCMORizer_runctrl_singleVarTypes_twoDomains.sh"

source loadenv.JURECA-DC_2023_Intel-PSMPI.ini

echo $SLURM_JOB_NAME

# ADJUST to the number of variables in the namelist, #36 press lev #2 min/max & special #39 std sfc 
let Y=$Y
let nvar=3

dir_work=$(pwd)
mkdir ${dir_work}/${Y}
cd "${dir_work}/${Y}"

cp -f ../runctrl.current.nml_template_d01_DA runctrl.current.nml_d01
cp -f ../runctrl.current.nml_template_d02_DA runctrl.current.nml_d02
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_d01
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_d02
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_d01
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_d02

# ADJUST if you want to run the script for a single month, stage only input data of this month this month, see ln -sf below
let M=1
M=$(printf "%02d" $M)

Yn=$(date -u --date="$Y-01-01 1 year" '+%Y')

echo "current year, next year, (current month)" $Y $Yn $M

# ADJUST determine here which files with which pattern you want to link from where; alternative: use the input pathname and the ts te string filename patterns in runctrl.nml; the version here is more straightforward
#ln -sf ${DATA_jjsc39}/jjsc3900/sim/CORDEX-FPSCONV_EUR-15-ALP-3_SMHI-EC-EARTH_historical_r12_FZJ-IDL-WRF381DA_v00aJurecaDcCpuProdPrjTt19952005/simres/d0{1,2}/*/wrfout_d0?_${Y}* .
ln -sf /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/simres/d0{1,2}/*/wrfout_d0?_${Y}* .
#ln -sf /p/scratch/cjjsc39/jjsc3900/sim/tmp/simres/d0{1,2}/*/wrfout_d0?_${Y}* .
#ln -sf /p/scratch/cjjsc39/jjsc3900/sim/tmp/simres/d0{1,2}/*/wrfout_d0?_${Y}${M}* .
#ln -sf /p/scratch/cjjsc39/jjsc3900/sim/tmp/simres/d0{1,2}/*/wrfxtrm_d0?_${Y}* .
#ln -sf /p/scratch/cjjsc39/jjsc3900/sim/tmp/simres/d0{1,2}/*/wrfxtrm_d0?_${Y}${M}* .

# ADJUST depending on the content of the outputs, one more file needs to be linked here in addition in order to being able to calculate the means (-12-31_23:30), here <year+1>-01-01_00:00 is needed
# ADJUST do not use this when just testing for a single month, the tool finds the additional file and does a processing, i.e. creates a new netCDF file and adds the data from the linked file below
if [ "$Y" != "2005" ]
then
  ln -sf /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/simres/d0{1,2}/*/wrfout_d0?_${Yn}0101* .
fi

# ADJUST depending on the variables, set the nvar and link filenames and adjust the wall clock time
cp -f ../runctrl.vars.std_presslev.nml runctrl.vars.nml
#cp -f ../runctrl.vars.std_sfc.nml runctrl.vars.nml
#cp -f ../runctrl.vars.std_minmax.nml runctrl.vars.nml
#cp -f ../runctrl.vars.special.nml runctrl.vars.nml

cp -f ../pCMORizer .
chmod a+x pCMORizer

# switch logfile OFF by redirecting to /dev/zero gains a little executtion speed
log_d01="/dev/zero"
log_d02="/dev/zero"
#log_d01="log_d01"
#log_d02="log_d02"

ln -sf runctrl.current.nml_d01 runctrl.current.nml
sleep 2
srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer > $log_d01 2>&1 &
sleep 30

ln -sf runctrl.current.nml_d02 runctrl.current.nml
sleep 2
srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer > $log_d02 2>&1 &
sleep 30

wait
