#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
#SBATCH --time=01:00:00
#SBATCH --partition=dc-cpu-devel
#SBATCH --mail-type=all
#SBATCH --mail-user=heimo.truhetz@uni-graz.at
#SBATCH --account=jjsc39

# load required modules
module --force purge
module use $OTHERSTAGES
module load Stages/2023
#module load Intel/2022.1.0  ParaStationMPI/5.8.1-1-mt
module load GCC/11.3.0  OpenMPI/4.1.4
module load CDO/2.1.1

NCOBIN=/p/software/jurecadc/stages/2023/software/NCO/5.1.4-npsmpic-2022a/bin

set -x

dir_src=/p/scratch/cjjsc39/jjsc3901/CMOR/CORDEX-FPSCONV/

function process_file () {
	dir_name=`dirname $1`
	f_name=`basename $1`
	agg_time=$2
	op_str=$3

	# cdo operator string
	if [[ "$op_str" == "maximum" ]]; then
	       	op=max
	       	cdo_op=${agg_time}${op}
        fi
	if [[ "$op_str" == "minimum" ]]; then
		op=min
		cdo_op=${agg_time}${op}
	fi
	if [[ "$op_str" == "mean" ]]; then
		cdo_op=${agg_time}"mean"
	fi
	[[ "$agg_time" == "6hr" ]]   && cdo_op="seltimestep,1/10000/6"
	[[ "$agg_time" == "3hr" ]]   && cdo_op="seltimestep,1/10000/3"

	# variable name and new variable name
	var_name=${f_name%%_*}
	var_name_target=${var_name}
	[[ "$agg_time" == "day" ]] && var_name_target=${var_name_target}${op}
	[[ "$var_name" == "cape" ]] && var_name_target="CAPE"
	[[ "$var_name" == "cin" ]] && var_name_target="CIN"


	# new directory and new file name
	dir_target=`echo $dir_name | sed "s#1hr#$agg_time#g" | sed "s#$var_name#$var_name_target#g"`
	f_target=`echo $f_name | sed "s#1hr#$agg_time#g" | sed "s#$var_name#$var_name_target#g"`
	if [[ "$agg_time" == "day" ]]; then
		# change file name to YYYYMMDD
		ts=${f_target##*_} ; ts=${ts%-*} ; ts_target=${ts:0:8}
		te=${f_target##*_} ; te=${te##*-} ; te=${te%.*} ; te_target=${te:0:8}
		f_target=`echo $f_target | sed "s#$ts#$ts_target#g" | sed "s#$te#$te_target#g"`
		if [[ ${var_name} == "snc" ]] || [[ ${var_name} == "snd" || ${var_name} == "mrsol" || ${var_name} == "mrso" ]]; then
			cdo_op="shifttime,+3hour -"${cdo_op}" -seltimestep,1/10000/6"
		else 
			cdo_op="shifttime,+30min -"${cdo_op}
		fi
	fi
	if [[ "$agg_time" == "3hr" ]]; then
		# change file name to YYYYMMDD
		ts=${f_target##*_} ; ts=${ts%-*} ; ts_target=${ts}
		te=${f_target##*_} ; te=${te##*-} ; te=${te%.*} ; te_target=${te:0:8}21
		f_target=`echo $f_target | sed "s#$ts#$ts_target#g" | sed "s#$te#$te_target#g"`
	fi
	if [[ "$agg_time" == "6hr" ]]; then
		# change file name to YYYYMMDD
		ts=${f_target##*_} ; ts=${ts%-*} ; ts_target=${ts}
		te=${f_target##*_} ; te=${te##*-} ; te=${te%.*} ; te_target=${te:0:8}18
		f_target=`echo $f_target | sed "s#$ts#$ts_target#g" | sed "s#$te#$te_target#g"`
	fi
	#if [[ "$agg_time" == "mon" ]]; then
	#	# change file name to YYYYMMDD
	#	ts=${f_target##*_} ; ts=${ts%-*} ; ts_target=${ts:0:6}
	#	te=${f_target##*_	} ; te=${te##*-} ; te=${te%.*} ; te_target=${te:0:6}
	#	f_target=`echo $f_target | sed "s#$ts#$ts_target#g" | sed "s#$te#$te_target#g"`
	#fi

	# action!
	mkdir -p ${dir_target}
	cdo --no_history -O -L -w -f nc4c -z zip_1 ${cdo_op} ${dir_name}/${f_name} ${dir_target}/${f_target}
	[[ $? -ne 0 ]] && return 1
	# correct time bounds
	if [[ "$agg_time" == "day" ]]; then 
		${NCOBIN}/ncap2 -h -O -s 'time_bnds(:,0)=time-0.5 ; time_bnds(:,1)=time+0.5' ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp 
		[[ $? -ne 0 ]] && return 1
		mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
	fi

	${NCOBIN}/ncatted -h -O -a cell_methods,${var_name},o,c,'time: '${op_str} ${dir_target}/${f_target}
	[[ $? -ne 0 ]] && return 1
	if [[ "${var_name}" != ${var_name_target} ]]; then
	       	${NCOBIN}/ncrename -h -O -v ${var_name},${var_name_target} ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
	fi

	if [[ "${agg_time}" != "1hr" ]]; then
	       ${NCOBIN}/ncatted -h -O -a _CoordinateAxisType,,d,, -a standard_name,rlon,o,c,'grid_longitude' -a standard_name,rlat,o,c,'grid_latitude' -a frequency,global,m,c,${agg_time} ${dir_target}/${f_target}
	       [[ $? -ne 0 ]] && return 1
        fi
       
#	[[ "${agg_time}" != "1hr" ]] && ${NCOBIN}/ncks -h -A -v rlat,rlon ${dir_name}/${f_name} ${dir_target}/${f_target}

	if [[ "${var_name_target}" == "tasmax" ]]; then 
		${NCOBIN}/ncatted -h -O -a long_name,${var_name_target},o,c,'Daily Maximum Near-Surface Air Temperature' -a coordinates,${var_name_target},o,c,'height lat lon' ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncks -h -A -v height ${dir_name}/${f_name} ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncwa -h -a height ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp
		[[ $? -ne 0 ]] && return 1
		mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncatted -h -O -a cell_methods,height,d,, ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		return 0
	fi
	if [[ "${var_name_target}" == "tasmin" ]];then 
		${NCOBIN}/ncatted -h -O -a long_name,${var_name_target},o,c,'Daily Minimum Near-Surface Air Temperature' -a coordinates,${var_name_target},o,c,'height lat lon' ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncks -h -A -v height ${dir_name}/${f_name} ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncwa -h -a height ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp
		[[ $? -ne 0 ]] && return 1
		mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncatted -h -O -a cell_methods,height,d,, ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		return 0
	fi
	if [[ "${var_name_target}" == "sfcWindmax" ]];then 
		${NCOBIN}/ncatted -h -O -a long_name,${var_name_target},o,c,'Daily Maximum Near-Surface Wind Speed' -a coordinates,${var_name_target},o,c,'height lat lon' ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncks -h -A -v height ${dir_name}/${f_name} ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncwa -h -a height ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp
		[[ $? -ne 0 ]] && return 1
		mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncatted -h -O -a cell_methods,height,d,, ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		return 0
	fi
	if [[ "${agg_time}" == "3hr" ]] || [[ "${agg_time}" == "6hr" && "${var_name_target:0:2}" == "zg" ]]; then
		${NCOBIN}/ncatted -h -O -a coordinates,${var_name_target},o,c,'plev lat lon' ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncks -h -A -v plev ${dir_name}/${f_name} ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncwa -h -a plev ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp
		[[ $? -ne 0 ]] && return 1
		mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		${NCOBIN}/ncatted -h -O -a cell_methods,plev,d,, ${dir_target}/${f_target}
		[[ $? -ne 0 ]] && return 1
		return 0
	fi

	[[ $? -ne 0 ]] && return 1
	return 0
}


let nproc_max=128 # maximum number of files to be processed in parallel
let ii=0
for f in `find ${dir_src} -type f -wholename "*1hr/*/*.nc"`; do
#for f in `find ${dir_src} -type f -wholename "*1hr/ta925/ta925*.nc"`; do
	#let ii+=1
	#process_file $f 6hr point &
	#process_file $f day mean &
	#process_file $f day maximum &

	ff=`basename $f`

	if [[ "${ff%%_*}" == *"tas"* ]]; then
		let ii+=1
		process_file $f day maximum &
		pid[${ii}]=$!
		if [ ${ii} -eq ${nproc_max} ]; then
    			for (( jj=1; jj<=${ii}; jj++ )); do
      				wait ${pid[${jj}]}
      				[ $? -ne 0 ] &&  echo "ERROR" && exit -1
    			done
    			let ii=0
		fi
		let ii+=1
		process_file $f day minimum &
		pid[${ii}]=$!
	fi
	if [[ "${ff%%_*}" == *"sfcWind"* ]]; then
		let ii+=1
		process_file $f day maximum &
		pid[${ii}]=$!	
	fi
	if [[ "${ff%%_*}" == *"ps"* ]]; then
		let ii+=1
		process_file $f 6hr point &
		pid[${ii}]=$!	
	fi
	if [[ "${ff%%_*}" == *"snc"* ]] || [[ "${ff%%_*}" == *"snd"* ]]; then
		let ii+=1
		process_file $f day mean &
		pid[${ii}]=$!	
	fi
	if [[ "${ff%%_*}" == *"mrso"* ]]; then
		let ii+=1
		process_file $f day mean &
		pid[${ii}]=$!	
	fi

	# ignore evspsbl* fields, because they are empty at the moment - bug in pCMORizer.f90 ?
	if [[ "${ff%%_*}" == *"evspsbl"* ]]; then
		echo "evspsbl is being ignored..."
	fi

	# 3D fields
	if [[ "${ff%%_*}" == *[s,a]"1000"* ]] || [[ "${ff%%_*}" == *[s,a]"925"* ]] || [[ "${ff%%_*}" == *[s,a]"850"* ]] || [[ "${ff%%_*}" == *[s,a]"700"* ]] || [[ "${ff%%_*}" == *[s,a]"500"* ]] || [[ "${ff%%_*}" == *[s,a]"200"* ]] ; then
		let ii+=1
		process_file $f 3hr point &
		pid[${ii}]=$!
	fi
	if [[ "${ff%%_*}" == *"zg"* ]]; then
		let ii+=1
		process_file $f 6hr point &
		pid[${ii}]=$!
	fi

	# special fields
	if [[ "${ff%%_*}" == *"cape"* ]] || [[ "${ff%%_*}" == *"cin"* ]]; then
		let ii+=1
		process_file $f day maximum &
		pid[${ii}]=$!	
	fi

	
	if [ ${ii} -eq ${nproc_max} ]; then
    		for (( jj=1; jj<=${ii}; jj++ )); do
      			wait ${pid[${jj}]}
      			if [[ $? -ne 0 ]]; then
			       echo "ERROR"
			       exit 1
			fi
    		done
    		let ii=0
	fi

done
if [[ ${ii} -ne 0 ]]; then
	for (( jj=1; jj<=${ii}; jj++ )); do
		wait ${pid[${jj}]}
      		if [[ $? -ne 0 ]]; then
			echo "ERROR"
			exit 1
		fi
	done
fi
 
[[ $? -ne 0 ]] && exit 1
exit 0
