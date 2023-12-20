FC = mpifort
FCFLAGS = -O2
FCFLAGS += -Wall
FCFLAGS += -ffree-line-length-none
FCFLAGS += -Wno-tabs
FCFLAGS += -cpp
FCFLAGS += -I$(shell nc-config --includedir)
LDFLAGS = $(shell nc-config --libs) -lnetcdff

PROGRAMS = pCMORizer

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
