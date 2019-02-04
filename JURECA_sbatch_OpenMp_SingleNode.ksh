#!/bin/ksh

# load le18a before
#USAGE="sbatch <runctl-file>"

#SBATCH --job-name="CMORizer04_1999_Alvaro_openmp_ALP3"
#SBATCH --nodes=1                                                               
#SBATCH --ntasks=1                                                               
#SBATCH --cpus-per-task=24
#SBATCH --time=20:00:00                                                         
#SBATCH --partition=batch
#SBATCH --account=jjsc39
#SBATCH --output=CMORizerCtrlOpenMPOutErr.%j
#SBATCH --error=CMORizerCtrlOpenMPOutErr.%j
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --mail-type=ALL

#source /etc/profile.d/modules.sh
#module --force purge &&
#module use /usr/local/software/jureca/OtherStages
#module load Stages/2017a
#module load Intel/2017.2.174-GCC-5.4.0
#module load ParaStationMPI/5.1.9-1
#module load HDF5/1.8.18
#module load HDF/4.2.12
#module load netCDF/4.4.1.1
#module load netCDF-Fortran/4.4.4

cd /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v02aJurecaCpuSpinUpTt1999/tools/ALP3_openmp

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
srun ./WRF_CMORizer > log2_0 2>&1
#srun ./test_openmp

exit 0
