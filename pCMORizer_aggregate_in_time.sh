#!/bin/bash
#SBATCH --job-name=pCMORizer_aggregate_in_time
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
#SBATCH --threads-per-core=1
#SBATCH --time=00:30:00
#SBATCH --partition=dc-cpu
#SBATCH --mail-type=all
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --account=jjsc39
#SBATCH --disable-turbomode
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#SBATCH --export=ALL

# AUTHOR(S): Heimo TRUHETZ (HTr), Uni-Graz/WEGC, heimo.truhetz@uni-graz.at
# CONTRIBUTER(S): edits/addons/fixes by Klaus GOERGEN (KGo), FZJ/IBG-3, k.goergen@fz-juelich.de
# VERSION: 2023-11-04
# USAGE="sbatch ./$0"
# PURPOSE: after CMORization of 1hr data, aggregate data in time, tailored to CORDEX-FPSCONV vars, can be expanded

source loadenv.JURECA-DC_2023_Intel-PSMPI.ini
CDOBIN=${EBROOTCDO}/bin
NCOBIN=${EBROOTNCO}/bin

set -x

dir_src=/p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized_1/CORDEX-FPSCONV/ # ADJUST!
let nproc_max=128 # maximum number of files to be processed in parallel, defaut is 128 on JURECA-DC, set to 1 to run the tool serially -> good to analyse the logs, otherwise all is cluttered due to the parellelism

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

  # sub-daily timestep settings
  if [[ "$agg_time" == "6hr" ]]; then
    cdo_op="seltimestep,1/10000/6"
  fi
  if [[ "$agg_time" == "3hr" ]]; then
    cdo_op="seltimestep,1/10000/3"
  fi

  # variable name and new variable name
  var_name=${f_name%%_*}
  var_name_target=${var_name}
  # this is for tasmin, tasmax, do ot understand how this works for other daily means
  #[[ "$agg_time" == "day" ]] && var_name_target=${var_name_target}${op}
  #this is not needed, although the VL has capital letters, groups and ESGF feature lower case -> more consistent
  #[[ "$var_name" == "cape" ]] && var_name_target="CAPE"
  #[[ "$var_name" == "cin" ]] && var_name_target="CIN"

  # new directory and new file name
  dir_target=`echo $dir_name | sed "s#1hr#$agg_time#g" | sed "s#$var_name#$var_name_target#g"`
  mkdir -p ${dir_target}
  f_target=`echo $f_name | sed "s#1hr#$agg_time#g" | sed "s#$var_name#$var_name_target#g"`

  if [[ "$agg_time" == "day" ]]; then
    # change file name date-time string from YYYYMMDDHH(MM) to YYYYMMDD
    ts=${f_target##*_} ; ts=${ts%-*} ; ts_target=${ts:0:8}
    te=${f_target##*_} ; te=${te##*-} ; te=${te%.*} ; te_target=${te:0:8}
    f_target=`echo $f_target | sed "s#$ts#$ts_target#g" | sed "s#$te#$te_target#g"`
    # todo: double-check this processing
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
  #  # change file name to YYYYMMDD
  #  ts=${f_target##*_} ; ts=${ts%-*} ; ts_target=${ts:0:6}
  #  te=${f_target##*_  } ; te=${te##*-} ; te=${te%.*} ; te_target=${te:0:6}
  #  f_target=`echo $f_target | sed "s#$ts#$ts_target#g" | sed "s#$te#$te_target#g"`
  #fi

  # aggregation
  cdo --no_history -O -L -w -f nc4c -z zip_1 ${cdo_op} ${dir_name}/${f_name} ${dir_target}/${f_target}
  [[ $? -ne 0 ]] && return 1

  # correct time bounds
  if [[ "$agg_time" == "day" ]]; then 
    ${NCOBIN}/ncap2 -h -O -s 'time_bnds(:,0)=time-0.5 ; time_bnds(:,1)=time+0.5' ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp 
    [[ $? -ne 0 ]] && return 1
    mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
    [[ $? -ne 0 ]] && return 1
  fi

  # general attribute adjustments
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
       
  #[[ "${agg_time}" != "1hr" ]] && ${NCOBIN}/ncks -h -A -v rlat,rlon ${dir_name}/${f_name} ${dir_target}/${f_target}

  # specific attribute adjustments
  #if [[ "${var_name_target}" == "tasmax" ]]; then 
  #  ${NCOBIN}/ncatted -h -O -a long_name,${var_name_target},o,c,'Daily Maximum Near-Surface Air Temperature' -a coordinates,${var_name_target},o,c,'height lat lon' ${dir_target}/${f_target}
  #  [[ $? -ne 0 ]] && return 1
  #  ${NCOBIN}/ncks -h -A -v height ${dir_name}/${f_name} ${dir_target}/${f_target}
  #  [[ $? -ne 0 ]] && return 1
  #  ${NCOBIN}/ncwa -h -a height ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp
  #  [[ $? -ne 0 ]] && return 1
  #  mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
  #  [[ $? -ne 0 ]] && return 1
  #  ${NCOBIN}/ncatted -h -O -a cell_methods,height,d,, ${dir_target}/${f_target}
  #  [[ $? -ne 0 ]] && return 1
  #  return 0
  #fi
  #if [[ "${var_name_target}" == "tasmin" ]];then 
  #  ${NCOBIN}/ncatted -h -O -a long_name,${var_name_target},o,c,'Daily Minimum Near-Surface Air Temperature' -a coordinates,${var_name_target},o,c,'height lat lon' ${dir_target}/${f_target}
  #  [[ $? -ne 0 ]] && return 1
  #  ${NCOBIN}/ncks -h -A -v height ${dir_name}/${f_name} ${dir_target}/${f_target}
  #  [[ $? -ne 0 ]] && return 1
  #  ${NCOBIN}/ncwa -h -a height ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp
  #  [[ $? -ne 0 ]] && return 1
  #  mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
  #  [[ $? -ne 0 ]] && return 1
  #  ${NCOBIN}/ncatted -h -O -a cell_methods,height,d,, ${dir_target}/${f_target}
  #  [[ $? -ne 0 ]] && return 1
  #  return 0
  #fi
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

let ii=0

#for f in `find ${dir_src} -type f -wholename "*1hr/*/*.nc" | sort`; do # default -> work on all vars
#for f in `find ${dir_src} -type f -wholename "*1hr/hus700/hus700*.nc" | sort`; do
#for f in `find ${dir_src} -type f -wholename "*1hr/va1000/va1000*.nc" | sort`; do
#for f in `find ${dir_src} -type f -wholename "*1hr/va850/va850*.nc" | sort`; do
#for f in `find ${dir_src} -type f -wholename "*1hr/ta500/ta500*.nc" | sort`; do
for f in `find ${dir_src} -type f -wholename "*1hr/*/mrso*.nc" | sort`; do

  #let ii+=1
  #process_file $f 6hr point &
  #process_file $f day mean &
  #process_file $f day maximum &

  ff=`basename $f`

  echo $f

  # surface fields
  #if [[ "${ff%%_*}" == *"tas"* ]]; then
  #  let ii+=1
  #  process_file $f day maximum &
  #  pid[${ii}]=$!
  #  # unclear start
  #  if [ ${ii} -eq ${nproc_max} ]; then
  #    for (( jj=1; jj<=${ii}; jj++ )); do
  #      wait ${pid[${jj}]}
  #      [ $? -ne 0 ] &&  echo "ERROR" && exit -1
  #    done
  #    let ii=0
  #  fi
  #  # unclear end
  #  let ii+=1
  #  process_file $f day minimum &
  #  pid[${ii}]=$!
  #fi
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
  if [[ "${ff%%_*}" == *"snc"* ]] || [[ "${ff%%_*}" == *"snd"* ]] || [[ "${ff%%_*}" == *"mrso"* ]] || [[ "${ff%%_*}" == *"mrsol"* ]] ; then
    let ii+=1
    process_file $f day mean &
    pid[${ii}]=$!  
  fi

  # ignore evspsbl* fields, because they are empty at the moment, not considered by the var nml of the CMORizer usually, but just in case something slips through, ignore here
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

  # if nproc_max is reached, wait until the process has finished
  # once process has finished successfully go to the next file
  # if any of the processes $! issues an exit code !=0, stop the script
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

done # filelist loop

# wait until all have finished running
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
