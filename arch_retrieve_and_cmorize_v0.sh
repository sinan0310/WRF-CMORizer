#!/bin/sh

#USAGE="nohup ./<$0> &" # logging to nohup.out

# 2019-02-04_KGo_k.goergen@fz-juelich.de
# 3 concurrent streams: XXXXXXXXXX manually adjust: this script + nml + sbatch XXXXXXXXXX
# as user knist1, get data from his simulation archive, untar them in $PROJECT of jjsc39 as there is enough space
# then trigger for jjsc39 account the cmorizer, about550-600GB/month 3km data 1h
# good test for final CMORization
# 3 streams at a time for different timeslices
# CMORizer runs on compute node, script stays running/idling on front node > combination
# of computing and data extraction > fastest and easiest way to realize this
# 3 logs: this script > nohup, sbatch, CMORizer > log

echo "================================================================================"
echo $0
echo $USER
hostname
date
echo "================================================================================"

dir_arch="/arch2/slts/slts04/data/ramod_WRF_SLTS/rv036r00_jure_c20_highres_tt1993-2005/simres/d02"
fn_pattern1="wrf_rv036r00_jure_c20_highres_tt1993-2005_simres_d02_"

fn_pattern2=".*.tar" #automatically expands filename

dir_base="/p/project/cjjsc39/jjsc3900/__sandbox__hist"
dir_local="work/jjsc15/jjsc1500/wrf_data/rv036r00_jure_c20_highres_tt1993-2005/simres/d02"

dir_postpro=${dir_base}/postpro && mkdir -p $dir_postpro
#mkdir -p ${dir_base}/killme
dir_tools=${dir_base}/tools

iyear=2005 # manually set
echo $iyear

for imonth in {01,02,03,04,05,06,07,08,09,10,11,12} # manually set
do 

  echo "--------------------------------------------------------------------------------"

  cd $dir_base && pwd
  echo $iyear $imonth
  date
  time tar -xvf ${dir_arch}/${iyear}/${fn_pattern1}${iyear}${imonth}${fn_pattern2} # ls -l takes about 1h
  date

  cd $dir_tools && pwd
  
  cp runctrl.BfG3km_ClimDyn_SKn.nml runctrl.current.nml # manually set
  sed -i -e "s/__YYYY__/${iyear}/g" runctrl.current.nml

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

  date

  mv log.txt log${iyear}${imonth}.txt

  cd ${dir_base}/${dir_local} && pwd
     ls */wrf*${iyear}${imonth}*.nc
  rm -v */wrf*${iyear}${imonth}*.nc # once restaged remains for some time once more on the intermediate disk
  #  mv */wrf*${iyear}${imonth}*.nc ${dir_base}/killme/.

done
