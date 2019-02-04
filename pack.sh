#!/bin/bash

tar -cvzf CMORizer.$(date +"%Y%m%d%H%M%S").tgz pack.sh load_env Makefile WRF_CMORizer.f90 *.nml* *sbatch*
