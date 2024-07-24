#!/bin/bash
#SBATCH --job-name=cmor
#SBATCH --output=cmor%j.out
#SBATCH --error=cmor%j.error
#SBATCH --ntasks=1
#SBATCH --qos=meteo_high
##SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --time=720:00:00
##SBATCH --exclusive
#SBATCH --mem-per-cpu=4G
##SBATCH --mem=60G
##SBATCH --hint=nomultithread
##SBATCH --nodelist=wncompute051
#SBATCH --mail-user=milovacj@unican.es
#SBATCH --partition=wncompute_meteo
##SBATCH --exclude=wncompute051

conda activate  NCLtoPY

export wrkdir=$PWD
export VERSION="v20240715"  #set the version of your postprocessed files (to create output folder)

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <CSV_FILE> <PATH_to_1hr_FILES>"
    exit 1
fi

# File path to the CSV file
CSV_FILE=$wrkdir/$1  	# a csv file containing complete list of variables
DATAPATH=$2 		# example: ./CMORized/FPS-URB-RCC/CMIP6/DD/PARIS-3/UCAN/ERA5/evaluation/r1i1p1f1/WRF451R-COLC/v1/
VARNAME=$3              # not obligatory
FREQ="day"

# If csv file given as 1st argument is a web location, first download the file
if [[ ${CSV_FILE:0:5} == "https" ]]; then
    echo "Downloading the csv file: $1"
    wget $1 -O data_request.csv
    CSV_FILE="data_request.csv"
fi

# Create a subset variable list with corresponig freqencies if 4th argument given
echo "Creating a sub-csv file only listing variables with the corresponding frequencies."
echo $(head -n 1 "$CSV_FILE") > "data_request_${FREQ}.csv"
grep ",${FREQ}," $CSV_FILE >> "data_request_${FREQ}.csv"
CSV_FILE="data_request_${FREQ}.csv"

# Read the header and split into an array of field names
IFS=',' read -r -a headers < <(head -n 1 "$CSV_FILE")
read_template=$(printf ' %s' "${headers[@]}")

# Read variables and frequencies from the given CSV file, skip the header, and send a job per year, domain, variable and frequency
if [ -e "$PWD/daily_variables_not_processed.txt" ]; then rm "$PWD/daily_variables_not_processed.txt"; fi
tail -n +2 "$CSV_FILE" | while IFS=, eval "read "$read_template; do
  if [ $# -eq 3 ]; then
   if [ "$out_name" == "$3" ]; then
    VARIABLE=$out_name
    METHOD=$(grep "time:" <<< "$cell_methods" | awk -F"time: " '{print $2}' | awk '{print $1}')
    if [ "$METHOD" = "maximum" ]; then
      METHOD="max"
    elif [ "$METHOD" = "minimum" ]; then
      METHOD="min"
    fi
    if [ -d "$DATAPATH/1hr/$VARIABLE" ]; then 
      if ls "$DATAPATH/1hr/$VARIABLE/"*/*.nc 1>/dev/null 2>&1; then
        echo "Calculating daily values"
        for file in "$DATAPATH/1hr/$VARIABLE/"*/*.nc; do
          
          # Set the correct name of the file
          FNAME=$(basename `ls $file`)
          FNAME_DAY="${FNAME/_1hr_/_day_}"
          FNAME_DAY="${FNAME_DAY//0000/}"
          
          # Create directory
          OUTDIR=$DATAPATH/day/$VARIABLE/$VERSION/
          mkdir -p $OUTDIR
          cdo day$METHOD $file $OUTDIR/$FNAME_DAY 
                     
          # Fix attributes (remove not needed and update tracking_id)
          ncatted -O -h -a CDI,global,d,, $OUTDIR/$FNAME_DAY
          ncatted -O -h -a history,global,d,, $OUTDIR/$FNAME_DAY
          ncatted -O -h -a CDO,global,d,, $OUTDIR/$FNAME_DAY
          ncatted -O -h -a tracking_id,global,m,c,"hdl:21.14103/`uuidgen`" $OUTDIR/$FNAME_DAY          
        done 
        
      else
        echo "$VARIABLE not processed, no 1hr data available" >> "$PWD/daily_variables_not_processed.txt"
      fi
    else
      echo "$VARIABLE not processed, no 1hr data available" >> "$PWD/daily_variables_not_processed.txt"
    fi
  fi
 fi
done

# Order the list of daily variables that are not processed
if [ -e "$PWD/daily_variables_not_processed.txt" ]; then 
    sort "$PWD/daily_variables_not_processed.txt" | uniq > tmp.txt
    mv tmp.txt "$PWD/daily_variables_not_processed.txt" 
else
    echo "All daily variables correclty postprocessed!"
fi
