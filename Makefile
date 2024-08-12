EBROOTNETCDFMINFORTRAN="full-path-to-netcdf-fortran library"
EBROOTNETCDF="full-path-to-netcdf-c library"

# gfortran flags (uncomment if using gfortran)
#FC = gfortran
#FCFLAGS = -O2 -cpp -DSERIAL
#FCFLAGS += -Wall
#FCFLAGS += -ffree-line-length-none
#FCFLAGS += -Wno-tabs -Wno-unused-variable -Wno-maybe-uninitialized

# intel flags (comment out if not using intel compiler)
FC = ifort 
FCFLAGS = -O2 -assume realloc_lhs -cpp -DSERIAL
FCFLAGS += -fp-model precise -prec-div -prec-sqrt

# Flags for gfortran and intel (never comment out)
FCFLAGS += -I$(EBROOTNETCDFMINFORTRAN)/include -I$(EBROOTNETCDF)/include
LDFLAGS = -L$(EBROOTNETCDFMINFORTRAN)/lib -lnetcdff -L${EBROOTNETCDF}/lib -lnetcdf

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

