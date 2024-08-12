#!/bin/bash
################################################################################################################################
# AUTHOR(S): Josipa Milovac, milovacj@unican.es, Instituto de Fisica de Cantabria (IFCA), CSIC-Universidad de Cantabria, Santander, Spain
# PURPOSE: The script reads a csv files with the complete variabels list and sends jobs per variabels per year and per domain
#
# The links to the csv files:
#   1. fps-conv variable list --> https://github.com/impetus4change/T32-CPRCM/raw/main/data-request-fpsconv.csv
#   2. fps-urban-rcc variable list --> https://github.com/impetus4change/T32-CPRCM/raw/main/data-request-fpsurbrcc.csv
#   3. i4c variable list --> https://raw.githubusercontent.com/impetus4change/T32-CPRCM/main/data-request.csv 
#   3. euro-cordex variable list --> to be checked
#
# USAGE: ./loop_pCMORizer_over_all_variables.sh <csv file> <year to postprocess> <domain> <project> <optional: frequency> 
#        If frequecy not given, the script reads corresponding frequencies from the given csv file
# VERSION: 2024-07-15
# REQUIREMENTS: bash
#
# NOTE: Since the main Fortran code cannot process daily output, this script reads info from the given csv file, and then changes
# the frequency to 1hr if the variable in this frequency is not required. For that reason, in the output will be all daily 
# variables available also in 1hr frequency. This is done because the daily files are calculated later using aggregate_per_day.sh
# from these hourly output.
####################################################################################################################################

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <CSV_FILE> <YEAR> <DOMAIN> <PROJECT> [optimal: FREQUENCY]"
    exit 1
fi

# File path to the CSV file
CSV_FILE=$1  	# a csv file containing complete list of variables
YEAR=$2      	# year to postporcess
DOMAIN=$3    	# domain, accepted fromat: d01 or d02
PROJECT=$4      # this chooses the correct template - runctrl.current.nml_template_${PROJECT}
FREQ=$5     	# optimal argument: 1hr, 3hr, 6hr, day acceptable

# If csv file given as 1st argument is a web location, first download the file
if [[ ${CSV_FILE:0:5} == "https" ]]; then
    echo "Downloading the csv file: $1"
    wget $1 -O data_request.csv
    CSV_FILE="data_request.csv"
fi

# Create a subset variable list with corresponig freqencies if 4th argument given
if [[ -n ${FREQ} ]]; then
    echo "Creating a sub-csv file only listing variabels with the corresponding frequencies."
    echo $(head -n 1 "$CSV_FILE") > "data_request_${PROJECT}_${FREQ}.csv"
    grep ",${FREQ}," $CSV_FILE >> "data_request_${PROJECT}_${FREQ}.csv"
    CSV_FILE="data_request_${PROJECT}_${FREQ}.csv"
fi

# Read the header and split into an array of field names
IFS=',' read -r -a headers < <(head -n 1 "$CSV_FILE")
read_template=$(printf ' %s' "${headers[@]}")

# Read variables and frequencies from the given CSV file, skip the header, and send a job per year, domain, variable and frequency
if [ -e "$PWD/variables_not_processed_${PROJECT}.txt" ]; then rm "$PWD/variables_not_processed_${PROJECT}.txt"; fi
tail -n +2 "$CSV_FILE" | while IFS=, eval "read "$read_template; do
    VARIABLE=$out_name
    FREQ=$frequency

    # Check if FREQ is 'day' and if VARIABLE with '1hr' does not exist, set frequency to 1hr
    if [ "$FREQ" == "day" ] && \
       ! grep -q "$VARIABLE,1hr" "$CSV_FILE"; then
       FREQ="1hr"
    fi
    
    # Check if variable can be processed - if available in wrfout or if can be calculated 
    if grep -q "$VARIABLE,-999" CORDEX_CMIP6_variables.csv && ! grep -q $VARIABLE pCMORizer.f90 \
	&& [[ "$VARIABLE" != "ta"* && "$VARIABLE" != "zg"* && "$VARIABLE" != "va"* \
        && "$VARIABLE" != "ua"* && "$VARIABLE" != "wa"* && "$VARIABLE" != "hus"*  ]]; then
        echo "Warning: Variable $VARIABLE not found in Fortran 90 file. Skipping..."
        echo "$VARIABLE" >> "variables_not_processed_${PROJECT}.txt"

    elif ! grep -q $VARIABLE CORDEX_CMIP6_variables.csv; then
        echo "Warning: Variable $VARIABLE not found in Fortran 90 file. Skipping..."
        echo "$VARIABLE" >> "variables_not_processed_${PROJECT}.txt"
    
    # Variables ta50m and hus50 cannot be caluclated, since vertical interpolation of scalar variables is not implemented in the code
    elif [[ $VARIABLE == "ta50m" || $VARIABLE == "hus50m" ]]; then
        echo "$VARIABLE" >> "variables_not_processed_${PROJECT}.txt"

    # Monthly aggregation is not implemnetd in the code
    elif [ $FREQ == "mon" ]; then
        echo "Warning: Frequency $FREQ cannot be processed, skipping..."
   
    else     
        echo "Variable: $VARIABLE, Frequency: $FREQ"
        if [ "$FREQ" != "day" ]; then
          echo "$YEAR $DOMAIN $VARIABLE $EXP"
          # Submitting in PBS
          #qsub -N "$EXP$VARIABLE$FREQ$YEAR" -F "$YEAR $DOMAIN $VARIABLE $PROJECT $FREQ" run_pCMORizer_in_quasi_parallel.sh
          # Submitting in SLURM
          sbatch --job-name="$VARIABLE$FREQ$YEAR" run_pCMORizer_in_quasi_parallel.sh $YEAR $DOMAIN $VARIABLE $PROJECT $FREQ
        fi
    fi
done

# Clean the list of variables that will not be processed
if [ -e "$PWD/variables_not_processed_${PROJECT}.txt" ]; then 
    sort "$PWD/variables_not_processed_${PROJECT}.txt" | uniq > tmp.txt
    mv tmp.txt "$PWD/variables_not_processed_${PROJECT}.txt" 
fi
