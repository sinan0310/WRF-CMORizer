FC = /oceano/gmeteo/users/milovacj/miniconda3/envs/cmor/bin/mpifort
FCFLAGS = -O2
FCFLAGS += -Wall
FCFLAGS += -ffree-line-length-none
FCFLAGS += -Wno-tabs
FCFLAGS += -I/oceano/gmeteo/users/milovacj/miniconda3/envs/cmor/include
FCFLAGS += -DSERIAL -cpp
LDFLAGS = -L/oceano/gmeteo/users/milovacj/miniconda3/envs/cmor/lib -lnetcdff -lnetcdf

PROGRAMS = pCMORizer

all: $(PROGRAMS)

%: %.o
	$(FC) $(FCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.f90
	$(FC) $(FCFLAGS) -c $<

.PHONY: clean veryclean

clean:
	rm -f *.o *.mod *.MOD *_genmod.f90

veryclean: clean
	rm -rf *~ $(PROGRAMS)
