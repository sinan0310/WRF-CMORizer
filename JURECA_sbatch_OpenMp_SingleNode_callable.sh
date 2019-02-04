#!/bin/sh

#USAGE="sbatch <runctl-file>"

#SBATCH --job-name="scen2CMORizer04plusOpenMPfast"
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --time=01:30:00
#SBATCH --partition=batch
#SBATCH --account=jjsc39
#SBATCH --output=scen2CMORizer04plusOpenMPfastOutErr.%j
#SBATCH --error=scen2CMORizer04plusOpenMPfastOutErr.%j
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --mail-type=ALL

cd /p/project/cjjsc39/jjsc3900/__sandbox__scen2/tools
source load_env

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
srun ./WRF_CMORizer > log209001.txt 2>&1
