#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
#SBATCH --time=14:00:00
#SBATCH --partition=dc-cpu
#SBATCH --mail-type=all
#SBATCH --mail-user=heimo.truhetz@uni-graz.at
#SBATCH --account=jjsc39
#SBATCH --disable-turbomode
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#SBATCH --constraint=largedata

# USAGE="export Y=1998 && sbatch --export=ALL,Y=$Y --job-name=pCMORizer$Y pCMORizer_runctrl.sh"

source loadenv.JURECA-DC_2020_Intel-PSMPI.ini

set -x

echo $SLURM_JOB_NAME

let Y=$Y
let nvar=36 #36 press lev #2 min/max & special #39 std sfc # ADJUST to the number of variables in the namelist

dir_work=$(pwd)
mkdir ${dir_work}/${Y}
cd "${dir_work}/${Y}"

cp -f ../runctrl.current.nml_template_d02_DA runctrl.current.nml_d02
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_d02
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_d02

# ADJUST if you want to run the script for a single month, stage only input data of this month this month, see ln -sf below
let M=1
M=$(printf "%02d" $M)

Yn=$(date -u --date="$Y-01-01 1 year" '+%Y')

echo "current year, next year, (current month)" $Y $Yn $M

# ADJUST determine here which files with which pattern you want to link from where; alternative: use the input pathname and the ts te string filename patterns in runctrl.nml; the version here is more straightforward

ln -sf /p/largedata/jjsc39/jjsc3901/results/FPS_WRF381DA_IPSL/wrfout_d02_${Y}* .

#ln -sf /p/scratch/cjjsc39/jjsc3900/sim/tmp/simres/d0{1,2}/*/wrfout_d0?_${Y}${M}* .
#ln -sf /p/scratch/cjjsc39/jjsc3900/sim/tmp/simres/d0{1,2}/*/wrfxtrm_d0?_${Y}* .
#ln -sf /p/scratch/cjjsc39/jjsc3900/sim/tmp/simres/d0{1,2}/*/wrfxtrm_d0?_${Y}${M}* .

# ADJUST depending on the content of the outputs, one more file needs to be linked here in addition in order to being able to calculate the means (-12-31_23:30), here <year+1>-01-01_00:00 is needed
# ADJUST do not use this when just testing for a single month, the tool finds the additional file and does a processing, i.e. creates a new netCDF file and adds the data from the linked file below
#if [ "$Y" != "2005" ]
#then
#  ln -sf /p/scratch/cjjsc39/jjsc3900/sim/tmp/simres/d0{1,2}/*/wrfout_d0?_${Yn}0101* .
#fi

# ADJUST depending on the variables, set the nvar and link filenames and adjust the wall clock time
#cp -f ../runctrl.vars.special.nml runctrl.vars.nml
#cp -f ../runctrl.vars.std_minmax.nml runctrl.vars.nml
cp -f ../runctrl.vars.std_presslev.nml runctrl.vars.nml
#cp -f ../runctrl.vars.std_sfc.nml runctrl.vars.nml

cp -f /p/project/cjjsc39/jjsc3901/src/WRF/pCMORizer-pCMORizer_clean/pCMORizer_${nvar} .
chmod a+x pCMORizer_${nvar}

# switch logfile OFF by redirecting to /dev/zero gains a little executtion speed
log_d01="/dev/zero"
log_d02="/dev/zero"
#log_d01="log_d01"
#log_d02="log_d02"

#ln -sf runctrl.current.nml_d01 runctrl.current.nml
#sleep 2
#srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer > $log_d01 2>&1 &
#sleep 30

let ii=0

ln -sf runctrl.current.nml_d02 runctrl.current.nml
sleep 2
let ii+=1
srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_${nvar} > $log_d02 2>&1 &
pid[${ii}]=$!
sleep 30

# now, start with the surface variables
cd ${dir_work}/${Y}

let nvar=39
cp -f ../runctrl.current.nml_template_d02_DA runctrl.current.nml_d02
sed -i "s/__YYYY__/$Y/g" runctrl.current.nml_d02
sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_d02
cp -f ../runctrl.vars.std_sfc.nml runctrl.vars.nml
cp -f /p/project/cjjsc39/jjsc3901/src/WRF/pCMORizer-pCMORizer_clean/pCMORizer_${nvar} .
chmod a+x pCMORizer_${nvar}

ln -sf runctrl.current.nml_d02 runctrl.current.nml
sleep 2
let ii+=1
srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_${nvar} > $log_d02 2>&1 &
pid[${ii}]=$!
sleep 30

# continue with the special vars
cd ${dir_work}/${Y}

let nvar=2
cp -f ../runctrl.current.nml_template_d02_DA runctrl.current.nml_d02

for MM in `seq -w 1 12`; do

	mkdir $MM
	cd $MM

	# get last day of month
	DD=`date --date="$Y/$MM/1 + 1 month - 1 day" "+%d"`

	cp -f ../../runctrl.current.nml_template_d02_DA runctrl.current.nml_d02
	sed -i "s/aggregation_individually = .F.,/aggregation_individually = .T.,/g" runctrl.current.nml_d02
	sed -i "s/__YYYY__-01-01/$Y-$MM-01/g" runctrl.current.nml_d02
	sed -i "s/__YYYY__-01-02/$Y-$MM-$DD/g" runctrl.current.nml_d02		
	sed -i "s/__nvar__/$nvar/g" runctrl.current.nml_d02
	ln -sf /p/largedata/jjsc39/jjsc3901/results/FPS_WRF381DA_IPSL/wrfout_d02_${Y}-${MM}* .
	cp -f ../../runctrl.vars.special.nml runctrl.vars.nml
	cp -f /p/project/cjjsc39/jjsc3901/src/WRF/pCMORizer-pCMORizer_clean/pCMORizer_${nvar} .
	chmod a+x pCMORizer_${nvar}
	ln -sf runctrl.current.nml_d02 runctrl.current.nml
	sleep 2
	let ii+=1
	srun --exact --cpu-bind=threads --distribution=block:cyclic:fcyclic --ntasks=$nvar ./pCMORizer_${nvar} > $log_d02 2>&1 &
	pid[${ii}]=$!
	sleep 10

	cd ..

done


# up to now, 14 jobs are running in parallel

for (( jj=1; jj<=14; jj++ )); do
	wait ${pid[${jj}]}
	if [[ $? -ne 0 ]]; then
		echo "ERROR in job "${jj} ${pid[${jj}]}
		exit 1
	fi
done

cd ../CORDEX-FPSCONV
find . -name "*${Yn}0101*" -delete

# concatenate monthly files into annual files
module load NCO

declare -a var_arr=("cape" "cin")

for var in "${var_arr[@]}"; do
	cd output/ALP-3/IPSL-WEGC/IPSL-IPSL-CM5A-MR/rcp85/r1i1p1/IPSL-WEGC-WRF381DA/fpsconv-x1n2-v1/1hr/${var}
	ncrcat -h ${var}_ALP-3_IPSL-IPSL-CM5A-MR_rcp85_r1i1p1_IPSL-WEGC-WRF381DA_fpsconv-x1n2-v1_1hr_${Y}*.nc tmp.nc
	[ $? -ne 0 ] && exit 1
	rm ${var}_ALP-3_IPSL-IPSL-CM5A-MR_rcp85_r1i1p1_IPSL-WEGC-WRF381DA_fpsconv-x1n2-v1_1hr_${Y}*.nc
	mv tmp.nc ${var}_ALP-3_IPSL-IPSL-CM5A-MR_rcp85_r1i1p1_IPSL-WEGC-WRF381DA_fpsconv-x1n2-v1_1hr_${Y}010100-${Y}123123.nc

	cd -
done

# start next year

#cd ${dir_work}

#export Y=${Yn} && sbatch --export=ALL,Y=$Y --job-name=pCMORizer$Y pCMORizer_runctrl.sh_allvars



