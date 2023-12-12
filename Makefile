#FC = mpifort  #ifort if serial
#FCFLAGS = -O2
#FCFLAGS += -Wall
#FCFLAGS += -ffree-line-length-none
#FCFLAGS += -Wno-tabs
#FCFLAGS += -DMPIRUN -cpp #DSERIAL or comment out the line of serial
#FCFLAGS += -I/${NETCDF}/include
#LDFLAGS = -L/${NETCDF}/lib -lnetcdff -lnetcdf


FC = mpiifort  
FCFLAGS = -O2 -assume realloc_lhs
FCFLAGS += -fp-model precise -prec-div -prec-sqrt
FCFLAGS += -DMPIRUN -cpp
FCFLAGS += -I/${NETCDF}/include
LDFLAGS = -L/${NETCDF}/lib -lnetcdff -lnetcdf

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
