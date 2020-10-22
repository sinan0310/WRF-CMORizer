#!/bin/sh

#USAGE="sbatch JURECA_sbatch_OpenMp_SingleNode.sh"

#SBATCH --job-name="CMORizerD01mt"
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --time=03:30:00
##SBATCH --time=00:45:00
#SBATCH --partition=batch
#SBATCH --account=jjsc39
#SBATCH --output=CMORizerOutErr.%j
#SBATCH --error=CMORizerOutErr.%j
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --mail-type=ALL

source $(pwd)/load_env

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
srun ./WRF_CMORizer > /dev/zero
#srun ./WRF_CMORizer > log.txt 2>&1

echo "1" >> ../status_d01_mt.txt # whether successful or not, script is moving on
