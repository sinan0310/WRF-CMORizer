#!/bin/sh

#./auto_launcher_farming.sh 

# at present this ool does not make any sense to be used with the CMORizer
# it needs manually prepared directory structures with inbdividually compiled tool versions

base_dir="/homea/slts/slts00/tools/postpro/WRF_CMORizer/current_dev_from_notebook"

echo "=================================="
date

for i in 1 2 3 4 5 6 ; do

  cd $base_dir
  echo "-------"
  echo $i
  sleep 4

  MachineNr=$(shuf -i 1-12 -n1)
  MachineNr=$(printf %02d $MachineNr)
  echo "jureca${MachineNr}.fz-juelich.de"

  nohup ssh -i ${HOME}/.ssh/sshkey_rsa_slts00_KGo_pwl slts00@jureca${MachineNr}.fz-juelich.de "hostname && cd ${base_dir}/p${i}CM && pwd && source /etc/profile.d/modules.sh && source ../load_env && ./postpro_model_WRF_to_ESGcompliancy > log6 " >> auto_launcher_farming.log &
       #ssh -i ${HOME}/.ssh/sshkey_rsa_slts00_KGo_pwl slts00@jureca${MachineNr}.fz-juelich.de "hostname && cd ${base_dir}/p${i}CM && pwd && source /etc/profile.d/modules.sh && source ../load_env && echo test> log " >> auto_launcher_farming.log &
       #ssh -i ${HOME}/.ssh/sshkey_rsa_slts00_KGo_pwl slts00@jureca${MachineNr}.fz-juelich.de "hostname && cd ${base_dir}/p${i}CM && pwd && echo klaus > log " >> auto_launcher_farming.log &

done

exit 0
