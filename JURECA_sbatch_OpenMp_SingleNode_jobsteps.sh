#!/bin/sh

#USAGE="sbatch JURECA_sbatch_OpenMp_SingleNode.sh"                         02:45:00

#SBATCH --job-name="CMORizerD01"
#SBATCH --nodes=1
#SBATCH --ntasks=6
#SBATCH --cpus-per-task=4
#SBATCH --time=00:40:00
#SBATCH --partition=batch
#SBATCH --account=jjsc39
#SBATCH --output=CMORizerOutErr.%j
#SBATCH --error=CMORizerOutErr.%j
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --mail-type=ALL

source $(pwd)/load_env

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
#srun ./WRF_CMORizer > /dev/zero # log.txt 2>&1 # /dev/zero 


for iv in "ps" "huss" "rlds" "rsds" "rsus" "rlus"
do

    cd /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/tools/CMORization/d01_${iv}
    srun --exclusive -n 1 ./WRF_CMORizer > /dev/zero &

done

wait

echo "1" >> /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/tools/CMORization/status_d01.txt
