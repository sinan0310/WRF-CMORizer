EBROOTNETCDFMINFORTRAN="/gpfs/projects/meteo/opt/spack/opt/spack/linux-almalinux9-zen2/intel-2021.10.0/netcdf-fortran-4.6.1-qkxq3x6syfzslfo24e5wzcgllfrpisum/"
EBROOTNETCDF="/gpfs/projects/meteo/opt/spack/opt/spack/linux-almalinux9-zen2/intel-2021.10.0/netcdf-c-4.9.2-r7sfzbgpbqtqpxlk5l5swrdxoej7mh4c/"
FC = /gpfs/projects/meteo/opt/spack/opt/spack/linux-almalinux9-x86_64/gcc-11.3.1/intel-oneapi-compilers-classic-2021.10.0-d2pr7o6urpbwb2rzhdhuravudmxwbbth/bin/ifort # or gfortran
FCFLAGS = -O2 -assume realloc_lhs -cpp -DSERIAL
FCFLAGS += -fp-model precise -prec-div -prec-sqrt
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
