2020-09-24 k.goergen@fz-juelich.de

# CMORizer for WRF RCM raw simulation outputs

See the preamble of the main program `WRF_CMORizer.f90` for a complete documentation.

## Concept

Model output exists ideally in tar archives, these are extracted before processing; scalable selective processing running distributed on multiple compute nodes using OpenMP per processing stream with a very low memory footprint.

## Test case

Knist et al., Clim Dyn, 2018 WRF data postprocessing
1h, 3km
tas, pr, prw, psl > weather type classification tool HTr
hist+scen1+scen2

## Performance

|TestNr|xHost |O3    |OpenMP|LogY/N|runtime|
|:----:|:----:|:----:|:----:|:----:|:----: |
| 1    | x    | x    | x    | x    | ?     |
| 2    |      | x    | x    | x    | ?     |
| 3    |      |      | x    | x    | ?     |
| 4    |      |      |      | x    | ?     |
| 5    |      |      |      |      | ?     |

## Ways of running CMORizer tool

Different namelists are needed

* Front node / any Linux box: serial, one variable after the other, no run control scripts needed, controlled entirely by large namelists
* Multiple front nodes, distributed
* Common, see examples below: On compute node, each variable on a single node, OpenMP-enabled (for pressure level data with computation): `CMORizer_ctrl_bulk-proc_year-loop_data-exists(_d02).ksh` + `JURECA_sbatch_OpenMp_SingleNode(_d02).sh`
* Common, see examples below: On compute node, several serial processing streams sharing a single node (for surface variables without much processing): `CMORizer_ctrl_bulk-proc_year-loop_data-exists_jobsteps(_d02).ksh` + `JURECA_sbatch_OpenMp_SingleNode_jobsteps(_d02).sh`
* ...

## Example adjustments of the CMORization engine before starting

```shell
   source load_env
   vim Makefile
   make veryclean
   make
   vim runctrl.current.nml.BB.EUR15
   vim CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh
   vim JURECA_sbatch_OpenMp_SingleNode.sh
```
## Starting

```shell
   nohup ./CMORizer_ctrl_bulk-proc_year-loop_data-exists.ksh > log &
```

## If a processing chain needs killing follow this sequence

* driver script
* untarring of inputs
* sbatch processing scripts
