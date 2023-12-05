#!/bin/bash
#PBS -N cmorizer
#PBS -l walltime=72:00:00  
#PBS -q himem
#PBS -l nodes=1:ppn=40
#PBS -l mem=10Gb

# AUTHOR(S): Heimo TRUHETZ (HTr), Uni-Graz/WEGC, heimo.truhetz@uni-graz.at, Klaus GOERGEN (KGo), FZJ/IBG-3, k.goergen@fz-juelich.de
# USAGE="export Y=1998 && export DOM=d01 && sbatch --export=ALL,Y=$Y,DOM=$DOM --job-name=pCMORizer$Y$DOM pCMORizer_runctrl_allVarTypes_singleDomain.sh"
# PURPOSE: Run-control script for pCMORizer.f90, work on single domain and year, all types of variables at the same time, the harddisk may be free of data once more
# PURPOSE: Run-control script for pCMORizer.f90, work on single domain and year, all types of variables at the same time, the harddisk may be free of data once more
# ADAPTED VERSION BY Josipa Milovac (milovacj@unican.es), 2023-12-05
# USAGE: ./pCMORizer_runctrl_allVarTypes_singleDomain_UCAN.sh $year $domain 

conda activate cmor

set -ex

echo $PBS_JOBNAME

let Y=$1 	#$Y
DOM=$2 		#$DOM

# ADJUST
identifier="UC" # BB CA DA
dir_data_in="/oceano/gmeteo/users/milovacj/asna/projects/fpssam/03_FPS-SESA-ext-CPM/data/raw/UCAN/raw"

# ADJUST, this is for cape and cin only, needs to be in line with the 
# runctrl-namelists, different for d01 and d02
dir_special_var="/oceano/gmeteo/users/milovacj/asna/projects/fpssam/03_FPS-SESA-ext-CPM/data/raw/UCAN/raw"

# ADJUST, this is for cape and cin only, needs to be in line with the 
# runctrl-namelists, different for d01 and d02
#dir_special_var="/p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized/CORDEX-FPSCONV/output/EUR-15/FZJ-IDL/SMHI-EC-EARTH/historical/r12i1p1/FZJ-IDL-WRF381DA/fpsconv-x0n1-v1/1hr"
#fn_special_var="_EUR-15_SMHI-EC-EARTH_historical_r12i1p1_FZJ-IDL-WRF381DA_fpsconv-x0n1-v1_1hr_"


dir_work="/oceano/gmeteo/users/milovacj/asna/WRF/tools/pCMORizer/" #$(pwd)
mkdir -p ${dir_work}/${DOM}/${Y}
cd "${dir_work}/${DOM}/${Y}"

# ADJUST if you want to run the script for a single month, stage only input data 
# of this month this month, see ln -sf below
let M=1
M=$(printf "%02d" $M)
Yn=$(date -u --date="$Y-01-01 1 year" '+%Y')
echo "current year, next year, (current month)" $Y $Yn $M

# ADJUST determine here which files with which pattern you want to link from 
# where; alternative: use the input pathname and the ts te string filename 
# patterns in runctrl.nml; the version here is more straightforward
ln -sf ${dir_data_in}/${Y}/wrfout_${DOM}_${Y}* .
ln -sf ${dir_data_in}/${Y}/wrfxtrm_${DOM}_${Y}* .
ln -sf ${dir_data_in}/${Y}/wrfpress_${DOM}_${Y}* . # Josipa!

# ADJUST depending on the content of the outputs, one more file needs to be 
# linked here in addition in order to being able to calculate the means 
# (-12-31_23:30), here <year+1>-01-01_00:00 is needed
# ADJUST do not use this when just testing for a single month, the tool finds 
# the additional file and does a processing, i.e. creates a new netCDF file and 
# adds the data from the linked file below
# The the year is not last year of the simulations:
if [ "$Y" != "2021" ] 
then
  ln -sf ${dir_data_in}/${Y}/wrfout_${DOM}_${Yn}-01-01* .
fi

# ADJUST depending on the variables, set the nvar and link filenames and 
# adjust the wall clock time
cp -f ../../runctrl.vars.*.nml .

# 4 different exe
cp -f ../../pCMORizer*.exe .
chmod a+x pCMORizer*.exe

# switch logging effectively OFF by redirecting to /dev/zero gains a little 
# executtion speed
log="/dev/zero"

# array to hold the process IDs, needed to avoid a race condition, where one 
# job stops the others being faster
pid=()
ipid=0

# std sfc
nvar=39
# copying and linking namelists
cp -f ../../runctrl.current.nml_template_${DOM}_${identifier} runctrl.current.nml_${DOM}
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_${DOM}
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_${DOM}
ln -sf runctrl.current.nml_${DOM} runctrl.current.nml

# compiling the code for the specific varlist
cp ../../pCMORizer.f90 ../../Makefile .
make veryclean
make
sleep 2
mv pCMORizer pCMORizer.exe
sleep 2

# running the code
./pCMORizer.exe			# serial run
#srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer.exe > $log 2>&1 &
#mpirun -n 39 ./pCMORizer.exe	# parallel run
#pid[${ipid}]=$!
#let ipid+=1
sleep 30

exit 0
