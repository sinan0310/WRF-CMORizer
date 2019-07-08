#!/bin/sh

#USAGE="nohup ./<$0> &" # logging to nohup.out

# 2019-03-19_KGo_k.goergen@fz-juelich.de
#
# CMORization starter script for archived model results
#
# adjustment of tools used with the data from sebastian, this time for current
# FPC CMCM data, eval run, needed by Pedro for some ad hoc analysis using new
# diagnostic; problem: data is saved annually, precip data is for the middle of 
# the hour; last timestep is 23:30; simulations are run monthly and and stored 
# monthly; have to get the data from the successive month; these are simulatioed,
# i.e. 00UTC of month+1, day 1 is usually simulated, but not put into the same 
# tar file 
#
# one may have some concurrent months, several years in parallel; CMORizer is 
# either urn on the front node or on the compute node; script may be run 
# concurrently or start a farming process
#
# manually adjust: 1 this script [X] + 2 nml [ ] + 3 sbatch [X]
# CMORizer runs on compute node, script stays running/idling on front node 
# > combination of computing and data extraction > fast and easy
# logs: 1 this script > nohup, 2 sbatch, 3 CMORizer > log
#
# run with the standard directory and archival structure of the WRF sims of KGo

echo "================================================================================"
echo $0
echo $USER
hostname
date
echo "================================================================================"

# manually set
dir_base="/p/scratch/cjjsc39/jjsc3900/sim"
dir_exp="/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014"

dir_arch="${dir_base}${dir_exp}/simres/d02"
fn_pattern1="FPSCPCM_eval_BBv03a_wrf_complete_raw_output_d02_"
fn_pattern2="*.tar"

dir_work="${dir_base}${dir_exp}/tools/cmor0ALP3"

for iyear in {2008,2009}
do
for imonth in {01,02,03,04,05,06,07,08,09,10,11,12}
do 

  echo "--------------------------------------------------------------------------------"

  nyear=$(date -u --date="${iyear}-${imonth}-01 +1 month" '+%Y')                  
  nmonth=$(date -u --date="${iyear}-${imonth}-01 +1 month" '+%m')

  cd $dir_arch && pwd

  echo $iyear $imonth $nyear $nmonth
  
  ctarfile=${fn_pattern1}${iyear}${imonth}${fn_pattern2}
  ntarfile=${fn_pattern1}${nyear}${nmonth}${fn_pattern2}
  nitarfile="${nyear}/wrfout_d02_${nyear}${nmonth}01000000.nc"
  echo $ctarfile 
  echo $ntarfile 
  echo $nitarfile
  date
  time tar -xvf $ctarfile
  time tar -xvf $ntarfile $nitarfile  # this also restages the subsequent monthly tar file which is needed anyway 
  date

  cd $dir_work && pwd
  
  cp runctrl.current.nml.ALP3 runctrl.current.nml  # manually set
  sed -i -e "s/__YYYY_ts__/${iyear}/g" runctrl.current.nml
  sed -i -e "s/__YYYY_te__/${nyear}/g" runctrl.current.nml

  date
  echo "run CMORizer"
  rm log.txt
  touch log.txt
  sbatch JURECA_sbatch_OpenMp_SingleNode_callable.sh
  checkflag=0
  while [ $checkflag -eq 0 ]
  do
    sleep 1m
    date
    grep -iq "CMORizer ran successfully" log.txt
    grep_res=$?
    if [ $grep_res -eq 0 ]
    then
      checkflag=1
    fi
  done
  echo "CMORizer has run, continue now cleaning and starting new month"
  mv log.txt log${iyear}${imonth}.txt
  date

  cd ${dir_arch} && pwd

  ls */wrf*${iyear}${imonth}*.nc
  #mv -vf */wrf*${iyear}${imonth}*.nc /p/scratch/cjjsc39/jjsc3900/sim/killme/. # once restaged tar files remain for some time once more on the intermediate disk, tar file contents are just extracted, tar file itself remains by and large untouched
  rm */wrf*${iyear}${imonth}*.nc

done
done
