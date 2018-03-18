!===============================================================================
! BOP
!
! ****************************************************************************
! ***                                                                      ***
! ***      SEE THE LICENSE INFORMATION AT THE END OF THE PREAMBLE          ***
! ***                                                                      ***  
! ***      THIS PREAMBLE IS THE ONLY DOCUMENTATION OF THIS PROGRAM         ***
! ***          BEFORE USING THIS PROGRAM, READ THIS PREAMBLE               ***
! ***                                                                      ***
! ****************************************************************************
!
! NAME:
!   WRF_CMORizer.f90
!
! VERSION:
!   vX.X as of 2018-03-18
!   see git tags and log for revision details, history, and versions
!
! STATUS:
!   under development -- not yet fit for purpose, see below
!
! CURRENT CODE MAINTAINER:
!   - Klaus GOERGEN | k.goergen@fz-juelich.de | KGo | FZJ/IBG-3
!
! FORMER CODE CONTRIBUTERS:
!   - Sebastian KNIST | sebastian.knist@gmx.de | SKn | MIUB
!   - Heimo TRUHETZ | heimo.truhetz@uni-graz.at | HTr | WEGC
!   - Aristotelis LAZARIDIS | lazarida@math.auth.gr | ALa | AUTH
! 
! SUPPORT AND TESTING:
!   - Kirsten WARRACH-SAGI
!   - Eleni KATRAGKOU
!
! PURPOSE / DESCRIPTION:
!   Fortran 95 postprocessing tool to convert raw, standard WRF regional 
!   climate model output (http://www2.mmm.ucar.edu/wrf/users/) to a CORDEX 
!   (http://cordex.org) experiment protocol compliant data set ("CMORization") 
!   (http://cordex.org/experiment-guidelines/experiment-protocol-rcms/) for 
!   exchange via ESGF data nodes (https://www.earthsystemcog.org).
!   The tool implements the CORDEX archive specification Version 3.1, as of 
!   3 March 2014 [1]. The code can easily be adjusted in case specifications 
!   change. The post-processing is necessary in order to being able to upload, 
!   stage and distribute RCM simulation results via the Earth System Grid 
!   infrastructure adopted by CORDEX from CMIP5. Files which do not adhere to 
!   this are rejected. For details of the features implemented for the CORDEX 
!   protocol see [1].
!   Furthermore the tool can be used to systematically reduce model output data
!   volume after a simulation; CMORized data are also used for efficient data
!   exchange between modelling groups as part of joint analysis; makes also a 
!   very good archive format. To reduce storage and archive data volume from
!   WRF simulaitons, the tool is intended to completely replace the raw output,
!   therefore many more than the required variables and diagnostics have been
!   implemented.
!
! MOTIVATION:
!   Developmnet started during Summer 2013 by K. GOERGEN, as it becamse obvious
!   that the combination of shell scripting, cdo and nco made the CMORization
!   of WRF EUR-11 evaluation and projection simulaitons very tedious; it would
!   mean lots of scripting and lots of I/O. The idea of the F95 tool is to be 
!   simple and by doing a single pass, with as few I/O operations as possible
!   and a low memory footprint, produce fully compliant ESGF-ready data.
!   Nearly every dataset in ESGF is in detail somewhat contradicting the spec.
!   also, because the spec. changed over time; with a one-stop tool, e.g. the
!   defintion of attributes etc. is very robust and transparent.
!   
! DISSEMINATION:
!   https://www.github.com/kgoergen
!
! CODING STANDARD / CONVENTIONS:
!   - No systematic standard follows, tries to adhere to
!     * http://fortranwiki.org/fortran/show/Style
!     * http://jules-lsm.github.io/coding_standards/
!   - Tries to be F95 ISO FORTRAN but has "SYSTEM" intrinsic function) 
!   - Also -std=f95 raises errors
!
! PRG.-LANGUAGE / ENVIRONMENT:
!   - >=F95 compiler
!   - Used for development and testing (latest development, should be backward
!     compatible):
!     * gfortran 7.2.0
!     * ifort 17.0.2
!   - Linux/UNIX OS (-> system calls)
!
! REQUIREMENTS:
!   - FORTRAN95 compiler
!   - netCDF F90 library (http://www.unidata.ucar.edu/software/netcdf/)
!     v4.x, used: v4.1.1 and 4.2.1.1 incl. HDF5 -> write netCDF-4 classic model
!     format, incl. compression
!   - make (https://www.gnu.org/software/make/)
!   - date (http://man7.org/linux/man-pages/man1/date.1.html)
!   - uuidgen (http://www.uuidgen.com/)
!
! BUILDING:
!   Two options:
!   a) command line, e.g.:
!        gfortran -I/usr/include <prg>.f90 -L/usr/lib -lnetcdff -lnetcdf
!   b) Makefile (recommended):
!        make
!
! CATEGORY:
!   PostPro.RCM.WRF.
!
! CALLING SEQUENCE EXAMPLES:
!   - ./postpro_model_WRF_to_ESGcompliancy
!   - ./postpro_model_WRF_to_ESGcompliancy > log
!   - ./postpro_model_WRF_to_ESGcompliancy > log 2>&1
!   - ./postpro_model_WRF_to_ESGcompliancy 2>&1 | tee output.log
!   - nohup time <any_command_from_above> &
! 
! GETTING STARTED:
!   1. Read this preamble as a user guide and technical description
!   2. Use a single or a few smaller WRF standard outputs from a single exp.
!   3. Adjust the main central namelist (just setup the input and output dirs.)
!   4. Start by using one variable namelist and specify a single variable: tas 
!
! CALLED FROM:
!   Standalone command-line tool. Can ideally be combined with any processing
!   chain.
!
! LOCAL VARIABLES:
!   See the variable declarations at the beginning of the code.
!
! INPUTS:
!   - NML files, see the tools main directory, have to be adjusted.
!   - WRF static fields (geo_em*)
!   - WRF outputs (wrfout*)
!   - WRF outputs extremes (wrfxtrm*)
!   No optional inputs, no keyword parameters. The tool is controlled by the
!   namelists entirely.
!
! OUTPUTS:
!   - netCDF files according to standard specification.
!   - No Optional outputs, except log file.
!
! FEATURES:
!   - The tool can produce all required variables, i.e. output netCDF files as
!     defined in the CORDEX archive design specifications as available in 2018
!     in possibly one pass based on standard WRF simulation
!     outputs. No additional processing is needed. Also the reuiqred netCDF-4
!     classic data model format is written immediately, no later conversion
!     needed.
!   - 3h/1h data is produced first. This is closest to outputs most groups have
!     anyway. It is possible to produce more 3hr output than needed, i.e. for
!     all variables specified plus more vertical levels. Thereby the tool might
!     also be used for a general data volume reduction after a model run.
!   - The application loops over various averaging intervals, then over
!     variables and then over the existing WRF data files.
!   - Very large WRF outputs and/or even larger model domains than used in
!     CORDEX can be handled as the tool is working on individual output
!     intervals only. The tradeoff is a more I/O overhead but lower RAM
!     requirements.
!   - The FORTRAN code is ISO FORTRAN95-compliant except for the "SYSTEM" calls.
!     Hence the tool should be portable easily.
!   - The tool has minimum requirements in terms of libraries or external tools.
!   - FORTRAN was chosen for its fast execution speed, suitable for the
!     large datasets and the possibility to use the tool in HPC environments as
!     well as on individual workstations with a good performance. Also it is
!     easily possible to parallelize portions of the code via e.g. OpenMP.
!   - By splitting the *vars* namelist, the tool may be run concurrently for
!     different portions of a WRF output dataset.
!   - No code modifications are needed to run the tool and customize it for use
!     with a different WRF experiment. Only the NML files need to be changed.
!   - Different WRF input sources are possible, currently the tool is designed
!     for wrfout and wrfxtrm files.
!   - The tool creates a reference time vector. The time-information contained
!     in each original WRF sim. file is retrieved and according to this
!     information data is sorted into the resulting netCDF files. This makes the
!     the tool rather robust and flexible, a tradeoff is the possibly longer
!     processing time due to the searches needed for the date and time matching.
!     However these searches are on subsets only and therefore fairly efficient.
!     It also means that the WRF outputs may cover any timespan, daily, monthly,
!     or any overlap of months and/or years and that they may come in filelists
!     even not temporally ordered.
!   - The tool is not takling care of the file handling of the wrf files before 
!     or after the processing.
!   - Different ways of temporal aggregation, output storage file structure:
!     (A)
!     With CORDEX archive protocol, at 3hr resolution, data is stored annually; 
!     daily data is stored 5-yearly. A file is automatically created if it does
!     not exist, based on the time information in the raw model output. Then 
!     data is sorted in.
!     (B)
!     If the tool is used for general postprocessing, then sometimes timespans 
!     of less than a year are simulated; for this case timespan in the general
!     namelist maye specified. The overall length of the simulation time-span, 
!     is independent of this.
!     (C)
!     A monthly option, which works like the annual default options has also 
!     been added.
!     With month and annual: the files are generated according to the content of
!     the input data; with individual storage files, the file is generated 
!     according to timespan and all wrf data which does not fit is left out;
!     also with individual the tool is run for one pass only, i.e.multiple wrf 
!     files may be read, but just one output file is generated
!   - An adjustment to other RCMs should be easy as only the variable table has 
!     to be translated to the other model. Anything hardcoded is based on ESGF 
!     variables.
!   - The static fields are treated independently by the tool.
!   - Currently the namelists are split into several parts but they may also 
!     be combined. 
!   - The tool is also intended to reduce WRF model output data volume. This
!     means that original raw model outputs are likely to be erased afterwards.
!     Therefore the tool generates slightly more variables than required by the
!     CORDEX data protocol: e.g. CAPE, ....
!   - To fully understand the structure and possibilities of the code, take a 
!     look at the code itself, it is rich in comments and explanations.
!   - Tries to have minimum hardcoded.
!   - The tool can be scripted and nml files maybe modified using sed, 
!     embedding in workflows possible.
!   - To adjust the tool to a new dataset / experiment, basically only the 
!     runctrl.current.nml namelist has to be adjusted.
!   - The tool is not hardcoded to any specific CORDEX domain, this is
!     determined by the main namelist settings and by the geo_em file, which has
!     to be read.
!
! PROCEDURE:
!   The tool may be called as part of a processing chain. It is meant as an all-
!   in-one tool. It basically reads data, controlled by a namelist, checks the
!   dates in the input file, starts looping over the input file, one variable or
!   diagnostic at a time, checks whether th storage file exists, and if not 
!   creates the storage file based on the data reference syntax and all. No 
!   ancilliary files except the basic namelists are needed, no libraries except 
!   netCDF. No fancy compiler functionalities are used. The tool always checks 
!   the model data time information and sorts in the data based on a reference
!   time vector. It handles a timestep at a time, to keep memory footprint very 
!   low. The namelists determine whether the variables are to be prepared for a 
!   certain resolution or averaged or regridded, based on the protocol variable
!   lists. They also contain the standard names. Namelists may be modified by
!   adding or removing vars, but thir processing may also be just switched off.
!   Originally all was meant to go into a single monolithic namelist, then it
!   was decided to split the namelists according to variable groups. 
!
!   The looping structure is as follows:
!
!   ifrq (loop over temporal output and aggregation frequencies) 
!     ivarnml (namelists with different variable combinations)
!       ivar (variables from the namelists)
!         ifl (all files in the search path)
!           it (all timesteps per file)
!             **processing**
!
!   WRF standard output means: Data as written based on a standard unmodified 
!   registry. The tool works on one experiment at a time (e.g. 'CORDEX'), and on
!   one resolution at a time (e.g. EUR-11). There is no relationship between 
!   different domains or experiments during processing.
!
!   If the storage file is created but the input data does not cover the 
!   complete file, once the first data have been written, the unlimited 
!   dimension is expanded and the empty fields / timesteps are filled with 
!   missing values. Due to the way the tool sorts in data, e.g., when working
!   in auto-mode, i.e. creating annual files for tier-2 storage, it will always
!   create as many files as needed according to the time information in the WRF
!   outputs. Fields can be sorted in as they appear. No matter whether it is in 
!   the middle of the storage file or at the very beginning, in chronoilogicl 
!   order.
!
!   To be resource efficient and fast, the tool tries to check whether a 
!   certain operation is nedded or not, like whether it is on a second pass 
!   through a file or variable, then ther eis no need to setup the time vecs 
!   etc. again. Though temporally very fine-grained, this improves efficieny.
!
!   This is pure research code, there is literally no error trapping.
!
!   There is one master namelist, which contains information on the experiment
!   this one is usually modified if and linked to runctrl.current.nml. The other
!   namelists are usually kept as is.
!
!   The tier-2 processing is usually done first, i.e. the highest resolution
!   data, 1h or 3h, e.g.; all tier-1 or core vars are derived by averaging from
!   this tier-2 dataset.
!
!   In the variable namelists, there is not distinction between height and plev;
!   the pressure levels can also be entered into the height field. During 
!   runtime there is a distinction: everything > 10 is considered a pressure 
!   level.
!
! RESTRICTIONS:
!   - No side effects.
!   - If the WRF output filenames are non-standard, the file list pattern 
!     matching may have to be adjusted
!   - Hardcoded time vector name 'Times', etc. so some work to adjust for other
!     RCMs. Some rae places where stuff is hardcoded.
!   - The highest temporal resolution possible is 1h at the moment, because of 
!     how the time matching is coded. Higher is possible.
!   - A maximum of 13 variables per namlist is currently hardcoded. Could be 
!     expanded, there is not limit.
!   - Currently only one input root directory is possible. If data is stored at
!     different locations, symbolic links might have to be done beforehand.
!   - With files with an individually created time-coverage (non standard) only 
!     one pass is possible, i.e. the file is created covering a certain timespan
!     and data from the netCDF files in the filelist are transferred according 
!     to the variable namelist.
!   - If a storage file exists and wrf data for a date/time is read a second 
!     time the data already stored will be overwritten; there is no warning;
!     in case the input data is from same original WRF output file, there is no 
!     damage done except for lost efficiency; if for some reason the data 
!     handling is messed up and the data is from a different experiment, the
!     stored data is corrupted.
!   - With many variables not transferred from reading to processing within the
!     data_in array, there is an inflation of the RAM used with further vars 
!     processed as they are not deallocated again after usage... nearly a bug.
!
! BUGS:
!   - In case of average variables, like pr, for the very last timestep in an 
!     storage file, there is one timestep too much. like 00:30, when then 
!     timespan ends at 00:00, no fields are written in there. Usually an issue
!     at the very end of the simulaiton timespan.
!   - When calculating the average time vec: e.g. 05:29:60 is shown with ncdump,
!     should be 05:30:00, even with double precision calc no chance. cdo is OK,
!     ncview too. Seems more a ncdump issue. Others have this issue too.
!   - In the Makefile, there is a 'veryclean' option: remove that, it is killing 
!     the data also. In there for testing.
!   - Filename: timespan information: point data, tier-2, e.g. 2100123123;
!     average data: 2101010100, end of the time_bnds block, if 23:30 is midpoint
!     time.
!   - Precipitation does not include graupel etc., just rainnc and rainc.
!
!   NEWLY INTRODUCED OR DISCOVERED / URGENT
!   - Refilling does not work anymore..., something is broken... !!!!!!!!!!
!
! TODO / PLANNED EXTENSIONS
! **see "TODO" and "CHECK" markers in the code**
!   - Add levels: plev, plev_bnds > half done
!   - Use of wrfxtrm, wrfpress aside from wrfout > easy, just add more filelists
!     control variable is contained in the nml files already
!   - Aside from mean, also have min/max
!   - Static fields processing, fx > seperate namelist
!   - Cover ALL REQUIRED variables/diagnostics + ADDITIONAL -> extensions nml
!   - Temporal aggregations, i.e. 6hr, day, mon, seas > controlled by nml and 
!     realized within loops
!   - Spatial averaging -> EUR-11i grid...
!   - Run output via the compliancy checker
!   - Registation of naming schemes with CORDEX (institude_id, model_id)
!   - Add CMIP "realm" as new attribute -> important for TerrSysMP
!   - (OpenMP parallelism for the processing section), via pre-processor flags
!   - (Parallel netCDF I/O where possible), via pre-processor flags > using all
!     compressed netCDF, no most likely not even possible
!   - ((Adjust to other model system)) > TerrSysMP
!
! QUESTIONS:
!   - -/-
!
! ONGOING DEVELOPMENTS (March 2018):
!   - Currently merging forks from different contributors, complete check of the
!     code, fix multiple functionalities not in line with the overall concept
!   - Despite on an internal gitlab nothing was merged, no work form others 
!     considered: take the latest heads from various git branches and merge old-
!     school locally without git
!   - Walk through the code, contnuously building and checking using gfortran
!   - Mid March 2018:
!     * [X] master totally out of date > Knist+Truhetz+Kartsios worked from here
!           most versions were running, but not ideal, just doing a fraction
!     * [X] start with Knist version as new base, know this version most
!     * [X] Truhetz merge file 1, start
!     * [X] fix (!) and check overall, document, and implement the flexible time 
!           span for the storage file > have some proper output which can be 
!           viewed with ncview also
!     * [X] fix preamble
!     * [X] check w/ FPS new nomenclature, also my runs...
!     * [X] check w/ protocol: definition + ESGF archive + CD convention
!     * [X] check the ESGF UCAN and CSC for reasonable additional global vars
!     * [ ] variable inventory, what is needed? ICTP + CORDEX + FPS
!     * [ ] Truhetz merge file 1, cont., u + v on mass grid!!!
!     * [ ] Truhetz merge file 2
!     * [ ] process data for the ICTP paper
!   - Later:
!     * [ ] Aris, temporal averaging merge
!     * [ ] adjustment for different RCMs < see CCLM code from Heimo 
!           (not yet included in merge file 1 or 2)
!     * [ ] register new institute ID and model name with O.B. Christensen at 
!           DMI.
!
! DOUBLE-CHECKING OF FUNCTIONALITY (March 2018):
! * tier-2 (1hr, 3hr): tas, pr
! * Testing: 2018-03-17: 
!   - time vec correct
!   - creation of files correct
!   - sorting in perfect (cdo, ncdump, ncview...)
!   - compression OK, format OK
!   - alternative timespans work
!
! MODIFICATION / REVISION HISTORY:
!   See either git log for details.
!
! CALLED PROCEDURES:
!   System calls: uuidgen, date, mkdir
!
! RELATED TOOLS:
!   - Lluis FITA-BORELL, WRF in-situ plugin module to write CMORized output
!   - Jesus FERNANDEZ, Python
!   - cdo
!   - NCL
!   - CMOR
!   Often do not do everything required. Too complicated to use. Cannot be used
!   on large existing datasets. Sometimes do not scale with very large model 
!   domains as they may treat too many time steps at a time. Development started
!   earlier in mid 2013.
!
! ACKNOWLEDGEMENTS:
!   Thanks from K.GOERGEN as the originator of the tool goes to all who willing-
!   ly helped to further develop and improve the code, namely, Sebastian, Heimo,
!   and Aris.
!   Thanks for testing goes to: Kirsten WARRACH-SAGI from University of Hohen-
!   heim, Germany, and Eleni KATRAGKOU.
!
! PERFORMANCE:
!   Single core, Linux workstation, O3 optimisation.
!   Runtimes:
!   - EUR-44: 1min/yr > 3hr/150yr OR 1h/1yr65vars... + averaging, after each run
!
! REFERENCES:
! [1] http://cordex.dmi.dk/joomla/images/CORDEX/cordex_archive_
!     specifications.pdf
! [2] https://www.hymex.org/cordexfps-convection/wiki/doku.php?id=protocol
! [3] https://www.unidata.ucar.edu/software/netcdf/conventions.html
! ...
!
! LICENSE / COPYING:
!
! ******************************************************************************
!
! MIT License
!
! Copyright (c) 2018 Klaus GOERGEN, Sebastian KNIST, Heimo TRUHETZ, 
!                    Aristotelis LAZARIDIS
!
! Permission is hereby granted, free of charge, to any person obtaining a copy
! of this software and associated documentation files (the "Software"), to deal
! in the Software without restriction, including without limitation the rights
! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
! copies of the Software, and to permit persons to whom the Software is
! furnished to do so, subject to the following conditions:
!
! The above copyright notice and this permission notice shall be included in all
! copies or substantial portions of the Software.
!
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
! SOFTWARE.
!
! ******************************************************************************
!
! For explanation see also
! https://choosealicense.com/, https://opensource.org/licenses/MIT
!
! EOP
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
! passing allocatable arrays between main program and external subroutine

MODULE FilelistHandling

  IMPLICIT NONE
  SAVE

  CHARACTER (len = 200):: tmpfileFL
  CHARACTER (len = 200), DIMENSION(:), ALLOCATABLE :: fl_wrfout
  CHARACTER (len = 200), DIMENSION(:), ALLOCATABLE :: fl_wrfxtr
  INTEGER :: ft

END MODULE FilelistHandling

!-------------------------------------------------------------------------------
! index, Y, M, D, H, depending on the "frequency" of the dataset, i.e. time
! intervals

MODULE RefTimeVecs

  IMPLICIT NONE
  SAVE

  REAL(KIND=8), DIMENSION(:,:), ALLOCATABLE :: TimeRefArray
  !DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE :: TimeRefArray
  !INTEGER :: Tyear_start, Tyear_end

END MODULE RefTimeVecs

!-------------------------------------------------------------------------------
! namelist handling

MODULE NamelistHandling

  IMPLICIT NONE
  SAVE

  INTEGER, PARAMETER :: nvars = 13 

  CHARACTER (len = 200) :: Conventions, contact, experiment_id, experiment, &
    driving_experiment, driving_model_id, driving_model_ensemble_member, &
    driving_experiment_name, institution, institute_id, model_id, &
    rcm_version_id, project_id, CORDEX_domain, product, references

  CHARACTER (len = 200) :: comment, institute_run_id, title

  CHARACTER (LEN = 100), DIMENSION(nvars):: var_wrf, var_cmip, standard_name, &
    long_name, units, filetype, cm1hr, cm3hr, cm6hr, cmDay, cmMon, cmSea, positive
  INTEGER, DIMENSION(nvars):: height, cordexID
  LOGICAL, DIMENSION(nvars):: time1hr, time3hr, time6hr, timeDay, timeMon, timeSea, &
     interpolate

  CHARACTER (len = 200) :: DirInputSimResRoot, DirOutputPostProRoot, domain

  INTEGER ::  nx, ny, nz, xoffset, yoffset, xfocus, yfocus
  CHARACTER (len = 4) :: ts, te
  CHARACTER (len = 19) :: tstot, tetot

  CHARACTER (len = 200) :: PnFnGeo

  LOGICAL :: aggregation_yearly, aggregation_monthly, aggregation_individually
  CHARACTER (len = 19) :: tsact, teact

  NAMELIST / globalvars / Conventions, contact, experiment_id, experiment, &
    driving_experiment, driving_model_id, driving_model_ensemble_member, &
    driving_experiment_name, institution, institute_id, model_id, &
    rcm_version_id, project_id, CORDEX_domain, product, references

  NAMELIST / globalvars_additional / comment, institute_run_id, title

  NAMELIST / vars / var_wrf, var_cmip, standard_name, long_name, units, &
    height, time1hr, time3hr, time6hr, timeDay, timeMon, timeSea, filetype, &
    cm1hr, cm3hr, cm6hr, cmDay, cmMon, cmSea, interpolate, cordexID, positive

  NAMELIST / filesystem / DirInputSimResRoot, DirOutputPostProRoot, domain

  NAMELIST / model_config / ts, te, nx, ny, nz, xoffset, yoffset, xfocus, &
    yfocus, tstot, tetot

  NAMELIST / static_fields / PnFnGeo

  NAMELIST / tool_config / aggregation_yearly, aggregation_monthly, &
    aggregation_individually, tsact, teact

END MODULE NamelistHandling

!===============================================================================

PROGRAM ppWRFCMIP

USE FilelistHandling
USE RefTimeVecs
USE NamelistHandling

USE netcdf

IMPLICIT NONE

!===============================================================================

INTERFACE

  SUBROUTINE GenerateFilelist
  END SUBROUTINE GenerateFilelist

  SUBROUTINE CreateRefTimeArray( dt )
    IMPLICIT NONE
    CHARACTER (LEN = 3), INTENT(IN) :: dt
  END SUBROUTINE CreateRefTimeArray

! HTr: modified calculation of mean sea level pressure adopted from wrf_interp.F90	
  SUBROUTINE calcslp(slp,pres,qv,tk1,ght,nz,ns,ew,T00)
    IMPLICIT NONE
    INTEGER, INTENT(IN) :: nz,ns,ew
    REAL, DIMENSION(:,:), INTENT(INOUT) :: slp
    REAL, DIMENSION(:,:,:), INTENT(IN) :: pres,qv,tk1,ght
    REAL, INTENT(IN) :: T00
  END SUBROUTINE

END INTERFACE

!===============================================================================
! filenames
! do not use the individual variable namelists here, they are set later on in a 
! loop; create symbolic links to have different base namelists, depending on the
! dataset and experiment

CHARACTER (len = *), PARAMETER :: fnNMLexp = "runctrl.current.nml"
CHARACTER (len = 100), DIMENSION(:), ALLOCATABLE :: fnNMLvar
CHARACTER (len = 200) :: pn_out, fn_out, iflWRFin

!-------------------------------------------------------------------------------

REAL, PARAMETER :: cp = 1004.0 ! [J kg-1 K-1]
REAL, PARAMETER :: R = 287.05 ! [J kg-1 K-1]
REAL, PARAMETER :: L = 2501000.0 ! [J kg-1]
REAL, PARAMETER :: a = 610.78 ! [Pa]
REAL, PARAMETER :: b = 17.27 !
REAL, PARAMETER :: c = 273.15 !
REAL, PARAMETER :: d = 35.86 !
REAL, PARAMETER :: n = L*0.622*a/cp !
REAL, PARAMETER :: mv = 1.e20 ! missing value as specified

! auxilliary vars, just needed during development
! INTEGER, PARAMETER :: nt = 8

! new netCDF file
INTEGER :: ncid, ncidin, ncidin0
INTEGER :: lon_dimid, lat_dimid, rec_dimid, height_dimid, &
  nb2_dimid, x_dimid, y_dimid, plev_dimid
INTEGER :: varid, x_varid, lon_varid, lat_varid, rlon_varid, rlat_varid, &
  rotated_pole_varid, height_varid, rec_varid, pp_varid, pb_varid, ph_varid, &
  phb_varid, qv_varid, qc_varid, qi_varid, qr_varid, qs_varid, &
  theta_varid, t2_varid, recbnds_varid, rainnc_varid, &
  rainc_varid, snownc_varid, u10_varid, v10_varid, u_varid, v_varid, &
  sfcevp_varid, potevp_varid, sfroff_varid, udroff_varid, acsnom_varid, &
  sinalpha_varid, cosalpha_varid, plev_varid, plevbnds_varid

! input data general query
INTEGER :: ncid_in, ndims_in, nvars_in, ngatts_in, unlimdimid_in !!!, formatp_in

! inputs, number of elements
INTEGER :: nvar_nml
! record variable in input data
INTEGER :: InVarIdRec, InDimLenRec !!!, InVarNdimsRec
CHARACTER (len = NF90_MAX_NAME) :: InDimNameRec !!!, InVarNameRec
!!!INTEGER, DIMENSION(NF90_MAX_VAR_DIMS) :: InDimIdsRec
CHARACTER (len = 19), DIMENSION(:), ALLOCATABLE :: InVarDataRec

! data
REAL, DIMENSION(:,:), ALLOCATABLE :: &
  data_in     , &
  psl_in      , &
  t2_in       , &
  cldfra_inv  , &
  u10_in      , &
  v10_in      , &
  cape        , &
  cin         , &
  lcl         , &
  lfc         , &
  prw         , &
  clwvi       , &
  clivi       , &
  sinalpha_in , &
  cosalpha_in
REAL, DIMENSION(:,:,:), ALLOCATABLE :: pp_in, pb_in, ph_in, phb_in, qv_in, qvs, &
  qc_in, qr_in, qi_in, qs_in,  theta_in, t_in, ph_fl, p_in, cldfra_in, &
  u_in, v_in, var3d_in, var_pl, potevp_in, &
  rainnc_in, rainc_in, rad_in, t_p, snownc_in, acsnom_in, GeoInLonLat, &
  sfcevp_in, sfroff_in, udroff_in
REAL, DIMENSION(:,:,:,:), ALLOCATABLE :: smois_in

! time vec stuff
REAL(KIND=8), DIMENSION(:,:), ALLOCATABLE :: &
  TimeRefArraySubset, &
  Time_bnds
REAL(KIND=8), DIMENSION(:), ALLOCATABLE :: &
  TimeRefArraySubsetMean

! bucket system
INTEGER, DIMENSION(:,:,:), ALLOCATABLE :: i_rainnc_in, i_rainc_in, i_rad_in
REAL :: bucket_mm, bucket_J


REAL, DIMENSION(:), ALLOCATABLE :: GeoInRLat, GeoInRLon, pout

! (het): base state temperature is made flexible in newer versions of WRF. The
! actual value is stored in variable T00
! also the base state pressure (P00) is kept flexible now.
REAL, DIMENSION(1) :: T00, P00
INTEGER :: t00_varid, p00_varid

! (het): variable for adopted vertical interpolation
REAL :: zg_pout

! (het): soil layer thickness may vary from simulation to simulation
REAL, DIMENSION(:), ALLOCATABLE :: DZS

! (het): meta information about the geographic projection used (coordinates of the rotated pole)
REAL :: GeoNPLat, GeoNPLon

REAL :: t_ii, dtHours



! time and date handling
CHARACTER (len = 3), DIMENSION(:), ALLOCATABLE :: frequency
!!!INTEGER :: WRFfileNyears, WRFfileNmonths
INTEGER, DIMENSION(:), ALLOCATABLE :: InDateTimeYear, InDateTimeMonth, &
  InDateTimeDay, InDateTimeHour, InDateTimeMinute, InDateTimeSecond      !, WRFfileIyears, WRFfileImonths
REAL, DIMENSION(:), ALLOCATABLE :: InDateTimeCombined
CHARACTER (LEN=4) :: InDateTimeYearStr
CHARACTER (LEN=2) :: InDateTimeMonthStr, LastHourStr
INTEGER :: InDateTimeYearPrev = 0, InDateTimeMonthPrev = 0
CHARACTER (len = 10) :: FileNameStartDateTime, FileNameEndDateTime
INTEGER :: tsactYear, tsactMonth, tsactDay, tsactHour, tsactMinute, tsactSecond, & 
  teactYear, teactMonth, teactDay, teactHour, teactMinute, teactSecond
CHARACTER (LEN=4) :: tsactYearStr, teactYearStr
CHARACTER (LEN=2) :: tsactMonthStr, tsactDayStr, tsactHourStr, tsactMinuteStr, &
  tsactSecondStr, teactMonthStr, teactDayStr, teactHourStr, teactMinuteStr, &
  teactSecondStr

CHARACTER (LEN = 100), DIMENSION(nvars) :: cell_methods

!-------------------------------------------------------------------------------
! statistics

REAL :: stat_mean, slope

!-------------------------------------------------------------------------------
! general

INTEGER :: i, sts, ivar, ifrq, ifl, it, counter, j, np, nl, ii, ivarnml, prevpass = 0
!!!INTEGER :: AllocateStatus, DeAllocateStatus
LOGICAL :: FileExists, newpass, time_match, calc = .TRUE.   !, comb_flags
REAL :: cpuTs, cpuTe
!REAL(KIND=8), ALLOCATABLE :: ipos(:)
INTEGER, ALLOCATABLE :: ipos(:)

!-------------------------------------------------------------------------------
! system calls

CHARACTER (len = *), PARAMETER :: cmdUUID = "uuidgen -t > tmpfileUUID"
CHARACTER (len = 37) :: trackingID

CHARACTER (len = *), PARAMETER :: cmdDate = "date -u +%Y-%m-%d-T%H:%M:%SZ > tmpfileDate"
CHARACTER (len = 21) :: creationDate

!===============================================================================

PRINT *, "============================================================"
PRINT *, "WRF RCM CMORizer"
PRINT *, "============================================================"

PRINT *, "============================================================"
PRINT *, "*** CENTRAL NAMELIST READING ***"
PRINT *, fnNMLexp

OPEN(2,FILE=fnNMLexp)
READ(UNIT=2,NML=globalvars)
CLOSE(2)

OPEN(2,FILE=fnNMLexp)
READ(UNIT=2,NML=globalvars_additional)
CLOSE(2)

OPEN(2,FILE=fnNMLexp)
READ(UNIT=2,NML=filesystem)
CLOSE(2)

OPEN(2,FILE=fnNMLexp)
READ(UNIT=2,NML=model_config)
CLOSE(2)

OPEN(2,FILE=fnNMLexp)
READ(UNIT=2,NML=static_fields)
CLOSE(2)

OPEN(2,FILE=fnNMLexp)
READ(UNIT=2,NML=tool_config)
CLOSE(2)

!-------------------------------------------------------------------------------
! allocate main data input array outside the loops based on nml entries
! dummy allocation of the ref time array -> has to maintain its values during
! several looping constructs and is de-allocated before the initial allocation

ALLOCATE( data_in( xfocus, yfocus ), STAT=sts )
IF (sts /= 0) STOP "*** Not enough memory on this device, stopping***"

ALLOCATE( TimeRefArraySubset(2,2) )
ALLOCATE( TimeRefArraySubsetMean(2) )
ALLOCATE( Time_bnds(2,2) )

!-------------------------------------------------------------------------------
! get the invariant vars which have to be added all the time from seperate file
! lon, lat, rlon, rlat, mass grid, etc.

PRINT *, "============================================================"
PRINT *, "*** STATIC FIELDS ***"
PRINT *, TRIM(PnFnGeo)

ALLOCATE( GeoInLonLat(yfocus, xfocus, 2) ) ! F95 order
PRINT *, SHAPE(GeoInLonLat)
ALLOCATE( GeoInRLat(yfocus) )
ALLOCATE( GeoInRLon(xfocus) )

sts = NF90_OPEN(TRIM(PnFnGeo), NF90_NOWRITE, ncidin)

sts = NF90_INQ_VARID(ncidin, "XLONG_M", varid)
sts = NF90_GET_VAR(ncidin, varid, GeoInLonLat(:, :, 1), &
  START = (/ xoffset, yoffset, 1 /), COUNT = (/ xfocus, yfocus, 1 /)) ! normal order: x y z t

sts = NF90_INQ_VARID(ncidin, "XLAT_M", varid)
sts = NF90_GET_VAR(ncidin, varid, GeoInLonLat(:, :, 2), &
  START = (/ xoffset, yoffset, 1 /), COUNT = (/ xfocus, yfocus, 1 /))

sts = NF90_INQ_VARID(ncidin, "CLONG", varid)
sts = NF90_GET_VAR(ncidin, varid, GeoInRLon(:), &
  START = (/ xoffset, 1, 1 /), COUNT = (/ xfocus, 1, 1 /))

sts = NF90_INQ_VARID(ncidin, "CLAT", varid)
sts = NF90_GET_VAR(ncidin, varid, GeoInRLat(:), &
  START = (/ 1, yoffset, 1 /), COUNT = (/ 1, yfocus, 1 /))

sts = NF90_GET_ATT(ncidin, NF90_GLOBAL, "POLE_LAT", GeoNPLat)
sts = NF90_GET_ATT(ncidin, NF90_GLOBAL, "POLE_LON", GeoNPLon)

sts = NF90_CLOSE(ncidin)

!PRINT *, "rlon = "
!PRINT *, SHAPE(GeoInRLon)
!PRINT *, GeoInRLon

!PRINT *, "rlat = "
!PRINT *, SHAPE(GeoInRLat)
!PRINT *, GeoInRLat

!PRINT *, "GeoInLonLat = "
!PRINT *, SHAPE(GeoInLonLat)
!PRINT *, "lon = ", GeoInLonLat(:,:,1)
!PRINT *, "lat = ", GeoInLonLat(:,:,2)

!-------------------------------------------------------------------------------
! main loop over the different variables, namelist controlled

ALLOCATE ( frequency(7) )
frequency(1) = "1hr"
frequency(2) = "3hr"
frequency(3) = "6hr"
frequency(4) = "day"
frequency(5) = "mon"
frequency(6) = "sem"
frequency(7) = "fx"

ALLOCATE ( fnNMLvar(11) )
fnNMLvar(1) = "runctrl.vars.nml"
fnNMLvar(2) = "runctrl.vars.nml_evp_roff"
fnNMLvar(3) = "runctrl.vars.nml_water_column"
fnNMLvar(4) = "runctrl.vars.nml_vars_on_plevels"
fnNMLvar(5) = "runctrl.vars.nml_pr_mrso"
fnNMLvar(6) = "runctrl.vars.nml_snow"
fnNMLvar(7) = "runctrl.vars.nml_radiation_alternative"
fnNMLvar(8) = "runctrl.vars.nml_cape"
fnNMLvar(9) = "runctrl.vars.nml_pr_tas_1hr_test"
fnNMLvar(10) = "runctrl.vars.nml_weathertyping" ! new form HTr
fnNMLvar(11) = "runctrl.vars.nml_psl" ! new from HTr

! individual vars contain information on whether they are treated or not, i.e.
! the tool may loop over all frequencies and the namelist controls what is to 
! be done
!DO ifrq = 1, SIZE(frequency), 1 
DO ifrq = 1, 1, 1

  PRINT *, "============================================================"
  PRINT *, "freq = ", frequency(ifrq)

!-------------------------------------------------------------------------------
! get a file list of all wrfout and wrfxtrm files
! use regex to refine the ls output and the filelist
! non-std, works for gfortran (fct & subroutine) + ifort
  
  PRINT *, "============================================================"
  PRINT *, "*** FILELIST CREATION ***"
  
  tmpfileFL = "tmpfileFL"
  
  !PRINT *, "filelist search pattern = ", TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/" // "*/*wrfout*nc"
  !CALL SYSTEM("ls -1 " // TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/*/*wrfout*{" // ts // ".." // te // "}*nc > " // tmpfileFL)
  !PRINT *, "filelist search pattern = ", TRIM(DirInputSimResRoot) // "/*wrfout*" // TRIM(domain) // "*"
  !CALL SYSTEM("ls -1 " // TRIM(DirInputSimResRoot) // "/*wrfout*" // TRIM(domain) // "* > " // tmpfileFL)
  PRINT *, "filelist search pattern = ", TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/" // "*/*wrfout*nc"
  CALL SYSTEM("ls -1 " // TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/*/*wrfout*nc > " // tmpfileFL)
  ft = 0 ! file type
  CALL GenerateFilelist
  
  PRINT *, "filelist search pattern = ", TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/" // "*/*wrfxtrm*nc"
  CALL SYSTEM("ls -1 " // TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/*/*wrfxtrm*{" // ts // ".." // te // "}*nc > " // tmpfileFL)
  ft = 1
  CALL GenerateFilelist
  
  DO i=1,SIZE(fl_wrfout(:)),1
    PRINT '(100A)', fl_wrfout(i)
  END DO
  DO i=1,SIZE(fl_wrfxtr(:)),1
      PRINT '(100A)', fl_wrfxtr(i)
  END DO
  
!-------------------------------------------------------------------------------
! creation of the main reference array
! independent of the actual timespan under processing
! usually it starts earlier or at the same date/time and ends at the same 
! date/time or later
  
  PRINT *, "============================================================"
  PRINT *, "*** TIME REFERENCE ARRAY ***"
  
  CALL CreateRefTimeArray( frequency(ifrq) )
  
  PRINT *, "size & shape of the TimRefArray = ", SIZE(TimeRefArray), &
    SHAPE(TimeRefArray)
  PRINT *, "SIZE(TimeRefArray,1)",SIZE(TimeRefArray,1) 
  PRINT *, "SHAPE(TimeRefArray,1)",  SHAPE(TimeRefArray,1)

!-------------------------------------------------------------------------------
! loop over the different namelists, each containing a specific set of related
! variables, this offers more flexibility in using the tool than putting all
! vars into a single namelist; choose just specific namelists from list above if
! you want to postprocess just specific variables or create your own variable 
! combinations
  
  DO ivarnml = 9, 9, 1
  
    PRINT *, "============================================================"
    PRINT *, "var. namelist nr. and name: ", ivarnml, TRIM(fnNMLvar(ivarnml))

    ! read the very specific namelist
    OPEN(2,FILE=TRIM(fnNMLvar(ivarnml)))
      READ(UNIT=2,NML=vars)
    CLOSE(2)

    ! must have read the namelist already
    ! get the call methods from the namelist, determines what has to be done with 
    ! a variable 
    SELECT CASE (frequency(ifrq))
    CASE ('1hr')
      cell_methods(:) = cm1hr(:)
      dtHours = 1.
    CASE ('3hr')
      cell_methods(:) = cm3hr(:)
      dtHours = 3.
    CASE ('6hr')
      cell_methods(:) = cm6hr(:)
      dtHours = 6.
    CASE ('day')
      cell_methods(:) = cmDay(:)
    CASE ('mon')
      cell_methods(:) = cmMon(:)
    CASE ('sem')
      cell_methods(:) = cmSea(:)
    CASE DEFAULT
      PRINT *, "invalid time interval specified"
      STOP
    END SELECT

    ! nvar_nnml might be determined through the namelist itself
    SELECT CASE (TRIM(fnNMLvar(ivarnml)))
    CASE ("runctrl.vars.nml")
      nvar_nml = 9
    CASE ("runctrl.vars.nml_evp_roff")
      nvar_nml = 4
    CASE ("runctrl.vars.nml_water_column")
      nvar_nml = 3
    CASE ("runctrl.vars.nml_vars_on_plevels")
      nvar_nml = 12
    CASE ("runctrl.vars.nml_pr_mrso")
      nvar_nml = 4
    CASE ("runctrl.vars.nml_snow")
      nvar_nml = 6 
    CASE ("runctrl.vars.nml_radiation")
      nvar_nml = 9
    CASE ("runctrl.vars.nml_radiation_alternative")
      nvar_nml = 9
    CASE ("runctrl.vars.nml_cape")
      nvar_nml = 1
    CASE ("runctrl.vars.nml_pr_tas_1hr_test") ! used right now for testing
      nvar_nml = 3
    CASE ("runctrl.vars.nml_weathertyping")
      nvar_nml = 6
    CASE ("runctrl.vars.nml_psl")
      nvar_nml = 1
    END SELECT
  
    print*, "number of vars inside current namelist: nvar_nml = ", nvar_nml
  
!-------------------------------------------------------------------------------
! loop over all vars in the individual namelist
! OR for testing choose just specific variables from namelist 
! (look up var column position in individual namelist)
! better avoid this kind of filtering, but then create a new namelist

    !DO ivar = 1, nvar_nml, 1
    DO ivar = 1, 2, 1 ! testing
  
      PRINT *,"============================================================"
      PRINT *, "*** ", TRIM(var_cmip(ivar)), " ***"
  
!-------------------------------------------------------------------------------
! loop over the filelist
! content of filelist is defined by filename patterns in system call
! two filelists: fl_wrfout, fl_wrfxtr
! the filelist loops does not care whether (a) the filelist spans multiple
! simulated years or just a single day or hour, neither does it care (b) how
! many files are contained and (c) whether a single file is oerlapping a 
! beginnning or end of the desired temporal unit (year, month, individual, etc.)

      !DO ifl = 1, 1, 1 ! testing: loop over specific entry in filelist (e.g. just January)
      DO ifl = 1, SIZE(fl_wrfout), 1 ! operational: loop over complete filelist

        PRINT *,"============================================================"
        PRINT *, "# files to process = ", SIZE(fl_wrfout)

        ! measure CPU time for 1 variable and file, including all timesteps
        CALL CPU_TIME(cpuTs)
        PRINT *, "-----------------------------------------------------------"
  
        IF ( filetype(ivar) == "s" ) THEN ! variable is in "s"tandard wrfout file
          iflWRFin = fl_wrfout(ifl)
        ELSE IF ( filetype(ivar) == "x" ) THEN ! variable is in e"x"tremes wrfxtrm file
          iflWRFin = fl_wrfxtr(ifl)
        END IF

        PRINT *, "this is the file to work on now:"
        PRINT '(100A)', TRIM(iflWRFin)
  
!-------------------------------------------------------------------------------
! which timespan is covered by the current WRF input file
! even in the same filelist file, each input file may cover a different timespan
! this determines how many times the tool has to loop over the inputs
! format of 'Times': 2009-06-20_08:00:00

        sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncid_in)
        sts = NF90_INQUIRE(ncid_in, ndims_in, nvars_in, ngatts_in, unlimdimid_in)
        sts = NF90_INQ_VARID(ncid_in, "Times", InVarIdRec)
        sts = NF90_INQUIRE_DIMENSION(ncid_in, unlimdimid_in, &
          NAME = InDimNameRec, LEN = InDimLenRec)
        ALLOCATE(InVarDataRec(InDimLenRec))
        sts = NF90_GET_VAR(ncid_in, InVarIdRec, InVarDataRec)
        sts = NF90_CLOSE(ncid_in)

        PRINT *, "RCM input file time coverage:"
        print *, InVarDataRec(1), " to ", InVarDataRec(InDimLenRec)
  
        ALLOCATE(InDateTimeYear(InDimLenRec))
        ALLOCATE(InDateTimeMonth(InDimLenRec))
        ALLOCATE(InDateTimeDay(InDimLenRec))
        ALLOCATE(InDateTimeHour(InDimLenRec))
        ALLOCATE(InDateTimeMinute(InDimLenRec))
        ALLOCATE(InDateTimeSecond(InDimLenRec))
        ALLOCATE(InDateTimeCombined(InDimLenRec))
        
        PRINT *, SIZE(InDateTimeYear)
        PRINT *, SIZE(InVarDataRec)
        PRINT *, InVarDataRec(:)
  
        ! this is the temporal coverage of the RCM input data of the specific
        ! file; split the date/time information string into several vectors
        DO i = 1, SIZE(InVarDataRec), 1
        
          READ( InVarDataRec(i), '(I4,1X,I2,1X,I2,1X,I2,1X,I2,1X,I2)' ) &
            InDateTimeYear(i), &
            InDateTimeMonth(i), &
            InDateTimeDay(i), &
            InDateTimeHour(i), &
            InDateTimeMinute(i), &
            InDateTimeSecond(i)
            
          ! 2009062008 use for later-on comparisons
          InDateTimeCombined(i) = & 
            InDateTimeYear(i) * 1000000 + &
            InDateTimeMonth(i) * 10000 + &
            InDateTimeDay(i) * 100 + &
            InDateTimeHour(i)
            
        END DO

!-------------------------------------------------------------------------------
! loop over the individual timesteps in the individual RCM input file
! this may take some time but it is robust and also extremely large arrays
! might be used; this leads to many I/O operations, but only small amounts of
! data, but the tradeoff is robustness, flexibility and still far less I/O 
! operations as if using script-based solutions (cdo, nco, etc.)

        DO it = 1, InDimLenRec, 1
  
          PRINT *, "-----------------------------------------------------------"
          PRINT *, "inner loop"
          PRINT *, "working on date in WRF inp. file = ", TRIM(InVarDataRec(it))
          PRINT *, InDateTimeYear(it), InDateTimeMonth(it), InDateTimeDay(it), InDateTimeHour(it), InDateTimeCombined(it)

!-------------------------------------------------------------------------------
! performance issue, speeds up the tool during subsequent passes as some 
! searching is always needed
! check whether file exists, highly likely as the RCM outputs usually have a
! higher frequency (e.g., monthly or daily) than the temporal granularity of the
! storage files (e.g., annual with the CORDEX protocol)
! also check whether this is the first pass on a new storage file or a 
! subsequent pass
! because data is read with a very fine-grained granularity, it's highly likely,
! that the file which is supposed to hold the data exists already, e.g., 8760
! timesteps per year at 1h temporal resolution vs. creation of 1 annual file,
! the tool checks before any operation whether the same temporal aggregation has
! been dealt with before (yearly, monthly, individual storage)
! if the InDateTimeMonthPrev or InDateTimeYearPrev are > 0 all variables are set
! already also
! in case of annual and monthly aggregation, the file content of the WRF inputs
! defines the storage files creation, in case of the individual definition, the
! opposite is true

          IF (aggregation_individually) THEN ! first pass, always needed, file may exist or not
            IF ( prevpass == 0 ) THEN
              newpass = .TRUE.
            END IF
          ELSE IF (aggregation_monthly) THEN
            IF ( InDateTimeMonthPrev /= InDateTimeMonth(it) ) THEN
              newpass = .TRUE.
            END IF
          ELSE ! default, if the current year is different than the one previous > create a new file
            IF ( InDateTimeYearPrev /= InDateTimeYear(it) ) THEN
              newpass = .TRUE.
            END IF
          END IF
          
          IF (newpass) THEN
  
            InDateTimeYearPrev = InDateTimeYear(it)
            InDateTimeMonthPrev = InDateTimeMonth(it)
            prevpass = 1
            newpass = .FALSE.
  
            PRINT *, "start of processing or new year/month/timespan encountered"

            ! information has to be down to the hour as 1h or 3h data is stored
            ! in this case, only a single file is created and filled successively
            ! use the information fromt he namelist
            ! 2009-06-20_00:00:00
            IF (aggregation_individually) THEN
              READ( tsact, '(I4,1X,I2,1X,I2,1X,I2,1X,I2,1X,I2)' ) &
                tsactYear, &
                tsactMonth, &
                tsactDay, &
                tsactHour, &
                tsactMinute, &
                tsactSecond
              READ( teact, '(I4,1X,I2,1X,I2,1X,I2,1X,I2,1X,I2)' ) &
                teactYear, &
                teactMonth, &
                teactDay, &
                teactHour, &
                teactMinute, &
                teactSecond
              WRITE (tsactYearStr,'(I4.4)') tsactYear
              WRITE (tsactMonthStr,'(I2.2)') tsactMonth
              WRITE (tsactDayStr,'(I2.2)') tsactDay
              WRITE (tsactHourStr,'(I2.2)') tsactHour
              WRITE (teactYearStr,'(I4.4)') teactYear
              WRITE (teactMonthStr,'(I2.2)') teactMonth
              WRITE (teactDayStr,'(I2.2)') teactDay
              WRITE (teactHourStr,'(I2.2)') teactHour
              FileNameStartDateTime = tsactYearStr//tsactMonthStr//tsactDayStr//tsactHourStr
              FileNameEndDateTime = teactYearStr//teactMonthStr//teactDayStr//teactHourStr
            ELSE
              !READ( InDateTimeYear(it), '(4A)' ) InDateTimeYearStr
              !READ( InDateTimeMonth(it), '(2A)' ) InDateTimeMonthStr
              WRITE (InDateTimeYearStr,'(I4.4)') InDateTimeYear(it)
              WRITE (InDateTimeMonthStr,'(I2.2)') InDateTimeMonth(it)              
              WRITE (LastHourStr,'(I2.2)') 23 ! TODO 24-dtHours type issues
              PRINT *, "strings for the output filename date/time information", &
                InDateTimeYearStr, InDateTimeMonthStr, LastHourStr
              IF (aggregation_monthly) THEN
                ! TODO replace the 31 with proper month length in days of the specific month
                FileNameStartDateTime = InDateTimeYearStr//InDateTimeMonthStr//"0100"
                FileNameEndDateTime = InDateTimeYearStr//InDateTimeMonthStr//"31"//LastHourStr
              ELSE ! default, annual
                FileNameStartDateTime = InDateTimeYearStr//"010100"
                FileNameEndDateTime = InDateTimeYearStr//"1231"//LastHourStr
              END IF
            END IF

            ! /hpc/shared/int/eva/ramod_WRF_CRPGL/WRFrv021rXXrcc3CpCdx/postpro/
            ! EUR-44/CRPGL/ECMWF-ERAINT/evaluation/r1i1p1/CRPGL-WRFARW331/v1
            pn_out = TRIM(project_id)                    // "/" // &
                     TRIM(CORDEX_domain)                 // "/" // &
                     TRIM(institute_id)                  // "/" // &
                     TRIM(driving_model_id)              // "/" // &
                     TRIM(driving_experiment_name)       // "/" // &
                     TRIM(driving_model_ensemble_member) // "/" // &
                     TRIM(model_id)                      // "/" // &
                     TRIM(rcm_version_id)                // "/" // &
                     TRIM(frequency(ifrq))               // "/" // &
                     TRIM(var_cmip(ivar))

            ! evspsbl_EUR-44_ECMWF-ERAINT_evaluation_r1i1p1_CRPGL-WRFARW331_v1_
            ! 3hr_1989010100-1989123121
            fn_out = TRIM(var_cmip(ivar))                // "_" // &
                     TRIM(CORDEX_domain)                 // "_" // &
                     TRIM(driving_model_id)              // "_" // &
                     TRIM(driving_experiment_name)       // "_" // &
                     TRIM(driving_model_ensemble_member) // "_" // &
                     TRIM(model_id)                      // "_" // &
                     TRIM(rcm_version_id)                // "_" // &
                     TRIM(frequency(ifrq))               // "_" // &
                     TRIM(FileNameStartDateTime) // "-" // TRIM(FileNameEndDateTime) // &
                     ".nc"
  
            PRINT *, "CORDEX compliant pathname, pn_out = ", TRIM(pn_out)
            PRINT *, "CORDEX compliant filename, fn_out = ", TRIM(fn_out)

!-------------------------------------------------------------------------------
! extract the time info from the ref time array which matches the respective
! file in which data is to be written and thereby matches also the input data
! ...as there is no "WHERE" the way I need it in F95, use loops
! this is needed whenever a new netCDF file is to be used and also if
! this file exists already
! still working on single variable 'ivar', file 'ifl', and timestep 'it'
! InDateTimeYear(it), InDateTimeMonth(it), InDateTimeDay(it), InDateTimeHour(it), InDateTimeCombined(it)
! TimeRefArray, TimeRefArraySubset

            ! index, y, m, d, h
            PRINT *, "size & shape of the TimRefArray = ", SIZE(TimeRefArray), &
              SHAPE(TimeRefArray)
  
            DEALLOCATE( TimeRefArraySubset )
            DEALLOCATE( TimeRefArraySubsetMean )
            DEALLOCATE( Time_bnds )
            
!            PRINT *,'SIZE(TimeRefArray, 1)', SIZE(TimeRefArray, 1)
!            PRINT *,'SHAPE(TimeRefArray, 1)', SHAPE(TimeRefArray, 1)
!            PRINT *,'TimeRefArray(1,2)', TimeRefArray(1,2)
!            PRINT *,'TimeRefArray(744,2)', TimeRefArray(744,2)
!            PRINT *,'InDateTimeYear(it)', InDateTimeYear(it)

            ! number of date/time steps in the ref array which match the current 
            ! year or month, or individual time span
            ! the TimeRefArray must span the requested subsets
            ALLOCATE( ipos(0) )
            counter = 0
            IF (aggregation_individually) THEN
              PRINT *, "aggregation_individually"
              PRINT *,tsactYear, tsactMonth, tsactDay, tsactHour, teactYear, teactMonth, teactDay, teactHour
              DO i = 1, SIZE(TimeRefArray, 1), 1
                IF ( ( TimeRefArray(i,2) >= tsactYear ) .AND. & 
                     ( TimeRefArray(i,2) <= teactYear ) .AND. &
                     ( TimeRefArray(i,3) >= tsactMonth ) .AND. &
                     ( TimeRefArray(i,3) <= teactMonth ) .AND. &
                     ( TimeRefArray(i,4) >= tsactDay ) .AND. &
                     ( TimeRefArray(i,4) < teactDay ) ) THEN !.AND. &
!                   ( TimeRefArray(i,5) >= tsactHour ) .AND. &
!                   ( TimeRefArray(i,5) <= teactHour ) ) THEN ! TODO, porblem if the end of also 00UTC > then there is no match with the hours
                  counter = counter + 1
                  ipos = [ipos, i] ! store the position, automatic reallocation
                END IF
              END DO
              ! TODO see the problem with the ending, there is one timestep too
              ! few in the file if this is not done
              ! artifically add a further postion at the very end
              ipos = [ipos, ipos(counter)+1] 
              counter = counter + 1
            ELSE IF (aggregation_monthly) THEN
              PRINT *, "aggregation_monthly"
              DO i = 1, SIZE(TimeRefArray, 1), 1
                IF (( TimeRefArray(i,2) == InDateTimeYear(it)) .AND. &
                   ( TimeRefArray(i,3) == InDateTimeMonth(it))) THEN
                  counter = counter + 1
                  ipos = [ipos, i]
                END IF
              END DO
              !ipos = [ipos, ipos(counter)+1] 
              !counter = counter + 1
            ELSE ! default, CORDEX annual files
              PRINT *, "aggregation_annually"
              PRINT *, InDateTimeYear(it)
              DO i = 1, SIZE(TimeRefArray, 1), 1
                IF ( TimeRefArray(i,2) == InDateTimeYear(it)) THEN
                  counter = counter + 1
                  ipos = [ipos, i]
                END IF
              END DO
            END IF
            PRINT *, "timesteps in the time ref. subset = ", counter

            ALLOCATE( TimeRefArraySubset( counter, 5 ) ) ! index, y, m, d, h
            ALLOCATE( TimeRefArraySubsetMean( counter ) )
            ALLOCATE( Time_bnds( 2, counter ) )

            ! the TimeRefArraySubset is the time vec of the newly created (or
            ! already existing) file; it may be any size <= the original ref
            ! time vec
            DO i = 1, counter, 1
              j = ipos(i)
              PRINT *, TimeRefArray(j, :)
              TimeRefArraySubset(i,1:5) = TimeRefArray(j,1:5)
            END DO
            !PRINT '(F9.3,1X,F5.0,1X,F3.0,1X,F3.0,1X,F3.0)', TRANSPOSE( TimeRefArraySubset(:,:) )

            DEALLOCATE(ipos)

!-------------------------------------------------------------------------------
! check for existance of the new output file and generate this file if needed
! could exist already from a previous run of tool and due to multiple months in 
! a file (i.e. one WRF output file may cover several months)
! i.e. this could be the first pass of a processing session, but a subsequent 
! pass over the storage file when continuously adding new data 
! could exist already from a previous run of tool and due to multiple
! months in a file (i.e. 1 WRF output file may cover several months)

            PRINT *, "*** CHECK FOR FILE EXISTANCE / CREATE FILE WITH BASIC STRUCTURE + METADATA***"

            INQUIRE( FILE=TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) // "/" // TRIM(fn_out), EXIST=FileExists )

            IF ( FileExists ) THEN
  
              PRINT *, "++++ path and file exist, continue filling"

            ELSE

              PRINT *, "++++ path and file do not yet exist, create path and netCDF file first"
              PRINT '(150A)', "path = ", TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out)
  
              CALL SYSTEM("mkdir -p " // TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) )
  
!-------------------------------------------------------------------------------
! the SYSTEM call is non-std Fortran95, works for gfortran (fct & subroutine) 
! and ifort
! comment lines in the netCDF file global attribute definition
! turn standard checking in Makefile off
! trackingID = "xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx"
! creationDate = "YYYY-MM-DD-THH:MM:SSZ"
  
              CALL SYSTEM(cmdUUID)
              OPEN(1,FILE="tmpfileUUID",STATUS='old')
              READ(1,*) trackingID
              CLOSE(1)
              PRINT *, "uuidgen externally generated trackingID = ", trackingID
  
              CALL SYSTEM(cmdDate)
              OPEN(1,FILE="tmpfileDate",STATUS='old')
              READ(1,*) creationDate
              CLOSE(1)
              PRINT *, "date externally generated creation date = ", creationDate
  
!-------------------------------------------------------------------------------
! create netCDF file, must be NetCDF4 'classic data model' and compression lvl=1
! NF90_CLASSIC_MODEL = NetCDF4_classic
! NF90_HDF5 = NetCDF4 based on HDF5
! NF90_CLOBBER = old netCDF
  
              !comb_flags = IOR(NF90_HDF5, NF90_CLASSIC_MODEL)
              !https://www.unidata.ucar.edu/software/netcdf/docs/netcdf-f90/NF90_005fCREATE.html
              !sts = NF90_CREATE(TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) // "/" // TRIM(fn_out), IOR(NF90_HDF5, NF90_CLASSIC_MODEL), ncid)   !not sure whether this is the right data format spec. I guess it may be right using compression but not the other fancy stuff from NetCDF4
              sts = NF90_CREATE(TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) // "/" // TRIM(fn_out), IOR(NF90_NETCDF4, NF90_CLASSIC_MODEL), ncid)   !if anything, then use this here
              !sts = NF90_CREATE(TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) // "/" // TRIM(fn_out), NF90_NETCDF4, ncid)

              !-----------------------------------------------------------------

              ! always included define dimensions
              sts = NF90_DEF_DIM(ncid, "x", xfocus, x_dimid)
              sts = NF90_DEF_DIM(ncid, "y", yfocus, y_dimid)
              sts = NF90_DEF_DIM(ncid, "rlon", xfocus, lon_dimid)
              sts = NF90_DEF_DIM(ncid, "rlat", yfocus, lat_dimid)
              IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) <= 10. ) ) THEN
                sts = NF90_DEF_DIM(ncid, "height", 1, height_dimid)
              END IF
              IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) > 10. ) ) THEN
                sts = NF90_DEF_DIM(ncid, "plev", 1, plev_dimid)
              END IF
              sts = NF90_DEF_DIM(ncid, "time", NF90_UNLIMITED, rec_dimid)
              IF ( cell_methods(ivar) == "mean" ) THEN
                sts = NF90_DEF_DIM(ncid, "bnds", 2, nb2_dimid)
              ENDIF

              !-----------------------------------------------------------------
              ! no rule in CF1.7 standard, for capital letters or not > make a
              ! rule of my own to have long names start with capital letter
              ! nice in plots

              ! always included -- longitude field, unrotated
              sts = nf90_def_var(ncid, "lon", NF90_DOUBLE, (/ x_dimid, y_dimid /), lon_varid)
              sts = nf90_def_var_deflate(ncid, lon_varid, 1, 1, 1)
              sts = nf90_put_att(ncid, lon_varid, "standard_name", "longitude")
              sts = nf90_put_att(ncid, lon_varid, "long_name", "Longitude")
              sts = nf90_put_att(ncid, lon_varid, "units", "degrees_east")
              sts = nf90_put_att(ncid, lon_varid, "_CoordinateAxisType", "Lon") ! special addon, not needed, but allowed

              ! always included -- latitude field, unrotated
              sts = nf90_def_var(ncid, "lat", NF90_DOUBLE, (/ x_dimid, y_dimid /), lat_varid)
              sts = nf90_def_var_deflate(ncid, lat_varid, 1, 1, 1)
              sts = nf90_put_att(ncid, lat_varid, "standard_name", "latitude")
              sts = nf90_put_att(ncid, lat_varid, "long_name", "Latitude")
              sts = nf90_put_att(ncid, lat_varid, "units", "degrees_north")
              sts = nf90_put_att(ncid, lat_varid, "_CoordinateAxisType", "Lat") ! special addon, not needed, but allowed
  
              ! always included -- longitude vector, rotated
              sts = nf90_def_var(ncid, "rlon", NF90_DOUBLE, (/ lon_dimid /), rlon_varid)
              sts = nf90_def_var_deflate(ncid, rlon_varid, 1, 1, 1)
              sts = nf90_put_att(ncid, rlon_varid, "standard_name", "grid_longitude")
              sts = nf90_put_att(ncid, rlon_varid, "long_name", "Longitude in rotated pole grid")
              sts = nf90_put_att(ncid, rlon_varid, "units", "degrees")
              sts = nf90_put_att(ncid, rlon_varid, "axis", "X")
  
              ! always included -- latitude vector, rotated
              sts = nf90_def_var(ncid, "rlat", NF90_DOUBLE, (/ lat_dimid /), rlat_varid)
              sts = nf90_def_var_deflate(ncid, rlat_varid, 1, 1, 1)
              sts = nf90_put_att(ncid, rlat_varid, "standard_name", "grid_latitude")
              sts = nf90_put_att(ncid, rlat_varid, "long_name", "Latitude in rotated pole grid")
              sts = nf90_put_att(ncid, rlat_varid, "units", "degrees")
              sts = nf90_put_att(ncid, rlat_varid, "axis", "Y")

              ! additional and useful
              ! important for remapping with cdo (conservative remapping only 
              ! possible with this information)
              !        vertices = 4 ;
              !        float lat_vertices(rlat, rlon, vertices) ;
              !                lat_vertices:units = "degrees_north" ;
              !        float lon_vertices(rlat, rlon, vertices) ;
              !                lon_vertices:units = "degrees_east" ;

              ! always included, restriction to one domain only
              sts = nf90_def_var(ncid, "rotated_pole", NF90_CHAR, rotated_pole_varid)
              sts = nf90_put_att(ncid, rotated_pole_varid, "grid_mapping_name", "rotated_latitude_longitude")
              sts = nf90_put_att(ncid, rotated_pole_varid, "grid_north_pole_latitude", GeoNPLat)
              sts = nf90_put_att(ncid, rotated_pole_varid, "grid_north_pole_longitude", GeoNPLon)
  
              ! depends whether height is set in the nml, all between 1.5 and 10m
              IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) <= 10. ) ) THEN
                sts = nf90_def_var(ncid, "height", NF90_DOUBLE, (/ height_dimid /), height_varid)
                sts = nf90_put_att(ncid, height_varid, "standard_name", "height")
                sts = nf90_put_att(ncid, height_varid, "long_name", "Height")
                sts = nf90_put_att(ncid, height_varid, "units", "m")
                sts = nf90_put_att(ncid, height_varid, "positive", "up")
                sts = nf90_put_att(ncid, height_varid, "axis", "Z")
              END IF
  
              ! lvl TODO
              ! just level definition, single number, like height
              ! there is no distinction between height and plev in the nml file
              IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) > 10. ) ) THEN
                sts = nf90_def_var(ncid, "plev", NF90_DOUBLE, (/ plev_dimid /), plev_varid)
                sts = nf90_put_att(ncid, plev_varid, "standard_name", "air_pressure")
                sts = nf90_put_att(ncid, plev_varid, "long_name", "Pressure")
                sts = nf90_put_att(ncid, plev_varid, "units", "Pa")
                sts = nf90_put_att(ncid, plev_varid, "positive", "down")
                sts = nf90_put_att(ncid, plev_varid, "axis", "Z")
                IF ( cell_methods(ivar) == "vmean" ) THEN ! if this is layers over which there has been some everaging
                  sts = nf90_put_att(ncid, plev_varid, "bounds", "plev_bnds")
                END IF
              END IF

              ! for vertically averaged variables need the plev bounds
              ! plev_bnds(2), always just single field per file: this is just two numbers 
              IF ( cell_methods(ivar) == "vmean" ) THEN
                sts = nf90_def_var(ncid, "plev_bnds", NF90_DOUBLE, (/ nb2_dimid /), plevbnds_varid)
              END IF
  
              ! always included
              sts = nf90_def_var(ncid, "time", NF90_DOUBLE, (/ rec_dimid /), rec_varid)
              sts = nf90_put_att(ncid, rec_varid, "standard_name", "time")
              sts = nf90_put_att(ncid, rec_varid, "long_name", "Time")
              sts = nf90_put_att(ncid, rec_varid, "units", "days since " // tstot(1:10) // "T" // tstot(12:19) // "Z" )
              sts = nf90_put_att(ncid, rec_varid, "calendar", "standard")
              sts = nf90_put_att(ncid, rec_varid, "axis", "T")
              IF ( cell_methods(ivar) == "mean" ) THEN
                sts = nf90_put_att(ncid, rec_varid, "bounds", "time_bnds")
              END IF
  
              ! for mean variables need the time bounds
              ! no further attributes, like plev_bnds > confirmed
              IF ( cell_methods(ivar) == "mean" ) THEN
                sts = nf90_def_var(ncid, "time_bnds", NF90_DOUBLE, (/ nb2_dimid, rec_dimid /), recbnds_varid)
              END IF

              !-----------------------------------------------------------------
              
              ! always included -- global attributes
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "Conventions", Conventions)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "contact", contact)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "creation_date", creationDate)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "experiment", experiment)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "experiment_id", experiment_id)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "driving_experiment", driving_experiment)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "driving_model_id", driving_model_id)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "driving_model_ensemble_member", driving_model_ensemble_member)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "driving_experiment_name", driving_experiment_name)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "frequency", frequency(ifrq))
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "institution", institution)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "institute_id", institute_id)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "model_id", model_id)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "rcm_version_id", rcm_version_id)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "project_id", project_id)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "CORDEX_domain", CORDEX_domain)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "product", product)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "references", references)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "tracking_id", trackingID)
              
              ! optional global variables
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "title", title)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "comment", comment)
              sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "institute_run_id", institute_run_id)

              !-----------------------------------------------------------------
              ! always included -- definition of the individual variable
              ! compression is always on variable level, use compression with 
              ! level = 1 (=> CORDEX protocol),  
              ! REAL PERFORMANCE ISSUES: shuffling and chunking
              ! https://earthscience.stackexchange.com/questions/12527/regarding-compression-shuffle-filter-of-netcdf4
              ! https://www.unidata.ucar.edu/software/netcdf/netcdf-4/newdocs/netcdf-f90.html#Variables
              ! https://www.unidata.ucar.edu/software/netcdf/workshops/2011/nc4chunking/index.html
              ! https://www.unidata.ucar.edu/software/netcdf/docs/netcdf_perf_chunking.html
              ! compression on/off: 19MB->12MB, 0.1s->0.5s
              ! chunking: needs some careful considerations

              ! not sure whether the height/plev dimension this is needed
              ! with CORDEX only one layer always per variable, see the
              ! coordinates attribute which makes the association
              ! this is also better for coding and data reading
              !IF ( height(ivar) /= -999 ) THEN
              !  sts = nf90_def_var(ncid, var_cmip(ivar), NF90_FLOAT, (/ lon_dimid, lat_dimid, height_dimid, rec_dimid /), x_varid)  
              !ELSE
                sts = nf90_def_var(ncid, var_cmip(ivar), NF90_FLOAT, (/ lon_dimid, lat_dimid, rec_dimid /), x_varid)
              !END IF

              ! TODO -> determine chunksizes vector beforehand otherwise
              ! this can only make it worse
              !sts = nf90_def_var_chunking(ncid, x_varid, NF90_CHUNKED, XXXchunksizesXXX) 
              ! fill up with missing values, despite unlimited dim.
              ! not needed, at this point the unlimited time dim is not filled
              !sts = nf90_def_var_fill(ncid, x_varid, 0, mv) 
              ! shuffle ON, deflate ON, deflate_level lowest
              sts = nf90_def_var_deflate(ncid, x_varid, 1, 1, 1)
              ! default, change with care
              !sts = nf90_def_var_endian(ncid, x_varid, NF90_ENDIAN_NATIVE)
                            
              sts = nf90_put_att(ncid, x_varid, "standard_name", standard_name(ivar))
              sts = nf90_put_att(ncid, x_varid, "long_name", long_name(ivar))
              sts = nf90_put_att(ncid, x_varid, "units", units(ivar))
              IF ( positive(ivar) /= '-999' ) THEN
                sts = nf90_put_att(ncid, x_varid, "positive", positive(ivar))
              END IF
              sts = nf90_put_att(ncid, x_varid, "cell_methods", "time: "//TRIM(cell_methods(ivar)))
              IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) <= 10. ) ) THEN
                sts = nf90_put_att(ncid, x_varid, "coordinates", "lon lat height")
              ELSE IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) > 10. ) ) THEN
                sts = nf90_put_att(ncid, x_varid, "coordinates", "lon lat plev") 
              ELSE
                sts = nf90_put_att(ncid, x_varid, "coordinates", "lon lat")
              END IF
              sts = nf90_put_att(ncid, x_varid, "grid_mapping", "rotated_pole")
              sts = nf90_put_att(ncid, x_varid, "missing_value", mv)
              sts = nf90_put_att(ncid, x_varid, "_FillValue", mv)

              !-----------------------------------------------------------------
  
              sts = NF90_ENDDEF(ncid)

              !-----------------------------------------------------------------  
              ! SUPER IMPORTANT: write time information, the complete time vec
              ! for the respective file

              IF ( cell_methods(ivar) == "point" ) THEN
  
                PRINT *, 'cell_methods:', cell_methods(ivar)
                PRINT *, TimeRefArraySubset(:,1)
                sts = NF90_PUT_VAR(ncid, rec_varid, TimeRefArraySubset(:,1) )

              END IF

              ! TODO, hardcoding! 
              IF ( cell_methods(ivar) == "mean" ) THEN

                ! problem
                ! https://www.unidata.ucar.edu/mailing_lists/archives/netcdfgroup/2015/msg00071.html  
                TimeRefArraySubsetMean (:) = TimeRefArraySubset(:,1) + ( 0.5_8 * (1._8 / 24._8)) !dtHours/2._8
                PRINT *, "cell_methods:", cell_methods(ivar)
                PRINT *, "dtHours",  dtHours, dtHours/2.
                PRINT *, "TimeRefArraySubset", TimeRefArraySubset(:,1)
                PRINT *, "TimeRefArraySubsetMean", TimeRefArraySubsetMean(:)
                sts = NF90_PUT_VAR(ncid, rec_varid, TimeRefArraySubsetMean(:) )
                PRINT *, 'sts NF90_PUT_VAR time', sts
    
                Time_bnds(1,:) = TimeRefArraySubset(:,1)
                Time_bnds(2,:) = TimeRefArraySubset(:,1) + ( 1.0_8 * (1._8 / 24._8)) !dtHours
                PRINT *, "time bnds lower", Time_bnds(1,:)
                PRINT *, "time bnds upper", Time_bnds(2,:)
                sts = NF90_PUT_VAR(ncid, recbnds_varid, Time_bnds(:,:), START = (/ 1, 1 /) , COUNT = (/ 2, SIZE(Time_bnds(1,:)) /) )
                PRINT *, 'sts NF90_PUT_VAR time bnds', sts
  
              END IF
              !print *,'TimeRefArraySubset(:,1)', TimeRefArraySubset(:,1)

              ! TODO
              ! define plev_bnds

              !-----------------------------------------------------------------
              ! write coordinates and height/level information
              
              ! add non-rotated coordinate fields
              sts = NF90_PUT_VAR(ncid, lon_varid, GeoInLonLat(:,:,1), &
                START = (/ 1, 1, 1 /), COUNT = (/ xfocus, yfocus, 1 /) )
              sts = NF90_PUT_VAR(ncid, lat_varid, GeoInLonLat(:,:,2), &
                START = (/ 1, 1, 2 /), COUNT = (/ xfocus, yfocus, 1 /) )

              ! add rotated coordinates
              sts = NF90_PUT_VAR(ncid, rlon_varid, GeoInRLon )
              sts = NF90_PUT_VAR(ncid, rlat_varid, GeoInRLat )
    
              ! add height from NML
              IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) <= 10. ) ) THEN
                sts = NF90_PUT_VAR(ncid, height_varid, height(ivar) )
              END IF

              ! add plev from NML
              IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) > 10. ) ) THEN
                sts = NF90_PUT_VAR(ncid, plev_varid, height(ivar) )
              END IF

              !-----------------------------------------------------------------
  
              sts = NF90_CLOSE(ncid)

              !-----------------------------------------------------------------
  
            END IF ! file exists y/n

!-------------------------------------------------------------------------------
  
          ELSE ! checking whether this is the first pass or previously run

            PRINT *, "this is a subsequent pass, just reading and procecessing stuff"

          END IF

!-------------------------------------------------------------------------------
! match timestep 'it' of WRFin with the subset of the ref time vec which belongs
! to the netCDF file of the year/month/arbitrary timespan currently open to
! receive data
  
          PRINT *, "reading WRF sim. res. = ", TRIM(InVarDataRec(it)), it
          !PRINT *, SIZE(TimeRefArraySubset,1)
          !PRINT *, SHAPE(TimeRefArraySubset)
          !PRINT *, "current transferred input time: ", InDateTimeYear(it), InDateTimeMonth(it), InDateTimeDay(it), InDateTimeHour(it)
  
          counter = 0
          time_match = .FALSE.
          DO i = 1, SIZE(TimeRefArraySubset,1),1 ! time content of the WRF file
  
            counter = counter + 1
  
            !PRINT '(F9.3,1X,F5.0,1X,F3.0,1X,F3.0,1X,F3.0)',TimeRefArraySubset(i,1),TimeRefArraySubset(i,2),TimeRefArraySubset(i,3),TimeRefArraySubset(i,4),TimeRefArraySubset(i,5)
  
            IF ( ( TimeRefArraySubset(i,2) == InDateTimeYear(it)  ) .AND. &
                 ( TimeRefArraySubset(i,3) == InDateTimeMonth(it) ) .AND. &
                 ( TimeRefArraySubset(i,4) == InDateTimeDay(it)   ) .AND. &
                 ( TimeRefArraySubset(i,5) == InDateTimeHour(it)  ) ) THEN
              time_match = .TRUE.
              EXIT
            END IF
  
          END DO

          ! in case the aggregation_individually is set and the desired file
          ! temporal coverage is after the beginning or before the end
          ! of the timespans covered by the WRF input file(s) this functionality
          ! prevents that the last counter value from above is just written to
          ! the file, even without a match; if there is no match then just go to
          ! the next 'it'
          ! with the annual and monthly this is not possible as with every 'it'
          ! there is a check whether a storage file exists
          IF (time_match) THEN
  
          PRINT *, "index, single number, where in the NC file the WRF data is sorted in = ", &
            counter
  
!-------------------------------------------------------------------------------
! read orig WRF outpouts
! there is always a corresponding time-slot in the NC file
! extracted time from above
! "it" controls it all: timestep in the individual WRF file
! there is only one variable at a time under processing

          PRINT *, "*** SOME VARS ALWAYS HAVE TO BE READ: T00, P00 ***"
  
          sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin)
  
          ! HTr: read actual value of base state temperature T00
          sts = NF90_INQ_VARID(ncidin, "T00", t00_varid)
          IF ( sts /= NF90_NOERR ) THEN
            T00(1) = 300.0
          ELSE
            sts = NF90_GET_VAR(ncidin, t00_varid, T00(:), &
              START = (/ it /), COUNT = (/ 1 /) )
          END IF
  
          ! HTr: use actual value of base state pressure P00, if possible
          sts = NF90_INQ_VARID(ncidin, "P00", p00_varid)
          IF ( sts /= NF90_NOERR ) THEN
            P00(1) = 100000.
          ELSE
            sts = NF90_GET_VAR(ncidin, p00_varid, P00(:), &
              START = (/ it /), COUNT = (/ 1 /) )
          END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! SKn: It is not necessary to read all 3D variables for every single output variable.
!      Here it is done to have a more compact structure, but it could be separated 
!      in multiple if-blocks for every variable.
! HTr: I've changed the hard coded '40' levels to nz levels given by the nml-file

          PRINT *, "*** READING OF VARIABLES ***"
          PRINT *, "variable to work on = ", TRIM(var_cmip(ivar))

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

          IF ( (var_cmip(ivar) == "psl") &
                .or. (height(ivar) == 850) &
                .or. (height(ivar) == 700) &
                .or. (height(ivar) == 500) &
                .or. (height(ivar) == 200) &
                .or. (var_cmip(ivar) == "prw") &
                .or. (var_cmip(ivar) == "clwvi") &
                .or. (var_cmip(ivar) == "clivi") &
                .or. (var_cmip(ivar) == "cape")) THEN
  
            PRINT *,'read 3D vars'
  
            ! (het) PH and PHB have "bottom_top_stag" levels, which are nz+1 
            ! ALLOCATE( ph_in( xfocus, yfocus, nz ), STAT=sts )
            ! ALLOCATE( phb_in( xfocus, yfocus, nz ), STAT=sts )
            ! (het) IF (.not. ALLOCATED) commands added, in order to avoid memory problems 
            ! when long-term simulations are converted to ESGF format
            IF (.not. ALLOCATED(pp_in)) ALLOCATE( pp_in( xfocus, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(pb_in)) ALLOCATE( pb_in( xfocus, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(ph_in)) ALLOCATE( ph_in( xfocus, yfocus, nz+1 ), STAT=sts )
            IF (.not. ALLOCATED(phb_in)) ALLOCATE( phb_in( xfocus, yfocus, nz+1 ), STAT=sts )
            IF (.not. ALLOCATED(theta_in)) ALLOCATE( theta_in( xfocus, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(qv_in)) ALLOCATE( qv_in( xfocus, yfocus, nz  ), STAT=sts )
            IF (.not. ALLOCATED(qc_in)) ALLOCATE( qc_in( xfocus, yfocus, nz  ), STAT=sts )
            IF (.not. ALLOCATED(qi_in)) ALLOCATE( qi_in( xfocus, yfocus, nz  ), STAT=sts )
            IF (.not. ALLOCATED(qr_in)) ALLOCATE( qr_in( xfocus, yfocus, nz  ), STAT=sts )
            IF (.not. ALLOCATED(qs_in)) ALLOCATE( qs_in( xfocus, yfocus, nz  ), STAT=sts )
  
            IF (.not. ALLOCATED(t_in)) ALLOCATE( t_in( xfocus, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(ph_fl)) ALLOCATE( ph_fl( xfocus, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(u_in)) ALLOCATE( u_in( xfocus+1, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(v_in)) ALLOCATE( v_in( xfocus, yfocus+1, nz ), STAT=sts )
            IF (.not. ALLOCATED(var3d_in)) ALLOCATE( var3d_in( xfocus, yfocus, nz ), STAT=sts )
  
            IF (.not. ALLOCATED(psl_in)) ALLOCATE( psl_in ( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(t2_in)) ALLOCATE( t2_in ( xfocus, yfocus ), STAT=sts )          
            
            IF (.not. ALLOCATED(t_p)) ALLOCATE( t_p( xfocus, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(qvs)) ALLOCATE( qvs( xfocus, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(cape)) ALLOCATE( cape( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(cin)) ALLOCATE( cin( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(lcl)) ALLOCATE( lcl( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(lfc)) ALLOCATE( lfc( xfocus, yfocus ), STAT=sts )
  
            IF (.not. ALLOCATED(prw)) ALLOCATE( prw( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(clwvi)) ALLOCATE( clwvi( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(clivi)) ALLOCATE( clivi( xfocus, yfocus ), STAT=sts )
  
            IF (.not. ALLOCATED(p_in)) ALLOCATE( p_in( xfocus, yfocus, nz ), STAT=sts )
  ! (het) pp_in is already allocated
  !          ALLOCATE( pp_in( xfocus, yfocus, nz ), STAT=sts )
  ! (het) cahnged to 4 pressure levels
  !          ALLOCATE( var_pl( xfocus, yfocus, 3 ), STAT=sts )
            IF (.not. ALLOCATED(var_pl)) ALLOCATE( var_pl( xfocus, yfocus, 4 ), STAT=sts )
            IF (.not. ALLOCATED(pout)) ALLOCATE( pout( 4 ), STAT=sts ) 
  
            IF (.not. ALLOCATED(sinalpha_in)) ALLOCATE( sinalpha_in( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(cosalpha_in)) ALLOCATE( cosalpha_in( xfocus, yfocus ), STAT=sts )
  
            sts = NF90_INQ_VARID(ncidin, "P", pp_varid)
            sts = NF90_INQ_VARID(ncidin, "PB", pb_varid)
            sts = NF90_INQ_VARID(ncidin, "PH", ph_varid)
            sts = NF90_INQ_VARID(ncidin, "PHB", phb_varid)
            sts = NF90_INQ_VARID(ncidin, "T", theta_varid)
            sts = NF90_INQ_VARID(ncidin, "QVAPOR", qv_varid)
            sts = NF90_INQ_VARID(ncidin, "QCLOUD", qc_varid)
            sts = NF90_INQ_VARID(ncidin, "QICE", qi_varid)
            sts = NF90_INQ_VARID(ncidin, "QRAIN", qr_varid)
            sts = NF90_INQ_VARID(ncidin, "QSNOW", qs_varid)
            sts = NF90_INQ_VARID(ncidin, "U", u_varid)
            sts = NF90_INQ_VARID(ncidin, "V", v_varid)
            sts = NF90_INQ_VARID(ncidin, "SINALPHA", sinalpha_varid)
            sts = NF90_INQ_VARID(ncidin, "COSALPHA", cosalpha_varid)
  
  !         sts = NF90_INQ_VARID(ncidin, "T2", t2_varid)  ! ????????????????????????????????????????????????????????????????????????????????????? is this needed at all here anywhere
  !         sts = NF90_GET_VAR(ncidin, t2_varid, t2_in(:,:), &
  !           START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
            
            sts = NF90_GET_VAR(ncidin, pp_varid, pp_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )          
  
            sts = NF90_GET_VAR(ncidin, pb_varid, pb_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, ph_varid, ph_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, phb_varid, phb_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, theta_varid, theta_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, qv_varid, qv_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, qc_varid, qc_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, qi_varid, qi_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, qr_varid, qr_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, qs_varid, qs_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )          
  
            sts = NF90_GET_VAR(ncidin, u_varid, u_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus+1, yfocus, nz, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, v_varid, v_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus+1, nz, 1 /) )
            
            sts = NF90_GET_VAR(ncidin, sinalpha_varid, sinalpha_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, cosalpha_varid, cosalpha_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ! Total Cloud Fraction [%] 
  
          ELSE IF (var_cmip(ivar) == "clt") THEN
  
            IF (.not. ALLOCATED(cldfra_in)) ALLOCATE( cldfra_in( xfocus, yfocus, nz ), STAT=sts )     
  
            sts = NF90_INQ_VARID(ncidin, "CLDFRA", varid)
   
            sts = NF90_GET_VAR(ncidin, varid, cldfra_in(:,:,:), &
              START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! Precipitation [kg m-2 s-1]
! EURO-CORDEX Jan/2018 meeting, conv+incl. snow graupel, hail, etc.
! TODO CHECK !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! this is without bucket method, this option here is bad
  
          ELSE IF (var_cmip(ivar) == "pr") THEN 
             
            PRINT *, "read iflWRFin " , iflWRFin
            PRINT *, "it = ", it
            PRINT *, "inDimLenRec, number of output times in input = ", InDimLenRec

            ! e.g. it=1..24, #24 fields/file > only 23 everage, field #23 = 22UTC
            IF (it < InDimLenRec) THEN 

              PRINT *, "read rainc and rainnc lower maximum"
  
              IF (.not. ALLOCATED(rainnc_in)) ALLOCATE( rainnc_in ( xfocus, yfocus, 2 ), STAT=sts )
              IF (.not. ALLOCATED(rainc_in)) ALLOCATE( rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "RAINNC", rainnc_varid)
              sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)

              ! read two timesteps to calculate difference
              sts = NF90_GET_VAR(ncidin, rainnc_varid, rainnc_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
              sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )

            ! if the successor file exists, get the data from that file
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN

              PRINT *, "get data from the subsequent file"

              IF (.not. ALLOCATED(rainnc_in)) ALLOCATE( rainnc_in ( xfocus, yfocus, 2 ), STAT=sts )        
              IF (.not. ALLOCATED(rainc_in)) ALLOCATE( rainc_in ( xfocus, yfocus, 2 ), STAT=sts )

              ! get the last available field from the current input file
              sts = NF90_INQ_VARID(ncidin, "RAINNC", rainnc_varid)
              sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)
  
              sts = NF90_GET_VAR(ncidin, rainnc_varid, rainnc_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus,yfocus, 1 /) )
  
              sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1 /) )

              ! just get the next input file
              iflWRFin = fl_wrfout(ifl+1)
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "RAINNC", rainnc_varid)
              sts = NF90_INQ_VARID(ncidin0, "RAINC", rainc_varid)

              ! read the first timestep of the subsequent wrfout file
              sts = NF90_GET_VAR(ncidin0, rainnc_varid, rainnc_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/ xfocus, yfocus,1 /) )
  
              sts = NF90_GET_VAR(ncidin0, rainc_varid, rainc_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/ xfocus, yfocus,1 /) )
   
              sts = NF90_CLOSE(ncidin0)

              ! set to the current wrfout file again
              iflWRFin = fl_wrfout(ifl) 

            ! no further file, nothing can be done
            ! just pass missing values on
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.
  
            END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! Convective Precipitation [kg m-2 s-1]
  
          ELSE IF (var_cmip(ivar) == "prc") THEN
  
  
            IF (it /= InDimLenRec) THEN
  
              ALLOCATE( rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)
  
              sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2/) ) 
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN 
  
              ALLOCATE( rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)
  
              sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1/))
  
              iflWRFin = fl_wrfout(ifl+1) ! set to the previous wrfout file 
                                          ! if it is not the first
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "RAINC", rainc_varid)
  
              sts = NF90_GET_VAR(ncidin0, rainc_varid, rainc_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/ xfocus,yfocus,1 /) ) 
   
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
  
            END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ! Snowfall Flux [kg m-2 s-1]
  
          ELSE IF (var_cmip(ivar) == "prsn") THEN
  
            IF (it /= InDimLenRec) THEN
  
              ALLOCATE( snownc_in ( xfocus, yfocus, 2 ), STAT=sts )
              
              sts = NF90_INQ_VARID(ncidin, "SNOWNC", snownc_varid)
  
              sts = NF90_GET_VAR(ncidin, snownc_varid, snownc_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 2 /) )
           
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN
  
              ALLOCATE( snownc_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "SNOWNC", snownc_varid)
  
              sts = NF90_GET_VAR(ncidin, snownc_varid, snownc_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1/))
  
              iflWRFin = fl_wrfout(ifl+1) ! set to the previous wrfoutfile 
                                          ! if it is not the first
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "SNOWNC", snownc_varid)
  
              sts = NF90_GET_VAR(ncidin0, snownc_varid, snownc_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/xfocus,yfocus,1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
  
            END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ! Surface Snow Melt [kg m-2 s-1]
  
          ELSE IF (var_cmip(ivar) == "snm") THEN
  
            IF (it /= InDimLenRec) THEN
  
              ALLOCATE( acsnom_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "ACSNOM", acsnom_varid)
  
              sts = NF90_GET_VAR(ncidin, acsnom_varid, acsnom_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
              print*, sts
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN
  
              ALLOCATE( acsnom_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "ACSNOM", acsnom_varid)
  
              sts = NF90_GET_VAR(ncidin, acsnom_varid, acsnom_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              iflWRFin = fl_wrfout(ifl+1) ! set to the previous wrfoutfile 
                                          ! if it is not the first
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
              
              sts = NF90_INQ_VARID(ncidin0, "ACSNOM", acsnom_varid)
            
              sts = NF90_GET_VAR(ncidin0, acsnom_varid, acsnom_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus,1 /) )
            
              sts = NF90_CLOSE(ncidin0)
            
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
              
            END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          ELSE IF (var_cmip(ivar) == "evspsbl") THEN
  
            IF (it /= InDimLenRec) THEN
  
              ALLOCATE( sfcevp_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "SFCEVP", sfcevp_varid)
  
              sts = NF90_GET_VAR(ncidin, sfcevp_varid, sfcevp_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
            
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN
  
              ALLOCATE( sfcevp_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "SFCEVP", sfcevp_varid)
  
              sts = NF90_GET_VAR(ncidin, sfcevp_varid, sfcevp_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              iflWRFin = fl_wrfout(ifl+1) ! set to the previous wrfoutfile 
                                          ! if it is not the first 
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "SFCEVP", sfcevp_varid)
  
              sts = NF90_GET_VAR(ncidin0, sfcevp_varid, sfcevp_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
  
            END IF 
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          ELSE IF (var_cmip(ivar) == "evspsblpot") THEN
  
            IF (it /= InDimLenRec) THEN         
  
              ALLOCATE( potevp_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "POTEVP", potevp_varid)
  
              sts = NF90_GET_VAR(ncidin, potevp_varid, potevp_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN
  
              ALLOCATE( potevp_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "POTEVP", potevp_varid)
  
              sts = NF90_GET_VAR(ncidin, potevp_varid, potevp_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              iflWRFin = fl_wrfout(ifl+1) ! set to the previous wrfoutfile 
                                          ! if it is not the first
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "POTEVP", potevp_varid)
  
              sts = NF90_GET_VAR(ncidin0, potevp_varid, potevp_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
  
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
  
            END IF 
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          ELSE IF (var_cmip(ivar) == "mrros") THEN
  
            IF (it /= InDimLenRec) THEN
  
              ALLOCATE( sfroff_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "SFROFF", sfroff_varid)
  
              sts = NF90_GET_VAR(ncidin, sfroff_varid, sfroff_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN
  
              ALLOCATE( sfroff_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "SFROFF", sfroff_varid)
  
              sts = NF90_GET_VAR(ncidin, sfroff_varid, sfroff_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              iflWRFin = fl_wrfout(ifl+1) ! set to the previous wrfoutfile 
                                          ! if it is not the first
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
              
              sts = NF90_INQ_VARID(ncidin0, "SFROFF", sfroff_varid)
  
              sts = NF90_GET_VAR(ncidin0, sfroff_varid, sfroff_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
  
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
  
            END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          ELSE IF (var_cmip(ivar) == "mrro") THEN
  
            IF (it /= InDimLenRec) THEN
  
              ALLOCATE( sfroff_in ( xfocus, yfocus, 2 ), STAT=sts )
              ALLOCATE( udroff_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "SFROFF", sfroff_varid)
              sts = NF90_INQ_VARID(ncidin, "UDROFF", udroff_varid)
  
              sts = NF90_GET_VAR(ncidin, sfroff_varid, sfroff_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
              sts = NF90_GET_VAR(ncidin, udroff_varid, udroff_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN
  
              ALLOCATE( sfroff_in ( xfocus, yfocus, 2 ), STAT=sts )
              ALLOCATE( udroff_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "SFROFF", sfroff_varid)
              sts = NF90_INQ_VARID(ncidin, "UDROFF", udroff_varid)
  
              sts = NF90_GET_VAR(ncidin, sfroff_varid, sfroff_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              sts = NF90_GET_VAR(ncidin, udroff_varid, udroff_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              iflWRFin = fl_wrfout(ifl+1) ! set to the previous wrfoutfile 
                                          ! if it is not the first
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "SFROFF", sfroff_varid)
              sts = NF90_INQ_VARID(ncidin, "UDROFF", udroff_varid)
  
              sts = NF90_GET_VAR(ncidin0, sfroff_varid, sfroff_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              sts = NF90_GET_VAR(ncidin0, udroff_varid, udroff_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
  
            END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          ELSE IF ((var_cmip(ivar) == "rsds") &
              .or. (var_cmip(ivar) == "rlds") &
              .or. (var_cmip(ivar) == "rsus") &
              .or. (var_cmip(ivar) == "rlus") &
              .or. (var_cmip(ivar) == "rlut") &
              .or. (var_cmip(ivar) == "rsdt") &
              .or. (var_cmip(ivar) == "rsut") &
              .or. (var_cmip(ivar) == "hfss") &
              .or. (var_cmip(ivar) == "hfls")) THEN
  
            IF (it /= InDimLenRec) THEN
  
              ALLOCATE( rad_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
  
              sts = NF90_GET_VAR(ncidin, varid, rad_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN
  
              ALLOCATE( rad_in ( xfocus, yfocus, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
  
              sts = NF90_GET_VAR(ncidin, varid, rad_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              iflWRFin = fl_wrfout(ifl+1) ! set to the previous wrfoutfile 
                                          ! if it is not the first
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, TRIM(var_wrf(ivar)), varid)
  
              sts = NF90_GET_VAR(ncidin0, varid, rad_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
  
            END IF
  
            print*, var_cmip(ivar), rad_in(50,50,1), rad_in(50,50,2)
            print*, 'difference in J m-2', (rad_in(50,50,2) - rad_in(50,50,1))
            print*, 'in mean W m-2', (rad_in(50,50,2) - rad_in(50,50,1))/ (dtHours*3600.)
  
            ! alternative: since accumulated values as read above get so large in 
            ! long term simulations that their differences loose accuracy, use 
            ! instantaneous values instead and calculate means
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          ELSE IF (var_cmip(ivar) == "mrso") THEN
  
            IF (it /= InDimLenRec) THEN
  
              ALLOCATE( smois_in( xfocus, yfocus, 4, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, "SMOIS", varid)
  
              sts = NF90_GET_VAR(ncidin, varid, smois_in(:,:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), &
                COUNT = (/ xfocus, yfocus, 4, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_wrfout)) ) THEN
  
              ALLOCATE( smois_in ( xfocus, yfocus, 4, 2 ), STAT=sts )
  
              sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
              
              sts = NF90_GET_VAR(ncidin, varid, smois_in(:,:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
  
              iflWRFin = fl_wrfout(ifl) ! set to the previous wrfoutfile 
                                        ! if it is not the first 
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, TRIM(var_wrf(ivar)), varid)
  
              sts = NF90_GET_VAR(ncidin0, varid, smois_in(:,:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_wrfout(ifl)  !set to the current wrfout file again
  
            END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          ELSE IF (var_cmip(ivar) == "sfcWind") THEN
  
            IF (.not. ALLOCATED(u10_in)) ALLOCATE( u10_in ( xfocus, yfocus ), STAT=sts ) 
            IF (.not. ALLOCATED(v10_in)) ALLOCATE( v10_in ( xfocus, yfocus ), STAT=sts )
  
            sts = NF90_INQ_VARID(ncidin, "U10", u10_varid)
  
            sts = NF90_INQ_VARID(ncidin, "V10", v10_varid)
  
            sts = NF90_GET_VAR(ncidin, u10_varid, u10_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, v10_varid, v10_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          ELSE IF ((var_cmip(ivar) == "uas") .or. (var_cmip(ivar) == "vas")) THEN
  
            IF (.not. ALLOCATED(u10_in)) ALLOCATE( u10_in ( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(v10_in)) ALLOCATE( v10_in ( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(sinalpha_in)) ALLOCATE( sinalpha_in( xfocus, yfocus ), STAT=sts )
            IF (.not. ALLOCATED(cosalpha_in)) ALLOCATE( cosalpha_in( xfocus, yfocus ), STAT=sts )
  
            sts = NF90_INQ_VARID(ncidin, "U10", u10_varid)
            sts = NF90_INQ_VARID(ncidin, "V10", v10_varid)
            sts = NF90_INQ_VARID(ncidin, "SINALPHA", sinalpha_varid)
            sts = NF90_INQ_VARID(ncidin, "COSALPHA", cosalpha_varid)
  
            sts = NF90_GET_VAR(ncidin, u10_varid, u10_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, v10_varid, v10_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, sinalpha_varid, sinalpha_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
  
            sts = NF90_GET_VAR(ncidin, cosalpha_varid, cosalpha_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )          
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! this is all variables which are solely based on the namelist for whom no 
! processing is needed whatsoever
  
          ELSE

            PRINT *, "variable to read/write (no additional processing) = ", var_wrf(ivar)
  
            sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
  
            sts = NF90_GET_VAR(ncidin, varid, data_in(:,:), &
              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
  
          END IF
  
          sts = NF90_CLOSE(ncidin)

!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! some analysis of the data
  
          PRINT *, "*** STATISTICS BEFORE PROCESSING OF VARIABLES ***"
          PRINT *, "(useless if more data is stored in other vars)"

          print *, "shape of array" , SHAPE(data_in)
          print *, "size of array" , SIZE(data_in)
          stat_mean = SUM(data_in(:,:))/SIZE(data_in(:,:))
          PRINT *, "mean of array", stat_mean

!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! this is where the real processing takes place 
! if nothing is to be calculated or scaled, etc., then the variables are just
! passed on to the write section in data_in 
  
          PRINT *, "*** PROCESSING OF VARIABLES ***"

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! ***psl***   ***vars on pressure levels***     
  
          IF ( (var_cmip(ivar) == "psl") .OR. &
               (height(ivar) == 850) .OR. &
               (height(ivar) == 700) .OR. &
               (height(ivar) == 500) .OR. &
               (height(ivar) == 200) ) THEN
  
            DO nl = 1,40-1
              ph_fl(:,:,nl) = ((ph_in(:,:,nl)+phb_in(:,:,nl))+(ph_in(:,:,nl+1)+phb_in(:,:,nl+1)))/2./9.81
            END DO
  
            t_in(:,:,:) = (theta_in(:,:,:)+300.)*((pp_in(:,:,:)+pb_in(:,:,:))/100000.)**(287./1004.)
  
            psl_in(:,:) = (pp_in(:,:,1)+pb_in(:,:,1))*((t_in(:,:,1)*(1.+0.61*qv_in(:,:,1))+0.0065*ph_fl(:,:,1))/(t_in(:,:,1)*(1+0.61*qv_in(:,:,1))))**(9.81/(287.*0.0065))
  
            pout = (/ 85000.,50000.,20000. /)
  
            p_in = pp_in+pb_in
  
            !DO np = 1,3     !SKn: could loop over heigts per variable or calculate t850, t500, t200 as individual variables 
  
            IF (height(ivar) == 850) THEN
              np = 1
            ELSE IF (height(ivar) == 700) THEN
              np = 2
            ELSE IF (height(ivar) == 500) THEN
              np = 3
            ELSE IF (height(ivar) == 200) THEN
              np = 4
            END IF
  
            !print *,'np', np      
  
            IF ( (var_cmip(ivar) == "ta850") .or. (var_cmip(ivar) == "ta500") .or. (var_cmip(ivar) == "ta200") ) THEN
              var3d_in(:,:,:) = t_in(:,:,:)
              !print*, 'var3d_in(50,50,10)', var3d_in(50,50,10), var_cmip(ivar)
            ELSE IF ( (var_cmip(ivar) == "hus850") ) THEN
              var3d_in(:,:,:) = qv_in(:,:,:)
              !print*, 'var3d_in(50,50,10)', var3d_in(50,50,10), var_cmip(ivar)
            ELSE IF ( (var_cmip(ivar) == "ua850") .or. (var_cmip(ivar) == "ua500") .or. (var_cmip(ivar) == "ua200") ) THEN
              DO i = 1,xfocus
              var3d_in(i,:,:) = (u_in(i,:,:)+u_in(i+1,:,:))/2.*cosalpha_in(:,:) - (v_in(i,:,:)+v_in(i+1,:,:))/2.*sinalpha_in(:,:) !rotate to earth grid
              END DO
              !print*, 'var3d_in(50,50,10)', var3d_in(50,50,10), var_cmip(ivar)
            ELSE IF ( (var_cmip(ivar) == "va850") .or. (var_cmip(ivar) == "va500") .or. (var_cmip(ivar) == "va200") ) THEN
              DO j = 1,yfocus
              var3d_in(:,j,:) = (v_in(:,j,:)+v_in(:,j+1,:))/2.*cosalpha_in(:,:) + (u_in(i,:,:)+u_in(i+1,:,:))/2.*sinalpha_in(:,:) !rotate to earth grid
              END DO
              !print*, 'var3d_in(50,50,10)', var3d_in(50,50,10), var_cmip(ivar)
            ELSE IF ( (var_cmip(ivar) == "zg500") .or. (var_cmip(ivar) == "zg200") ) THEN
              var3d_in(:,:,:) = ph_fl(:,:,:)
              !print*, 'var3d_in(50,50,10)', var3d_in(50,50,10), var_cmip(ivar)
            END IF
  
            var_pl = mv
  
            IF (var_cmip(ivar) == "psl") THEN
              data_in(:,:) = psl_in(:,:)
  
            ELSE
              DO i = 1,xfocus 
                DO j = 1,yfocus
                  DO nl = 1,40 - 1
                    IF (pout(np).lt.p_in(i,j,nl) .and. pout(np).gt.p_in(i,j,nl+1)) then
                    
                      !slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/ (p_in(i,j,nl)-p_in(i,j,nl+1))
                      !var_pl(i,j,np) = var3d_in(i,j,nl+1) + slope* (pout(np)-p_in(i,j,nl+1))
                      slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/(LOG(p_in(i,j,nl))-LOG(p_in(i,j,nl+1)))
                      var_pl(i,j,np) = var3d_in(i,j,nl+1) + slope*(LOG(pout(np))-LOG(p_in(i,j,nl+1)))
                    END IF
                  END DO
                END DO
              END DO
              !END DO
              data_in(:,:) = var_pl(:,:,np)
            END IF 
  
          END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! ***prw, clwvi, clivi***
  
          IF ( (var_cmip(ivar) == "prw") ) THEN     
  
            t_in(:,:,:) = (theta_in(:,:,:)+300.)*((pp_in(:,:,:)+pb_in(:,:,:))/100000.)**(R/cp)
            p_in = pp_in+pb_in
  
            prw(:,:) = 0.
  
            DO nl = 1,nz - 1
  
              prw(:,:) = prw(:,:) + qv_in(:,:,nl) * p_in(:,:,nl)/(R*t_in(:,:,nl)) * ((ph_in(:,:,nl+1)+phb_in(:,:,nl+1)) - (ph_in(:,:,nl)+phb_in(:,:,nl)))/9.81
  
              data_in(:,:) = prw(:,:)            
  
            END DO
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          IF ( (var_cmip(ivar) == "clwvi") ) THEN
  
            t_in(:,:,:) = (theta_in(:,:,:)+300.)*((pp_in(:,:,:)+pb_in(:,:,:))/100000.)**(R/cp)
            p_in = pp_in+pb_in          
  
            clwvi(:,:) = 0.
  
            DO nl = 1,nz - 1
  
              clwvi(:,:) = clwvi(:,:) + (qc_in(:,:,nl) + qi_in(:,:,nl) + qr_in(:,:,nl) + qs_in(:,:,nl) ) * p_in(:,:,nl)/(R*t_in(:,:,nl)) * ((ph_in(:,:,nl+1)+phb_in(:,:,nl+1)) - (ph_in(:,:,nl)+phb_in(:,:,nl)))/9.81
              
            END DO
  
            data_in(:,:) = clwvi(:,:) 
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          IF ( (var_cmip(ivar) == "clivi")) THEN
  
            t_in(:,:,:) = (theta_in(:,:,:)+300.)*((pp_in(:,:,:)+pb_in(:,:,:))/100000.)**(R/cp)
            p_in = pp_in+pb_in
  
            clivi(:,:) = 0.
  
            DO nl = 1,nz - 1
  
              clivi(:,:) = clivi(:,:) + (qi_in(:,:,nl) + qs_in(:,:,nl)) * p_in(:,:,nl)/(R*t_in(:,:,nl)) * ((ph_in(:,:,nl+1)+phb_in(:,:,nl+1)) - (ph_in(:,:,nl)+phb_in(:,:,nl)))/9.81
              
            END DO
  
            data_in(:,:) = clivi(:,:)
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***cape***
  
          IF ( (var_cmip(ivar) == "cape") ) THEN
  
            t_in(:,:,:) = (theta_in(:,:,:)+300.)*((pp_in(:,:,:)+pb_in(:,:,:))/100000.)**(287./1004.)
  
            p_in = pp_in+pb_in          
  
            t_p(:,:,1) = t_in(:,:,1)
  
            cape(:,:) = 0.
            cin(:,:) = 0.
            lcl(:,:) = -999.
            lfc(:,:) = -999.
  
            DO i = 1,xfocus
              DO j = 1,yfocus
                DO nl = 1,nz-1
  
                  qvs(i,j,nl) = 0.622*a*exp(b*(t_p(i,j,nl)-c)/(t_p(i,j,nl)-d))/p_in(i,j,nl)
  
                  IF (qvs(i,j,nl) .gt. qv_in(i,j,1)) THEN !dry adiabatic ascent
                 
                    t_p(i,j,nl+1) = (theta_in(i,j,1)+300.)*(p_in(i,j,nl+1)/100000.)**(R/cp)   
  
                  ELSE IF (qvs(i,j,nl) .lt. qv_in(i,j,1)) THEN ! moist adiabatic ascent
  
                    IF (lcl(i,j) .eq. -999) THEN    ! lifting condensation level
                      lcl(i,j) = p_in(i,j,nl)
                    END IF
  
                    t_ii = t_p(i,j,nl)
  
                    DO ii = 1,10  !solve iteratively
  
                      qvs(i,j,nl+1) = 0.622*a*exp(b*(t_ii-c)/(t_ii-d))/p_in(i,j,nl+1)
  
                      t_ii = t_ii - (t_ii*(100000./p_in(i,j,nl+1))**(R/cp)*exp(L*qvs(i,j,nl+1)/(cp*t_ii)) &
                             - (t_p(i,j,nl)*(100000./p_in(i,j,nl))**(R/cp)*exp(L*qvs(i,j,nl)/(cp*t_p(i,j,nl))))) &
                             / ( (100000./p_in(i,j,nl+1))**(R/cp)*exp(n/(p_in(i,j,nl+1)*t_ii)*exp(b*(t_ii-c)/(t_ii-d))) * &
                                 (1 - (n/p_in(i,j,nl+1)*exp(b*(t_ii-c)/(t_ii-d))*(t_ii*(t_ii-b*c)+(b-2)*d*t_ii+d**2))/(t_ii*(d-t_ii)**2)) )
  
                    END DO
  
                      !print*, 'thetae(i,j,nl)',(t_p(i,j,nl)*(100000./p_in(i,j,nl))**(R/cp)*exp(L*qvs(i,j,nl)/(cp*t_p(i,j,nl))))
                      !print*,'thetae(i.j.nl+1)',(t_ii*(100000./p_in(i,j,nl+1))**(R/cp)*exp(L*qvs(i,j,nl+1)/(cp*t_ii))) 
  
                    
                    t_p(i,j,nl+1) = t_ii
  
                    !print*, nl, 'moist', t_p(i,j,nl+1), t_in(i,j,nl+1), (t_p(i,j,nl+1)-t_in(i,j,nl+1))
  
                  END IF                 
         
  
                  IF (t_p(i,j,nl) .gt. t_in(i,j,nl)) THEN
                 
                    IF (lfc(i,j) .eq. -999) THEN   ! level of free convection
                      lfc(i,j) = p_in(i,j,nl)
                    END IF
  
                    cape(i,j) = cape(i,j) + (t_p(i,j,nl) - t_in(i,j,nl)) / t_in(i,j,nl) * ((phb_in(i,j,nl)+ph_in(i,j,nl))-(phb_in(i,j,nl-1)+ph_in(i,j,nl-1)))
  
                    !print*, 'nl, cape(i,j)', nl, cape(i,j)
  
                  ELSE IF ( (t_p(i,j,nl) .lt. t_in(i,j,nl)) .and. (cape(i,j) .eq. 0.) )  THEN   !convective inhibition 
               
                    cin(i,j) = cin(i,j) + (t_in(i,j,nl) - t_p(i,j,nl)) / t_in(i,j,nl) * ((phb_in(i,j,nl)+ph_in(i,j,nl))-(phb_in(i,j,nl-1)+ph_in(i,j,nl-1))) 
  
                    !print*, 'nl, cin(i,j)', nl, cin(i,j)
  
                  END IF
  
  
                END DO
              END DO
            END DO
  
            data_in(:,:) = cape(:,:)
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***clt***
  
          IF (var_cmip(ivar) == "clt") THEN
  
            IF (.not. ALLOCATED(cldfra_inv)) ALLOCATE( cldfra_inv( xfocus, yfocus ), STAT=sts )
  
            cldfra_inv(:,:) = 1.
  
            !DO nl = 1,40 - 1
            DO i = 1,xfocus
              DO j = 1,yfocus
                IF (maxval(cldfra_in(i,j,:)) .lt. 0.99) THEN
                  cldfra_inv(i,j) = 1.
                  DO nl = 2,nz
                    cldfra_inv(i,j) = cldfra_inv(i,j)*(1- max(cldfra_in(i,j,nl),cldfra_in(i,j,nl-1))/(1-cldfra_in(i,j,nl-1))) !unit [%] 
                  END DO
                ELSE 
                  cldfra_inv(i,j) = 0.  
                END IF
              END DO
            END DO
            !END DO
  
            data_in(:,:) = (1 - cldfra_inv(:,:))*100.
  
            WHERE (data_in .gt. 100.) data_in = 100.
            WHERE (data_in .lt. 0.) data_in = 0.
  
          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! pr
! [mm/3h] -> [kg m-2 s-1]
! t2-t1, no bucket used
! InDimLenRec - 1

          IF (var_cmip(ivar) == "pr") THEN

            IF (calc) THEN
  
              data_in(:,:) = ( ( rainnc_in(:,:,2) + rainc_in(:,:,2) ) - &
                               ( rainnc_in(:,:,1) + rainc_in(:,:,1) ) ) / &
                               ( dtHours * 3600. )

            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***prc***
  
          IF (var_cmip(ivar) == "prc") THEN
  
            data_in(:,:) = (rainc_in(:,:,2) - rainc_in(:,:,1))/(dtHours*3600.) !unit [mm/3hr] to [kg m-2 s-1]
  
          END IF
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***prsn***
  
          IF (var_cmip(ivar) == "prsn") THEN
  
            data_in(:,:) = (snownc_in(:,:,2) - snownc_in(:,:,1))/(dtHours*3600.) !unit [mm/3hr] to [kg m-2 s-1]
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***snm***
  
          IF (var_cmip(ivar) == "snm") THEN
  
            data_in(:,:) = (acsnom_in(:,:,2) - acsnom_in(:,:,1))/(dtHours*3600.) !unit [kg m-2 /3hr] to [kg m-2 s-1]
  
          END IF
          
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***evspsbl***
  
          IF (var_cmip(ivar) == "evspsbl") THEN
  
            data_in(:,:) = (sfcevp_in(:,:,2) - sfcevp_in(:,:,1))/(dtHours*3600.) !unit [kg m-2 /3hr] to [kg m-2 s-1]
  
          END IF
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***evspblpot**
  
          IF (var_cmip(ivar) == "evspsblpot") THEN
  
            data_in(:,:) = (potevp_in(:,:,2) - (potevp_in(:,:,1)))/L   !unit [W m-2]/[J kg-1] -> [kg m-2 s-1]
  
          ! THERE IS STH WRONG WITH THE UNITS: WRF's POTEVP is accumulated and declared to be in W m-2. 
          ! It doesen't make sense to accumulate in W m-2, but even if assume it as J m-2 or derive kg m-2 
          ! by using latent heat of vaporization you never get values that have a reasonable magnitude...
  
          END IF
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***mrros***
  
          IF (var_cmip(ivar) == "mrros") THEN
  
            data_in(:,:) = (sfroff_in(:,:,2) - sfroff_in(:,:,1))/(dtHours*3600.)       !unit [mm/3hr] to [kg m-2 s-1]
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***mrro***
  
          IF (var_cmip(ivar) == "mrro") THEN
  
            data_in(:,:) = ((sfroff_in(:,:,2) - sfroff_in(:,:,1)) + (udroff_in(:,:,2) - udroff_in(:,:,1)))/(dtHours*3600.) !unit [mm/3hr] to [kg m-2 s-1]
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***rsds, rlds, rsus, rlus***
  
          IF ( (var_cmip(ivar) == "rsds") .or. (var_cmip(ivar) == "rlds")      &
               .or. (var_cmip(ivar) == "rsus") .or. (var_cmip(ivar) == "rlus") &
               .or. (var_cmip(ivar) == "hfss") .or. (var_cmip(ivar) == "hfls")) THEN
    
            IF (TRIM(fnNMLvar(ivarnml)) == "runctrl.vars.nml_radiation") THEN
             
              data_in(:,:) = (rad_in(:,:,2) - rad_in(:,:,1)) /(dtHours*3600.)       ! take difference of accumulated values
  
            ELSE IF (TRIM(fnNMLvar(ivarnml)) == "runctrl.vars.nml_radiation_alternative") THEN
             
              data_in(:,:) = (rad_in(:,:,2) + rad_in(:,:,1)) / 2.              ! take mean of instantaneous values
  
            END IF 
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***mrso***
  
          IF (var_cmip(ivar) == "mrso") THEN
    
            data_in(:,:) = ((smois_in(:,:,1,1)*0.1 + smois_in(:,:,2,1)*0.3 + smois_in(:,:,3,1)*0.6 + smois_in(:,:,4,1)*1.0 ) + &
                           (smois_in(:,:,1,2)*0.1 + smois_in(:,:,2,2)*0.3 + smois_in(:,:,3,2)*0.6 + smois_in(:,:,4,2)*1.0 ))/2.*1000. 
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***snc,sic***
  
          IF ( (var_cmip(ivar) == "snc") .or. (var_cmip(ivar) == "sic") ) THEN
  
            data_in(:,:) = data_in(:,:)*100. !unit [] to [%]
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***sfcWind***
  
          IF (var_cmip(ivar) == "sfcWind") THEN
  
            data_in(:,:) = (u10_in(:,:)**2 + v10_in(:,:)**2)**0.5 
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  !       ***uas***
  
          IF (var_cmip(ivar) == "uas") THEN 
  
            data_in(:,:) = u10_in(:,:)*cosalpha_in(:,:) - v10_in(:,:)*sinalpha_in(:,:) ! rotate to earth grid
  
          END IF
  
  !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
          IF (var_cmip(ivar) == "vas")  THEN
  
            data_in(:,:) = v10_in(:,:)*cosalpha_in(:,:) + u10_in(:,:)*sinalpha_in(:,:) ! rotate to earth grid
  
          END IF

!-------------------------------------------------------------------------------
! write data to netCDF file

          PRINT *, ""
          PRINT *, "*** WRITE DATA TO netCDF ***"
          PRINT *, TRIM(pn_out) // "/" // TRIM(fn_out)
          PRINT *, TRIM(var_cmip(ivar)), xfocus, yfocus, counter, ncid, x_varid
  
          sts = NF90_OPEN( TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) // "/" // TRIM(fn_out), NF90_WRITE, ncid )

          ! file must exist, just from the logic of the code, nevertheless: test
          IF (sts/=0) EXIT
          
          sts = NF90_INQ_VARID(ncid, TRIM(var_cmip(ivar)), x_varid)
          PRINT *, "NF90_OPEN",  sts
  
            PRINT *, 'NF90_INQ_VARID', ncid
            PRINT *, 'var_cmip(ivar)', var_cmip(ivar)
            PRINT *, 'x_varid', x_varid
            PRINT *, 'counter/offset', counter
            PRINT *, 'xfocus', xfocus
            PRINT *, 'yfocus', yfocus
    
            ! not needed anymore, always store 3D only, have height information
            ! in the coordinates
            !IF ( height(ivar) /= -999 ) THEN
            !  sts = NF90_PUT_VAR( ncid, x_varid, data_in(:,:),  &
            !    START=(/ 1, 1, 1, counter /), COUNT = (/ xfocus, yfocus, 1, 1 /) )
            !ELSE
              sts = NF90_PUT_VAR( ncid, x_varid, data_in(:,:),  &
                START=(/ 1, 1, counter /), COUNT = (/ xfocus, yfocus, 1 /) )
            !END IF
    
            PRINT *, 'NF90_PUT_VAR', sts
            PRINT *, 'ncid', ncid
            PRINT *, 'x_varid', x_varid
            PRINT *, 'some exmple output in the middle of the domain', data_in(xfocus/2:(xfocus/2+2),yfocus/2:(yfocus/2+2))

          sts = NF90_CLOSE(ncid)
          PRINT *, "NF90_CLOSE",  sts

!-------------------------------------------------------------------------------

          ELSE

            ! tested this: just define file with a temporal coverage outside the
            ! range of the input file: create file, loop over the inputs,
            ! nothing happens, no false sorting in 
            PRINT *, "no time match", time_match

          END IF

!-------------------------------------------------------------------------------
  
        END DO ! it i-time WRF indiv file loop
  
!-------------------------------------------------------------------------------
! next WRF file may contain different number of output intervals

        DEALLOCATE(InVarDataRec)

        DEALLOCATE(InDateTimeYear)
        DEALLOCATE(InDateTimeMonth)
        DEALLOCATE(InDateTimeDay)
        DEALLOCATE(InDateTimeHour)
        DEALLOCATE(InDateTimeMinute)
        DEALLOCATE(InDateTimeSecond)

        DEALLOCATE(InDateTimeCombined)

!-------------------------------------------------------------------------------

        PRINT *, "-----------------------------------------------------------"
        CALL CPU_TIME(cpuTe)
        PRINT '("CPU timing for the processing of one WRF file and one output variable = ",F10.1," s")',cpuTe-cpuTs

      END DO ! ifl - specific WRF input file, filelist loop

      ! must be reset, when moving to new var, always check file existance
      InDateTimeYearPrev = 0
      InDateTimeMonthPrev = 0
      prevpass = 0 ! ?????????????????????? one level inside????

    END DO ! ivar - variable loop

  END DO ! ivarnml - namelist loop ! TODO fix indention

END DO ! ifrq - different temporal aggregations

!===============================================================================

END PROGRAM ppWRFCMIP

!===============================================================================

SUBROUTINE GenerateFilelist

USE FilelistHandling

IMPLICIT NONE

CHARACTER (len = 200) :: ifl
INTEGER :: i, IOstatus, nfl, AllocateStatus

OPEN(2,FILE=tmpfileFL,STATUS='old')

i = 0
DO
  READ(2,FMT='(a)',IOSTAT=IOstatus) ifl
  IF (IOstatus/=0) EXIT
  i = i + 1
END DO
nfl = i
PRINT *, "number of matching files contained in filelist = ", nfl

IF (ft == 0) THEN
  ALLOCATE(fl_wrfout(nfl), STAT=AllocateStatus)
END IF
IF (ft == 1) THEN
  ALLOCATE(fl_wrfxtr(nfl), STAT=AllocateStatus)
END IF
IF (AllocateStatus /= 0) STOP "*** Not enough memory ***"

REWIND(2)
DO i = 1,nfl
  IF (ft == 0) THEN
    READ(2,FMT='(a)') fl_wrfout(i)
  END IF
  IF (ft == 1) THEN
    READ(2,FMT='(a)') fl_wrfxtr(i)
  END IF
END DO

CLOSE(2)

END SUBROUTINE GenerateFilelist

!===============================================================================

SUBROUTINE CreateRefTimeArray(dt)

USE RefTimeVecs
USE NamelistHandling

IMPLICIT NONE

CHARACTER (LEN = 3), INTENT(IN) :: dt

INTEGER :: i, j, k, l, counter
REAL(KIND=8) :: dtDecDay
INTEGER :: tstotYYYY, tstotMM, tstotDD, tstotHH
INTEGER :: tetotYYYY, tetotMM, tetotDD, tetotHH
!!!INTEGER :: ndpy
INTEGER, DIMENSION(12) :: ndpm
!IF (noCMOR) THEN
!  INTEGER :: ndOverall = 0 ! (n)umber of (d)ays
!ELSE
INTEGER :: ndOverall = 31 ! initialized with the 31 days of Dec 1949, this is DIRTY
!END IF
INTEGER :: ntspd ! number of timesteps per time-interval

PRINT *, "CreateRefTimeArray"
PRINT *, dt

SELECT CASE (dt)
CASE ('3hr')
  dtDecDay = 0.125
  ntspd = 1.0 / dtDecDay ! (n)umber (t)ime(s)teps (p)er (d)ay
CASE ('1hr')
  dtDecDay = 1.0 / 24.0_8
  ntspd = 24.
CASE DEFAULT
  PRINT *, "invalid time interval specified"
  STOP
END SELECT

! "tstot" contains the absolute starting point, 1949-12-01_00:00:00
READ( tstot, '(I4,1X,I2,1X,I2,1X,I2)' ) tstotYYYY, tstotMM, tstotDD, tstotHH
READ( tetot, '(I4,1X,I2,1X,I2,1X,I2)' ) tetotYYYY, tetotMM, tetotDD, tetotHH

! get the overall number of days within the considered timespan
DO i=tstotYYYY+1,tetotYYYY,1
!DO i=tstotYYYY,tetotYYYY,1
  ndOverall = ndOverall + CheckForLeapyear( i )
END DO
PRINT *, "number of days, overall = ", ndOverall

ALLOCATE( TimeRefArray( ndOverall*ntspd, 5 ) ) ! index, y, m, d, h         y,x
!PRINT *, "size and shape of the TimRefArray = ", SIZE(TimeRefArray), &
!  SHAPE(TimeRefArray)

! fill up the decimal days
! xxxxxxxxxxxxxxxxx  critical: maybe this is the part that makes the exact timespan definition
DO i=0,ndOverall*ntspd-1,1
  !TimeRefArray( i+1, 1 ) = i * dtDecDay ! original, also used by HTr
  TimeRefArray( i+1, 1 ) = i / ntspd + mod(i,ntspd) * dtDecDay ! refined by SKn
END DO

! handle the Dec 1949, too complicated to have this in the upcoming loop
! overall start is at 1949-12-01_00:00:00
!TimeRefArray( 1:31*ntspd, 2 ) = 1949.
!TimeRefArray( 1:31*ntspd, 3 ) = 12.
! (het): the wrfout files do not always start in 1949...
TimeRefArray( 1:31*ntspd, 2 ) = REAL(tstotYYYY)
TimeRefArray( 1:31*ntspd, 3 ) = REAL(tstotMM)


DO i=1,31,1
  TimeRefArray( i*ntspd-(ntspd-1):i*ntspd, 4 ) = i
  TimeRefArray( i*ntspd-(ntspd-1):i*ntspd, 5 ) = (/ (j, j=0, 24-24/ntspd , 24/ntspd) /) !00  03 06 09 12 15 18 21
END DO
print*, "(/ (j, j=0, 24-24/ntspd , 24/ntspd) /)", (/ (j, j=0, 24-24/ntspd , 24/ntspd) /)
! add the rest of the Y M D H information
counter = 1
DO i=tstotYYYY+1,tetotYYYY,1
  IF ( CheckForLeapyear( i ) == 366 ) THEN
    ndpm = (/31,29,31,30,31,30,31,31,30,31,30,31/)
  ELSE
    ndpm = (/31,28,31,30,31,30,31,31,30,31,30,31/)
  END IF
  DO j=1,12,1
    ! sort in on daily basis
    DO k=1,ndpm(j)

!      TimeRefArray( 31*24/ntspd + counter*ntspd-(ntspd-1) : 31*24/ntspd + counter*ntspd , 2) = i
!      TimeRefArray( 31*24/ntspd + counter*ntspd-(ntspd-1) : 31*24/ntspd + counter*ntspd , 3) = j
!      TimeRefArray( 31*24/ntspd + counter*ntspd-(ntspd-1) : 31*24/ntspd + counter*ntspd , 4) = k
!      TimeRefArray( 31*24/ntspd + counter*ntspd-(ntspd-1) : 31*24/ntspd + counter*ntspd , 5) = (/(l, l=0, 24-24/ntspd , 24/ntspd) /)

      TimeRefArray( 31*ntspd + counter*ntspd-(ntspd-1) : 31*ntspd + counter*ntspd , 2) = i
      TimeRefArray( 31*ntspd + counter*ntspd-(ntspd-1) : 31*ntspd + counter*ntspd , 3) = j
      TimeRefArray( 31*ntspd + counter*ntspd-(ntspd-1) : 31*ntspd + counter*ntspd , 4) = k
      TimeRefArray( 31*ntspd + counter*ntspd-(ntspd-1) : 31*ntspd + counter*ntspd , 5) = (/(l, l=0, 24-24/ntspd , 24/ntspd) /)

      counter = counter + 1

    END DO

  END DO
END DO

!PRINT '(5(F9.3))', TRANSPOSE(TimeRefArray(1:300,:))
!PRINT '(5(F9.3))', TRANSPOSE(TimeRefArray(200000:200040,:))

!-------------------------------------------------------------------------------

CONTAINS

  INTEGER FUNCTION CheckForLeapyear( year )

    IMPLICIT NONE

    INTEGER, INTENT(IN) :: year

    IF ( ( MOD(year, 4) == 0 .AND. MOD(year, 100) /= 0 ) .OR. ( MOD(year, 400) == 0 ) ) THEN
      CheckForLeapyear = 366
    ELSE
      CheckForLeapyear = 365
    END IF

  END FUNCTION CheckForLeapyear

END SUBROUTINE CreateRefTimeArray
