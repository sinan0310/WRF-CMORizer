# Postprocessing scripts #

The postprocessing scripts and codes given here enables an efficient postprocessing of WRF raw output data, ensuring that it is correctly formatted and that contains all required variables ([link](https://github.com/impetus4change/T32-CPRCM/tree/0c10961)) for subsequent analyses. 

### Instructions to run the code: ###
1. After cloning the repository, enter the CMORizer folder, and adjust:
    - correct compiler and path to your NetCDF-Fortran folder in [Makefile](https://github.com/impetus4change/wrf/blob/main/CMORizer/Makefile)  
    - characteristics of your domain and global attributes if necesary to fit to your domains in [d01](https://github.com/impetus4change/wrf/blob/main/CMORizer/runctrl.current.nml_template_d01) and [d02](https://github.com/impetus4change/wrf/blob/main/CMORizer/runctrl.current.nml_template_d02) templates
    - paths to the WRF raw output files and geo_em files in [run_CMORizer_in_quasi_parallel.sh](https://github.com/impetus4change/wrf/blob/main/CMORizer/run_CMORizer_in_quasi_parallel.sh)
2. Run the code:
 - To test the code manually for a single variable:
   ```
   ./ run_CMORizer_in_quasi_parallel.sh <YEAR> <DOMAIN> <VARNAME> <FREQUENCY>
   ```
   Accepted formats:
    - YEAR: e.g. '2020'
    - DOMAIN: e.g. 'd01' or 'd02'
    - VARNAME: e.g. 'tas'
    - FREQUENCY: 'fx' '1hr' '3hr' '6hr' 'day'

 - To send the job for e.g. all requested variables in the I4C project use this command:
   ```
   ./loop_variables.sh <VARLIST> <YEAR> <DOMAIN> <FREQUENCY-OPTIONAL>
   ```
   Accepted formats:
    - VARLIST: a download link for a csv file can be given or csv file itself that has to be located in the running directory
    - YEAR: e.g. '2020'
    - DOMAIN: e.g. 'd01' or 'd02'
    - FREQUENCY: 'fx' '1hr' '3hr' '6hr' 'day' - optional argument
    
   This script loops over all variabels in the given csv file, reads required frequency and if the is frequency "day", it sets the FREQ to "1hr". This is done since the main code does not perform the daily aggreagation. For daily aggregation an additional script is created that reads "1hr" postprocessed data. 
   If FREQ argument is given, then the script subsets the csv files and extracts only required frequency from the variables.
   Furthemore, the script trys to detect variables that are missing or cannot be postprocessed, and gives info on nonprocessed variables in a txt output variables_not_processed.txt 
   
3. Run a script for daily aggreagtion:
   ```
   ./aggregate_per_day.sh <VARLIST> <PATH_TO_CMORIZED_DATA>
   ```
   Accepted formats:
    - VARLIST: a download link for a csv file can be given or csv file itself that has to be located in the running directory
    - PATH_TO_CMORIZED_DATA: The full path to the the folder with frequencies - e.g. /$PWD/<project_id>/<mip_era>/<activity_id>/<domain_id>/<institution_id>/<driving_source_id>/<driving_experiment_id>/
<driving_variant_label>/<source_id>/<version_realization>/ 
     
### Detailed description of the files and their usage:  ###

1. [pCMORizer.f90](https://github.com/impetus4change/wrf/blob/main/CMORizer/pCMORizer.f90) is the main Fortran code that reads raw wrfout files, extracts requested variables, and writes and aggregates them in a CF conforming NetCDF file. For the compilation of the code use the [Makefile](https://github.com/impetus4change/wrf/blob/main/CMORizer/Makefile).
2. [CORDEX_CMIP6_variables.csv](https://github.com/impetus4change/wrf/blob/main/CMORizer/CORDEX_CMIP6_variables.csv) lists all necessary variables and metadata required for CORDEX CMIP6 domains, including the corresponding variable names in the WRF model. The metadata is based on the official CORDEX CMIP6 [variable list](https://cordex.org/experiment-guidelines/cordex-cmip6/data-request-cordex-cmip6-rcms/).
3. data-request_*.csv files contain lists of requested variables for different projects. Each project has a separate CSV file:
    - FPS-URBAN-RCC ([data-request_fpsurban.csv](https://github.com/impetus4change/wrf/blob/main/CMORizer/data-request_fpsurban.csv)),
    - FPS-CONV ([data-request_fpsconv.csv](https://github.com/impetus4change/wrf/blob/main/CMORizer/data-request_fpsconv.csv)),
    - I4C ([data-request_i4c.csv](https://github.com/impetus4change/wrf/blob/main/CMORizer/data-request_i4c.csv)),
    - Merged ([data-request_merged.csv](https://github.com/impetus4change/wrf/blob/main/CMORizer/data-request_merged.csv))
4. [LCC_coodinates2geo_em.py](https://github.com/impetus4change/wrf/blob/main/CMORizer/LCC_coodinates2geo_em.py) calculates and ingests x and y coordinates for the Lambert Conformal Conical (LCC) projection, as well as areacella, into the geo_em file. To run it, use the following command:
   ```
   python LCC_coodinates2geo_em.py <geo_em file>
   ```
5. [generate_vars_namelist.py](https://cordex.org/experiment-guidelines/cordex-cmip6/generate_vars_namelist.py) creates a namelist for a desired variable, containing the information necessary for the main code to be executed. To run it, use the following command:.
   ```
   python generate_vars_namelist.py <variable name(s)>
   ```
6. Two templates for the core namelist, runctrl.current.nml, for two domains: [d01](https://github.com/impetus4change/wrf/blob/main/CMORizer/runctrl.current.nml_template_d01) and [d02](https://github.com/impetus4change/wrf/blob/main/CMORizer/runctrl.current.nml_template_d02). The templates provide information on global attributes of the corized file, characteristics of the domain, and the aggregation method to be applied (from date to date, monthly, yearly).
7. [run_CMORizer_in_quasi_parallel.sh](https://github.com/impetus4change/wrf/blob/main/CMORizer/run_CMORizer_in_quasi_parallel.sh) sends a job to a HPC per variable, per year, per domain, and per frequency.
8. [loop_variables.sh](https://github.com/impetus4change/wrf/blob/main/CMORizer/loop_variables.sh) is a small wrapper script that loops over all variables read from a selected CSV table. To run it, use the following command::
   ```
   ./loop_variables.sh <VARLIST> <YEAR> <DOMAIN> <FREQUENCY-OPTIONAL>
   ```
8. [aggregate_per_day.sh](https://github.com/impetus4change/wrf/blob/main/CMORizer/laggregate_per_day.sh) is a script that loops over all variables from the given CSV file with daily frequencies and used cdo and nco tool to obtain daily mean, maximums, or minimums. To run it, use the following command::
   ```
   ./aggregate_per_day.sh <VARLIST> <PATH_TO_CMORIZED_DATA>
   ```
