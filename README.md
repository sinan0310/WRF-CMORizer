# RCM Fortran CMORizer WRF

2020-09-26 k.goergen@fz-juelich.de

See the preamble of the main program for complete documentation.

## Purpose

Standard (WRF) RCM raw model output > single-pass flexible, runtime or postprocessing CMORization according to EURO-CORDEX archive protocol > fully CMORized, standard-compliant netCDF data repository ready for ESGF staging

## Test case

Knist et al., Clim Dyn, 2018 WRF data postprocessing
1h, 3km
tas, pr, prw, psl > weather type classification tool HTr
hist+scen1+scen2

## Performance

Optimisation options and their impact on total processing time:

| |xHost  |O3 or  |OpenMP |LogFile|runtime|
| |y/n    |O2     |y/n    |y/n    |[sec]  |
|-|:-----:|:-----:|:-----:|:-----:|:-----:|
|1| x     | x     | x     | x     |       |
|2|       | x     | x     | x     |       |
|3|       |       | x     | x     |       |
|4|       |       |       | x     |       |
|5|       |       |       |       |       |

## Adjust the CMORization engine and start

```shell
   source load_env
   vim Makefile
   make veryclean
   make
   vim runctrl.current.nml.BB.EUR15
   vim CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh
   vim JURECA_sbatch_OpenMp_SingleNode.sh
```

## Running 

Most basic (serial):
```shell
   nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh > log &
```

## If a processing chain needs killing follow this sequence
 
* driver
* tar
* sbatch

## Alternative ways of running CMORizer tool

* Front node / any Linux box: serial, one variable after the other, no run control scripts needed, controlled entirely by large namelists
* On compute node, each variable on a single node, OpenMP-enabled: `CMORizer_ctrl_bulk-proc_year-loop_data-exists(_d02).ksh` + `JURECA_sbatch_OpenMp_SingleNode(_d02).sh`
* On compute node, several serial processing streams sharing a single node: `CMORizer_ctrl_bulk-proc_year-loop_data-exists_jobsteps(_d02).ksh` + `JURECA_sbatch_OpenMp_SingleNode_jobsteps(_d02).sh`
* ...
