#!/bin/ksh

# 2019-08-13_KGo_k.goergen@fz-juelich.de
# for LATSIS symposium 2019 analysis and poster
# one domain at a time, one year at a time
# this is the first processing step, hourly data, WRF raw -> CMORized
# assume data is available locally as tar archive files, not on tape, beforehand restaged via tar -tvf command (was on tape originally)
# P-R-O-T-O-T-Y-P-E
# check for "adjust" string
# USAGE="source load_env && ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh &"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh > log &"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh > log 2>&1"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh 2>&1 | tee log"

dom="d01" # adjust d01 d02  !!!!!!!!!!!!!!!!
dom_name="EUR15" # adjust EUR15 ALP3  !!!!!!!!!!!!!!!!
#PID="2019091800"

# start from the tools parent directory, ref dir > ctrl dir
dir_tools=$(pwd)

typeset -Z 2 mi

for yi in {2005..2009} # 2000-2014 # adjust  !!!!!!!!!!!!!!
#for yi in 2000 
do
  print "================================================================================"
  print $HOSTNAME
  print $USER
  date
  print $yi

  # original directory where data should be
  cd /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/simres/${dom} # adjust
  pwd

  for mi in {01..12}
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

  # runctrl files are all adjusted to the filesystem structure and names etc.
  print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  cd $dir_tools && pwd
  # one year at a time, not moving forward until the year is done
  echo "0" > ../status_${dom}.txt
  cp -f runctrl.current.nml.${dom_name} runctrl.current.nml
  sed -i -e "s/__YYYY_ts__/${yi}/g" runctrl.current.nml
  #sed -i -e "s/__YYYY_te__/${yi}/g" runctrl.current.nml
  #time ./WRF_CMORizer > /dev/zero #log_CMORizer_${PID}_${dom}_${yi}.txt
  ###echo "running" > status.txt
  # 7x for each variable, wait until all vars have been processed, then move on to next year
  # copied the ref dir by hand beforehand too
  # link set by hand beforehand fot the nml files
  # access the files of one year concurrently > unclear how well this works
  for iv in "pr" "prc" "prw" "tas" "ta850" "ta500" "ta200"
  do
    print $iv
    mkdir -p ../${dom}_${iv} 
    cp -f runctrl.current.nml WRF_CMORizer load_env *.mod JURECA_sbatch_OpenMp_SingleNode.sh ../${dom}_${iv}/.
    cd ../${dom}_${iv} && pwd
    ln -f -s ${dir_tools}/nml_${iv} runctrl.vars_misc.nml_link
    sbatch JURECA_sbatch_OpenMp_SingleNode.sh
    #sleep 60 #> not all work on the same files from the start
  done

  # each sbatch script adds a number to the status file after sun has run > once 7x1 is in the file the code moves on
  print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  cd $dir_tools && pwd
  counter=0
  while (( $counter < 1 ))
  do
    grep_res=$(paste -s -d+ ../status_${dom}.txt | bc)
    if (( $grep_res < 7 ))
    then
      sleep 30
    elif (( $grep_res == 7 ))
    then
      ((counter+=1))
      print "all vars per year processes, move to next year in loop"
    fi
    print $counter
  done

  #remove data after end of processing
  rm -v /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/simres/${dom}/*/wrfout*${yi}*nc # adjust

done

exit 0
