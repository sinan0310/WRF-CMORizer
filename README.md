2021-05-31 k.goergen@fz-juelich.de

# CMORizer for WRF RCM raw simulation outputs

See the preamble of the main program `WRF_CMORizer.f90` for a complete documentation.

## Concept

Model output exists ideally in tar archives, these are extracted before processing; scalable selective processing running distributed on multiple compute nodes using OpenMP per processing stream with a very low memory footprint.

## Purpose

Standard (WRF) RCM raw model output > single-pass flexible, runtime or postprocessing CMORization according to EURO-CORDEX archive protocol > fully CMORized, standard-compliant netCDF data repository ready for ESGF staging

## Test case

Knist et al., Clim Dyn, 2018 WRF data postprocessing
1h, 3km
tas, pr, prw, psl > weather type classification tool HTr
hist+scen1+scen2

## Performance

Optimisation options and their impact on total processing time:

|Config Nr |xHost y/n |O3 or O2 |OpenMP y/n |LogFile y/n |runtime [sec] |
|----------|:--------:|:-------:|:---------:|:----------:|:------------:|
|1         | y        | 3       | y         | n          |              |
|2         | n        | 3       | y         | n          |              |
|3         | n        | 2       | y         | n          |              |
|4         | n        | 2       | n         | n          |              |
|5         | n        | 2       | n         | n          |              |

## Ways of running CMORizer tool, depending on processing setup, urgency, amount of data, available resources

* The main `runctrl.current.nml` namelist configures the global attributes and defines all dirtectories and the year range.
* Depending on the setup, namelists with many variables which are processed subsequently or with single variables which are processed in parallel, are used.
* The input data is either: a) fresh from model run, b) stored as netCDF files, c) in tar archives on spinning disks (e.g., by retrieving the tar archives form tape beforehand)
* Concurrency: minimum: different model domains; mostly: multiple variables
* Data extraction and handling is needed to reduce storage footprint

Using CMORizer standalone: 

* Front node / any Linux box: serial, one variable after the other, no run control scripts needed, controlled entirely by large namelists (activated in the code), one main standard control nml in the same directory as the CMORizer is controlling it all: which years to work on and which directories to check for inputs

Wrapping the CMORizer in control scripts:

1. Multiple front nodes, distributed, manual setup needed, does not make much sense: `auto_launcher_farming.sh`
2. On (multiple) compute node(s), each variable on a single node, OpenMP-enabled (for pressure level data with computation): `CMORizer_ctrl_bulk-proc_year-loop_data-exists(_d02).ksh` + `JURECA_sbatch_OpenMp_SingleNode(_d02).sh`; incl. data extraction
3. On compute node, several serial processing streams sharing a single node (for surface variables without much processing): `CMORizer_ctrl_bulk-proc_year-loop_data-exists_jobsteps(_d02).ksh` + `JURECA_sbatch_OpenMp_SingleNode_jobsteps(_d02).sh`; incl. data extraction
4. One single compute node, multiple, serial jobs, all manually prepared, no data extraction: `JURECA_sbatch_MultipleSerial_ManuallyPinned.ksh`
5. Original bulk-propcessing script: `CMORizer_ctrl_bulk-proc_year-loop_data-exists_serial_orig.ksh` (-> merged with Nr.2), CMORizer on front node, multiple vars after each other, year-per-year, could also start CMORizer via sbatch script

## Example adjustments of the CMORization engine before starting

```shell
   source load_env_jureca-dc
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

## If a processing chain needs killing, follow this sequence

* `kill -9`: driver script
* `kill -9`: untarring of inputs
* `scancel`: sbatch processing scripts

## Inputs and setup

`geo_em` files are given incl. the boundary relaxation zone
