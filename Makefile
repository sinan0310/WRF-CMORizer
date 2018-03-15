# ==============================================================================
# Name        : Makefile
# Author      : Klaus Goergen, MIUB/JSC, k.goergen@gmx.net
# Version     : 2013-07-24
# Copyright   : GPLv3
# Description : Makefile for postpro_model_WRF_to_ESGcompliancy.f90
# Source      : http://www.webalice.it/o.drofa/davide/makefile-fortran/
#               makefile-fortran.html
# Alternative : gfortran -I/usr/include <prgname>.f90 -L/usr/lib -lnetcdff -lnetcdf
# Requirements: - NetCDF Fortran library, > v4, used: v4.1.1 and v4.2.1.1, all
#                 including HDF5 > write NetCDF v4
#               - F95 compiler, used: gfortran, ifort
#
#
#    Copyright (C) 2013 Klaus GOERGEN
#
#    This file is part of postpro_model_WRF_to_ESGcompliancy.
#
#    postpro_model_WRF_to_ESGcompliancy is free software: you can 
#    redistribute it and/or modify it under the terms of the GNU 
#    General Public License as published by the Free Software 
#    Foundation, either version 3 of the License, or any later 
#    version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# ==============================================================================

# JSC/JURECA HPC system (easybuild + modules software environment)
# load environment first, compatible with multiple stages and toolchains
#FC = $(EBROOTIFORT)/bin/ifort
#FCFLAGS = -O3
#FCFLAGS += -warn all
#FCFLAGS += -I$(EBROOTNETCDFMINFORTRAN)/include
#LDFLAGS = -L$(EBROOTNETCDFMINFORTRAN)/lib -lnetcdff -lnetcdf

# Ubuntu Desktop
FC = /usr/bin/gfortran
FCFLAGS = -O3
FCFLAGS += -Wall
#FCFLAGS += -std=f95
FCFLAGS += -ffree-line-length-none
FCFLAGS += -Wno-tabs
#FCFLAGS += -fall-intrinsics
FCFLAGS += -I/usr/include
LDFLAGS = -L/usr/lib -lnetcdff -lnetcdf

PROGRAMS = postpro_model_WRF_to_ESGcompliancy

all: $(PROGRAMS)

%: %.o
	$(FC) $(FCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.f90
	$(FC) $(FCFLAGS) -c $<

.PHONY: clean veryclean

clean:
	rm -f *.o *.mod *.MOD *_genmod.f90 tmpfile* log

veryclean: clean
	rm -rf *~ $(PROGRAMS) /home/kgo/Documents/sandbox/cmorization_testing/CORDEX
