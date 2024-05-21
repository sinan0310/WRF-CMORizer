FC = mpifort
FCFLAGS_GNU = -ffree-line-length-none -Wall -Wno-tabs
FCFLAGS_INTEL = -assume realloc_lhs -fp-model precise -prec-div -prec-sqrt
FCFLAGS = -O2 -cpp
FCFLAGS += $(FCFLAGS_GNU)
FCFLAGS += -I$(shell nc-config --includedir)
LDFLAGS = -L$(shell nc-config --libs) -lnetcdff -lnetcdf

all: $(PROGRAMS)

serial: FC = gfortran
serial: FCFLAGS += -DSERIAL
serial: all

%: %.o
	$(FC) $(FCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.f90
	$(FC) $(FCFLAGS) -c $<

.PHONY: clean veryclean

clean:
	rm -f *.o *.mod *.MOD *_genmod.f90

veryclean: clean
	rm -rf *~ $(PROGRAMS)
