# ==============================================================================
# Name        : Makefile
# Author      : Klaus Goergen, MIUB/JSC, k.goergen@gmx.net
# Version     : 2013-07-24
# Copyright   : GPLv3
# Description : Makefile for postpro_model_WRF_to_ESGcompliancy.f90
# Source      : http://www.webalice.it/o.drofa/davide/makefile-fortran/
#               makefile-fortran.html
# Alternative : gfortran -I/usr/include t006.f90 -L/usr/lib -lnetcdff -lnetcdf
# Requirements: - NetCDF Fortran90 library, > v4, used: v4.1.1 and v4.2.1.1, all
#                 including HDF5 > write NetCDF v4
#               - F90 compiler, used: gfortran
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

FC = /usr/local/intel/Compiler/11.1/072/bin/intel64/ifort
#FCFLAGS = -g
FCFLAGS = -O3
#FCFLAGS += -std95 -warn all
FCFLAGS += -warn all
#####FCFLAGS += -I/usr/local/netcdf/v4.1.1_classic/include
#####LDFLAGS = -L/usr/local/netcdf/v4.1.1_classic/lib -lnetcdf
FCFLAGS += -I/usr/local/netcdf/v4.2.1.1/include
LDFLAGS = -L/usr/local/netcdf/v4.2.1.1/lib -lnetcdff -lnetcdf

#FC = /usr/bin/gfortran-4.6
#FCFLAGS = -O3
#FCFLAGS += -std=f95 -Wall -pedantic # if this is on, SYSTEM does not work
#FCFLAGS += -I/usr/include
#LDFLAGS = -L/usr/lib -lnetcdff -lnetcdf

PROGRAMS = postpro_model_WRF_to_ESGcompliancy

all: $(PROGRAMS)

%: %.o
	$(FC) $(FCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.f90
	$(FC) $(FCFLAGS) -c $<

.PHONY: clean veryclean

clean:
	rm -f *.o *.mod *.MOD

veryclean: clean
	rm -f *~ $(PROGRAMS)
