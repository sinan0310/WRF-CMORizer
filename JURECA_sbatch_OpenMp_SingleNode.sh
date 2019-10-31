#!/bin/sh

#USAGE="sbatch <runctl-file>"

#SBATCH --job-name="CMORizer"
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --time=02:45:00
#SBATCH --partition=batch
#SBATCH --account=jjsc39
#SBATCH --output=CMORizerOutErr.%j
#SBATCH --error=CMORizerOutErr.%j
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --mail-type=ALL

#cd /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v03aJurecaCpuProdTt20002014/tools/CMORization/d01_I_ref
#source $(pwd)/load_env

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
srun ./WRF_CMORizer > /dev/zero # log.txt 2>&1 # /dev/zero 

echo "1" >> ../status_d01.txt
