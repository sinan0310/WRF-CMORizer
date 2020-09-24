#!/bin/sh

#USAGE="sbatch JURECA_sbatch_OpenMp_SingleNode_d02.sh"            05:00:00

#SBATCH --job-name="CMORizerD02mt"
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --time=06:00:00
#SBATCH --partition=batch
#SBATCH --account=jjsc39
#SBATCH --output=CMORizerOutErr.%j
#SBATCH --error=CMORizerOutErr.%j
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --mail-type=ALL

source $(pwd)/load_env

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
srun ./WRF_CMORizer > /dev/zero # log.txt 2>&1 # /dev/zero 

echo "1" >> ../status_d02_mt.txt # whether successful or not, script is moving on
