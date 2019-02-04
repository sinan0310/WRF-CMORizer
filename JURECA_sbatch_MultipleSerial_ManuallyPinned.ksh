#!/bin/ksh

#USAGE="sbatch <runctl-file>"

# 2019-01-26_k.goergen@fz-juelich.de_goergen1_FZJ/IBG-3
# http://www.fz-juelich.de/ias/jsc/EN/Expertise/Supercomputers/JURECA/UserInfo/Binding.html

#SBATCH --job-name="CMORizer04_1999_Alvaro"
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --time=10:00:00
#SBATCH --output=CMORizerCtrlOutErr.%j
#SBATCH --error=CMORizerCtrlOutErr.%j
#SBATCH --mail-user=k.goergen@fz-juelich.de
#SBATCH --mail-type=ALL
#SBATCH --partition=batch
#SBATCH --account=jjsc39

source /etc/profile.d/modules.sh
module --force purge &&
module use /usr/local/software/jureca/OtherStages
module load Stages/2017a
module load Intel/2017.2.174-GCC-5.4.0
module load ParaStationMPI/5.1.9-1
module load HDF5/1.8.18
module load HDF/4.2.12
module load netCDF/4.4.1.1
module load netCDF-Fortran/4.4.4

# 2 serial jobs on one compute node
# ntasks=2
# this is properly pinned, i.e. one core on socket0 and once core on socket1
# checked by htop and logging in onto node during runtime

cd /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v02aJurecaCpuSpinUpTt1999/tools/EUR15
srun -n 1 --cpu_bind=map_cpu:0 ./WRF_CMORizer > log2_0 2>&1 & #0-11, socket 0, phys cores

cd /p/scratch/cjjsc39/jjsc3900/sim/CORDEX-FPSCEM_EUR-15-ALP-3_ECMWF-ERAINT_evaluation_r1i1p1_FZJ-IBG3-WRF381BB_v02aJurecaCpuSpinUpTt1999/tools/ALP3
srun -n 1 --cpu_bind=map_cpu:12 ./WRF_CMORizer > log2_1 2>&1a #12-23, socket 1, phys cores

exit 0
