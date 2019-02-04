See the preamble of the main program for complete documentation.

Development notes:

Optimisation of runtime: SMP (OpenMP), more aggressive compiler options


test case: 
Knist et al., Clim Dyn, 2018 WRF data postprocessing
1h, 3km
tas, pr, prw, psl > weather type classification tool HTr
hist+scen1+scen2

  xHost   O3   OpenMP   LogFile   runtime
1 x       x    x        x
2         x    x        x
3              x        x
4                       x
5
