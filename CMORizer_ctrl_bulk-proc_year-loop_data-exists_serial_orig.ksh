#!/bin/ksh

# 2020-10-23_KGo_k.goergen@fz-juelich.de
# for LATSIS symposium 2019 analysis and poster
# one domain at a time, one year at a time
# this is the first processing step, hourly data, WRF raw -> CMORized
# assume data is available locally as tar archive files, not on tape, beforehand restaged via tar -tvf command (was on tape originally)
# quick and dirty
# check for "adjust" string
# USAGE="source load_env && ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh &"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh > log &"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh > log 2>&1"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh 2>&1 | tee log"

dom="d02" # adjust
PID="2019081301" # adjust

# start from the tools parent directory
dir_tools=$(pwd)

typeset -Z 2 mi

for yi in {2000..2004} # 2000-2014 # adjust
#for yi in 2000 # adjust
do
  print "================================================================================"
  print $HOSTNAME
  print $USER
  date
  print $yi

  # original directory where data should be
  cd /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/simres/${dom} # adjust
  pwd

  for mi in {01..12} # adjust
  do
    print "--------------------------------------------------------------------------------"
    print "unpacking $yi $mi"
    pn_fn_tar="/p/largedata/jjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/simres/${dom}/FPSCPCM_eval_BBv03a_wrf_complete_raw_output_${dom}_${yi}${mi}.tar" # adjust
    print $pn_fn_tar
    time tar --wildcards -xvf $pn_fn_tar *wrfout*.nc # adjust
  done
  ((yi_next=$yi+1))
  if (( yi_next < 2016 ))
  then
    pn_fn_tar_next="/p/largedata/jjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/simres/${dom}/FPSCPCM_eval_BBv03a_wrf_complete_raw_output_${dom}_${yi_next}01.tar" # adjust
    print $pn_fn_tar_next
    time tar --wildcards -xvf $pn_fn_tar_next *wrfout*${yi_next}0101*.nc # adjust
  fi

  print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  print "raw WRF output CMORization: front node serial (access to /p/largedata, /p/scratch, /p/project, /p/fastdata), compute node OpenMP parallel (access to /p/scratch, /p/project, /p/fastdata)"
  print "run per year and domain on front node, serially"
  cd $dir_tools && pwd
  # runctrl files are all adjusted to the filesystem structure and names etc.
  cp -f runctrl.current.nml.ALP3 runctrl.current.nml # adjust
  sed -i -e "s/__YYYY_ts__/${yi}/g" runctrl.current.nml
  sed -i -e "s/__YYYY_te__/${yi}/g" runctrl.current.nml
  # inside CMORizer variable namelists are activated, inside the namelist files different vars are activated
  time ./WRF_CMORizer > /dev/zero #log_CMORizer_${PID}_${dom}_${yi}.txt

  #remove data after end of processing
  rm -v /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/simres/${dom}/*/wrfout*${yi}*nc # adjust

done

exit 0
