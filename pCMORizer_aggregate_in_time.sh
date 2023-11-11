#!/bin/bash

#SBATCH --job-name=pCMORizer_aggregate_in_time
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
#SBATCH --threads-per-core=1
#SBATCH --time=01:00:00
#SBATCH --partition=dc-cpu-devel
#SBATCH --mail-type=all
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --account=jjsc39
#SBATCH --disable-turbomode
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

# AUTHOR(S): Heimo TRUHETZ (HTr), Uni-Graz/WEGC, heimo.truhetz@uni-graz.at
# CONTRIBUTER(S): edits/addons/fixes by Klaus GOERGEN (KGo), FZJ/IBG-3, k.goergen@fz-juelich.de
# VERSION: 2023-11-08
# INVOCATION: "sbatch ./$0"
# PURPOSE: after CMORization of 1hr data, aggregate data in time, tailored to CORDEX-FPSCONV vars, can be easily expanded
# USAGE: no settings elsewhere, just run this code 
# REQUIREMENTS: sh, CDO, NCO

# in line with CMORizer
source loadenv.JURECA-DC_2023_Intel-PSMPI.ini
#source loadenv.JURECA-DC_2023_Intel-PSMPI_forAggregate.ini
#source testenv.ini
CDOBIN=${EBROOTCDO}/bin
NCOBIN=${EBROOTNCO}/bin

# used by HTr, specifically for this tool
#module --force purge
#module use $OTHERSTAGES
#module load Stages/2023
#module load GCC/11.3.0  OpenMPI/4.1.4
#module load CDO/2.1.1
#CDOBIN=${EBROOTCDO}/bin
#NCOBIN=/p/software/jurecadc/stages/2023/software/NCO/5.1.4-npsmpic-2022a/bin

echo $CDOBIN
echo $NCOBIN

#set -ex

dir_src=/p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized/CORDEX-FPSCONV/ # ADJUST!, input and output dir
#dir_src=/p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized_2_was_thought_to_be_OK/CORDEX-FPSCONV/
#dir_src=/p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/WEGC_all_new_final0/CMORized/CORDEX-FPSCONV/
let nproc_max=128 # ADJUST! maximum number of files to be processed in parallel, defaut is 128 on JURECA-DC, set to 1 to run the tool serially -> good to analyse the logs, otherwise all is cluttered due to the parellelism

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
  [[ "$var_name" == "sfcWind" ]] && var_name_target="sfcWindmax"

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

  # processing starts here

  # aggregation
  cdo --no_history -O -L -w -f nc4c -z zip_1 ${cdo_op} ${dir_name}/${f_name} ${dir_target}/${f_target} # orig
  #cdo --no_history -O -L -v -d -f nc4c -z zip_1 ${cdo_op} ${dir_name}/${f_name} ${dir_target}/${f_target} # full verbosity
  #cdo               -O       -f nc4c ${cdo_op} ${dir_name}/${f_name} ${dir_target}/${f_target}
  #cdo --no_history -O -L -w -f nc4 -z zip_1 ${cdo_op} ${dir_name}/${f_name} ${dir_target}/${f_target}
  #cdo --no_history -O -L -v -d -f nc4c  ${cdo_op} ${dir_name}/${f_name} ${dir_target}/${f_target}
  if [[ $? -ne 0 ]] ; then
    echo "ISSUE: ${f_target}, step: cdo aggregation"
    return 1
  fi

  # correct time bounds
  if [[ "$agg_time" == "day" ]]; then 
    ${NCOBIN}/ncap2 -h -O -s 'time_bnds(:,0)=time-0.5 ; time_bnds(:,1)=time+0.5' ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp 
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: ncap2 time bnds"
      return 1
    fi
    mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: mv"
      return 1
    fi
  fi

  # general attribute adjustments
  ${NCOBIN}/ncatted -h -O -a cell_methods,${var_name},o,c,'time: '${op_str} ${dir_target}/${f_target}
  if [[ $? -ne 0 ]] ; then
    echo "ISSUE: ${f_target}, step: ncatted cell_methods"
    return 1
  fi

  if [[ "${var_name}" != ${var_name_target} ]]; then
    ${NCOBIN}/ncrename -h -O -v ${var_name},${var_name_target} ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: ncrename"
      return 1
    fi
  fi

  if [[ "${agg_time}" != "1hr" ]]; then
    ${NCOBIN}/ncatted -h -O -a _CoordinateAxisType,,d,, -a standard_name,rlon,o,c,'grid_longitude' -a standard_name,rlat,o,c,'grid_latitude' -a frequency,global,m,c,${agg_time} ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: ncatted coordinates"
      return 1
    fi
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
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: sfcWindmax name and coords"
      return 1
    fi
    ${NCOBIN}/ncks -h -A -v height ${dir_name}/${f_name} ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: sfcWindmax height"
      return 1
    fi
    ${NCOBIN}/ncwa -h -a height ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: sfcWindmax height2"
      return 1
    fi
    mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
    [[ $? -ne 0 ]] && return 1
    ${NCOBIN}/ncatted -h -O -a cell_methods,height,d,, ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: sfcWindmax height3"
      return 1
    fi
    return 0
  fi
  if [[ "${agg_time}" == "3hr" ]] || [[ "${agg_time}" == "6hr" && "${var_name_target:0:2}" == "zg" ]]; then
    ${NCOBIN}/ncatted -h -O -a coordinates,${var_name_target},o,c,'plev lat lon' ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: 3hr 6 hr zg coords"
      return 1
    fi
    ${NCOBIN}/ncks -h -A -v plev ${dir_name}/${f_name} ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: 3hr 6 hr zg plev1"
      return 1
    fi
    ${NCOBIN}/ncwa -h -a plev ${dir_target}/${f_target} ${dir_target}/${f_target}_tmp
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: 3hr 6 hr zg plev2"
      return 1
    fi
    mv ${dir_target}/${f_target}_tmp ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: 3hr 6 hr zg mv"
      return 1
    fi
    ${NCOBIN}/ncatted -h -O -a cell_methods,plev,d,, ${dir_target}/${f_target}
    if [[ $? -ne 0 ]] ; then
      echo "ISSUE: ${f_target}, step: 3hr 6 hr zg cell methods"
      return 1
    fi
    return 0
  fi

  [[ $? -ne 0 ]] && return 1
  return 0
}

let ii=0


# addon: expand the filelist generation through with grep to loop only over those files which are actually to be processed
# nproc_max check can be avoided / adjusted when using filtered filelist -> know in advance how many files are to be procesed
varlist="sfcWind_|snc_|snd_|mrso_|mrsol_|ps_|psl_|va[0-9]*_|ua[0-9]*_|wa[0-9]*_|hus[0-9]*_|ta[0-9]*_|zg[0-9]*_"
#varlist="sfcWind_|zg[0-9]*_|snc_"
#varlist="sfcWind_"

for f in $(find ${dir_src} -type f -wholename "*1hr/*/*.nc" | sort | grep -E "${varlist}") ; do # default -> work on all vars
#for f in $(find ${dir_src} -type f -wholename "*1hr/*/*.nc" | sort | grep -E "${varlist}" | grep -E "2002") ; do # default -> work on all vars

  # also works:
  #let ii+=1
  #process_file $f 6hr point &
  #process_file $f day mean &
  #process_file $f day maximum &

  ff=$(basename $f)

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
  #if [[ "${ff%%_*}" == *"evspsbl"* ]]; then
  #  echo "evspsbl is being ignored..."
  #fi

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
  # this is needed just here as the loop just works on file by file, 
  # each file (=specific year and variable) is handled seperately
  # inefficient: if 128 are dealt with, then wait until all 128 are done
  # only then proceeed with the next batch
  # as soon as an erorr is found and "return 1" is isseed after each new 
  # file has been ingested, the script is checking for any process lanuched
  # before
  echo ${ii} ${pid[${ii}]} ${f}
  if [ ${ii} -eq ${nproc_max} ]; then
    echo "wait with next batch, all processes occupied"
    date
    for (( jj=1; jj<=${ii}; jj++ )); do
      wait ${pid[${jj}]}
      if [[ $? -ne 0 ]]; then
        echo "WARNING: there was an ERROR with PID ${pid[${jj}]}"
        #exit 1
      fi
    done
    echo "release, continue with processing of subsequent batch"
    date
    let ii=0
  fi

done # filelist loop

# wait until all have finished running
# the wait is essential for the slurm "job step" functionality
# same check as above, for the last set of files
if [[ ${ii} -ne 0 ]]; then
  for (( jj=1; jj<=${ii}; jj++ )); do
    wait ${pid[${jj}]}
    if [[ $? -ne 0 ]]; then
      echo "WARNING: there was an ERROR with PID ${pid[${jj}]}"
      #exit 1
    fi
  done
fi

# just for testing
#rm -rf /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized/CORDEX-FPSCONV/output/ALP-3/FZJ-IDL/SMHI-EC-EARTH/historical/r12i1p1/FZJ-IDL-WRF381DA/fpsconv-x1n2-v1/day
#rm -rf /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized/CORDEX-FPSCONV/output/ALP-3/FZJ-IDL/SMHI-EC-EARTH/historical/r12i1p1/FZJ-IDL-WRF381DA/fpsconv-x1n2-v1/6hr
#rm -rf /p/scratch/cjjsc39/goergen1/sim/tmp_FPSCONV/tmp_DA/postpro/CMORized/CORDEX-FPSCONV/output/ALP-3/FZJ-IDL/SMHI-EC-EARTH/historical/r12i1p1/FZJ-IDL-WRF381DA/fpsconv-x1n2-v1/3hr

[[ $? -ne 0 ]] && exit 1
exit 0
