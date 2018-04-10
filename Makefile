# ==============================================================================
# Name        : Makefile
# Author      : Klaus GOERGEN, k.goergen@fz-juelich.de 
# Version     : See the git log
# License     : MIT, see license.txt
# Description : Makefile for WRF_CMORizer.f90, more compile options in preamble
# ==============================================================================

# JSC/JURECA HPC system (easybuild + modules software environment)
# load environment first; tool is compatible with multiple stages and toolchains
# le17a
#FC = $(EBROOTIFORT)/bin/ifort
#FCFLAGS = -O2
#FCFLAGS += -warn all
#FCFLAGS += -I$(EBROOTNETCDFMINFORTRAN)/include
#LDFLAGS = -L$(EBROOTNETCDFMINFORTRAN)/lib -lnetcdff -lnetcdf

# Ubuntu Desktop, -g or -O2
FC = /usr/bin/gfortran
FCFLAGS = -O2
FCFLAGS += -Wall
FCFLAGS += -ffree-line-length-none
FCFLAGS += -Wno-tabs
FCFLAGS += -I/usr/include
LDFLAGS = -L/usr/lib -lnetcdff -lnetcdf

PROGRAMS = WRF_CMORizer

all: $(PROGRAMS)

%: %.o
	$(FC) $(FCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.f90
	$(FC) $(FCFLAGS) -c $<

.PHONY: clean veryclean

clean:
	rm -f *.o *.mod *.MOD *_genmod.f90 tmpfile* log

veryclean: clean
	rm -rf *~ $(PROGRAMS)
#	rm -rf *~ $(PROGRAMS) /home/kgo/Documents/sandbox/cmorization_testing/CORDEX-FPSCEM-CMWL
