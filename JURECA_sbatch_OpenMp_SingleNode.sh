#!/bin/sh

#USAGE="sbatch <runctl-file>"

#SBATCH --job-name="CMORizer04plusOpenMPfast"
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --time=00:30:00
#SBATCH --partition=devel
#SBATCH --account=jjsc39
#SBATCH --output=CMORizer04plusOpenMPfastOutErr.%j
#SBATCH --error=CMORizer04plusOpenMPfastOutErr.%j
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --mail-type=ALL

cd /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381A0_v04aJurecaCpuSensGeoEmXSoilLuTsInitWlCmX/tools/CMORizer_v04PlusFast_20190708
source $(pwd)/load_env

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
srun ./WRF_CMORizer > log.txt 2>&1
