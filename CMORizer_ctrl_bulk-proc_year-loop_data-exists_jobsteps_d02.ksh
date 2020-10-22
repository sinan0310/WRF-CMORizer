#!/bin/ksh

# 2019-11-03_KGo_k.goergen@fz-juelich.de_goergen1

# for LATSIS symposium 2019 analysis and poster, for FPS CP GA 2019 and IPCC AR6 papers
# one domain per control directory, start independently, then: one year at a time, distributed processing streams on different JURECA nodes, wait until all have finished and then move to the next year
# this is the first processing step, hourly data, WRF raw -> CMORized
# assume data is available locally as tar archive files, not on tape, beforehand restaged via tar -tvf command (was on tape originally)

# USAGE="source load_env && ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh &"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh > log &"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh > log 2>&1"
# USAGE="source load_env && nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh 2>&1 | tee log"

# ---- ADJUST HERE -------------------------------------------------------------

dom="d02" # d01 d02
dom_name="ALP3" # EUR15 ALP3
expID="BB" # BB CA
PID="2019091800" # not in use
sbatch_script="JURECA_sbatch_OpenMp_SingleNode_jobsteps_d02.sh"

 dir_tools="/p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/tools/CMORization/ctrl"
#dir_tools="/p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_SMHI-EC-EARTH_historical_r12_FZJ-IBG3-WRF381CA_v00aJuwelsCpuProdAdHocPrjTt19952005/tools/CMORization/ctrl"

 dir_simres="/p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/simres"
#dir_simres="/p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_SMHI-EC-EARTH_historical_r12_FZJ-IBG3-WRF381CA_v00aJuwelsCpuProdAdHocPrjTt19952005/simres"

 year_start=2000 # 2000
 year_stop=2009 # 2014
 year_end=2016 #+2
#year_start=1996 # 1996
#year_stop=2005 # 2005
#year_end=2007 #+2

 fn_pattern0="FPSCPCM_eval_BBv03a_wrf_complete_raw_output"
#fn_pattern0="FPSCPCM_hist_ECEARTH_CAv00a_wrf_complete_raw_output"

# ------------------------------------------------------------------------------

typeset -Z 2 mi

for yi in {$year_start..$year_stop}
do
  print "================================================================================"
  print $HOSTNAME
  print $USER
  print $0
  date
  print $yi

  # original directory where data should be
  cd ${dir_simres}/${dom} # adjust
  pwd

  # tar files handling
  for mi in {01..12}
  do
    print "--------------------------------------------------------------------------------"
    print "unpacking $yi $mi"
    pn_fn_tar="${dir_simres}/${dom}/${fn_pattern0}_${dom}_${yi}${mi}.tar" # adjust
    print $pn_fn_tar
    #time tar --wildcards -xvf $pn_fn_tar *wrfout*.nc # adjust
    time tar --wildcards -xvf $pn_fn_tar *wrfxtrm*.nc # adjust
  done
  #adjust
  #((yi_next=$yi+1))
  #if (( yi_next < $year_end ))
  #then
  #  pn_fn_tar_next="${dir_simres}/${dom}/${fn_pattern0}_${dom}_${yi_next}01.tar" # adjust
  #  print $pn_fn_tar_next
  #  time tar --wildcards -xvf $pn_fn_tar_next *wrfout*${yi_next}0101*.nc # adjust
  #fi

  # runctrl files are all adjusted to the filesystem structure and names etc.
  print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  cd $dir_tools && pwd
  # one year at a time, not moving forward until the year is done
  echo "0" > ../status_${dom}.txt
  cp -f runctrl.current.nml.${expID}.${dom_name} runctrl.current.nml.${dom_name}
  sed -i -e "s/__YYYY_ts__/${yi}/g" runctrl.current.nml.${dom_name}
  #sed -i -e "s/__YYYY_te__/${yi}/g" runctrl.current.nml
  #time ./WRF_CMORizer > /dev/zero #log_CMORizer_${PID}_${dom}_${yi}.txt
  ###echo "running" > status.txt
  # 7x for each variable, wait until all vars have been processed, then move on to next year
  # copied the ref dir by hand beforehand too
  # link set by hand beforehand fot the nml files
  # access the files of one year concurrently > unclear how well this works
  n_var=3
  #for iv in "pr" "tas"
  #for iv in "pr" "prc" "prw" "tas" "ta850" "ta500" "ta200" # Bastin et al. ICRC + paper BB
  #for iv in "wa500" "ua500" "va500" "ua700" "va700" "pr"   "tas" # Sobolowski et al. IPCC AR6 paper CA
  #for iv in "tas" "huss" "ts" "zmla" "uas" "vas" "sfcWind" "ps" "psl"    "prw" "clwvi" "clivi"    "evspsbl" "evspsblpot" "mrros" "mrro"  # runctrl.vars.nml runctrl.vars.nml_water_column runctrl.vars.nml_evp_roff   CA
  #                      "pr"  
  #for iv in "mrso" "clt"      "prc" "mrlsl" "tsl"    "rsds" "rlds" "hfls" "hfss" "rsus" "rlus" "rlut" "rsdt" "rsut" "sund"    "snw" "snc" "snd" "sic" "prsn" "snm"  # runctrl.vars.nml_pr_mrso (mrlsl not OK vertical infos) runctrl.vars.nml_radiation runctrl.vars.nml_snow   CA
  #for iv in "ta200" "hus200" "zg200" "ua200" "va200" "wa200"   "ta500" "hus500" "zg500" "ua500" "va500" "wa500"   "ta700" "hus700" "zg700" "ua700" "va700" "wa700"   "ta850" "hus850" "zg850" "ua850" "va850" "wa850"   "ta925" "hus925" "zg925" "ua925" "va925" "wa925"   "ta1000" "hus1000" "zg1000" "ua1000" "va1000" "wa1000"
  #for iv in          "hus200" "zg200" "ua200" "va200" "wa200"           "hus500" "zg500"                           "ta700" "hus700" "zg700"                 "wa700"           "hus850" "zg850" "ua850" "va850" "wa850"   "ta925" "hus925" "zg925" "ua925" "va925" "wa925"   "ta1000" "hus1000" "zg1000" "ua1000" "va1000" "wa1000"   "sund"
  #for iv in "ps" "va850" "zg500" "huss" "rlds" "rsds" "rsus" "rlus"
  #for iv in "ps" "huss" "rlds" "rsds" "rsus" "rlus"
  for iv in "tasmin" "tasmax" "sfcWindmax"
  do
    print $iv
    mkdir -p ../${dom}_${iv} 
    #cp -f WRF_CMORizer load_env *.mod $sbatch_script ../${dom}_${iv}/.
    cp -f WRF_CMORizer load_env *.mod ../${dom}_${iv}/.
    cd ../${dom}_${iv} && pwd
    ln -f -s ${dir_tools}/nml_${iv} runctrl.vars_misc.nml_link
    ln -f -s ${dir_tools}/runctrl.current.nml.${dom_name} runctrl.current.nml
    #sbatch $sbatch_script
    #sleep 60 #> not all work on the same files from the start
  done

  cd $dir_tools && pwd
  sbatch $sbatch_script

  # each sbatch script adds a number to the status file after sun has run > once 7x1 is in the file the code moves on
  print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  cd $dir_tools && pwd
  counter=0
  while (( $counter < 1 ))
  do
    grep_res=$(paste -s -d+ ../status_${dom}.txt | bc)
    #if (( $grep_res < $n_var ))
    if (( $grep_res < 1 ))
    then
      sleep 30
    elif (( $grep_res == 1 ))
    then
      ((counter+=1))
      print "all vars per year processes, move to next year in loop"
    fi
    print $counter
  done

  # remove data after end of processing
  # adjust
  #rm -v ${dir_simres}/${dom}/*/wrfout*${yi}*nc
  rm -v ${dir_simres}/${dom}/*/wrfxtrm*${yi}*nc

  print "finish with the year loop"

done

exit 0
