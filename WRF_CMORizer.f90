!-------------------------------------------------------------------------------
! BOP
!
! ****************************************************************************
! ***                                                                      ***
! ***      SEE THE LICENSE INFORMATION AT THE END OF THE PREAMBLE          ***
! ***  DESPITE THE LICENSE, PLEASE DO NOT DISTRIBUTE AT THE PRESENT STAGE  ***
! ***                                                                      ***
! ***      THIS PREAMBLE IS THE ONLY DOCUMENTATION OF THIS PROGRAM         ***
! ***          BEFORE USING THIS PROGRAM, READ THIS PREAMBLE               ***
! ***                                                                      ***
! *** code is under development, missing functionalities being added by KG ***
! ***                      during CW 15, 16, 17                            ***
! ***                    see "missing still" below                         ***
! ***     ask k.goergen@fz-juelich.de if anything is unclear, needs fixing ***
! ***                       or shall be added                              ***
! ***                                                                      ***
! *** AN ALL NEW IDEA FOR THIS TOOL EXISTS, AND MAY BE REALIZED WITH V2.0  ***
! ***                                                                      ***
! ****************************************************************************
!
! NAME:
!   WRF_CMORizer.f90
!
! VERSION:
!   v0.4 (= git tag) as of 2018-04-11
!   see git tags and log for revision details, history, and versions
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
!   thereforei, ideally, more than the required variables and diagnostics shall
!   be implemented.
!
! STATUS:
!   UNDER DEVELOPMENT -- decide whether it is fit for purpose yourself
!   - PLEASE NOTE: This 1st public version does the highest temporal resolution
!     pass over all variables, i.e., e.g., at dt=3hr or 1hr. It processes all 
!     variables during this pass, even those specified only at coarser temporal 
!     resolution. Thereby the tool (i) CMORizes the WRF outputs and (ii) reduces 
!     the output data volume. The averages are to be computed later on, based on 
!     the high-resolution CMORized data and fine-grained namelist settings, 
!     which determine which variable shall be provided at which resolution.
!     Most ongoing joint FPS studies require a high temporal resolution anyway. 
!     A drawback is, that variables, which do not need high resolution, are 
!     stored at high resolution also, albeit only as 2D fields.
!
!     MISSING STILL:
!     * Temporal averaging (6hr, day, mon, seasons) functionality based on 
!       tier-2, has to be added still -> part of the structure of the code 
!       (v0.5)
!     * Fixed fields (based on geo_em files), easy to implement via namelist and
!       search path -> part of the structure of the codeA (in v0.6)
!     * Some variables / diagnostics, see below (in v0.7)
!     * Spatial interpolation to common regular grid EUR-11i (v0.8)
!
!   - Double-checked, tested and refined namelists with their respective
!     variables and diagnostics, after code merging and refactoring, all needed
!     extensive checking and fixing, if checked here, all vars in that namelist
!     are covered by the code and should be OK:
!     * [X] runctrl.current.nml (overall setup)
!     * [X] runctrl.vars.nml_pr_tas_1hr_test (special testing table)
!     * [X] runctrl.vars.nml_vars_on_plevels
!     * [X] runctrl.vars.nml (standard table with common vars)
!     * [X] runctrl.vars.nml_water_column
!     * [X] runctrl.vars.nml_cape (hourly at the moment, can be aggregated)
!     * [X] runctrl.vars.nml_pr_mrso
!     * [x] runctrl.vars.nml_evp_roff (cannot finally test as I am lacking data in the output)
!     * [X] runctrl.vars.nml_radiation
!     * [x] runctrl.vars.nml_snow (check sic once more with winter data)
!     * [X] runctrl.vars.nml_minmax (uses 'wrfxtrm')
!     Because the temporal aggregation is not fully implemented yet, the nml
!     entries for temporally aggregated variables, except for the extremes, may
!     not be all consistent with the variable tables of the protocol, i.e. which
!     variable is to be processed with which temporal aggregation.
!
!   - Variables (from most recent protocol versions) not yet implemented:
!     CORDEX:
!     * hurs
!     * mrfso
!     * wsgsmax
!     * tauu
!     * tauv
!     * cll
!     * clm
!     * clh
!     * areacella (fx)
!     * orog (fx)
!     * sftlf (fx)
!     * sftgif (fx)
!     * mrsofc (fx)
!     * rootd (fx)
!     Special, additional FPS CEM variables:
!     * ua100m
!     * va100m
!     * wsgmax100m
!     * mrsol
!     * clbvi
!     * clgvi
!     * (ic_lightning) need special scheme
!     * (cg_lightning)
!     * (total_lightning)
!     All other variables are covered by namelists and implemented.
!
!   - Desired additional diagnostics (not yet implemented):
!     * vorticity
!     * ...
!
! *** - TO USE THE TOOL, NO CODE MODIFICATION SHOULD BE NEEDED              ***
! *** - SOME WARNINGS DURING COMPILATION SHOULD NOT DO ANY HARM             ***
! *** - CONTAINS TOO MANY PRINT STATEMENTS AND DEVELOPMENT NOTES            ***
! *** - CONTAINS STILL MANY INEFFICIENCIES, MANY PEOPLE DEVELOPING, ETC.    ***
! *** - MOST THINGS ARE DONE FOR A CERTAIN REASON, IF YOU DO NOT UNDERSTAND ***
! ***      THE FULL CONCEPT AND STRUCTURE, CHECK WITH THE DEVELOPERS BEFORE ***
! ***      MOFIFYING THE CODE, THIS INCREASES THE CHANCE THAT MODIFICATIONS ***
! ***      CAN MAKE IT TO THE MAIN BRANCH WITHOUT TOO MUCH EFFORT           ***
! *** - IF ANYTHING IS NOT OK, IT IT MERELY DUE TO LACK OF TIME             ***
! *** - THIS DOCUMENTATION CONTAINS MANY THINGS REDUNDANT                   ***
!
! CURRENT CODE MAINTAINER:
!   - Klaus GOERGEN | k.goergen@fz-juelich.de | KGo | FZJ/IBG-3
!
! CODE CONTRIBUTERS:
!   - Sebastian KNIST | sebastian.knist@gmx.de | SKn | MIUB
!   - Heimo TRUHETZ | heimo.truhetz@uni-graz.at | HTr | WEGC
!   - Aristotelis LAZARIDIS | lazarida@math.auth.gr | ALa | AUTH
!   - NN | ? | LAh | WEGC -- who is this, Heimo?
! 
! SUPPORT AND TESTING:
!   - Kirsten WARRACH-SAGI et al.
!   - Eleni KATRAGKOU et al.
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
!   Using Fortran in hindsight was too optimistic and overcomplicates things 
!   considerably; given the time invested the tool is finished in Fortran.
!   The structure follows a concept but as the tool grew became quite clumsy, 
!   but no time to change that now.
!   
! DISSEMINATION (later on):
!   https://www.github.com/kgoergen
!
! CODING STANDARD / CONVENTIONS:
!   - No systematic standard followed, tries to adhere to
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
!   - ./WRF_CMORizer
!   - ./WRF_CMORizer > log
!   - ./WRF_CMORizer > log 2>&1
!   - ./WRF_CMORizer 2>&1 | tee output.log
!   - nohup time <any_command_from_above> &
! 
! FIRST STEPS:
!   1. Read this preamble as a user guide and technical description
!   2. Compile code: 'make', there will be a few warnings, but the code should 
!      built -- my apologies for that.
!   3. Adjust the main run-control file: "runctrl.current.nml"; it is rich in 
!      comments and has been used with the processing of the variables for the
!      large scale forcing ICTP analysis of the FPS CEM INIWL and INITCM runs.
!      Use a single or a few smaller WRF standard outputs from a single WRF
!      experiment. Do not rename the namelists.
!      The time setting at the moment is that monthly files are created, based 
!      on the inputs.
!   4. In the code the ifrq and ivarnml are hardcoded to run on 1hr output only
!      and to just use one test variable namelist; inside that namelist per 
!      default only tas is activated. Run with this setting first and check.
!      Then expand the list of variables to be processed, setting time1hr to .T.
!      The namelist is 'runctrl.vars.nml_pr_tas_1hr_test'.
!   5. Later on activate further namelists; all namelists provided are tested 
!      and should work, see informaiton in this preamble.
!      See around line 1250 to activate the full namelist loop.
!
!      If e.g. the minmax nml is to be used, set 
!          DO ifrq = 4, 4, 1 -> activate the daily processing
!      and 
!          DO ivarnml = 5, 5, 1 -> select minmax nml only
!
!      It is possible to loop over all aggregation levels and namelists already
!      now as all variable processing has been deactivated in the nml other than
!      1hr (and daily for extremes).
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
!   - WRF outputs extremes (wrfxtrm*) if extreme vars are processedm see 
!     filetype 'x' in the variable namelists.
!   No optional inputs, no keyword parameters. The tool is controlled by the
!   namelists entirely.
!
! OUTPUTS:
!   - netCDF files according to standard specification.
!   - No Optional outputs, except log file.
!
! FEATURES:
!   - The tool can produce most required variables, i.e. output netCDF files as
!     defined in the CORDEX archive design specifications as available in 2018
!     in possibly one pass (sveral loops over different temporal aggregations)
!     based on standard WRF simulation
!     outputs. No additional processing is needed. Also the reuiqred netCDF-4
!     classic data model format is written immediately, no later conversion
!     needed.
!   - 3h/1h data is produced first. This is closest to outputs most groups have
!     anyway. It is possible to produce more 1/3hr output than needed, i.e. for
!     all variables specified plus more vertical levels. Thereby the tool might
!     also be used for a general data volume reduction after a model run.
!   - The application loops over various averaging intervals, then over
!     variables and then over the existing WRF data files, see PROCEDURE below.
!   - Very large WRF outputs and/or even larger model domains than used in
!     CORDEX can be handled as the tool is working on individual output
!     intervals only. The tradeoff is a more I/O overhead but lower RAM
!     requirements. At the same time there is in absolute numbers little I/O as
!     most things are done in one pass.
!   - The Fortran code tries to be ISO F95-compliant except for "SYSTEM" calls.
!     The tool shall be portable easily.
!   - The tool has minimum requirements in terms of libraries or external tools.
!   - Fortran was chosen for its fast execution speed, suitable for the
!     large datasets and the possibility to use the tool in HPC environments as
!     well as on individual workstations with a good performance. Also it is
!     easily possible to parallelize portions of the code via e.g. OpenMP.
!   - By splitting the *vars* namelist, the tool may be run concurrently for
!     different portions of a WRF output dataset.
!   - No code modifications are needed to run the tool and customize it for use
!     with a different WRF experiment. Only the NML files need to be changed.
!   - Different WRF input sources are possible, currently the tool is designed
!     for wrfout and wrfxtrm (and geo_em) files.
!   - The tool creates a reference time vector. The time-information contained
!     in each original WRF sim. file is retrieved and according to this
!     information data is sorted into the resulting netCDF files. This makes the
!     the tool rather robust and flexible, a tradeoff is the possibly longer
!     processing time due to the searches needed for the date and time matching.
!     However these searches are on subsets only and therefore fairly efficient.
!     It also means that the WRF outputs may cover any timespan, daily, monthly,
!     or any overlap of months and/or years and that they may come in filelists
!     even not temporally ordered. The tool is entirely relying on time
!     information inside the netCDF files, no filename is analyzed.
!   - The tool is not taking care of the file handling of the wrf files before 
!     or after the processing.
!
!   - Different temporal aggregations, i.e., output storage file structure:
!     ==(A)==
!     With CORDEX archive protocol, at 3hr resolution, data is stored annually; 
!     daily data is stored 5-yearly. A storage file is automatically created if 
!     is does not exist, based on the time information in the raw model output.
!     Then data is then sorted in. 1hr data from high-resolution runs can also
!     be stored annually.
!     ==(B)==
!     If the tool is used for general postprocessing, then sometimes timespans 
!     of less than a year are simulated; for this case an arbitray timespan in
!     the general namelist maybe specified. The overall length of the simulation
!     time-span, is independent of this. I.e., even if WRF outputs covers a
!     longer time-span, the tool will sort everything in correctly and discard
!     the overlapping dates and times. With this option, the tool does a single
!     pass only and handles data for the specified timespan, still compliant
!     with the CORDEX protocol.
!     ==(C)==
!     A monthly option, which works like the annual default options has also 
!     been added. Here the month is auto-generated, if not existing already.
!
!   - With month and annual: The files are generated according to the content of
!     the input data; with individual storage files, the file is generated 
!     according to timespan and all wrf data which does not fit is left out;
!     also here, the tool is run for one pass only, i.e.multiple wrf 
!     files may be read, but just one output file is generated.
!   - An adjustment to other RCMs should be 'easy'; only the variable table has 
!     to be translated to the other model. Anything hardcoded is based on ESGF 
!     variables.
!   - The static fields are treated independently by the tool.
!   - Currently the namelists are split into several parts but they may also 
!     be combined into one single large monolithic namelist. Albeit does this
!     not have any advantage.
!   - The tool is also intended to reduce WRF model output data volume. This
!     means that original raw model outputs are likely to be erased afterwards.
!     Therefore the tool generates slightly more variables than required by the
!     CORDEX data protocol: e.g. CAPE, ....
!   - To fully understand the structure and possibilities of the code, take a 
!     look at the code itself, it tries to be rich in comments and explanations.
!   - Tries to have minimum hardcoded stuff, if at all.
!   - The tool can be scripted and nml files maybe modified using sed, 
!     embedding in arbitrary workflows is possible.
!   - To adjust the tool to a new WRF dataset / experiment, basically only the 
!     runctrl.current.nml namelist has to be adjusted. Also if only a subset
!     of variables is to be generated for a soecific study, all these variables
!     may be added to a single dedicated namelist.
!   - The tool is not hardcoded to any specific CORDEX domain, this is
!     determined by the main namelist settings and by the geo_em file, which has
!     to be read.
!   - Variables do not depend on each other, except for the CAPE and CIN calc.;
!     i.e. there is no mandatory namelist selection or any sequence which has to 
!     be considered in processing. Each variable is treated seperately.
!     This may be at some point a bit more inefficient, but everything else
!     would make the tool too complicated.
!   - Pressure variables are all calculated. They might also be read form 
!     wrfpress.
!   - Three filetypes can be specified; the filename search patterns 
!     are hardcoded:
!     * (s)tandard = wrfout*
!     * e(x)tremes = wrfxtrm*
!     * (p)ress = wrfpress* -- not needed or used at the moment, pressure level
!                              calcs yield about the same results as in wrfpress
!   - Different slp computation options, see calc_clp_type variable
!     * 0 = most simple implementation
!     * 1 = modified wrf_interp.F90
!     * 2 = fullpos_cy38 implementation (ERA/IFS/APACHE/ALADIN) (HTr, LAh)
!           DEFAULT for FPS as decided in Trieste Nov 2017, always set
!     * 3 = HIRLAM method (Poisson eq.), not yet implemented, tested by WEGC
!
! PROCEDURE:
!   The tool may be called as part of a processing chain. It is meant as an all-
!   in-one tool. It basically reads data, controlled by a namelist, checks the
!   dates in the input file, starts looping over the input file, one variable or
!   diagnostic at a time, checks whether the storage file exists, and if not 
!   creates the storage file based on the data reference syntax and all. No 
!   ancilliary files except the basic namelists are needed, no libraries except 
!   netCDF. No fancy compiler functionalities are used. The tool always checks 
!   the model data time information and sorts in the data based on a reference
!   time vector. It handles one timestep at a time during initial CMORization.
!   The namelists determine whether the variables are to be prepared for a 
!   certain resolution or averaged or regridded, based on the CORDEX variable
!   lists. They also contain the standard names. Namelists may be modified by
!   adding or removing vars, but processing of vars  may also be just switched 
!   on/off.
!   Originally all was meant to go into a single monolithic namelist, then it
!   was decided to split the namelists according to "variable groups". 
!
!   The looping structure is as follows:
!
!   'ifrq' (loop over temporal output and aggregation frequencies) 
!     'ivarnml' (namelists with different variable combinations)
!       'ivar' (variables from the namelists)
!         'ifl' (all files in the search path)
!           'it' (all timesteps per file)
!             **gather all vars needed, maybe just one, like with tas**
!             **processing, maybe nothing is done, just stored with meta data**
!
!   "WRF standard output" means: Data as written based on a standard unmodified 
!   registry. The tool works on one experiment at a time (e.g. 'CORDEX'), and on
!   one resolution at a time (e.g. EUR-11). There is no relationship between 
!   different domains or experiments during processing.
!   To cover all variables requested by the CORDEX protocol, iofields.txt has to
!   be used in combination with the standard registry, or the registry must be 
!   modified.
!
!   If the storage file is created but the input data does not cover the 
!   complete file, once the first data have been written, the unlimited 
!   dimension is expanded and the empty fields / timesteps are filled with 
!   missing values. Due to the way the tool sorts in data, e.g., when working
!   in auto-mode, i.e. creating annual files for tier-2 storage, it will always
!   create as many files as needed according to the time information in the WRF
!   outputs. Fields can be sorted in as they appear. No matter whether it is in 
!   the middle of the storage file or at the very beginning, a proper
!   chronoilogical order is by design always retained.
!
!   To be resource efficient and fast, the tool tries to check whether a 
!   certain operation is nedded or not, like whether it is on a second pass 
!   through a file or variable, then there is no need to setup the time vecs 
!   etc. again. Though temporally very fine-grained, this improves efficiency.
!   For each new variable though all is nicely set up again.
!
!   This is pure research code, there is literally no error trapping.
!
!   There is one master namelist, which contains information on the experiment
!   this one is usually modified and linked to runctrl.current.nml. The other
!   namelists are usually kept as is.
!
!   The tier-2 processing is usually done first, i.e. the highest resolution
!   data, 1h or 3h, e.g.; all tier-1 or core vars are derived by averaging from
!   this tier-2 dataset in later pass with the model, during the same execution
!   or really later and then e.g. by deactivating the 1hr/3hr ifrq or by 
!   switching variables on or off using the time<1hr/3hr...> flag. The logic is
!   that e.g. a model run is done, immediately after 1hr or 3hr data are 
!   CMORized, but the temporal aggregation, like daily or monthly means is 
!   at a later time when enough data is available.
!
!   In the variable namelists, there is not distinction between height and plev;
!   the pressure levels can also be entered into the height field. During 
!   runtime there is this distinction: everything > 10 is considered a pressure 
!   level. This might be an issue with FPS CEM height 100m, but then only "10"
!   had to be increased to 100, as long as it is below the highest plev there is
!   no problem.
!
!   CORDEX_ID from the variable namelists remains unused. Often set to 999;
!   a legacy, might be set to any integer.
!
!   Dimensions are usually given unstaggered in the runctrl.current.nml file;
!   tol takes care: make all unstaggered and rotated to true geographic North.
!
!   Variable namelists can be all merged into one or may be split into several
!   thematic namelists; there is one place in the code where namelists are 
!   explicitely named. Splitting namelists can be used to concurrently process
!   different variables. Via the variable namelist also other model can be used
!   with the postprocessing tool as here the variable matching is done.
!
!   Also different spatial resolutions may be processed concurrently.
!
!   The wrfxtrm-based min/max data are usually on a daily basis. This is 
!   realized via the runctrl.vars.nml_minmax namelist; here for the initial
!   processing of the variables, the 1hr and 3hr time-flag is set to FALSE; the
!   daily flag is set to TRUE; this means automatically the proper time vector
!   is generated; however for point data this vector is going from 
!   start, e.g. 2013-01-01_00:00:00 to 2014-01-01_00:00:00, ... forgot what I
!   was about to write... Bottom line is: In accordance to the protocol, de-
!   pending on the cell_method and the temporal resolution of the data, the 
!   time vec in the netCDF file is generated and the start and end date/time
!   information in the filename is generated. If e.g. cell method mean is used,
!   the new CMOR standard defines that e.g. with 1hr data the first time 
!   information is then 0030 and the last 2330 (mid-point); with point data
!   it might be 00 and day+1 00, etc. (see CORDEX protocol p19 in [1])
!
! RESTRICTIONS:
!   - No side effects.
!   - If the WRF output filenames are non-standard, the file list pattern 
!     matching may have to be adjusted
!   - Hardcoded time vector name 'Times', etc. so some work to adjust for other
!     RCMs. Some rare places where stuff is hardcoded.
!   - The highest temporal resolution possible is 1h at the moment, because of 
!     how the time matching is coded. Shorter is possible.
!   - A maximum of 36 variables per namlist is currently hardcoded. Could be 
!     expanded, there is no limit.
!   - Currently only one input root directory is possible. If data is stored at
!     different locations, symbolic links might have to be done beforehand.
!   - Storage files with individually created time-coverage (non standard) only 
!     one pass is possible, i.e. the file is created covering a certain timespan
!     and data from the netCDF files in the filelist are transferred according 
!     to the variable namelist. No second storage file is created depending on
!     the time coverage of the original WRF outputs.
!   - If a storage file exists and wrf data for a date/time is read a second 
!     time the data already stored will be overwritten; there is no warning;
!     in case the input data is from SAME original WRF output file, there is no 
!     damage done except for lost efficiency; if for some reason the data 
!     handling is messed up and the data is from a different experiment, the
!     stored data is corrupted.
!   - With many variables not transferred from reading to processing within the
!     data_in array, there is an inflation of the RAM used with further vars 
!     processed as specific vars for specific ESGF variables are not deallocated
!     again after usage... nearly a bug.
!   - There is no extrapolation like in the p_interp tool for pressure levels
!     such as 1000hPa, this results in extensive missing value fields.
!   - There is no error trapping.
!
!     IMPORTANT:
!   - In case cell method is 'mean' when the last timestep is read, like 23UTC,
!     The tool would not be able to calculate the mid point time value 23:30
!     field, e.g. the average pr between 23UTC and 00UTC; during the next file 
!     processing however, the first field is 00UTC and the next midpoint is 
!     00:30, no matter whether mm_bucket etc. is used or not. Hence 23:30 would
!     be missing; therefore the tool checks for the next file in the filelist, 
!     and if this file exists, it reads the 1st field. BUT: It just takes the 
!     next file and first field, it does not do a date-time check!!! Also, 
!     due to this, you should always have at least two output files in a row the 
!     tool can work on.
!     I know this all migth be circumvented with another overlapping WRF output
!     strategy, but if people do not have this there would be gaps at each date
!     time when a WRF output file ends.
!
! BUGS:
!   - When calculating the average time vec: e.g. 05:29:60 is shown with ncdump,
!     should be 05:30:00, even with double precision calc no chance. cdo is OK,
!     ncview too. Seems more a ncdump issue. Others have this issue too.
!   - Precipitation does not include graupel etc., just rainnc and rainc.
!
! TODO / PLANNED EXTENSIONS
! **see "TODO" and "CHECK" markers in the code**
! **see the Ongoing Developments section below**
!   Top
!   - Static fields processing, fx > seperate namelist; pass through
!   - Cover ALL REQUIRED variables/diagnostics + ADDITIONAL -> extensions nml
!   - Temporal aggregations, i.e. 6hr, day, mon, seas > controlled by nml and 
!     realized within loops
!   - Add levels: plev_bnds, needed for: clh, clm, cll
!   Important
!   - Spatial averaging -> EUR-11i grid...
!   - Run output again the compliancy checker
!   - Registation of naming schemes with CORDEX (institude_id, model_id)
!   Soon
!   - gitlab staging
!   - Add CMIP "realm" as new attribute -> important for TerrSysMP
!   - (OpenMP parallelism for the processing section), via pragmas in the code
!   - Add: debug option in Makefile.
!   Not so soon
!   - (Parallel netCDF I/O where possible), via pre-processor flags > using all
!     compressed netCDF, no most likely not even possible
!   - ((Adjust to other model system)) > TerrSysMP
!   - (((Refactoring the code to make it more modular using modules and
!     subroutines. Time-pressed evolution, no time to restruct during v1 devs)))
!   - STRUCTURE:
!     Move the generation of the mid-point timevec and the time_bnds calc
!     into the ref time vec subroutine; use this information then also for
!     double-checking when averaging any data; the ref time vec as is at the 
!     moment basically reflects only the 'point' information and everything
!     else is calculated on top, very complicated. Move the call of the ref time
!     vec calc down in the loop hierarchy into the beginning of the variable 
!     loop as the cell method is set on a per variable basis. 
!
! TEST PROCEDURE for all variables:
!   - Per variable and namelist.
!   - Implement variables and test via the special testing namelist.
!   - Check one namelist after the other. There are no overlapping variables
!     between nmls.
!   - Per namelist: check processing of each variable seperately.
!   - Per namelist: check processing of all variables in one go.
!   - Checking: (i) log, (ii) ncdump, (iii) cdo, (iv) ncview.
!
! QUESTIONS:
!   (1)
!   Q "theta_in(:,:,:) + T00(1)" (correct, right?) OR "theta_in(:,:,:) + 300" 
!     (www2.mmm.ucar.edu/wrf/users/docs/user_guide_V3.8/users_guide_chap5.htm)
!     if not 300K is used, then there is a conflict between wrfpress diagnostics
!     and the WRF_CMORizer. Is wrfpress wrong with built-in diagnostics or the \
!     WRF_CMORizer?
!   A http://mailman.ucar.edu/pipermail/wrf-users/2013/003117.html
!     Do not use T00 form the meta-data, but set to 300K hardcoded. Tested and 
!     also confirmed by NCAR, personal comm.
!
! ONGOING DEVELOPMENTS (March/April 2018):
!   - Currently merging forks from different contributors, complete check of the
!     code, fix multiple functionalities not in line with the overall concept
!   - Despite on an internal gitlab nothing was merged, no work form others 
!     considered: take the latest heads from various git branches and merge old-
!     school locally without git
!   - Walk through the code, continuously building and checking using gfortran
!   - Mid March / beginning April 2018:
!     * [X] 'master' branch out of date > Knist+Truhetz+Kartsios worked from; 
!           most versions were running, but not ideal, just doing a fraction
!           of the needed fixes and adjustments
!     * [X] start with Knist version as new base, know this version most
!     * [X] Truhetz merge file 1, start
!     * [X] fix (!) and check overall, document, and implement the flexible time 
!           span for the storage file > have some proper output which can be 
!           viewed with ncview also
!     * [X] fix preamble
!     * [X] check w/ FPS new nomenclature, also my runs...
!     * [X] check w/ protocol: definition + ESGF archive + CD convention
!     * [X] check the ESGF UCAN and CSC for reasonable additional global vars
!     * [X] variable inventory, what is needed? ICTP + CORDEX + FPS
!     * [X] Truhetz merge file 1, cont., u + v on mass grid!!! > DESTAGGERING!!!
!     * [X] Truhetz merge file 2, compare HTr1 w/ HTr2
!     * [X] Truhetz add/merge 2018-03-21 stuff, changed slp calc > combine above
!     * [X] compare pressure calcs with wrfpress
!     * [X] TESTING and REFINEMENTS > also related to the data delivery for ICTP
!           x staggering test > uw, PH PHB
!           x psl integrate and also new stuff from heimo
!           X all new pressure level calcs
!           x variable grouping: 3D vars: improve
!           x bucket fct checking > radiation (OK) and precipitation (OK)
!     * [X] test ALL other tier-2 variables already implemented in f90 and nml
!     * [X] what happens when going accross months with indiv timing?
!     * [X] min / max shifting
!     * [X] new filename protocol: last/first element: -/+dthours/2 if cell 
!           method 'mean': 23UTC to 00UTC hourly precipitation: end filename is 
!           2330, not day+1_00UTC: the mid point value is to be used 
!     * [X] process data for the ICTP paper >>> test on JURECA once more (Intel
!           + multiple files), v0.3, nml #1 & #2
!     * [X] xtrm
!     * [ ] temporal averaging, merge Aris
!     * [ ] add fx data functionality (new namelist)
!     * [ ] add missing vars, see above (see e.g. Chus / UNICAN table)
!     * [ ] grid transform
!   - Later:
!     * [ ] register new institute ID and model name with O.B. Christensen at 
!           DMI.!
!   - Long-term:
!     * [ ] adjustment for different RCMs < see CCLM code from Heimo 
!           (not yet included in merge file 1 or 2)
!
! MODIFICATION / REVISION HISTORY:
!   See either git log for details.
!
! CALLED PROCEDURES:
!   System calls: uuidgen, date, mkdir
!
! RELATED TOOLS (incomplete):
!   - Lluis FITA-BORELL, WRF in-situ plugin module to write CMORized output
!   - Jesus FERNANDEZ, Python
!   - cdo ...
!   - NCL ...
!   - CMOR ...
!
! ACKNOWLEDGEMENTS:
!   Thanks from K.GOERGEN as the originator of the tool goes to all who willing-
!   ly helped to further develop and improve the code, namely, Sebastian, Heimo,
!   and Aris.
!   Thanks for testing and support to: Kirsten WARRACH-SAGI from University of
!   Hohenheim, Germany, and Eleni KATRAGKOU from University of Thessaloniki,
!   Greece.
!
! PERFORMANCE:
!   No new measurements yet.
!
!   ***NOT YET OPTIMIZED, ASIDE FROM SAHRED MEMORY PARALLELISM A LOT NEEDS TO BE 
!   CHECKED USING PROPER PROFILER***
!
!   - revisit variable allocation
!   - CAPE/CIN split not ideal...
!   - ...
!
! REFERENCES:
! [1] http://cordex.dmi.dk/joomla/images/CORDEX/cordex_archive_
!     specifications.pdf
! [2] https://www.hymex.org/cordexfps-convection/wiki/doku.php?id=protocol
! [3] https://www.unidata.ucar.edu/software/netcdf/conventions.html
! [4] http://www2.mmm.ucar.edu/wrf/users/utilities/util.htm
! [5] http://www.meteo.unican.es/wiki/cordexwrf/OutputVariables
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
  CHARACTER (len = 200), DIMENSION(:), ALLOCATABLE :: &
    fl_wrfout   , &
    fl_wrfxtr   , & 
    fl_wrfpres  , &
    fl_input
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

  INTEGER, PARAMETER :: nvars = 36 ! maximum number of vars per namelist

  CHARACTER (len = 200) :: Conventions, contact, experiment_id, experiment, &
    driving_experiment, driving_model_id, driving_model_ensemble_member, &
    driving_experiment_name, institution, institute_id, model_id, &
    rcm_version_id, project_id, CORDEX_domain, product, references

  CHARACTER (len = 200) :: comment, institute_run_id, title

  CHARACTER (LEN = 100), DIMENSION(nvars) :: var_wrf, var_cmip, standard_name, &
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

PROGRAM WRFCMORizer

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

  ! HTr: modified calculation of mean sea level pressure adopted from 
  ! wrf_interp.F90	
  SUBROUTINE calcslp(slp,pres,qv,tk1,ght,nz,ns,ew,T00)
    IMPLICIT NONE
    INTEGER, INTENT(IN) :: nz,ns,ew
    REAL, DIMENSION(:,:), INTENT(INOUT) :: slp
    REAL, DIMENSION(:,:,:), INTENT(IN) :: pres,qv,tk1,ght
    REAL, INTENT(IN) :: T00
  END SUBROUTINE calcslp

  SUBROUTINE calcslptwo(slp, PP, P_s, PHI_s, T_L, nz, ns, ew)
    IMPLICIT NONE
    REAL, DIMENSION(:,:),   INTENT(OUT) :: slp
    REAL, DIMENSION(:,:,:), INTENT(IN)  :: PP
    REAL, DIMENSION(:,:),   INTENT(IN)  :: P_s
    REAL, DIMENSION(:,:),   INTENT(IN)  :: PHI_s
    REAL, DIMENSION(:,:),   INTENT(IN)  :: T_L
    INTEGER,                INTENT(IN)  :: nz, ns, ew
  END SUBROUTINE calcslptwo

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
REAL, PARAMETER :: R = 287.04 ! [J kg-1 K-1]
REAL, PARAMETER :: L = 2501000.0 ! [J kg-1]
REAL, PARAMETER :: a = 610.78 ! [Pa]
REAL, PARAMETER :: b = 17.27 !
REAL, PARAMETER :: c = 273.15 !
REAL, PARAMETER :: d = 35.86 !
REAL, PARAMETER :: n = L*0.622*a/cp !
REAL, PARAMETER :: mv = 1.e20 ! missing value as specified
REAL, PARAMETER :: gr = 9.81

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
  rainc_varid, snownc_varid, u10_varid, v10_varid, u_varid, v_varid, w_varid, &
  sfcevp_varid, potevp_varid, sfroff_varid, udroff_varid, acsnom_varid, &
  sinalpha_varid, cosalpha_varid, plev_varid, plevbnds_varid, psfc_varid, &
  landmask_varid, xland_varid, swdown_varid

! input data general query
INTEGER :: ncid_in, ndims_in, nvars_in, ngatts_in, unlimdimid_in !!!, formatp_in

! inputs, number of elements
INTEGER :: nvar_nml
! record variable in input data
INTEGER :: InVarIdRec, InDimLenRec !!!, InVarNdimsRec
CHARACTER (len = NF90_MAX_NAME) :: InDimNameRec !!!, InVarNameRec
!!!INTEGER, DIMENSION(NF90_MAX_VAR_DIMS) :: InDimIdsRec
CHARACTER (len = 50) :: fl_filter
CHARACTER (len = 19), DIMENSION(:), ALLOCATABLE :: InVarDataRec

! data
REAL, DIMENSION(:,:), ALLOCATABLE :: &
  data_in     , &
  psl_in      , &
  !t2_in       , &
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
  cosalpha_in , &
  !!var_pl      , &
  psfc_in     , &
  tmp_2d      , &
  rainc_max_in, &
  rainnc_max_in , &
  landmask_in   , &
  xland_in
REAL, DIMENSION(:,:,:), ALLOCATABLE :: &
  pp_in       , &
  pb_in       , &
  ph_in       , &
  phb_in      , &
  qv_in       , &
  qvs         , &
  qc_in       , &
  qr_in       , &
  qi_in       , &
  qs_in       , &
  theta_in    , &
  t_in        , &
  ph_fl       , &
  p_in        , &
  u_in        , &
  v_in        , &
  w_in        , &
  var3d_in    , &
  !var_pl      , &
  potevp_in   , &
  rainnc_in   , &
  rainc_in    , &
  rad_in      , &
  t_p         , &
  snownc_in   , &
  acsnom_in   , &
  GeoInLonLat , &
  sfcevp_in   , &
  sfroff_in   , &
  udroff_in   , &
  swdown_in   , &
  tmp_3d
REAL, DIMENSION(:,:,:,:), ALLOCATABLE :: &
  cldfra_in   , &
  smois_in
REAL, DIMENSION(:), ALLOCATABLE :: &
  GeoInRLat   , &
  GeoInRLon

! target pressure levels [Pa]
REAL, DIMENSION(6) :: pout = (/100000.,92500.,85000.,70000.,50000.,20000./)

! time vec stuff
REAL(KIND=8), DIMENSION(:,:), ALLOCATABLE :: &
  TimeRefArraySubset, &
  Time_bnds
REAL(KIND=8), DIMENSION(:), ALLOCATABLE :: &
  TimeRefArraySubsetMean

! bucket system
INTEGER, DIMENSION(:,:,:), ALLOCATABLE :: &
  i_rainnc_in , &
  i_rainc_in  , &
  i_rad_in
REAL :: bucket_mm, bucket_J

! (het): base state temperature is made flexible in newer versions of WRF. The
! actual value is stored in variable T00
! also the base state pressure (P00) is kept flexible now.
REAL, DIMENSION(1) :: T00, P00
INTEGER :: t00_varid, p00_varid

! variable for adopted vertical interpolation
REAL :: zg_pout

! soil layer thickness may vary from simulation to simulation
REAL, DIMENSION(:), ALLOCATABLE :: DZS

! meta information about the geographic projection used (coordinates of the rotated pole)
REAL :: GeoNPLat, GeoNPLon

REAL :: t_ii, dtHours

! time and date handling
CHARACTER (len = 3), DIMENSION(:), ALLOCATABLE :: frequency
!!!INTEGER :: WRFfileNyears, WRFfileNmonths
INTEGER, DIMENSION(:), ALLOCATABLE :: InDateTimeYear, InDateTimeMonth, &
  InDateTimeDay, InDateTimeHour, InDateTimeMinute, InDateTimeSecond      !, WRFfileIyears, WRFfileImonths
REAL, DIMENSION(:), ALLOCATABLE :: InDateTimeCombined
CHARACTER (LEN=4) :: InDateTimeYearStr
CHARACTER (LEN=2) :: &
  InDateTimeMonthStr    , &
  FirstHourStr          , &
  FirstMinuteStr        , &
  LastDayStr            , &
  LastHourStr           , &
  LastMinuteStr
INTEGER :: InDateTimeYearPrev = 0, InDateTimeMonthPrev = 0
CHARACTER (len = 12) :: FileNameStartDateTime, FileNameEndDateTime
INTEGER :: tsactYear, tsactMonth, tsactDay, tsactHour, tsactMinute, tsactSecond, & 
  teactYear, teactMonth, teactDay, teactHour, teactMinute, teactSecond
CHARACTER (LEN=4) :: tsactYearStr, teactYearStr
CHARACTER (LEN=2) :: tsactMonthStr, tsactDayStr, tsactHourStr, tsactMinuteStr, &
  tsactSecondStr, teactMonthStr, teactDayStr, teactHourStr, teactMinuteStr, &
  teactSecondStr
REAL(KIND=8) :: tsact_singlenumber, teact_singlenumber

REAL(KIND=8), DIMENSION(:), ALLOCATABLE :: tmp2D_singlenumber
REAL(KIND=8), DIMENSION(:,:), ALLOCATABLE :: tmp2D

CHARACTER (LEN = 100), DIMENSION(nvars) :: cell_methods
LOGICAL, DIMENSION(nvars) :: procflag

LOGICAL :: fractSeaIce = .FALSE.

!-------------------------------------------------------------------------------
! statistics

REAL :: stat_mean, slope

!-------------------------------------------------------------------------------
! general

INTEGER :: i, j, k, sts, ivar, ifrq, ifl, it, counter, np, nl, ii, ivarnml, &
  prevpass = 0, AllocateStatus, DeAllocateStatus
LOGICAL :: FileExists, newpass, time_match, calc = .TRUE.
REAL :: cpuTs, cpuTe
INTEGER, ALLOCATABLE :: ipos(:)
! choose how psl is calculated, 0 OK, 1 OK, 2 OK, no not change throughout
! see preamble for detailed information
INTEGER :: calc_slp_type = 2 

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
! normal order: x y z t

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
  START = (/ xoffset, yoffset, 1 /), COUNT = (/ xfocus, yfocus, 1 /))

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
! setup of loop control vectors

ALLOCATE ( frequency(7) )
frequency(1) = "1hr"
frequency(2) = "3hr"
frequency(3) = "6hr"
frequency(4) = "day"
frequency(5) = "mon"
frequency(6) = "sem"
frequency(7) = "fx"

ALLOCATE ( fnNMLvar(12) )
fnNMLvar(1) = "runctrl.vars.nml_pr_tas_1hr_test" ! OK
fnNMLvar(2) = "runctrl.vars.nml_vars_on_plevels" ! OK
fnNMLvar(3) = "runctrl.vars.nml" ! OK
fnNMLvar(4) = "runctrl.vars.nml_pr_mrso" ! OK
fnNMLvar(5) = "runctrl.vars.nml_minmax" ! OK
fnNMLvar(6) = "runctrl.vars.nml_evp_roff" ! ok not yet tested: evspsbl, evspsblpot
fnNMLvar(7) = "runctrl.vars.nml_water_column" ! OK
fnNMLvar(8) = "runctrl.vars.nml_radiation" ! OK
fnNMLvar(9) = "runctrl.vars.nml_snow" ! ok not yet tested in winter: sic
fnNMLvar(10) = "runctrl.vars.nml_cape" ! OK
fnNMLvar(11) = "runctrl.vars.nml_weathertyping"  ! new from HTr, not implemented
fnNMLvar(12) = "runctrl.vars.nml_psl"            ! new from HTr, not implemented

!-------------------------------------------------------------------------------
! individual vars contain information on whether they are treated or not, i.e.
! the tool may loop over all frequencies and the namelist controls what is to 
! be done
! this is the outer loop as it also controls the averaging; the main processing
! is done during the 1st pass, i.e., the tier-2 processing at dt=1h or 3h
! ATTENTION: averaging functionality not it reintegrated
!            during testing too lazy to set all temporally aggregated vars to 
!            FALSE
!            -> just run the outer loop over 1 frequency only

!DO ifrq = 1, SIZE(frequency), 1 
DO ifrq = 1, 1, 1 ! 1hr
!DO ifrq = 4, 4, 1 ! check min/max day

  PRINT *, "============================================================"
  PRINT *, "freq = ", frequency(ifrq)

!-------------------------------------------------------------------------------
! - get a file list of all wrfout, wrfxtrm and wrfpress files -- if they exist
! - use regex to refine the ls output and the filelist
! - non-std F95, works for gfortran (fct & subroutine) + ifort
! - to not check the filesystem too often, this is done at this point
! - also the search results might be limited
! - this can be made more efficient, but then it is not so generic anymore
!   depending on the depth of the search path find takes some time
  
  PRINT *, "============================================================"
  PRINT *, "*** FILELIST CREATION ***"
  
  tmpfileFL = "tmpfileFL"

  ! creates a year range, can be expanded also to use months
  IF ( (ts == "0000") .AND. (te == "0000") ) THEN
    fl_filter = ""
  ELSE
    !fl_filter = "{" // ts // ".." // te // "}" ! does not work with SYSTEM call
    fl_filter = ts
  END IF
  
  CALL SYSTEM("find " // TRIM(DirInputSimResRoot) // "/ -name wrfout*" // TRIM(domain) // "*" // TRIM(fl_filter) // "*.nc  > " // tmpfileFL)
  ft = 0 ! file type
  CALL GenerateFilelist
  
  CALL SYSTEM("find " // TRIM(DirInputSimResRoot) // "/ -name wrfxtrm*" // TRIM(domain) // "*" // TRIM(fl_filter) // "*.nc  > " // tmpfileFL)
  ft = 1
  CALL GenerateFilelist

  CALL SYSTEM("find " // TRIM(DirInputSimResRoot) // "/ -name wrfpress*" // TRIM(domain) // "*" // TRIM(fl_filter) // "*.nc  > " // tmpfileFL)
  ft = 2
  CALL GenerateFilelist
 
  DO i=1,SIZE(fl_wrfout(:)),1
    PRINT '(100A)', fl_wrfout(i)
  END DO
  DO i=1,SIZE(fl_wrfxtr(:)),1
    PRINT '(100A)', fl_wrfxtr(i)
  END DO
  DO i=1,SIZE(fl_wrfpres(:)),1
    PRINT '(100A)', fl_wrfpres(i)
  END DO
  
!-------------------------------------------------------------------------------
! creation of the main reference array
! independent of the actual timespan under processing
! usually it starts earlier or at the same date/time and ends at the same 
! date/time or later
! input time information in WRF is 2009-06-20_00:00:00 for extremes

  PRINT *, "============================================================"
  PRINT *, "*** TIME REFERENCE ARRAY ***"
  
  CALL CreateRefTimeArray( frequency(ifrq) )
  
  PRINT *, "size & shape of the TimRefArray = ", SIZE(TimeRefArray), &
    SHAPE(TimeRefArray)
  PRINT *, "SIZE(TimeRefArray,1): ", SIZE(TimeRefArray,1) 
  !PRINT *, "SHAPE(TimeRefArray,1): ", SHAPE(TimeRefArray,1)

!-------------------------------------------------------------------------------
! loop over the different namelists, each containing a specific set of related
! variables, this offers more flexibility in using the tool than putting all
! vars into a single namelist; choose just specific namelists from list above if
! you want to postprocess just specific variables or create your own variable 
! combinations
  
  !DO ivarnml = 1, 9, 1 ! loop over all regular namelists
  DO ivarnml = 1, 1, 1 ! recommended to all for first steps and testing: nml #1
  !DO ivarnml = 1, 2, 1 ! ICTP paper data contrib
  !DO ivarnml = 5, 5, 1 ! test min/max
  
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
      procflag(:) = time1hr(:)
      dtHours = 1.
    CASE ('3hr')
      cell_methods(:) = cm3hr(:)
      procflag(:) = time3hr(:)
      dtHours = 3.
    CASE ('6hr')
      cell_methods(:) = cm6hr(:)
      procflag(:) = time6hr(:)
      dtHours = 6.
    CASE ('day')
      cell_methods(:) = cmDay(:)
      procflag(:) = timeDay(:)
      dtHours = 24.
    CASE ('mon')
      STOP "monthly aggregation not yet implemented"
      cell_methods(:) = cmMon(:)
      procflag(:) = timeMon(:)
    CASE ('sem')
      STOP "seasonal aggregation not yet implemented"
      cell_methods(:) = cmSea(:)
      procflag(:) = timeSea(:)
    CASE DEFAULT
      PRINT *, "invalid time interval specified"
      STOP
    END SELECT

    ! nvar_nml might be determined through the namelist itself
    ! sequence here does not matter
    SELECT CASE (TRIM(fnNMLvar(ivarnml)))
    CASE ("runctrl.vars.nml") ! OK
      nvar_nml = 9
    CASE ("runctrl.vars.nml_evp_roff") ! ok -- see above
      nvar_nml = 4
    CASE ("runctrl.vars.nml_water_column") ! OK
      nvar_nml = 3
    CASE ("runctrl.vars.nml_vars_on_plevels") ! OK
      nvar_nml = 36
    CASE ("runctrl.vars.nml_pr_mrso") ! OK
      nvar_nml = 4
    CASE ("runctrl.vars.nml_snow") ! ok -- see above
      nvar_nml = 6 
    CASE ("runctrl.vars.nml_radiation") ! OK
      nvar_nml = 10
    CASE ("runctrl.vars.nml_cape") ! OK
      nvar_nml = 2
    CASE ("runctrl.vars.nml_pr_tas_1hr_test") ! OK
      nvar_nml = 12 
    CASE ("runctrl.vars.nml_weathertyping") ! new stuff from HTr, no nml yet available
      nvar_nml = 6
    CASE ("runctrl.vars.nml_psl") ! new stuff from HTr, no nml yet available
      nvar_nml = 1
    CASE ("runctrl.vars.nml_minmax") ! OK
      nvar_nml = 4
    END SELECT
  
    PRINT *, "number of vars inside current namelist: nvar_nml = ", nvar_nml
  
!-------------------------------------------------------------------------------
! loop over all vars in the individual namelist
! OR for testing choose just specific variables from namelist 
! (look up var column position in individual namelist)
! better avoid this kind of filtering: create a new namelist or switch the vars
! properly on/off for the respective temporal aggregation level

    DO ivar = 1, nvar_nml, 1
  
      PRINT *,"============================================================"
      PRINT *, "*** ", TRIM(var_cmip(ivar)), procflag(ivar), " ***"
 
      ! shall this variable be processed at all?
      ! either control by i) including/excluding brute-force from a namelist, by 
      ! customizing the namelist list or ii) by setting "timeXX" per temporal 
      ! resolution/aggregation to TRUE or FALSE (=recommended way)
      IF (procflag(ivar)) THEN

      !this is the place to put the ref time vec calculation to incorporate
      !the specifics of the respective variable, like point or mean data in
      !combinaiton with the ifrq  
 
!-------------------------------------------------------------------------------
! loop over the filelist
! content of filelist is defined by filename patterns in system call
! three types of filelists: fl_wrfout, fl_wrfxtr (all depends on the variable
! which filelist shall be used)
! the filelist loops does not care whether (a) the filelist spans multiple
! simulated years or just a single day or hour, neither does it care (b) how
! many files are contained and (c) whether a single file is oerlapping a 
! beginnning or end of the desired temporal unit (year, month, individual, etc.)

      IF ( filetype(ivar) == "s" ) THEN ! variable is in "s"tandard wrfout file
        IF (ALLOCATED(fl_input)) DEALLOCATE( fl_input )
        ALLOCATE( fl_input ( SIZE(fl_wrfout) ), STAT=sts )
        fl_input = fl_wrfout
      ELSE IF ( filetype(ivar) == "x" ) THEN ! variable is in e"x"tremes wrfxtrm file
        IF (ALLOCATED(fl_input)) DEALLOCATE( fl_input )
        ALLOCATE( fl_input ( SIZE(fl_wrfxtr) ), STAT=sts )
        fl_input = fl_wrfxtr
      ELSE IF ( filetype(ivar) == "p" ) THEN ! variable is in "p"ress wrfpress file
        IF (ALLOCATED(fl_input)) DEALLOCATE( fl_input )
        ALLOCATE( fl_input ( SIZE(fl_wrfpres) ), STAT=sts )
        fl_input = fl_wrfpres
      ELSE
        STOP "filetype in the variable namelist must be one of s, x, p"
      END IF

      !DO ifl = 1, 1, 1 ! testing: loop over specific entry in filelist (e.g. just January)
      DO ifl = 1, SIZE(fl_input), 1 ! operational: loop over complete filelist

        PRINT *,"============================================================"
        PRINT *, "filelist filetype = ", filetype(ivar) 
        PRINT *, "# files to process = ", SIZE(fl_input)

        ! measure CPU time for 1 variable and file, including all timesteps
        CALL CPU_TIME(cpuTs)
        PRINT *, "-----------------------------------------------------------"

        iflWRFin = fl_input(ifl)
        PRINT *, "this is the file to work on now:"
        PRINT '(100A)', TRIM(iflWRFin)
  
!-------------------------------------------------------------------------------
! which timespan is covered by the CURRENT WRF input file
! even in the same filelist file, each input file may cover a different timespan
! this determines how many times the tool has to loop over the inputs
! format of 'Times': 2009-06-20_08:00:00

        sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncid_in)
        sts = NF90_INQUIRE(ncid_in, ndims_in, nvars_in, ngatts_in, unlimdimid_in)
        sts = NF90_INQ_VARID(ncid_in, "Times", InVarIdRec)
        sts = NF90_INQUIRE_DIMENSION(ncid_in, unlimdimid_in, &
          NAME = InDimNameRec, LEN = InDimLenRec)
        ! with the wrfxtrm minimum and maximum fields, the 1st field per file is
        ! empty, but the last field has already the next day assigned; this 
        ! leads to a plus 1 day time shift in the minimum and maximum data
        ! by shortening the input time vector and by offsetting the time-dim
        ! by 1 in the output writing this is fixed
        ! see "variable to read/write with no additional processing" part
        PRINT *, "number of timesteps in the input data: ", InDimLenRec
        IF ( ( cell_methods(ivar) == "minimum" ) .OR. &
             ( cell_methods(ivar) == "maximum" ) ) THEN
          InDimLenRec = InDimLenRec - 1
          PRINT *, "fixing number of input timesteps for min/max: ", InDimLenRec
        END IF
        ALLOCATE(InVarDataRec(InDimLenRec))
        sts = NF90_GET_VAR(ncid_in, InVarIdRec, InVarDataRec)
        sts = NF90_CLOSE(ncid_in)
        PRINT *, "RCM input file time coverage:"
        PRINT *, InVarDataRec(1), " to ", InVarDataRec(InDimLenRec)
 
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
          PRINT *, "working on timestep it = ", &
                   InDateTimeYear(it), "-", InDateTimeMonth(it), "-", &
                   InDateTimeDay(it), "_", &
                   InDateTimeHour(it), " ", InDateTimeCombined(it)

!-------------------------------------------------------------------------------
! performance issue: speed up the tool during subsequent passes, i.e. is the 
! storage file etc. existing already
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
          ELSE IF (aggregation_yearly) THEN ! default, if the current year is different than the one previous > create a new file
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

!-------------------------------------------------------------------------------
! extract the time info from the ref time array which matches the respective
! file in which data is to be written and thereby matches also the input data
! ...as there is no "WHERE" the way I need it in F95, use loops
! this is needed whenever a new netCDF file is to be used and also if
! this file exists already
! still working on single variable 'ivar', file 'ifl', and timestep 'it'
! InDateTimeYear(it), InDateTimeMonth(it), InDateTimeDay(it), InDateTimeHour(it), InDateTimeCombined(it)
! TimeRefArray, TimeRefArraySubset
!
! the time span covered by the storage file is determining the time vector subset
! to be extracted from the reference time vec which is again spanning the
! complete experiment; once this reference time vector subset (matching the 
! storage file) is determined the individual offset may be determined which is 
! used to sort the individual WRF field in

            PRINT *, "subsetting the TimeRefArray"

            !PRINT *, "TimeRefArray: index, y, m, d, h"
            !PRINT *, "size & shape of the main TimRefArray = ", &
            !  SIZE(TimeRefArray), SHAPE(TimeRefArray)
            !PRINT "(6F20.6)", TRANSPOSE(TimeRefArray(20000:20010,:))
  
            DEALLOCATE( TimeRefArraySubset )
            DEALLOCATE( TimeRefArraySubsetMean )
            DEALLOCATE( Time_bnds )
            
!            PRINT *,'SIZE(TimeRefArray, 1)', SIZE(TimeRefArray, 1)
!            PRINT *,'SHAPE(TimeRefArray, 1)', SHAPE(TimeRefArray, 1)
!            PRINT *,'TimeRefArray(1,2)', TimeRefArray(1,2)
!            PRINT *,'TimeRefArray(744,2)', TimeRefArray(744,2)
!            PRINT *,'InDateTimeYear(it)', InDateTimeYear(it)

            ! only needed for aggregation_individually
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

            ! number of date/time steps in the ref array which match the current 
            ! year or month, or individual time span
            ! the TimeRefArray must span the requested subsets, this is a 
            ! special case as requested e.g. in some FPS sideline and WL/CM 
            ! studies
            ALLOCATE( ipos(0) )
            counter = 0
            IF (aggregation_individually) THEN
              PRINT *, "aggregation_individually"
              PRINT *,tsactYear, tsactMonth, tsactDay, tsactHour, teactYear, teactMonth, teactDay, teactHour

              tsact_singlenumber = REAL(tsactYear,8)*1000000._8 + REAL(tsactMonth,8)*10000._8 + REAL(tsactDay,8)*100._8 + REAL(tsactHour,8)
              teact_singlenumber = REAL(teactYear,8)*1000000._8 + REAL(teactMonth,8)*10000._8 + REAL(teactDay,8)*100._8 + REAL(teactHour,8)
              PRINT *, tsact_singlenumber, teact_singlenumber
              DO i = 1, SIZE(TimeRefArray, 1), 1
                IF ( ( TimeRefArray(i,6) >= tsact_singlenumber ) .AND. & 
                     ( TimeRefArray(i,6) <= teact_singlenumber ) ) THEN ! CHECK/TODO <= or < -->>> wrong wit <= when doing daily min/max: one day too many in time vec
                  counter = counter + 1
                  ipos = [ipos, i]
                END IF
              END DO
              PRINT *, "size ipos", SIZE(ipos)
              PRINT *, "counter = ", counter
              IF ( ( cell_methods(ivar) == "mean" ) .OR. &
                   ( cell_methods(ivar) == "sum" ) .OR. &
                   ( cell_methods(ivar) == "minimum" ) .OR. &
                   ( cell_methods(ivar) == "maximum" ) ) THEN
                counter = counter - 1
                ipos = ipos(1:counter)
                PRINT *, "size ipos", SIZE(ipos)
                PRINT *, "counter = ", counter
              END IF     

!              DO i = 1, SIZE(TimeRefArray, 1), 1
!                IF ( ( TimeRefArray(i,2) >= tsactYear ) .AND. & 
!                     ( TimeRefArray(i,2) <= teactYear ) .AND. &
!                     ( TimeRefArray(i,3) >= tsactMonth ) .AND. &
!                     ( TimeRefArray(i,3) <= teactMonth ) .AND. &
!                     ( TimeRefArray(i,4) >= tsactDay ) .AND. &
!                     ( TimeRefArray(i,4) < teactDay ) ) THEN !.AND. &
!!                   ( TimeRefArray(i,5) >= tsactHour ) .AND. &
!!                   ( TimeRefArray(i,5) <= teactHour ) ) THEN ! problem if the end of also 00UTC > then there is no match with the hours
!                  ! special case, e.g. 20090620_00:00:00 to 20090627_00:00:00 = defined timespan
!                  ! the last mean field is then 20090627_00:30:00, one less mean fields in the total time span covered
!                  counter = counter + 1
!                  ipos = [ipos, i]
!                END IF
!              END DO
!              ! see the problem with the ending, there is one timestep too
!              ! few in the file if this is not done
!              ! artifically add a further postion at the very end
!                  IF ( cell_methods(ivar) == "point" ) THEN ! and then also automatically sub-daily
!                    ipos = [ipos, ipos(counter)+1] 
!                    counter = counter + 1
!                  END IF
            ELSE IF (aggregation_monthly) THEN
              PRINT *, "aggregation_monthly"
              DO i = 1, SIZE(TimeRefArray, 1), 1
                IF (( TimeRefArray(i,2) == InDateTimeYear(it)) .AND. &
                   ( TimeRefArray(i,3) == InDateTimeMonth(it))) THEN
                  counter = counter + 1
                  ipos = [ipos, i]
                END IF
              END DO
              !!ipos = [ipos, ipos(counter)+1] 
              !!counter = counter + 1
            ELSE IF (aggregation_yearly) THEN ! default, CORDEX annual files
              PRINT *, "aggregation_annually"
              PRINT *, InDateTimeYear(it)
              DO i = 1, SIZE(TimeRefArray, 1), 1
                IF ( TimeRefArray(i,2) == InDateTimeYear(it)) THEN
                  counter = counter + 1
                  ipos = [ipos, i]
                END IF
              END DO
              !!ipos = [ipos, ipos(counter)+1] ! XXXXXXXXXX remove this
              !!counter = counter + 1
            END IF
            PRINT *, "timesteps in the time ref. subset = ", counter

            ALLOCATE( TimeRefArraySubset( counter, 5 ) ) ! index, y, m, d, h
            ALLOCATE( TimeRefArraySubsetMean( counter ) )
            ALLOCATE( Time_bnds( 2, counter ) )

            ! the TimeRefArraySubset is the time vec of the newly created (or
            ! already existing) file; it may be any size =< the original ref
            ! time vec; WRF data will be matched with this time vec
            ! this time vec is basically created for point data
            DO i = 1, counter, 1
              j = ipos(i)
              TimeRefArraySubset(i,1:5) = TimeRefArray(j,1:5)
              PRINT *, TimeRefArraySubset(i,1:5) ! index, y, m, d, h
            END DO
            !PRINT '(F9.3,1X,F5.0,1X,F3.0,1X,F3.0,1X,F3.0)', TRANSPOSE( TimeRefArraySubset(:,:) )
            !print *, TimeRefArraySubset(0,:)

            DEALLOCATE(ipos)

!-------------------------------------------------------------------------------
! create path- and filenames according to the ruleset of the CORDEX data 
! protocol: 2 main options here:
! Non standard:
! 1. individual time range
! 2. monthly, determined by input file
! Standard (storage file is determined by the temporal aggregation):
! 3. yearly, for anything higher than daily
! 4. 5-yearly or less, for anything daily
! 5. 10-yearly or less, for anything monthly or seasonally
! TODO: not all is implemented as the averaging is not yet implemented

            PRINT *, "generate path and filename"

            ! only a single file is created and filled successively
            ! use the information from the namelist
            ! 2009-06-20_00:00:00, may be full days or end e.g. at 23UTC
            ! arbitrary timespan
            IF (aggregation_individually) THEN

              WRITE (tsactYearStr,'(I4.4)') tsactYear
              WRITE (tsactMonthStr,'(I2.2)') tsactMonth
              WRITE (tsactDayStr,'(I2.2)') tsactDay
              WRITE (tsactHourStr,'(I2.2)') tsactHour
              WRITE (teactYearStr,'(I4.4)') teactYear
              WRITE (teactMonthStr,'(I2.2)') teactMonth
              WRITE (teactDayStr,'(I2.2)') teactDay
              WRITE (teactHourStr,'(I2.2)') teactHour 

              IF ((frequency(ifrq) == '1hr') .OR. &
                  (frequency(ifrq) == '3hr') .OR. &
                  (frequency(ifrq) == '6hr')) THEN

                FileNameStartDateTime = tsactYearStr//tsactMonthStr//tsactDayStr//tsactHourStr
                FileNameEndDateTime = teactYearStr//teactMonthStr//teactDayStr//teactHourStr

              ELSE IF (frequency(ifrq) == 'day') THEN
  
                FileNameStartDateTime = tsactYearStr//tsactMonthStr//tsactDayStr
                FileNameEndDateTime = teactYearStr//teactMonthStr//teactDayStr

              ELSE IF ((frequency(ifrq) == 'mon') .OR. &
                       (frequency(ifrq) == 'sem')) THEN

                FileNameStartDateTime = tsactYearStr//tsactMonthStr
                FileNameEndDateTime = teactYearStr//teactMonthStr

              END IF

            ! determined by the date information in the wrf outputs, automatic
            ! monthly aggregation is also special
            ELSE IF ( (aggregation_monthly) .OR. (aggregation_yearly) ) THEN

              !READ( InDateTimeYear(it), '(4A)' ) InDateTimeYearStr
              !READ( InDateTimeMonth(it), '(2A)' ) InDateTimeMonthStr
              WRITE (InDateTimeYearStr,'(I4.4)') InDateTimeYear(it)
              WRITE (InDateTimeMonthStr,'(I2.2)') InDateTimeMonth(it)              
              WRITE (LastDayStr,'(I2.2)') INT(TimeRefArraySubset(0,5))
              IF ( (cell_methods(ivar) == "mean") .OR. (cell_methods(ivar) == "sum") ) THEN 
                WRITE (FirstHourStr,'(I2.2)') INT( FLOOR( ((dthours/2.)*60.) / 60. ) )
                WRITE (FirstMinuteStr,'(I2.2)') INT( MOD( (dtHours/2.)*60., 60. ) )
                WRITE (LastHourStr,'(I2.2)') INT( FLOOR( ( (24.*60.) - (dthours/2.)*60.)  / 60. ) )
                WRITE (LastMinuteStr,'(I2.2)') INT( MOD( (24.*60.) - (dtHours/2.)*60., 60. ) )
                PRINT *, "first and last h + min strings: ", FirstHourStr, FirstMinuteStr, LastHourStr, LastMinuteStr
              ELSE
                FirstHourStr = "00"
                WRITE (LastHourStr,'(I2.2)') 24-INT(dtHours)
              END IF
              PRINT *, "date/time information for the automatic output path- and filename generation: ", &
                InDateTimeYearStr, InDateTimeMonthStr, FirstHourStr, LastHourStr, LastDayStr

              ! last hour may be YYYY-<NextMonth>-01_00:00:00 for point
              ! last hour may be YYYY-<NextMonth>-01_00:00:00 for mean (last 
              ! time in bound value) -> this is the old spec
              ! e.g.: time_bnds 21:00-24:00 and for the midpoint 22:30 
              ! here the new standard is applied:
              ! always have the midpoint time value of the first and last time 
              ! element in the file in the filename
              IF (aggregation_monthly) THEN

                IF ((frequency(ifrq) == '1hr') .OR. &
                    (frequency(ifrq) == '3hr') .OR. &
                    (frequency(ifrq) == '6hr')) THEN

                  IF ( (cell_methods(ivar) == "mean") .OR. (cell_methods(ivar) == "sum") ) THEN
                    FileNameStartDateTime = InDateTimeYearStr//InDateTimeMonthStr//"01"//FirstHourStr//FirstMinuteStr
                    FileNameEndDateTime = InDateTimeYearStr//InDateTimeMonthStr//LastDayStr//LastHourStr//LastMinuteStr
                  ELSE
                    FileNameStartDateTime = InDateTimeYearStr//InDateTimeMonthStr//"01"//FirstHourStr
                    FileNameEndDateTime = InDateTimeYearStr//InDateTimeMonthStr//LastDayStr//LastHourStr
                  END IF  

                ELSE IF (frequency(ifrq) == 'day') THEN
  
                  FileNameStartDateTime = InDateTimeYearStr//InDateTimeMonthStr//"01"
                  FileNameEndDateTime = InDateTimeYearStr//InDateTimeMonthStr//LastDayStr

                END IF

              ! with the full default, the aggregation in files depends all on 
              ! the temporal resolution of the data to be stored, see the 
              ! beginning of this section
              ! default: either annual, 5 years or 10 years, depending on the 
              ! aggregation
              ELSE IF (aggregation_yearly) THEN 

                IF ((frequency(ifrq) == '1hr') .OR. &
                    (frequency(ifrq) == '3hr') .OR. &
                    (frequency(ifrq) == '6hr')) THEN

                  IF ( (cell_methods(ivar) == "mean") .OR. (cell_methods(ivar) == "sum") ) THEN
                    FileNameStartDateTime = InDateTimeYearStr//"0101"//FirstHourStr//FirstMinuteStr
                    FileNameEndDateTime = InDateTimeYearStr//"1231"//LastHourStr//LastMinuteStr
                  ELSE
                    FileNameStartDateTime = InDateTimeYearStr//"0101"//FirstHourStr
                    FileNameEndDateTime = InDateTimeYearStr//"1231"//LastHourStr
                  END IF

                ! TODO: 5 yearly
                ELSE IF (frequency(ifrq) == 'day') THEN
  
                  FileNameStartDateTime = InDateTimeYearStr//"0101"
                  FileNameEndDateTime = InDateTimeYearStr//"1231"

                ! TODO: 10 yearly
                ELSE IF ((frequency(ifrq) == 'mon') .OR. &
                         (frequency(ifrq) == 'sem')) THEN

                  STOP "not yet implemented functionality, monthly/seasonally"
                !  FileNameStartDateTime = tsactYearStr//tsactMonthStr
                !  FileNameEndDateTime = teactYearStr//teactMonthStr

                END IF

              END IF

            END IF

            ! /hpc/shared/int/eva/ramod_WRF_CRPGL/WRFrv021rXXrcc3CpCdx/postpro/
            ! EUR-44/CRPGL/ECMWF-ERAINT/evaluation/r1i1p1/CRPGL-WRFARW331/v1
            pn_out = TRIM(project_id)                    // "/" // &
                     TRIM(product)                       // "/" // &
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

              !https://www.unidata.ucar.edu/software/netcdf/docs/netcdf-f90/NF90_005fCREATE.html
              PRINT *, "create netCDF file"
              sts = NF90_CREATE(TRIM(DirOutputPostProRoot) // "/" // &
                TRIM(pn_out) // "/" // TRIM(fn_out), IOR(NF90_NETCDF4, &
                NF90_CLASSIC_MODEL), ncid)

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
              IF ( ( cell_methods(ivar) == "mean" ) .OR. &
                   ( cell_methods(ivar) == "sum" ) .OR. &
                   ( cell_methods(ivar) == "minimum" ) .OR. &
                   ( cell_methods(ivar) == "maximum" ) ) THEN
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
              IF ( ( cell_methods(ivar) == "mean" ) .OR. &
                   ( cell_methods(ivar) == "sum" ) .OR. &
                   ( cell_methods(ivar) == "minimum" ) .OR. &
                   ( cell_methods(ivar) == "maximum" ) ) THEN
                sts = nf90_put_att(ncid, rec_varid, "bounds", "time_bnds")
              END IF
  
              ! for mean variables need the time bounds
              ! no further attributes, like plev_bnds > confirmed
              IF ( ( cell_methods(ivar) == "mean" ) .OR. &
                   ( cell_methods(ivar) == "sum" ) .OR. &
                   ( cell_methods(ivar) == "minimum" ) .OR. &
                   ( cell_methods(ivar) == "maximum" ) ) THEN
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
              ! this is a bit of a trick, although time informaiton in used to 
              ! sort in the data, the time vector is only derived from that 
              ! subset time vector, one could base the complete tool entirely
              ! very strictly on time and time_bnds information > v2 idea

              IF ( cell_methods(ivar) == "point" ) THEN
  
                PRINT *, 'cell_methods:', cell_methods(ivar)
                PRINT *, TimeRefArraySubset(:,1)
                sts = NF90_PUT_VAR(ncid, rec_varid, TimeRefArraySubset(:,1) )

              END IF

              IF ( ( cell_methods(ivar) == "mean" ) .OR. &
                   ( cell_methods(ivar) == "sum" ) .OR. &
                   ( cell_methods(ivar) == "minimum" ) .OR. &
                   ( cell_methods(ivar) == "maximum" ) ) THEN

                ! problem
                ! https://www.unidata.ucar.edu/mailing_lists/archives/netcdfgroup/2015/msg00071.html
                ! use the old scheme for the time_bnds
                ! mid-point of time interval [decimal days]
                TimeRefArraySubsetMean (:) = TimeRefArraySubset(:,1) + ( 0.5_8 * (1._8 / (24._8/dtHours) ) )
                PRINT *, "cell_methods:", cell_methods(ivar)
                PRINT *, "dtHours",  dtHours, dtHours/2.
                PRINT *, "TimeRefArraySubset", TimeRefArraySubset(:,1)
                PRINT *, "TimeRefArraySubsetMean, mid-points of time intervals: ", TimeRefArraySubsetMean(:)
                sts = NF90_PUT_VAR(ncid, rec_varid, TimeRefArraySubsetMean(:) )
                PRINT *, 'sts NF90_PUT_VAR time', sts
    
                Time_bnds(1,:) = TimeRefArraySubset(:,1)
                Time_bnds(2,:) = TimeRefArraySubset(:,1) + ( 1._8 * (1._8 / (24._8/dtHours) )) 
                PRINT *, "time bnds lower", Time_bnds(1,:)
                PRINT *, "time bnds upper", Time_bnds(2,:)
                sts = NF90_PUT_VAR(ncid, recbnds_varid, Time_bnds(:,:), START = (/ 1, 1 /) , COUNT = (/ 2, SIZE(Time_bnds(1,:)) /) )
                PRINT *, 'sts NF90_PUT_VAR time bnds', sts
  
              END IF
              !print *,'TimeRefArraySubset(:,1)', TimeRefArraySubset(:,1)

              ! TODO
              ! define plev_bnds, needed mainly for clh clm cli

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

              ! add plev from NML, [hPa] -> [Pa]
              IF ( ( height(ivar) /= -999 ) .AND. ( height(ivar) > 10. ) ) THEN
                sts = NF90_PUT_VAR(ncid, plev_varid, height(ivar)*100. )
              END IF

              !-----------------------------------------------------------------
  
              sts = NF90_CLOSE(ncid)

              !-----------------------------------------------------------------
  
            END IF ! file exists y/n

!-------------------------------------------------------------------------------
  
          ELSE ! checking whether this is the first pass or previously run

            PRINT *, "this is a subsequent pass, just read, procecess and sort in stuff"

          END IF

!-------------------------------------------------------------------------------
! match timestep 'it' of WRFin with the subset of the ref time vec which belongs
! to the netCDF file of the year/month/arbitrary timespan currently open to
! receive data
! counter = offset in the netCDF file
! this is done once for the 1h/3h/6h input (point/mean) AND daily data (min/max)
! this match 'translates' the way WRF stores variables tempotally to ESGF
! e.g. in the wrfxtrm files the min/max are for day1 are stored in 00UTC field
! of day2
  
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
! read orig WRF outputs
! there is always a corresponding time-slot in the NC file
! extracted time from above
! "it" controls it all: timestep in the individual WRF file
! there is only one variable at a time under processing

          PRINT *, "*** SOME VARS ALWAYS HAVE TO BE READ: (T00), P00 ***"
  
          sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin)
  
          ! HTr: read actual value of base state temperature T00
          ! vector, 1 value /timestep, usually constant
          ! default changed over time with WRF versions, was 290K, is 300K
          T00(1) = 300.0
          !sts = NF90_INQ_VARID(ncidin, "T00", t00_varid)
          !IF ( sts /= NF90_NOERR ) THEN
          !  T00(1) = 300.0
          !ELSE
          !  sts = NF90_GET_VAR(ncidin, t00_varid, T00(:), &
          !    START = (/ it /), COUNT = (/ 1 /) )
          !END IF
  
          ! HTr: use actual value of base state pressure P00, if possible
          sts = NF90_INQ_VARID(ncidin, "P00", p00_varid)
          IF ( sts /= NF90_NOERR ) THEN
            P00(1) = 100000.
          ELSE
            sts = NF90_GET_VAR(ncidin, p00_varid, P00(:), &
              START = (/ it /), COUNT = (/ 1 /) )
          END IF
          
          PRINT *, T00(1), P00(1)

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! data handling here is inefficient
! read too many variables
! read all vertical levels

          PRINT *, "*** READING OF VARIABLES ***"
          PRINT *, "variable to work on = ", TRIM(var_cmip(ivar))

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! psl [Pa] i Sea Level Pressure
! select via height:
!  ua [m s-1] i Eastward Wind
!  va [m s-1] i Northward Wind
!  wa
!  ta [K] i Air Temperature
!  hus [1] i Specific Humidity
!  zg
! prw [kg m-2] i Water Vapor Path
! clwvi [kg m-2] i Condensed Water Path  
! clwvi [kg m-2] i Condensed Water Path  
! cape [J kg-1] i 2-D Maximum convective available potential energy
! cin [J kg-1] i 2-D Maximum convective inhibition
! CONSIDER GRID STAGGERING
! keeping the code compact and avoiding unnecessary allocations is sometimes 
! tricky and may lead to unallocated variables during processing
! if changes are made here, it must be tested with each variable seperate (all 
! others OFF in the variable namelist) whether it works, otherwise the 
! allocation may still persist from a previous pass of the code with a different
! variable

          IF ( (var_cmip(ivar) == "psl") &
                .OR. (height(ivar) == 1000) &
                .OR. (height(ivar) == 925) &
                .OR. (height(ivar) == 850) &
                .OR. (height(ivar) == 700) &
                .OR. (height(ivar) == 500) &
                .OR. (height(ivar) == 200) &
                .OR. (var_cmip(ivar) == "prw") &
                .OR. (var_cmip(ivar) == "clwvi") &
                .OR. (var_cmip(ivar) == "clivi") &
                .OR. (var_cmip(ivar) == "cape") &
                .OR. (var_cmip(ivar) == "cin") ) THEN

            PRINT *,'read 3D vars'

            !-------------------------------------------------------------------
            ! internal vars needed in the pressure level / 3D processing section

            PRINT *, "allocate p_in, t_in, ph_fl" 
            IF (.not. ALLOCATED(p_in)) ALLOCATE( p_in( xfocus, yfocus, nz ), STAT=sts ) ! always needed
            IF (.not. ALLOCATED(t_in)) ALLOCATE( t_in( xfocus, yfocus, nz ), STAT=sts )
            IF (.not. ALLOCATED(ph_fl)) ALLOCATE( ph_fl( xfocus, yfocus, nz ), STAT=sts )

            IF ( var_cmip(ivar) == "prw" ) THEN
              IF (.not. ALLOCATED(prw)) ALLOCATE( prw( xfocus, yfocus ), STAT=sts )
            END IF

            IF ( var_cmip(ivar) == "psl" ) THEN
              IF (.not. ALLOCATED(psl_in)) ALLOCATE( psl_in ( xfocus, yfocus ), STAT=sts )
            END IF

            IF ( (var_cmip(ivar) == "cape" ) .OR. (var_cmip(ivar) == "cin" ) ) THEN
              IF (.not. ALLOCATED(cape)) ALLOCATE( cape( xfocus, yfocus ), STAT=sts )
              IF (.not. ALLOCATED(cin)) ALLOCATE( cin( xfocus, yfocus ), STAT=sts )
              IF (.not. ALLOCATED(t_p)) ALLOCATE( t_p( xfocus, yfocus, nz ), STAT=sts )
              IF (.not. ALLOCATED(qvs)) ALLOCATE( qvs( xfocus, yfocus, nz ), STAT=sts )
              IF (.not. ALLOCATED(lcl)) ALLOCATE( lcl( xfocus, yfocus ), STAT=sts )
              IF (.not. ALLOCATED(lfc)) ALLOCATE( lfc( xfocus, yfocus ), STAT=sts )
            END IF

            IF ( var_cmip(ivar) == "clwvi" ) THEN
              IF (.not. ALLOCATED(clwvi)) ALLOCATE( clwvi( xfocus, yfocus ), STAT=sts )
            ENDIF

            IF ( var_cmip(ivar) == "clivi" ) THEN
              IF (.not. ALLOCATED(clivi)) ALLOCATE( clivi( xfocus, yfocus ), STAT=sts )
            END IF

            ! PROBLEM to make this efficient: selection of vars via height
            ! is not really efficient; if one defines a list of concrete
            ! variable names this list has to always be expanded if a new 
            ! variable is needed
            IF ( height(ivar) > 10 ) THEN
              PRINT *, "prep. int. 3D pres. level vars"
              ! IF (.not. ALLOCATED(var_pl)) ALLOCATE( var_pl( xfocus, yfocus, 6 ), STAT=sts ) ! working on one variable at a time
              !!IF (.not. ALLOCATED(var_pl)) ALLOCATE( var_pl( xfocus, yfocus ), STAT=sts ) ! get completely rid of this thing
              ! var_pl(:,:,:) = mv
              !!var_pl(:,:) = mv
              IF (.not. ALLOCATED(var3d_in)) ALLOCATE( var3d_in( xfocus, yfocus, nz ), STAT=sts )
              !!!IF (.not. ALLOCATED(pout)) ALLOCATE( pout( SIZE(pout) ), STAT=sts ) ! # pressure levels can be removed
            END IF

            !-------------------------------------------------------------------
            ! read data as needed
            ! these 5 vars are always calculated

            !IF (.not. ALLOCATED(t2_in)) ALLOCATE( t2_in ( xfocus, yfocus ), STAT=sts )
            !sts = NF90_INQ_VARID(ncidin, "T2", t2_varid)
            !sts = NF90_GET_VAR(ncidin, t2_varid, t2_in(:,:), &
            !  START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
          
            IF ( ( var_cmip(ivar) == "prw" )   .OR. &
                 ( var_cmip(ivar) == "psl" )   .OR. &
                 ( height(ivar) > 10  )        .OR. &
                 ( var_cmip(ivar) == "clwvi" ) .OR. &
                 ( var_cmip(ivar) == "clivi" ) .OR. &
                 ( var_cmip(ivar) == "cape" )  .OR. &
                 ( var_cmip(ivar) == "cin" ) ) THEN

              PRINT *, "read P"
              IF (.not. ALLOCATED(pp_in)) ALLOCATE( pp_in( xfocus, yfocus, nz ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "P", pp_varid)
              sts = NF90_GET_VAR(ncidin, pp_varid, pp_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )

              PRINT *, "read PB"
              IF (.not. ALLOCATED(pb_in)) ALLOCATE( pb_in( xfocus, yfocus, nz ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "PB", pb_varid)
              sts = NF90_GET_VAR(ncidin, pb_varid, pb_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )

              PRINT *, "read PH"
              IF (.not. ALLOCATED(ph_in)) ALLOCATE( ph_in( xfocus, yfocus, nz+1 ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "PH", ph_varid)
              sts = NF90_GET_VAR(ncidin, ph_varid, ph_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz+1, 1 /) )

              PRINT *, "read PHB"
              IF (.not. ALLOCATED(phb_in)) ALLOCATE( phb_in( xfocus, yfocus, nz+1 ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "PHB", phb_varid)
              sts = NF90_GET_VAR(ncidin, phb_varid, phb_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz+1, 1 /) )

              PRINT *, "read T" ! perturbation potential temperature (theta-t0)
              IF (.not. ALLOCATED(theta_in)) ALLOCATE( theta_in( xfocus, yfocus, nz ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "T", theta_varid)
              sts = NF90_GET_VAR(ncidin, theta_varid, theta_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )

            END IF

            !-------------------------------------------------------------------

            IF ( ( var_cmip(ivar) == "prw" ) .OR. ( var_cmip(ivar) == "psl" ) .OR. &
                 ( SCAN(var_cmip(ivar),"hus") == 1 ) .OR. ( var_cmip(ivar) == "cape" ) .OR. &
                 ( var_cmip(ivar) == "cin" ) ) THEN
              PRINT *, "read QVAPOR"
              IF (.not. ALLOCATED(qv_in)) ALLOCATE( qv_in( xfocus, yfocus, nz  ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "QVAPOR", qv_varid)
              sts = NF90_GET_VAR(ncidin, qv_varid, qv_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
            END IF  

            IF ( var_cmip(ivar) == "clwvi" ) THEN
              PRINT *, "read QCLOUD"
              IF (.not. ALLOCATED(qc_in)) ALLOCATE( qc_in( xfocus, yfocus, nz  ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "QCLOUD", qc_varid)
              sts = NF90_GET_VAR(ncidin, qc_varid, qc_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
            END IF

            IF ( ( var_cmip(ivar) == "clwvi" ) .OR. ( var_cmip(ivar) == "clivi" ) ) THEN
              PRINT *, "read QICE"
              IF (.not. ALLOCATED(qi_in)) ALLOCATE( qi_in( xfocus, yfocus, nz  ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "QICE", qi_varid)
              sts = NF90_GET_VAR(ncidin, qi_varid, qi_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
            END IF

            IF ( var_cmip(ivar) == "clwvi" ) THEN
              PRINT *, "read QRAIN"
              IF (.not. ALLOCATED(qr_in)) ALLOCATE( qr_in( xfocus, yfocus, nz  ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "QRAIN", qr_varid)
              sts = NF90_GET_VAR(ncidin, qr_varid, qr_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
            END IF
  
            IF ( ( var_cmip(ivar) == "clwvi" ) .OR. ( var_cmip(ivar) == "clivi" ) ) THEN
              PRINT *, "read QSNOW"
              IF (.not. ALLOCATED(qs_in)) ALLOCATE( qs_in( xfocus, yfocus, nz  ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "QSNOW", qs_varid)
              sts = NF90_GET_VAR(ncidin, qs_varid, qs_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz, 1 /) )
            END IF

            IF ( (SCAN(var_cmip(ivar),"ua") == 1) .OR. (SCAN(var_cmip(ivar),"va") == 1) ) THEN
              PRINT *, "read U"
              IF (.not. ALLOCATED(u_in)) ALLOCATE( u_in( xfocus+1, yfocus, nz ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "U", u_varid)
              sts = NF90_GET_VAR(ncidin, u_varid, u_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus+1, yfocus, nz, 1 /) )
            END IF
  
            IF ( (SCAN(var_cmip(ivar),"ua") == 1) .OR. (SCAN(var_cmip(ivar),"va") == 1) ) THEN
              PRINT *, "read V"
              IF (.not. ALLOCATED(v_in)) ALLOCATE( v_in( xfocus, yfocus+1, nz ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "V", v_varid)
              sts = NF90_GET_VAR(ncidin, v_varid, v_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus+1, nz, 1 /) )
            END IF
            
            IF ( (SCAN(var_cmip(ivar),"wa") == 1) ) THEN
              PRINT *, "read W"
              IF (.not. ALLOCATED(w_in)) ALLOCATE( w_in( xfocus, yfocus, nz+1 ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "W", w_varid)
              sts = NF90_GET_VAR(ncidin, w_varid, w_in(:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, nz+1, 1 /) )
            END IF

            IF ( (SCAN(var_cmip(ivar),"ua") == 1) .OR. (SCAN(var_cmip(ivar),"va") == 1) ) THEN
              PRINT *, "read SINALPHA"
              IF (.not. ALLOCATED(sinalpha_in)) ALLOCATE( sinalpha_in( xfocus, yfocus ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "SINALPHA", sinalpha_varid)
              sts = NF90_GET_VAR(ncidin, sinalpha_varid, sinalpha_in(:,:), &
                START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
            END IF
  
            IF ( (SCAN(var_cmip(ivar),"ua") == 1) .OR. (SCAN(var_cmip(ivar),"va") == 1) ) THEN
              PRINT *, "read COSALPHA"
              IF (.not. ALLOCATED(cosalpha_in)) ALLOCATE( cosalpha_in( xfocus, yfocus ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "COSALPHA", cosalpha_varid)
              sts = NF90_GET_VAR(ncidin, cosalpha_varid, cosalpha_in(:,:), &
                START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
            END IF
  
            IF ( var_cmip(ivar) == "psl" ) THEN
              PRINT *, "read PSFC"
              IF (.not. ALLOCATED(psfc_in)) ALLOCATE( psfc_in( xfocus, yfocus ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "PSFC", psfc_varid)
              sts = NF90_GET_VAR(ncidin, psfc_varid, psfc_in(:,:), &
                START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
            END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! clt [%] a Total Cloud Fraction
  
          ELSE IF (var_cmip(ivar) == "clt") THEN

            IF (.not. ALLOCATED(cldfra_in)) ALLOCATE( cldfra_in( xfocus, yfocus, nz, 2 ), STAT=sts )   
  
            IF (it /= InDimLenRec) THEN

              sts = NF90_INQ_VARID(ncidin, "CLDFRA", varid)
              sts = NF90_GET_VAR(ncidin, varid, cldfra_in(:,:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), &
                COUNT = (/ xfocus, yfocus, nz, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_input)) ) THEN

              sts = NF90_INQ_VARID(ncidin, "CLDFRA", varid)
              sts = NF90_GET_VAR(ncidin, varid, cldfra_in(:,:,:,1), &
                START = (/ xoffset, yoffset, 1, it /), &
                COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
              iflWRFin = fl_input(ifl+1) ! set to the previous wrfoutfile 
                                          ! if it is not the first
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)

              sts = NF90_INQ_VARID(ncidin0, "CLDFRA", varid)
              sts = NF90_GET_VAR(ncidin0, varid, cldfra_in(:,:,:,2), &
                START = (/ xoffset, yoffset, 1, 1 /), &
                COUNT = (/ xfocus, yfocus, nz, 1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_input(ifl)  !set to the current wrfout file again

            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.

            END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! pr [kg m-2 s-1] a Precipitation 
! EURO-CORDEX Jan/2018 meeting, conv+incl. snow graupel, hail, etc.
! TODO CHECK !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! always need two adjacent output intervals to calculate the amount of precip
! between dates and consider whether the bucket_mm has been used:
! http://www2.mmm.ucar.edu/wrf/users/docs/user_guide_V3.8/users_guide_chap5.htm#bucket
  
          ELSE IF (var_cmip(ivar) == "pr") THEN 
             
            PRINT *, "read iflWRFin " , iflWRFin
            PRINT *, "it = ", it
            PRINT *, "inDimLenRec, number of output times in input = ", InDimLenRec

            ! e.g. it=1..24, 00UTC-23UTC, #24 fields/file > only 23 average fields
            ! 00-01UTC -> 00:30UTC average 
            ! try to read if 23UTC the 00UTC from next file
            ! this is all independent of bucket or not
            ! if 00-day1 to 00-day2, then the last search finds 00UTC-day2 as a match
            ! for 24UTC from day1 > will be written to 00:30 from day2 > no problem
            IF (it < InDimLenRec) THEN 

              PRINT *, "read rainc and rainnc two dates from the same file"

              IF (.not. ALLOCATED(rainnc_in)) ALLOCATE( rainnc_in ( xfocus, yfocus, 2 ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "RAINNC", rainnc_varid)
              sts = NF90_GET_VAR(ncidin, rainnc_varid, rainnc_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )

              IF (.not. ALLOCATED(rainc_in)) ALLOCATE( rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)  
              sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )

              sts = NF90_GET_ATT(ncidin, NF90_GLOBAL, "BUCKET_MM", bucket_mm)
              IF ( bucket_mm > 0. ) THEN
                IF (.not. ALLOCATED(i_rainnc_in)) ALLOCATE( i_rainnc_in ( xfocus, yfocus, 2 ), STAT=sts )
                sts = NF90_INQ_VARID(ncidin, "I_RAINNC", varid)
                sts = NF90_GET_VAR(ncidin, varid, i_rainnc_in(:,:,:), &
                  START = (/ xoffset, yoffset, it /), &
                  COUNT = (/ xfocus, yfocus, 2 /) )   
                IF (.not. ALLOCATED(i_rainc_in)) ALLOCATE( i_rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
                sts = NF90_INQ_VARID(ncidin, "I_RAINC", varid)
                sts = NF90_GET_VAR(ncidin, varid, i_rainc_in(:,:,:), &
                  START = (/ xoffset, yoffset, it /), &
                  COUNT = (/ xfocus, yfocus, 2 /) )
              END IF

            ! if the successor file exists, get the data from that file
            ! get the last available field from the current input file
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_input)) ) THEN

              PRINT *, "read rainc and rainnc from the current and the subsequent file"

              IF (.not. ALLOCATED(rainnc_in)) ALLOCATE( rainnc_in ( xfocus, yfocus, 2 ), STAT=sts )        
              sts = NF90_INQ_VARID(ncidin, "RAINNC", rainnc_varid)
              sts = NF90_GET_VAR(ncidin, rainnc_varid, rainnc_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus,yfocus, 1 /) )

              IF (.not. ALLOCATED(rainc_in)) ALLOCATE( rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
              sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)
              sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1 /) )

              sts = NF90_GET_ATT(ncidin, NF90_GLOBAL, "BUCKET_MM", bucket_mm)
              IF ( bucket_mm > 0. ) THEN
                IF (.not. ALLOCATED(i_rainnc_in)) ALLOCATE( i_rainnc_in ( xfocus, yfocus, 2 ), STAT=sts )
                sts = NF90_INQ_VARID(ncidin, "I_RAINNC", varid)
                sts = NF90_GET_VAR(ncidin, varid, i_rainnc_in(:,:,1), &
                  START = (/ xoffset, yoffset, it /), &
                  COUNT = (/ xfocus, yfocus, 1 /) )   
                IF (.not. ALLOCATED(i_rainc_in)) ALLOCATE( i_rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
                sts = NF90_INQ_VARID(ncidin, "I_RAINC", varid)
                sts = NF90_GET_VAR(ncidin, varid, i_rainc_in(:,:,1), &
                  START = (/ xoffset, yoffset, it /), &
                  COUNT = (/ xfocus, yfocus, 1 /) )
              END IF

              ! just get the next input file
              ! read the first timestep of the subsequent wrfout file
              iflWRFin = fl_input(ifl+1)
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "RAINNC", rainnc_varid)
              sts = NF90_GET_VAR(ncidin0, rainnc_varid, rainnc_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/ xfocus, yfocus,1 /) )

              sts = NF90_INQ_VARID(ncidin0, "RAINC", rainc_varid)  
              sts = NF90_GET_VAR(ncidin0, rainc_varid, rainc_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/ xfocus, yfocus,1 /) )

              sts = NF90_GET_ATT(ncidin0, NF90_GLOBAL, "BUCKET_MM", bucket_mm)
              IF ( bucket_mm > 0. ) THEN
                sts = NF90_INQ_VARID(ncidin0, "I_RAINNC", varid)
                sts = NF90_GET_VAR(ncidin0, varid, i_rainnc_in(:,:,2), &
                  START = (/ xoffset, yoffset, 1 /), &
                  COUNT = (/ xfocus, yfocus, 1 /) )   
                sts = NF90_INQ_VARID(ncidin0, "I_RAINC", varid)
                sts = NF90_GET_VAR(ncidin0, varid, i_rainc_in(:,:,2), &
                  START = (/ xoffset, yoffset, 1 /), &
                  COUNT = (/ xfocus, yfocus, 1 /) )
              END IF

              sts = NF90_CLOSE(ncidin0)

              ! set to the current wrfout file again
              iflWRFin = fl_input(ifl) 

            ! no further file, nothing can be done
            ! just pass missing values on
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.
  
            END IF
 
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! prc [kg m-2 s-1] a Convective Precipitation 
! read two timesteps to calculate 1h or 3h sum  

          ELSE IF (var_cmip(ivar) == "prc") THEN

            IF (.not. ALLOCATED(rainc_in)) ALLOCATE( rainc_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN
  
              sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)
              sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2/) ) 

              sts = NF90_GET_ATT(ncidin, NF90_GLOBAL, "BUCKET_MM", bucket_mm)
              IF ( bucket_mm > 0. ) THEN
                IF (.not. ALLOCATED(i_rainc_in)) ALLOCATE( i_rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
                sts = NF90_INQ_VARID(ncidin, "I_RAINC", varid)
                sts = NF90_GET_VAR(ncidin, varid, i_rainc_in(:,:,:), &
                  START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 2 /) )
              END IF

            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_input)) ) THEN 
  
                sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)
                sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,1), &
                  START = (/ xoffset, yoffset, it /), &
                  COUNT = (/ xfocus, yfocus, 1/))

                sts = NF90_GET_ATT(ncidin, NF90_GLOBAL, "BUCKET_MM", bucket_mm)
                IF ( bucket_mm > 0. ) THEN
                  IF (.not. ALLOCATED(i_rainc_in)) ALLOCATE( i_rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
                  sts = NF90_INQ_VARID(ncidin, "I_RAINC", varid)
                  sts = NF90_GET_VAR(ncidin, varid, i_rainc_in(:,:,1), &
                    START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
                END IF

                iflWRFin = fl_input(ifl+1)
  
                sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
                sts = NF90_INQ_VARID(ncidin0, "RAINC", rainc_varid)
                sts = NF90_GET_VAR(ncidin0, rainc_varid, rainc_in(:,:,2), &
                  START = (/ xoffset, yoffset, 1 /), &
                  COUNT = (/ xfocus,yfocus,1 /) ) 

                sts = NF90_GET_ATT(ncidin0, NF90_GLOBAL, "BUCKET_MM", bucket_mm)
                IF ( bucket_mm > 0. ) THEN
                  sts = NF90_INQ_VARID(ncidin0, "I_RAINC", varid)
                  sts = NF90_GET_VAR(ncidin0, varid, i_rainc_in(:,:,2), &
                    START = (/ xoffset, yoffset, 1 /), COUNT = (/ xfocus, yfocus, 1 /) )
                END IF
   
                sts = NF90_CLOSE(ncidin0)
  
                iflWRFin = fl_input(ifl)  !set to the current wrfout file again

            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.  
  
            END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! prsn [kg m-2 s-1] ?>a Snowfall Flux
  
          ELSE IF (var_cmip(ivar) == "prsn") THEN
  
            IF (.not. ALLOCATED(snownc_in)) ALLOCATE( snownc_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SNOWNC", snownc_varid)
              sts = NF90_GET_VAR(ncidin, snownc_varid, snownc_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 2 /) )
           
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_input)) ) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SNOWNC", snownc_varid)
              sts = NF90_GET_VAR(ncidin, snownc_varid, snownc_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1/))
  
              iflWRFin = fl_input(ifl+1)
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "SNOWNC", snownc_varid)
              sts = NF90_GET_VAR(ncidin0, snownc_varid, snownc_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/xfocus, yfocus, 1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_input(ifl)
  
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.  
  
            END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! snm [kg m-2 s-1] a Surface Snow Melt
  
          ELSE IF (var_cmip(ivar) == "snm") THEN
  
            IF (.not. ALLOCATED(acsnom_in)) ALLOCATE( acsnom_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN
  
              sts = NF90_INQ_VARID(ncidin, "ACSNOM", acsnom_varid)
              sts = NF90_GET_VAR(ncidin, acsnom_varid, acsnom_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
              print*, sts
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_input)) ) THEN
  
              sts = NF90_INQ_VARID(ncidin, "ACSNOM", acsnom_varid)
              sts = NF90_GET_VAR(ncidin, acsnom_varid, acsnom_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1 /))
  
              iflWRFin = fl_input(ifl+1)
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
              
              sts = NF90_INQ_VARID(ncidin0, "ACSNOM", acsnom_varid)
              sts = NF90_GET_VAR(ncidin0, acsnom_varid, acsnom_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus, yfocus, 1 /) )
            
              sts = NF90_CLOSE(ncidin0)
            
              iflWRFin = fl_input(ifl)
              
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.  
  
            END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! evspsbl [kg m-2 s-1] a Evaporation
  
          ELSE IF (var_cmip(ivar) == "evspsbl") THEN
  
            IF (.not. ALLOCATED(sfcevp_in)) ALLOCATE( sfcevp_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SFCEVP", sfcevp_varid)
              sts = NF90_GET_VAR(ncidin, sfcevp_varid, sfcevp_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
            
            ELSE IF ( (it == InDimLenRec) .AND. (ifl /= SIZE(fl_input)) ) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SFCEVP", sfcevp_varid)
              sts = NF90_GET_VAR(ncidin, sfcevp_varid, sfcevp_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1/))
  
              iflWRFin = fl_input(ifl+1) 
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "SFCEVP", sfcevp_varid)
              sts = NF90_GET_VAR(ncidin0, sfcevp_varid, sfcevp_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus,yfocus, 1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_input(ifl)  !set to the current wrfout file again
  
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.  
  
            END IF 
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! evspblpot [kg m-2 s-1] a Potential Evapotranspiration 
  
          ELSE IF (var_cmip(ivar) == "evspsblpot") THEN
  
            IF (.not. ALLOCATED(potevp_in)) ALLOCATE( potevp_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN         
  
              sts = NF90_INQ_VARID(ncidin, "POTEVP", potevp_varid)
              sts = NF90_GET_VAR(ncidin, potevp_varid, potevp_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .AND. (ifl /= SIZE(fl_input)) ) THEN
  
              sts = NF90_INQ_VARID(ncidin, "POTEVP", potevp_varid)
              sts = NF90_GET_VAR(ncidin, potevp_varid, potevp_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              iflWRFin = fl_input(ifl+1)
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
                sts = NF90_INQ_VARID(ncidin0, "POTEVP", potevp_varid)
                sts = NF90_GET_VAR(ncidin0, potevp_varid, potevp_in(:,:,2), &
                  START = (/ xoffset, yoffset, 1 /), &
                  COUNT =(/xfocus,yfocus,1 /) )
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_input(ifl)  !set to the current wrfout file again
  
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.  
  
            END IF 
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! mrros [kg m-2 s-1] a Surface Runoff
  
          ELSE IF (var_cmip(ivar) == "mrros") THEN
  
            IF (.not. ALLOCATED(sfroff_in)) ALLOCATE( sfroff_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SFROFF", sfroff_varid)
              sts = NF90_GET_VAR(ncidin, sfroff_varid, sfroff_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_input)) ) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SFROFF", sfroff_varid)
              sts = NF90_GET_VAR(ncidin, sfroff_varid, sfroff_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              iflWRFin = fl_input(ifl+1)
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
                sts = NF90_INQ_VARID(ncidin0, "SFROFF", sfroff_varid)
                sts = NF90_GET_VAR(ncidin0, sfroff_varid, sfroff_in(:,:,2), &
                  START = (/ xoffset, yoffset, 1 /), &
                  COUNT =(/xfocus,yfocus, 1 /) )
              sts = NF90_CLOSE(ncidin0)

              iflWRFin = fl_input(ifl)
  
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.  
  
            END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! mrro [kg m-2 s-1] a Total Runoff
  
          ELSE IF (var_cmip(ivar) == "mrro") THEN
  
            IF (.not. ALLOCATED(sfroff_in)) ALLOCATE( sfroff_in ( xfocus, yfocus, 2 ), STAT=sts )
            IF (.not. ALLOCATED(udroff_in)) ALLOCATE( udroff_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SFROFF", sfroff_varid)
              sts = NF90_GET_VAR(ncidin, sfroff_varid, sfroff_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
              sts = NF90_INQ_VARID(ncidin, "UDROFF", udroff_varid)
              sts = NF90_GET_VAR(ncidin, udroff_varid, udroff_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
  
            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_input)) ) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SFROFF", sfroff_varid)
              sts = NF90_GET_VAR(ncidin, sfroff_varid, sfroff_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus,1/))
  
              sts = NF90_INQ_VARID(ncidin, "UDROFF", udroff_varid)
              sts = NF90_GET_VAR(ncidin, udroff_varid, udroff_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT =(/xfocus,yfocus,1 /) )
  
              iflWRFin = fl_input(ifl+1)
  
              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
              sts = NF90_INQ_VARID(ncidin0, "SFROFF", sfroff_varid)
              sts = NF90_INQ_VARID(ncidin0, "UDROFF", udroff_varid)
  
              sts = NF90_GET_VAR(ncidin0, sfroff_varid, sfroff_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus, yfocus, 1 /) )
  
              sts = NF90_GET_VAR(ncidin0, udroff_varid, udroff_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT =(/xfocus, yfocus, 1 /) )
  
              sts = NF90_CLOSE(ncidin0)
  
              iflWRFin = fl_input(ifl)
  
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.  
  
            END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! rsds [W m-2] a Surface Downwelling Shortwave Radiation
! rlds [W m-2] a Surface Downwelling Longwave Radiation
! rsus [W m-2] a Surface Upwelling Shortwave Radiation 
! rlus [W m-2] a Surface Upwelling Longwave Radiation
! hfss [W m-2] a Surface Upward Latent Heat Flux
! hfls [W m-2] a Surface Upward Sensible Heat Flux
! rlut [W m-2] a TOA Outgoing Longwave Radiation
! rsdt [W m-2] a TOA Incident Shortwave Radiation
! rsut [W m-2] a TOA Outgoing Shortwave Radiation
! only method in use finally: accumulated values with bucket
! restriction: assume bucket is used
  
          ELSE IF ((var_cmip(ivar) == "rsds") &
            .OR. (var_cmip(ivar) == "rlds") &
            .OR. (var_cmip(ivar) == "rsus") &
            .OR. (var_cmip(ivar) == "rlus") &
            .OR. (var_cmip(ivar) == "hfss") &
            .OR. (var_cmip(ivar) == "hfls") &
            .OR. (var_cmip(ivar) == "rlut") &
            .OR. (var_cmip(ivar) == "rsdt") &
            .OR. (var_cmip(ivar) == "rsut")) THEN

            PRINT *, "get radiation variables incl. bucket if set"

            IF (.not. ALLOCATED(rad_in)) ALLOCATE( rad_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN
 
              PRINT *, "read rad_in for two times from the same file"

              sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
              sts = NF90_GET_VAR(ncidin, varid, rad_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )
 
              sts = NF90_GET_ATT(ncidin, NF90_GLOBAL, "BUCKET_J", bucket_J)
              IF ( bucket_J > 0. ) THEN
                IF (.not. ALLOCATED(i_rad_in)) ALLOCATE( i_rad_in ( xfocus, yfocus, 2 ), STAT=sts )
                sts = NF90_INQ_VARID(ncidin, TRIM('I_' // var_wrf(ivar)), varid)
                sts = NF90_GET_VAR(ncidin, varid, i_rad_in(:,:,:), &
                  START = (/ xoffset, yoffset, it /), &
                  COUNT = (/ xfocus, yfocus, 2 /) )
              END IF

            ELSE IF ( (it == InDimLenRec) .AND. (ifl /= SIZE(fl_input)) ) THEN
  
              PRINT *, "read rad_in for one timestep from two files each"

              sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
              sts = NF90_GET_VAR(ncidin, varid, rad_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1/))

              sts = NF90_GET_ATT(ncidin, NF90_GLOBAL, "BUCKET_J", bucket_J)
              IF ( bucket_J > 0. ) THEN
                IF (.not. ALLOCATED(i_rad_in)) ALLOCATE( i_rad_in ( xfocus, yfocus, 2 ), STAT=sts )
                sts = NF90_INQ_VARID(ncidin, TRIM('I_' // var_wrf(ivar)), varid)
                sts = NF90_GET_VAR(ncidin, varid, i_rad_in(:,:,1), &
                  START = (/ xoffset, yoffset, it /), &
                  COUNT = (/ xfocus, yfocus, 1 /) )
              END IF

              iflWRFin = fl_input(ifl+1)

              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)

              sts = NF90_INQ_VARID(ncidin0, TRIM(var_wrf(ivar)), varid)
              sts = NF90_GET_VAR(ncidin0, varid, rad_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/ xfocus, yfocus, 1/))

              sts = NF90_GET_ATT(ncidin0, NF90_GLOBAL, "BUCKET_J", bucket_J)
              IF ( bucket_J > 0. ) THEN
                sts = NF90_INQ_VARID(ncidin0, TRIM('I_' // var_wrf(ivar)), varid)
                sts = NF90_GET_VAR(ncidin0, varid, i_rad_in(:,:,2), &
                  START = (/ xoffset, yoffset, 1 /), &
                  COUNT = (/ xfocus, yfocus, 1 /) )
              END IF

              sts = NF90_CLOSE(ncidin0)

              iflWRFin = fl_input(ifl)
  
            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.
  
            END IF
  
            PRINT *, "values in middle of domain = ", var_cmip(ivar), rad_in(xfocus/2,yfocus/2,1), rad_in(xfocus/2,yfocus/2,2)
            PRINT *, "difference [J m-2] = ", (rad_in(xfocus/2,yfocus/2,2) - rad_in(xfocus/2,yfocus/2,1))
            PRINT *, "mean [W m-2] = ", (rad_in(xfocus/2,yfocus/2,2) - rad_in(xfocus/2,yfocus/2,1))/ (dtHours*3600.)
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! sund [s] s Duration of Sunshine
! WMO definition >= 120 W m-2

          ELSE IF (var_cmip(ivar) == "sund") THEN

            IF (.not. ALLOCATED(swdown_in)) ALLOCATE( swdown_in ( xfocus, yfocus, 2 ), STAT=sts )

            IF (it /= InDimLenRec) THEN
 
              sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
              sts = NF90_GET_VAR(ncidin, varid, swdown_in(:,:,:), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 2 /) )

            ELSE IF ( (it == InDimLenRec) .AND. (ifl /= SIZE(fl_input)) ) THEN

              sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
              sts = NF90_GET_VAR(ncidin, varid, swdown_in(:,:,1), &
                START = (/ xoffset, yoffset, it /), &
                COUNT = (/ xfocus, yfocus, 1/))

              iflWRFin = fl_input(ifl+1)

              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)

              sts = NF90_INQ_VARID(ncidin0, TRIM(var_wrf(ivar)), varid)
              sts = NF90_GET_VAR(ncidin0, varid, swdown_in(:,:,2), &
                START = (/ xoffset, yoffset, 1 /), &
                COUNT = (/ xfocus, yfocus, 1/))

              sts = NF90_CLOSE(ncidin0)

              iflWRFin = fl_input(ifl)

            ELSE

              PRINT *, "no data available for average calculation any more"

              calc = .FALSE.
  
            END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! mrso [kg m-2] i Total Soil Moisture Content
! was beforehand treated as averaged variable, but is defined instantaneous
  
          ELSE IF (var_cmip(ivar) == "mrso") THEN
 
            IF (.not. ALLOCATED(DZS)) ALLOCATE( DZS( 4 ), STAT=sts )
            sts = NF90_INQ_VARID(ncidin, "DZS", varid)
            IF ( sts /= NF90_NOERR ) THEN
              DZS = (/ 0.1, 0.3, 0.6, 1.0 /) ! total with Noah LSM 2m depth
            ELSE
              sts = NF90_GET_VAR(ncidin, varid, DZS, &
              START = (/ 1, it /), COUNT = (/ 4, 1 /) )
              PRINT*,'DZS ', DZS(:)
            END IF
 
!            IF (.not. ALLOCATED(smois_in)) ALLOCATE( smois_in( xfocus, yfocus, 4, 2 ), STAT=sts )
            IF (.not. ALLOCATED(smois_in)) ALLOCATE( smois_in( xfocus, yfocus, 4, 1 ), STAT=sts )
  
!            IF (it /= InDimLenRec) THEN
  
              sts = NF90_INQ_VARID(ncidin, "SMOIS", varid)
              sts = NF90_GET_VAR(ncidin, varid, smois_in(:,:,:,:), &
                START = (/ xoffset, yoffset, 1, it /), &
                COUNT = (/ xfocus, yfocus, 4, 1 /) )
!                COUNT = (/ xfocus, yfocus, 4, 2 /) )
  
!            ELSE IF ( (it == InDimLenRec) .and. (ifl /= SIZE(fl_input)) ) THEN
  
!              sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
!              sts = NF90_GET_VAR(ncidin, varid, smois_in(:,:,:,1), &
!                START = (/ xoffset, yoffset, it /), &
!                COUNT = (/ xfocus, yfocus,1/))
  
!              iflWRFin = fl_input(ifl) ! set to the previous wrfoutfile 
!                                        ! if it is not the first 
  
!              sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin0)
  
!              sts = NF90_INQ_VARID(ncidin0, TRIM(var_wrf(ivar)), varid)
!              sts = NF90_GET_VAR(ncidin0, varid, smois_in(:,:,:,2), &
!                START = (/ xoffset, yoffset, 1 /), &
!                COUNT =(/xfocus,yfocus,1 /) )
  
!              sts = NF90_CLOSE(ncidin0)
  
!              iflWRFin = fl_input(ifl)  !set to the current wrfout file again
  
!            END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! sfcWind [m s-1] i Near-Surface Wind Speed

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
! uas [m s-1] i Eastward Near-Surface Wind
! vas [m s-1] i Northward Near-Surface Wind

          ELSE IF ((var_cmip(ivar) == "uas") .OR. (var_cmip(ivar) == "vas")) THEN
  
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
! prhmax [kg m-2 s-1] m Daily Maximum Hourly Precipitation Rate (using wrfxtrm)
! reuse variables form rainc and rainnc
! special offset, as needed with minimum and maximum per file 
! as 'it' counts per input file this is OK

          ELSE IF (var_cmip(ivar) == "prhmax") THEN
 
            IF (.not. ALLOCATED(rainc_max_in)) ALLOCATE( rainc_max_in ( xfocus, yfocus ), STAT=sts ) 
            IF (.not. ALLOCATED(rainnc_max_in)) ALLOCATE( rainnc_max_in ( xfocus, yfocus ), STAT=sts )
  
            sts = NF90_INQ_VARID(ncidin, "RAINCVMAX", rainc_varid)
            sts = NF90_INQ_VARID(ncidin, "RAINNCVMAX", rainnc_varid)
  
            sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_max_in(:,:), &
              START = (/ xoffset, yoffset, it+1 /), COUNT = (/ xfocus, yfocus, 1 /) )
            sts = NF90_GET_VAR(ncidin, rainnc_varid, rainnc_max_in(:,:), &
              START = (/ xoffset, yoffset, it+1 /), COUNT = (/ xfocus, yfocus, 1 /) )
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! two possibilities with sea ice: either in SEAICE variable as fractional sea 
! ice, or contained as binary sea ice in the landmask field during runtime
! extent: XLAND = LU_INDEX

!          ELSE IF ( (var_cmip(ivar) == "sic") .AND. (fractSeaIce .EQV. .FALSE.) ) THEN

!            IF (.not. ALLOCATED(landmask_in)) ALLOCATE( landmask_in ( xfocus, yfocus ), STAT=sts ) 
!            IF (.not. ALLOCATED(xland_in)) ALLOCATE( xland_in ( xfocus, yfocus ), STAT=sts )
  
!            sts = NF90_INQ_VARID(ncidin, "LANDMASK", landmask_varid)
!            sts = NF90_INQ_VARID(ncidin, "XLAND", xland_varid)
  
!            sts = NF90_GET_VAR(ncidin, landmask_varid, landmask_in(:,:), &
!              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
!            sts = NF90_GET_VAR(ncidin, xland_varid, xland_in(:,:), &
!              START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! this is all others variables which are solely based on a namelist for whom 
! no processing is needed whatsoever, e.g. tas, ps, huss, ...
! they are read into data_in and also passed on in this 2D array for writing

          ELSE

            PRINT *, "variable to read/write with no additional processing = ", var_wrf(ivar)
  
            sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)
  
            IF ( ( cell_methods(ivar) == "minimum" ) .OR. &
                 ( cell_methods(ivar) == "maximum" ) ) THEN
              sts = NF90_GET_VAR(ncidin, varid, data_in(:,:), &
                    START = (/ xoffset, yoffset, it+1 /), COUNT = (/ xfocus, yfocus, 1 /) )
            ELSE 
              sts = NF90_GET_VAR(ncidin, varid, data_in(:,:), &
                    START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
            END IF

          END IF
  
          sts = NF90_CLOSE(ncidin)

!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! some analysis of the data
!  
!         PRINT *, "*** STATISTICS BEFORE PROCESSING OF VARIABLES ***"
!         PRINT *, "(useless if data is stored in other vars than 'data_in')"
!
!         print *, "shape of array" , SHAPE(data_in)
!         print *, "size of array" , SIZE(data_in)
!         stat_mean = SUM(data_in(:,:))/SIZE(data_in(:,:))
!         PRINT *, "mean of array", stat_mean
!
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! this is where the real processing takes place 
! if nothing is to be calculated or scaled, etc., then the variables are just
! passed on to the write section in data_in
  
          PRINT *, "*** PROCESSING OF VARIABLES ***"

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! CORDEX [X], FPS CEM [X]
! vars on pressure levels > for simplicity and as we like to use these data
! instead of the original model outputs: extract and convert more than specified
! at full temporal resolution, selective aggregation later
! use different interpolation methods for different variables
! psl [Pa] i Sea Level Pressure
! ua [m s-1] i Eastward Wind
! va [m s-1] i Northward Wind
! ta [K] i Air Temperature
! hus [1] i Specific Humidity
! also needed:
! wa
! zg
! levels needed CORDEX:            850       500  200
! levels needed FPS   : 1000  925   "   700   "    "

          IF ( (var_cmip(ivar) == "psl") .OR. &
               (height(ivar) == 1000) .OR. &
               (height(ivar) == 925) .OR. &
               (height(ivar) == 850) .OR. &
               (height(ivar) == 700) .OR. &
               (height(ivar) == 500) .OR. &
               (height(ivar) == 200) .OR. &
               (var_cmip(ivar) == "prw") .OR. &
               (var_cmip(ivar) == "clwvi") .OR. &
               (var_cmip(ivar) == "clivi") .OR. &
               (var_cmip(ivar) == "cape") .OR. &
               (var_cmip(ivar) == "cin") ) THEN

            PRINT *, var_cmip(ivar), height(ivar)

            ! needs this initialisation, might be possible that for very low
            ! high levels calculation cannot be done, then it is set to official
            ! missing value
            data_in(:,:) = mv

            ! total pressure [Pa]
            ! perturbation pressure + base state pressure
            ! see: http://www2.mmm.ucar.edu/wrf/users/docs/user_guide_V3.8/users_guide_chap5.htm
            p_in(:,:,:) = pp_in(:,:,:) + pb_in(:,:,:)

            ! PH and PHB are on nz+1 levels
            ! vertically destaggering
            ! total geopotential height [m]
            ! see: http://www2.mmm.ucar.edu/wrf/users/docs/user_guide_V3.8/users_guide_chap5.htm
            DO nl = 1,nz 
              ph_fl(:,:,nl) = ((ph_in(:,:,nl)+phb_in(:,:,nl))+ &
                              (ph_in(:,:,nl+1)+phb_in(:,:,nl+1)))/2./gr
            END DO

            ! transfer theta-t0 to total potential temperature [K]
            ! and then convert potential temperature theta to absolute temperature
            ! this is the correct version, using 290K as base temp
            ! wrfpress contains data that are still calculated with 300K
            t_in(:,:,:) = ( theta_in(:,:,:) + T00(1) ) * &
                          ( p_in(:,:,:) / P00(1) )**(R/cp)

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

            IF (height(ivar) == 1000) THEN
              np = 1
            ELSE IF (height(ivar) == 925) THEN
              np = 2
            ELSE IF (height(ivar) == 850) THEN
              np = 3
            ELSE IF (height(ivar) == 700) THEN
              np = 4
            ELSE IF (height(ivar) == 500) THEN
              np = 5
            ELSE IF (height(ivar) == 200) THEN
              np = 6
            END IF
 
            ! vars needed: 3x int.: t_in, p_in, ph_fl 
            !              -> need: ph_in, phb_in, theta_in, pp_in, pb_in
            ! var_pl, var3d_in
            ! pout, slope, zg_pout
            ! comparison with wrfpress, same time: distribution OK, but ours is
            ! much colder, old vs new scheme about identical, ta500
            IF ( (var_cmip(ivar) == "ta1000") .OR. &
                 (var_cmip(ivar) == "ta925") .OR.  &
                 (var_cmip(ivar) == "ta850") .OR.  &
                 (var_cmip(ivar) == "ta700") .OR.  &
                 (var_cmip(ivar) == "ta500") .OR.  &
                 (var_cmip(ivar) == "ta200") ) THEN
              PRINT *, "calc ta..."
              var3d_in(:,:,:) = t_in(:,:,:)
              ! linear in zg
              DO i = 1,xfocus 
                DO j = 1,yfocus
                  DO nl = 1,nz - 1
                    IF (pout(np).LE.p_in(i,j,nl) .AND. pout(np).GT.p_in(i,j,nl+1)) THEN
                      ! HTr: calculate zg at pout, first (linear in log(p)
                      !slope = (ph_fl(i,j,nl)-ph_fl(i,j,nl+1))/ (LOG(p_in(i,j,nl))-LOG(p_in(i,j,nl+1)))
                      !zg_pout = ph_fl(i,j,nl+1) + slope* (LOG(pout(np))-LOG(p_in(i,j,nl+1)))
                      ! HTr: interpolate linearly in zg
                      !slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/ &
                      !        (ph_fl(i,j,nl)-ph_fl(i,j,nl+1))
                      !var_pl(i,j) = var3d_in(i,j,nl+1) + &
                      !              slope*(zg_pout-ph_fl(i,j,nl+1))
                      slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/&
                              (p_in(i,j,nl)-p_in(i,j,nl+1))
                      data_in(i,j) = var3d_in(i,j,nl+1) + &
                                    slope*(pout(np)-p_in(i,j,nl+1))
                    END IF
                  END DO
                END DO
              END DO

            ! vars needed: int.: p_in (> in: pp_in, pb_in)
            !              out: var_pl, var3d_in
            !              tmp: pout, slope, zg_pout
            !              in: qv_in
            ! comparison with wrfpress, same time: about identical, also old and 
            ! new scheme, simple vs. sophisticated, hus500
            ELSE IF ( (var_cmip(ivar) == "hus1000") .OR. &
                 (var_cmip(ivar) == "hus925") .OR.       &
                 (var_cmip(ivar) == "hus850") .OR.       &
                 (var_cmip(ivar) == "hus700") .OR.       &
                 (var_cmip(ivar) == "hus500") .OR.       &
                 (var_cmip(ivar) == "hus200") ) THEN
              PRINT *, "calc hus..."
              var3d_in(:,:,:) = qv_in(:,:,:)
              ! linear in log(p)
              DO i = 1,xfocus
                DO j = 1,yfocus
                  DO nl = 1,nz - 1
                    IF (pout(np).LE.p_in(i,j,nl) .AND. pout(np).GT.p_in(i,j,nl+1)) THEN
                      !slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/ &
                      !        (LOG(p_in(i,j,nl))-LOG(p_in(i,j,nl+1)))
                      !var_pl(i,j) = var3d_in(i,j,nl+1) + &
                      !              slope*(LOG(pout(np))-LOG(p_in(i,j,nl+1)))
                      slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/&
                              (p_in(i,j,nl)-p_in(i,j,nl+1))
                      data_in(i,j) = var3d_in(i,j,nl+1) + &
                                    slope*(pout(np)-p_in(i,j,nl+1))
                    END IF
                  END DO
                END DO
              END DO

            ! check as is: strange data holes, all negative speeds are affected
            ! compare with wrfpress orig run, looks good, distribution OK
            ! compare with heimo old, identical
            ! insert SKn routine, simplified interpolation: looks OK
            ! could also compare with p_interp: processeding and code: not done
            ! comparison with wrfpress, same time: apart from the holes where
            ! negative values are with the more sophisticated scheme, all three
            ! datasets about identical: pattern and range, wrfpress, old scheme,
            ! new scheme
            ELSE IF ( (var_cmip(ivar) == "ua1000") .OR. &
                 (var_cmip(ivar) == "ua925") .OR.       &
                 (var_cmip(ivar) == "ua850") .OR.       &
                 (var_cmip(ivar) == "ua700") .OR.       &
                 (var_cmip(ivar) == "ua500") .OR.       &
                 (var_cmip(ivar) == "ua200") ) THEN
              ! rotate to earth grid and destagger
              PRINT *, "calc ua..."
              DO i = 1,xfocus
                var3d_in(i,:,:) = ((u_in(i,:,:)+u_in(i+1,:,:))/2.)*cosalpha_in(:,:) - &
                                  ((v_in(i,:,:)+v_in(i+1,:,:))/2.)*sinalpha_in(:,:) 
              END DO
              ! logarithmic in zg
              DO i = 1,xfocus 
                DO j = 1,yfocus
                  DO nl = 1,nz - 1
                    IF (pout(np).LE.p_in(i,j,nl) .AND. pout(np).GT.p_in(i,j,nl+1)) THEN
                      ! HTr: calculate zg at pout, first (linear in log(p)
                      !slope = (ph_fl(i,j,nl)-ph_fl(i,j,nl+1))/ &
                      !        (LOG(p_in(i,j,nl))-LOG(p_in(i,j,nl+1)))
                      !zg_pout = ph_fl(i,j,nl+1) + slope* &
                      !          (LOG(pout(np))-LOG(p_in(i,j,nl+1)))
                      ! HTr: interpolate logarithmic in zg
                      !slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/ &
                      !        (ph_fl(i,j,nl)-ph_fl(i,j,nl+1))
                      !var_pl(i,j) = var3d_in(i,j,nl) * &
                      !                 EXP( (zg_pout - ph_fl(i,j,nl)) * &
                      !                      (LOG(var3d_in(i,j,nl+1)) - &
                      !                       LOG(var3d_in(i,j,nl))) / &
                      !                 (ph_fl(i,j,nl+1)-ph_fl(i,j,nl)))
                      slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/&
                              (p_in(i,j,nl)-p_in(i,j,nl+1))
                      data_in(i,j) = var3d_in(i,j,nl+1) + &
                                    slope*(pout(np)-p_in(i,j,nl+1))
                    END IF
                  END DO
                END DO
              END DO

            ! comparison with wrfpress, same time: simple scheme about the same
            ! results
            ELSE IF ( (var_cmip(ivar) == "va1000") .OR. &
                 (var_cmip(ivar) == "va925") .OR.       &
                 (var_cmip(ivar) == "va850") .OR.       &
                 (var_cmip(ivar) == "va700") .OR.       &
                 (var_cmip(ivar) == "va500") .OR.       &
                 (var_cmip(ivar) == "va200") ) THEN
              ! rotate to earth grid and destagger
              DO j = 1,yfocus
                var3d_in(:,j,:) = (v_in(:,j,:)+v_in(:,j+1,:))/2.*cosalpha_in(:,:) + &
                                  (u_in(:,j,:)+u_in(:,j+1,:))/2.*sinalpha_in(:,:) 
              END DO
              ! logarithmic in zg
              DO i = 1,xfocus 
                DO j = 1,yfocus
                  DO nl = 1,nz - 1
                    IF (pout(np).LE.p_in(i,j,nl) .AND. pout(np).GT.p_in(i,j,nl+1)) THEN                
                      ! HTr: calculate zg at pout, first (linear in log(p)
                      !slope = (ph_fl(i,j,nl)-ph_fl(i,j,nl+1))/ (LOG(p_in(i,j,nl))-LOG(p_in(i,j,nl+1)))
                      !zg_pout = ph_fl(i,j,nl+1) + slope* (LOG(pout(np))-LOG(p_in(i,j,nl+1)))
                      ! HTr: interpolate logarithmic in zg
                      !slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/ (ph_fl(i,j,nl)-ph_fl(i,j,nl+1))
                      !var_pl(i,j) = var3d_in(i,j,nl) * EXP( (zg_pout - ph_fl(i,j,nl)) * (LOG(var3d_in(i,j,nl+1)) - LOG(var3d_in(i,j,nl))) / (ph_fl(i,j,nl+1)-ph_fl(i,j,nl)))
                      slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/&
                              (p_in(i,j,nl)-p_in(i,j,nl+1))
                      data_in(i,j) = var3d_in(i,j,nl+1) + &
                                    slope*(pout(np)-p_in(i,j,nl+1))
                    END IF
                  END DO
                END DO
              END DO

            ! comparison with orig model data between level 16 and 17
            ! OK
            ELSE IF ( (var_cmip(ivar) == "wa1000") .OR. &
                 (var_cmip(ivar) == "wa925") .OR.       &
                 (var_cmip(ivar) == "wa850") .OR.       &
                 (var_cmip(ivar) == "wa700") .OR.       &
                 (var_cmip(ivar) == "wa500") .OR.       &
                 (var_cmip(ivar) == "wa200") ) THEN
              ! vertically destagger:
              DO nl = 1,nz
                var3d_in(:,:,nl) = ( w_in(:,:,nl) + w_in(:,:,nl+1) ) / 2.
              END DO
              DO i = 1,xfocus 
                DO j = 1,yfocus
                  DO nl = 1,nz - 1
                    IF (pout(np).le.p_in(i,j,nl) .and. pout(np).gt.p_in(i,j,nl+1)) then                
                      slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/&
                              (p_in(i,j,nl)-p_in(i,j,nl+1))
                      data_in(i,j) = var3d_in(i,j,nl+1) + &
                                    slope*(pout(np)-p_in(i,j,nl+1))
                    END IF
                  END DO
                END DO
              END DO              

            ! vars needed: int.: ph_fl (> in: ph_in, phb_in); p_in (> in: pp_in, pb_in)
            !              out: var_pl, var3d_in
            !              tmp: pout, slope
            ! comparison with wrfpress, same time: wrfpress, old and new scheme
            ! about identical
            ELSE IF ( (var_cmip(ivar) == "zg1000") .OR. &
                 (var_cmip(ivar) == "zg925") .OR.       &
                 (var_cmip(ivar) == "zg850") .OR.       &
                 (var_cmip(ivar) == "zg700") .OR.       &
                 (var_cmip(ivar) == "zg500") .OR.       &    
                 (var_cmip(ivar) == "zg200") ) THEN
              PRINT *, "calc zg..."
              var3d_in(:,:,:) = ph_fl(:,:,:)
              ! linear in log(p)
              DO i = 1,xfocus 
                DO j = 1,yfocus
                  DO nl = 1,nz - 1
                    IF (pout(np).LE.p_in(i,j,nl) .AND. pout(np).GT.p_in(i,j,nl+1)) THEN               
                      !slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/ &
                      !        (LOG(p_in(i,j,nl))-LOG(p_in(i,j,nl+1)))
                      !var_pl(i,j) = var3d_in(i,j,nl+1) + &
                      !              slope*(LOG(pout(np))-LOG(p_in(i,j,nl+1)))
                      slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/&
                              (p_in(i,j,nl)-p_in(i,j,nl+1))
                      data_in(i,j) = var3d_in(i,j,nl+1) + &
                                    slope*(pout(np)-p_in(i,j,nl+1))
                    END IF
                  END DO
                END DO
              END DO
            END IF

            ! alternative: use one routine for all
            ! using np here is rubbish and wrong > originally trickeled up as well...
!            DO i = 1,xfocus 
!              DO j = 1,yfocus
!                DO nl = 1,nz - 1
!                  IF (pout(np).le.p_in(i,j,nl) .and. pout(np).gt.p_in(i,j,nl+1)) then                
!                    ! SKn: original version
!                    !slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/ (p_in(i,j,nl)-p_in(i,j,nl+1))
!                    !var_pl(i,j,np) = var3d_in(i,j,nl+1) + slope*(pout(np)-p_in(i,j,nl+1))
!                    ! HTr: change interpolation to be linear in log(p)
!                    slope = (var3d_in(i,j,nl)-var3d_in(i,j,nl+1))/ (LOG(p_in(i,j,nl))-LOG(p_in(i,j,nl+1)))
!                    var_pl(i,j,np) = var3d_in(i,j,nl+1) + slope*(LOG(pout(np))-LOG(p_in(i,j,nl+1)))
!                  END IF
!                END DO
!              END DO
!            END DO

            !!data_in(:,:) = var_pl(:,:) ! superfluous, remove var_pl TODO was some old idea of someone but does not fit into the overall concept

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! CORDEX [X], FPS CEM [X]
! psl [Pa] i Sea Level Pressure

            ! several options to calculate slp, either from formula
            ! internal vars needed: ph_fl, t_in, p_in
            IF ( var_cmip(ivar) == "psl" ) THEN

              SELECT CASE (calc_slp_type)
              CASE(0)
                ! HTr this calculation of mean sea level pressure gives quite high
                ! anomalies in mountainous areas
                PRINT *, "psl calc option 0: standard"
                psl_in(:,:) = (pp_in(:,:,1)+pb_in(:,:,1))*((t_in(:,:,1)*(1.+0.61*qv_in(:,:,1))+ &
                  0.0065*ph_fl(:,:,1))/(t_in(:,:,1)*(1+0.61*qv_in(:,:,1))))**(gr/(R*0.0065))
              CASE(1)
                ! modified version from wrf_interp.F90
                PRINT *, "psl calc option 1: p_interp"
                CALL calcslp(psl_in,p_in,qv_in,theta_in,ph_fl,nz,yfocus,xfocus,T00(1))
              CASE(2)
                ! officially agreed upon variant using ECMWF methodology as
                ! decided during autumn 2018 Trieste CORDEX FPS CEM meeting
                ! fullpos_cy38 implementation (ERA/IFS/APACHE/ALADIN)
                PRINT *, "psl calc option 2: fullpos_cy38 method"
                ! the lowest layer of ph+phb (nz+1 layers!) is exactly the surface)
                !            (slp,    PP,   P_s,     PHI_s,                      T_L,         nz, ns,     ew    )
                !slp        !(output) sea level pressure
                !PP         !(input) 3D pressure
                !P_s        !(input) pressure at surface
                !PHI_s      !(input) 2D geopotential of the surface
                !T_L        !(input) temperature at lowest level
                !nz, ns, ew !(input) dimensions: vertical, north-south, east-west
                CALL calcslptwo(psl_in, p_in, psfc_in, ph_in(:,:,1)+phb_in(:,:,1), t_in(:,:,1), nz, yfocus, xfocus)
                !                     int c    read   read          read         int c
              CASE DEFAULT
                PRINT *, 'CAUTION: unknown setting for calcslp, proceed with default method'
                STOP 'calc_slp_type not properly set'
              END SELECT

              data_in(:,:) = psl_in(:,:)

            END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! CORDEX [X], FPS CEM [X]
! prw [kg m-2] i Water Vapor Path

            IF ( (var_cmip(ivar) == "prw") ) THEN
  
              !t_in(:,:,:) = ( theta_in(:,:,:)+T00(1) ) * ( (pp_in(:,:,:)+pb_in(:,:,:))/P00(1) )**(R/cp)
              !p_in(:,:,:) = pp_in(:,:,:) + pb_in(:,:,:)
  
              prw(:,:) = 0.
              DO nl = 1, nz
                prw(:,:) = prw(:,:) + &
                  (qv_in(:,:,nl) * p_in(:,:,nl)/(R*t_in(:,:,nl)) * &
                  ((ph_in(:,:,nl+1)+phb_in(:,:,nl+1)) - (ph_in(:,:,nl)+ &
                  phb_in(:,:,nl)))/gr)
              END DO
              data_in(:,:) = prw(:,:)
  
            END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! CORDEX [X], FPS CEM [X]
! clwvi [kg m-2] i Condensed Water Path  

            IF ( (var_cmip(ivar) == "clwvi") ) THEN
    
              !t_in(:,:,:) = (theta_in(:,:,:)+T00(1))*((pp_in(:,:,:)+pb_in(:,:,:))/P00(1))**(R/cp)
              !p_in(:,:,:) = pp_in(:,:,:) + pb_in(:,:,:)

              clwvi(:,:) = 0.
              DO nl = 1,nz - 1
                clwvi(:,:) = clwvi(:,:) + (qc_in(:,:,nl) + qi_in(:,:,nl) + &
                             qr_in(:,:,nl) + qs_in(:,:,nl) ) * p_in(:,:,nl)/ &
                             (R*t_in(:,:,nl)) * ((ph_in(:,:,nl+1)+ &
                             phb_in(:,:,nl+1)) - (ph_in(:,:,nl)+ &
                             phb_in(:,:,nl)))/gr
              END DO
              data_in(:,:) = clwvi(:,:)

            END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! CORDEX [X], FPS CEM [X]
! clivi  [kg m-2] i Ice Water Path

            IF ( (var_cmip(ivar) == "clivi")) THEN
    
              !t_in(:,:,:) = (theta_in(:,:,:)+T00(1))*((pp_in(:,:,:)+pb_in(:,:,:))/P00(1))**(R/cp)
              !p_in(:,:,:) = pp_in(:,:,:) + pb_in(:,:,:)
    
              clivi(:,:) = 0.
              DO nl = 1,nz - 1
                clivi(:,:) = clivi(:,:) + (qi_in(:,:,nl) + qs_in(:,:,nl)) * &
                             p_in(:,:,nl)/(R*t_in(:,:,nl)) * &
                             ((ph_in(:,:,nl+1)+phb_in(:,:,nl+1)) - &
                             (ph_in(:,:,nl)+phb_in(:,:,nl)))/gr
              END DO
              data_in(:,:) = clivi(:,:)
    
            END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! CORDEX [ ], FPS CEM [X]
! cape [J kg-1] i 2-D Maximum Convective Available Potential Energy
! cin [J kg-1] i 2-D Maximum Convective Inhibition

            IF ( (var_cmip(ivar) == "cape") .OR. (var_cmip(ivar) == "cin") ) THEN
    
              !t_in(:,:,:) = (theta_in(:,:,:)+T00(1))*((pp_in(:,:,:)+pb_in(:,:,:))/P00(1))**(R/cp)
              !p_in = pp_in+pb_in          
    
              t_p(:,:,1) = t_in(:,:,1)
    
              cape(:,:) = 0.
              cin(:,:) = 0.
              lcl(:,:) = -999.
              lfc(:,:) = -999.
    
              DO i = 1,xfocus
                DO j = 1,yfocus
                  DO nl = 1,nz-1
    
                    qvs(i,j,nl) = 0.622*a*exp(b*(t_p(i,j,nl)-c)/(t_p(i,j,nl)-d))/p_in(i,j,nl)
    
                    IF (qvs(i,j,nl) .gt. qv_in(i,j,1)) THEN ! dry adiabatic ascent
                   
                      t_p(i,j,nl+1) = (theta_in(i,j,1)+T00(1))*(p_in(i,j,nl+1)/P00(1))**(R/cp)
    
                    ELSE IF (qvs(i,j,nl) .lt. qv_in(i,j,1)) THEN ! moist adiabatic ascent
    
                      IF (lcl(i,j) .eq. -999) THEN ! lifting condensation level
                        lcl(i,j) = p_in(i,j,nl)
                      END IF
    
                      t_ii = t_p(i,j,nl)
    
                      DO ii = 1,10 ! solve iteratively
    
                        qvs(i,j,nl+1) = 0.622*a*exp(b*(t_ii-c)/(t_ii-d))/p_in(i,j,nl+1)
    
                        t_ii = t_ii - (t_ii*(P00(1)/p_in(i,j,nl+1))**(R/cp)*exp(L*qvs(i,j,nl+1)/(cp*t_ii)) - &
                               (t_p(i,j,nl)*(P00(1)/p_in(i,j,nl))**(R/cp)*exp(L*qvs(i,j,nl)/(cp*t_p(i,j,nl))))) / &
                               ( (P00(1)/p_in(i,j,nl+1))**(R/cp)*exp(n/(p_in(i,j,nl+1)*t_ii)*exp(b*(t_ii-c)/(t_ii-d))) * &
                               (1 - (n/p_in(i,j,nl+1)*exp(b*(t_ii-c)/(t_ii-d))*(t_ii*(t_ii-b*c)+(b-2)*d*t_ii+d**2))/(t_ii*(d-t_ii)**2)) )
  
                      END DO
    
                      !print*, 'thetae(i,j,nl)',(t_p(i,j,nl)*(100000./p_in(i,j,nl))**(R/cp)*exp(L*qvs(i,j,nl)/(cp*t_p(i,j,nl))))
                      !print*,'thetae(i.j.nl+1)',(t_ii*(100000./p_in(i,j,nl+1))**(R/cp)*exp(L*qvs(i,j,nl+1)/(cp*t_ii))) 
  
                      t_p(i,j,nl+1) = t_ii
    
                      !print*, nl, 'moist', t_p(i,j,nl+1), t_in(i,j,nl+1), (t_p(i,j,nl+1)-t_in(i,j,nl+1))
    
                    END IF                 
  
                    IF (t_p(i,j,nl) .gt. t_in(i,j,nl)) THEN
                   
                      IF (lfc(i,j) .eq. -999) THEN ! level of free convection
                        lfc(i,j) = p_in(i,j,nl)
                      END IF
    
                      cape(i,j) = cape(i,j) + (t_p(i,j,nl) - t_in(i,j,nl)) / t_in(i,j,nl) * ((phb_in(i,j,nl)+ph_in(i,j,nl))-(phb_in(i,j,nl-1)+ph_in(i,j,nl-1)))
    
                      !print*, 'nl, cape(i,j)', nl, cape(i,j)
    
                    ELSE IF ( (t_p(i,j,nl) .lt. t_in(i,j,nl)) .and. (cape(i,j) .eq. 0.) ) THEN ! convective inhibition 
                 
                      cin(i,j) = cin(i,j) + (t_in(i,j,nl) - t_p(i,j,nl)) / t_in(i,j,nl) * ((phb_in(i,j,nl)+ph_in(i,j,nl))-(phb_in(i,j,nl-1)+ph_in(i,j,nl-1))) 
    
                      !print*, 'nl, cin(i,j)', nl, cin(i,j)
    
                    END IF
    
                  END DO
                END DO
              END DO
  
              IF ( var_cmip(ivar) == "cape") THEN
                data_in(:,:) = cape(:,:)
              END IF
              IF ( var_cmip(ivar) == "cin") THEN
                data_in(:,:) = cin(:,:)
              END IF
    
            END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

          END IF ! pressure levels processing

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! CORDEX [X], FPS CEM [X]
! clt [%] a Total Cloud Fraction
! not instantaneous, but average, have to recode here
  
          IF (var_cmip(ivar) == "clt") THEN

            IF (calc) THEN
  
              IF (.not. ALLOCATED(cldfra_inv)) ALLOCATE( cldfra_inv( xfocus, yfocus ), STAT=sts )

              IF (ALLOCATED(tmp_3d)) DEALLOCATE( tmp_3d )
              ALLOCATE( tmp_3d( xfocus, yfocus, 2 ), STAT=sts )

              DO k =1,2,1

                cldfra_inv(:,:) = 1.
  
                DO i = 1,xfocus
                  DO j = 1,yfocus
                    IF (maxval(cldfra_in(i,j,:,k)) .lt. 0.99) THEN
                      cldfra_inv(i,j) = 1.
                      DO nl = 2,nz
                        cldfra_inv(i,j) = cldfra_inv(i,j) * &
                          (1- max(cldfra_in(i,j,nl,k),cldfra_in(i,j,nl-1,k)) / &
                          (1-cldfra_in(i,j,nl-1,k))) 
                      END DO
                    ELSE 
                      cldfra_inv(i,j) = 0.  
                    END IF
                  END DO ! j
                END DO ! i
  
                tmp_3d(:,:,k) = (1 - cldfra_inv(:,:))*100.
  
              END DO ! k

              WHERE (tmp_3d > 100.) tmp_3d = 100.
              WHERE (tmp_3d < 0.) tmp_3d = 0.

              data_in(:,:) = ( tmp_3d(:,:,1) + tmp_3d(:,:,2) ) / 2.

              DEALLOCATE(tmp_3d)

            ! this is the last field, i.e. no subsequent field can be found
            ! any more in the staged data
            ELSE

                data_in(:,:) = mv

            END IF

            calc = .TRUE.
  
          END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! CORDEX [X], FPS CEM [X]
! pr [kg m-2 s-1] a Precipitation  
! [mm dtHours-1] -> [kg m-2 s-1]
! accumulated quantity (using a bucket)

          IF (var_cmip(ivar) == "pr") THEN

            IF (calc) THEN
  
              IF ( bucket_mm > 0. ) THEN

                !data_in(:,:) = ((rainnc_in(:,:,2) + rainc_in(:,:,2)) - (rainnc_in(:,:,1) + rainc_in(:,:,1)) + &
                !                (i_rainnc_in(:,:,2) + i_rainc_in(:,:,2) - i_rainnc_in(:,:,1) - i_rainc_in(:,:,1))*bucket_mm)/(dtHours*3600.) 

                data_in(:,:) = (((rainnc_in(:,:,2)+i_rainnc_in(:,:,2)*bucket_mm) + &
                                 (rainc_in(:,:,2)+i_rainc_in(:,:,2)*bucket_mm  )) - &
                                ((rainnc_in(:,:,1)+i_rainnc_in(:,:,1)*bucket_mm) + &
                                 (rainc_in(:,:,1)+i_rainc_in(:,:,1)*bucket_mm  ))) / &
                               (dtHours*3600.) 

              ELSE

                data_in(:,:) = ( ( rainnc_in(:,:,2) + rainc_in(:,:,2) ) - &
                                 ( rainnc_in(:,:,1) + rainc_in(:,:,1) ) ) / &
                                 ( dtHours * 3600. )

              END IF

            ! this is the last field, i.e. no subsequent field can be found
            ! any more in the staged data
            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! prc [kg m-2 s-1] a Convective Precipitation 
! unit [mm/3hr] to [kg m-2 s-1]
  
          IF (var_cmip(ivar) == "prc") THEN

            IF (calc) THEN

              IF ( bucket_mm > 0. ) THEN
              
                data_in(:,:) = ( ( rainc_in(:,:,2)+i_rainc_in(:,:,2)*bucket_mm ) - &
                                 ( rainc_in(:,:,1)+i_rainc_in(:,:,1)*bucket_mm ) ) / &
                                 (dtHours*3600.) 

              ELSE

                data_in(:,:) = ( rainc_in(:,:,2) - rainc_in(:,:,1) ) / &
                               (dtHours*3600.)
 
              END IF

            ! this is the last field, i.e. no subsequent field can be found
            ! any more in the staged data
            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! prsn [kg m-2 s-1] ? Snowfall Flux
! unit [mm/3hr] to [kg m-2 s-1]
  
          IF (var_cmip(ivar) == "prsn") THEN
  
            IF (calc) THEN
            
              data_in(:,:) = (snownc_in(:,:,2) - snownc_in(:,:,1)) / &
                             (dtHours*3600.)
  
            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! snm [kg m-2 s-1] a Surface Snow Melt
! unit [kg m-2 /3hr] to [kg m-2 s-1]
  
          IF (var_cmip(ivar) == "snm") THEN
  
            IF (calc) THEN
            
              data_in(:,:) = (acsnom_in(:,:,2) - acsnom_in(:,:,1)) / &
                             (dtHours*3600.)
  
            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF
          
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! evspsbl [kg m-2 s-1] a Evaporation
! unit [kg m-2 /3hr] to [kg m-2 s-1]
! TO CHECK STILL, in principle OK
  
          IF (var_cmip(ivar) == "evspsbl") THEN
  
            IF (calc) THEN
            
              data_in(:,:) = ( sfcevp_in(:,:,2) - sfcevp_in(:,:,1) ) / &
                             (dtHours*3600.)
  
            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! evspblpot [kg m-2 s-1] a Potential Evapotranspiration 
! unit [W m-2]/[J kg-1] -> [kg m-2 s-1]
! TO CHECK STILL, in principle OK
! TODO / CHECK
! THERE IS STH WRONG WITH THE UNITS: WRF's POTEVP is accumulated and declared to be in W m-2. 
! It doesen't make sense to accumulate in W m-2, but even if assume it as J m-2 or derive kg m-2 
! by using latent heat of vaporization you never get values that have a reasonable magnitude...
! CHECK with registry on the units
  
          IF (var_cmip(ivar) == "evspsblpot") THEN
  
            IF (calc) THEN
            
              data_in(:,:) = (potevp_in(:,:,2) - (potevp_in(:,:,1))) / L
  
            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! mrros [kg m-2 s-1] a Surface Runoff
! unit [mm/3hr] to [kg m-2 s-1]
  
          IF (var_cmip(ivar) == "mrros") THEN
  
            IF (calc) THEN

              data_in(:,:) = (sfroff_in(:,:,2) - sfroff_in(:,:,1)) / &
                             (dtHours*3600.)
  
            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! mrro [kg m-2 s-1] a Total Runoff
! unit [mm/3hr] to [kg m-2 s-1]
! SFROFF, UDROFF
! UDROFF is accumulated!
  
          IF (var_cmip(ivar) == "mrro") THEN
  
            IF (calc) THEN

              data_in(:,:) = ( (sfroff_in(:,:,2) - sfroff_in(:,:,1)) + &
                               (udroff_in(:,:,2) - udroff_in(:,:,1)) ) / &
                             (dtHours*3600.) 
  
            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! rsds [W m-2] a Surface Downwelling Shortwave Radiation
! rlds [W m-2] a Surface Downwelling Longwave Radiation
! rsus [W m-2] a Surface Upwelling Shortwave Radiation 
! rlus [W m-2] a Surface Upwelling Longwave Radiation
! hfss [W m-2] a Surface Upward Latent Heat Flux
! hfls [W m-2] a Surface Upward Sensible Heat Flux
! rlut [W m-2] a TOA Outgoing Longwave Radiation
! rsdt [W m-2] a TOA Incident Shortwave Radiation
! rsut [W m-2] a TOA Outgoing Shortwave Radiation
  
          IF ( (var_cmip(ivar) == "rsds") &
            .OR. (var_cmip(ivar) == "rlds") &
            .OR. (var_cmip(ivar) == "rsus") &
            .OR. (var_cmip(ivar) == "rlus") &
            .OR. (var_cmip(ivar) == "hfss") &
            .OR. (var_cmip(ivar) == "hfls") &
            .OR. (var_cmip(ivar) == "rlut") &
            .OR. (var_cmip(ivar) == "rsdt") &
            .OR. (var_cmip(ivar) == "rsut") ) THEN
    
            IF (calc) THEN

              IF ( bucket_J > 0. ) THEN

                data_in(:,:) = ( ( rad_in(:,:,2) + ( i_rad_in(:,:,2) * bucket_J ) ) - &
                               ( rad_in(:,:,1) + ( i_rad_in(:,:,1) * bucket_J ) ) ) / &
                               (dtHours*3600.)
               
              ELSE

                data_in(:,:) = (rad_in(:,:,2) - rad_in(:,:,1)) / (dtHours*3600.)

              END IF

            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! sund [s] s Duration of Sunshine
! WMO definition >= 120 W m-2

          IF ( var_cmip(ivar) == "sund" ) THEN
    
            IF (calc) THEN

              DO i = 1,xfocus
                DO j = 1,yfocus

                  ! if both neighbouring data points are above the threshold
                  IF ( (swdown_in(i,j,1) >= 120.) .AND. (swdown_in(i,j,2) >= 120.) ) THEN 
                    data_in(i,j) = dtHours*3600.
                  ELSE IF ( (swdown_in(i,j,1) < 120.) .AND. (swdown_in(i,j,2) < 120.) ) THEN 
                    data_in(i,j) = 0.
                  ELSE
                    slope = ( swdown_in(i,j,2) - swdown_in(i,j,1) ) / &
                            ( dtHours * 3600. ) 
                    IF ( slope > 0 ) THEN 
                      data_in(i,j) = ( dtHours * 3600. ) - ( (120. - swdown_in(i,j,1)) / slope )
                    ELSE IF ( slope < 0 ) THEN
                      data_in(i,j) = (120. - swdown_in(i,j,1)) / slope
                    END IF
                  END IF
               
                END DO
              END DO

            ELSE

              data_in(:,:) = mv

            END IF

            calc = .TRUE.

          END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! mrso [kg m-2] i Total Soil Moisture Content 
! see comment in the variable aquisition section
! m3 m-3 -> kg m-2

          IF (var_cmip(ivar) == "mrso") THEN
    
            !data_in(:,:) = ((smois_in(:,:,1,1)*DZS(1) + smois_in(:,:,2,1)*DZS(2) + smois_in(:,:,3,1)*DZS(3) + smois_in(:,:,4,1)*DZS(4) ) + &
            !                (smois_in(:,:,1,2)*DZS(1) + smois_in(:,:,2,2)*DZS(2) + smois_in(:,:,3,2)*DZS(3) + smois_in(:,:,4,2)*DZS(4) ))/2.*1000. 
  
            data_in(:,:) =  (smois_in(:,:,1,1)*DZS(1) + &
                             smois_in(:,:,2,1)*DZS(2) + &
                             smois_in(:,:,3,1)*DZS(3) + &
                             smois_in(:,:,4,1)*DZS(4)) * 1000.

          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! snc [%] i Snow Area Fraction
! unit [] to [%]

          IF ( (var_cmip(ivar) == "snc") ) THEN
  
            data_in(:,:) = data_in(:,:)*100. 
  
          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! sic [%] ?>i Sea Ice Area Fraction
! no temporal aggregation defined, treat as tier-2 instantaneous data, most
! reasonable; also offers the possibility of some proper sea-ice treatment

          IF ( (var_cmip(ivar) == "sic") ) THEN
 
            ! fractional sea ice 
!           IF (fractSeaIce) THEN

              data_in(:,:) = data_in(:,:) * 100. 

            ! binary sea ice mask, SEAICE is empty variable
!           ELSE
!
!             WHERE ( xland_in == 2. )
!
!               xland_in = 0.
!
!             END WHERE
!
!              data_in(:,:) = ( landmask_in(:,:) - xland_in(:,:) ) * 100.
!
!            END IF
  
          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! -1] i Near-Surface Wind Speed
  
          IF (var_cmip(ivar) == "sfcWind") THEN
  
            data_in(:,:) = (u10_in(:,:)**2 + v10_in(:,:)**2)**0.5 
  
          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! uas [m s-1] i Eastward Near-Surface Wind
  
          IF (var_cmip(ivar) == "uas") THEN 
  
            data_in(:,:) = u10_in(:,:)*cosalpha_in(:,:) - v10_in(:,:)*sinalpha_in(:,:) ! rotate to earth grid
  
          END IF
  
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! vas [m s-1] i Northward Near-Surface Wind
  
          IF (var_cmip(ivar) == "vas")  THEN
  
            data_in(:,:) = v10_in(:,:)*cosalpha_in(:,:) + u10_in(:,:)*sinalpha_in(:,:) ! rotate to earth grid
  
          END IF

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! prhmax [kg m-2 s-1] m Daily Maximum Hourly Precipitation Rate (using wrfxtrm)

          IF (var_cmip(ivar) == "prhmax") THEN

            data_in(:,:) = rainnc_max_in(:,:) + rainc_max_in(:,:)

          END IF

!-------------------------------------------------------------------------------
! write data to netCDF file

          PRINT *, "*** WRITE DATA TO netCDF ***"
          PRINT *, TRIM(pn_out) // "/" // TRIM(fn_out)
          PRINT *, TRIM(var_cmip(ivar)), xfocus, yfocus, counter, ncid, x_varid
  
          sts = NF90_OPEN( TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) &
            // "/" // TRIM(fn_out), NF90_WRITE, ncid )

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
            ! in the coordinates, this was before a standard 'violation'
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
            PRINT *, 'some sample output 3x3 in the middle of the domain', &
              data_in(xfocus/2:(xfocus/2+2),yfocus/2:(yfocus/2+2))

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

      ENDIF ! procflag T/F TODO fix indention

    END DO ! ivar - variable loop

  END DO ! ivarnml - namelist loop 

END DO ! ifrq - different temporal aggregations

!===============================================================================

END PROGRAM WRFCMORizer

!===============================================================================
! HTr routines for psl calculation

SUBROUTINE calcslp(slp, pres, qv, tk1, ght, nz, ns, ew, T00)

IMPLICIT NONE

INTEGER, INTENT(IN) :: nz,ns,ew
REAL, DIMENSION(:,:), INTENT(INOUT) :: slp
REAL, DIMENSION(:,:,:), INTENT(IN) :: pres,qv,tk1,ght
REAL, INTENT(IN) :: T00
INTEGER :: i,j,k,klo,khi
INTEGER, DIMENSION(ew,ns) :: level
REAL, DIMENSION(ew, ns) :: t_sea_level, t_surf
REAL, DIMENSION(ew, ns, nz) :: tk
REAL :: rgas,grav,gamma
REAL :: plo , phi , tlo, thi , zlo , zhi
REAL :: p_at_pconst , t_at_pconst , z_at_pconst
REAL :: z_half_lowest
REAL :: tc,pconst
LOGICAL :: l1, l2, l3, found, ridiculous_mm5_test

rgas = 287.04
grav = 9.81
gamma = 0.0065
tc = 273.16+17.5

! in wrf_interp pconst is set to 10000 Pa, but this gives too low pressure 
! values at sea level. So, I've reduced pconst to 5000 Pa, which reduces this 
! underestimation.
!pconst = 10000.
pconst = 5000.
ridiculous_mm5_test = .TRUE. 

! Find least zeta level that is PCONST Pa above the surface. We later use this
! level to extrapolate a surface pressure and temperature, which is supposed
! to reduce the effect of the diurnal heating cycle in the pressure field.
tk = tk1 + T00
DO j = 1, ns
  DO i = 1, ew

    level(i,j) = -1
    k = 1
    found = .false.

    DO WHILE( (.NOT. found) .AND. (k .LE. nz) )
      IF ( pres(i, j, k) .LT. pres(i, j, 1)-PCONST ) THEN
        level(i, j) = k
        found = .true.
      END IF
      k = k+1
    END DO 

    IF ( level(i,j) .EQ. -1 ) THEN
      PRINT '(A,I4,A)','Troubles finding level ',NINT(PCONST)/100,' above ground.'
      PRINT '(A,I4,A,I4,A)','Problems first occur at (',i,',',j,')'
      PRINT '(A,F6.1,A)','Surface pressure = ',pres(i,j,1)/100,' hPa.'
      STOP 'Error_in_finding_100_hPa_up'
    END IF

  END DO ! ew
END DO ! ns
  
! Get temperature PCONST Pa above surface. Use this to extrapolate 
! the temperature at the surface and down to sea level.
DO j = 1, ns
  DO i = 1, ew

    klo = MAX ( level(i,j) - 1 , 1      )
    khi = MIN ( klo + 1        , nz - 1 )
     
    IF ( klo .EQ. khi ) THEN
      PRINT '(A)','Trapping levels are weird.'
      PRINT '(A,I3,A,I3,A)','klo = ',klo,', khi = ',khi,': and they should not be equal.'
      STOP 'Error_trapping_levels'
    END IF

    plo = pres(i,j,klo)
    phi = pres(i,j,khi)
    tlo = tk(i,j,klo) * (1. + 0.608 * qv(i,j,klo) )
    thi = tk(i,j,khi) * (1. + 0.608 * qv(i,j,khi) )
    zlo = ght(i,j,klo)         
    zhi = ght(i,j,khi)

    p_at_pconst = pres(i,j,1) - pconst
    t_at_pconst = thi-(thi-tlo)*LOG(p_at_pconst/phi)*LOG(plo/phi)
    z_at_pconst = zhi-(zhi-zlo)*LOG(p_at_pconst/phi)*LOG(plo/phi)

    t_surf(i,j) = t_at_pconst*(pres(i,j,1)/p_at_pconst)**(gamma*rgas/grav)
    t_sea_level(i,j) = t_at_pconst+gamma*z_at_pconst

  END DO ! ew
END DO !ns

! If we follow a traditional computation, there is a correction to the sea level 
! temperature if both the surface and sea level temnperatures are *too* hot.
IF ( ridiculous_mm5_test ) THEN
  DO j = 1, ns
    DO i = 1, ew
      l1 = t_sea_level(i,j) .LT. TC 
      l2 = t_surf     (i,j) .LE. TC
      l3 = .NOT. l1
      IF ( l2 .AND. l3 ) THEN
        t_sea_level(i,j) = TC
      ELSE
        t_sea_level(i,j) = TC - 0.005*(t_surf(i,j)-TC)**2
      END IF
    END DO
  END DO
END IF

! The grand finale: ta da!
DO j = 1, ns
  DO i = 1, ew
    z_half_lowest=ght(i,j,1)
    slp(i,j) = pres(i,j,1) *EXP((2.*grav*z_half_lowest)/(rgas*(t_sea_level(i,j)+t_surf(i,j))))
    !slp(i,j) = slp(i,j) * 0.01
  END DO ! ew
END DO ! ns

END SUBROUTINE calcslp

!===============================================================================

!(lah): fullpos_cy38 routine
!(lah): this code resembles the algorithm described in chapter 4 of "FULL-POS in
!       the cycle 38 of ARPEGE/IFS" by Yessad K. (Meteo-France/CNRM/GMAP/ALGO),
!       November 10, 2011. The equation can be found especially in the section
!       (4.3.1) "Mean sea level pressure PP_msl (routine PPPMER)"

SUBROUTINE calcslptwo(slp, PP, P_s, PHI_s, T_L, nz, ns, ew)

IMPLICIT NONE

real, DIMENSION(:,:),   INTENT(OUT) :: slp        !(output) sea level pressure
real, DIMENSION(:,:,:), INTENT(IN)  :: PP         !(input) 3D pressure
real, DIMENSION(:,:),   INTENT(IN)  :: P_s        !(input) pressure at surface
real, DIMENSION(:,:),   INTENT(IN)  :: PHI_s      !(input) 2D geopotential of the surface
real, DIMENSION(:,:),   INTENT(IN)  :: T_L        !(input) temperature at lowest level
INTEGER,                INTENT(IN)  :: nz, ns, ew !(input) dimensions: vertical, north-south, east-west

real, DIMENSION(ew,ns)              :: P_L        !(calculated) pressure at lowest level
real                                :: T_surf     !(calculated) surface temperature
real                                :: gamma_mod  !(calculated) modified lapse rate that is actually used for calculations
real                                :: x          !(calculated) expansion coefficient of (eq. 9)
real                                :: T_0        !(calculated) auxiliary variable

real, PARAMETER                     :: Rd    = 287.04 ![J kg-1 K-1] (const.) dry air constant
real, PARAMETER                     :: g     = 9.81   ![m s-2] (const.) acceleration due to gravity
real, PARAMETER                     :: gamma = 0.0065 ![K m-1] (const.) lapse rate at const. 0.0065 K/m, also denoted as (dT/dz)_st
integer                             :: j,k !loop parameters

!print *,'this is calcslptwo !!!'

P_L = PP(:,:,1)  !extract lowest layer

DO j = 1 , ew
  DO k = 1 , ns
        
    !always assume none of the IF conditions trigger, then (according to step 5)
    gamma_mod = gamma
    
    !(0) if abs(PHI_s)<0.001 ("sea" grid cells) then set slp to surface pressure
    IF (ABS(PHI_s(j,k)).lt.0.001) THEN
      
      slp(j,k) = P_s(j,k) !in this case we are done with this grid cell
       
    ELSE !else apply the following algorithm

      !always assume none of the following IF conditions trigger
      !then we use the constant camma (according to step 5)
      gamma_mod = gamma
      
      !(1) compute T_surf according to eq (1)
      !T_surf = T_L + gamma*(Rd/g)*(P_s/P_L-1.0)*T_L
      T_surf = T_L(j,k) + gamma * (Rd/g) * ( P_s(j,k)/P_L(j,k) - 1.0 ) * T_L(j,k)
      
      !(2) compute T_0=T_surf+gamma*PHI_s/g
      T_0 = T_surf + gamma * PHI_s(j,k) / g
      
      !(3) to avoid extrapolation of too low pressures over high and warm surfaces:
      ! if (T_0 > 290.5):
      !    if (T_surf <= 290.5): gamma_mod=(290.5-T_surf)*g/PHI_s (eq. 7)
      !    else: gamma_mod=0.0, T_surf=0.5*(290.5+T_surf)
      IF (T_0 .gt. 290.5) THEN
        IF (T_surf .le. 290.5) THEN
          gamma_mod = ( 290.5 - T_surf ) * g / PHI_s(j,k)
        ELSE
          gamma_mod = 0.0
          T_surf = 0.5 * ( 290.5 + T_surf )
        END IF
      END IF
         
      !(4) to avoid extrapolation of too high pressures over cold surfaces:
      ! if T_surf < 255: gamma_mod=gamma, T_surf=0.5*(255+T_surf)
      IF (T_surf .lt. 255.0) THEN
        gamma_mod = gamma
        T_surf = 0.5 * ( 255.0 + T_surf )
      END IF
      
      !(5) in other cases set gamma_mod=gamma
      !this was already done in the beginning of the loop!
      
      !(6) compute mean sea level pressure (eq. 8) using the above determined parameters
      !x=gamma_mod*PHI_s/(g*T_surf)
      !slp=P_s*exp(PHI_s/(R_d*T_surf)*(1-x/2.+x*x/3.))
      x = gamma_mod * PHI_s(j,k) / ( g * T_surf )
      slp(j,k) = P_s(j,k) * EXP( PHI_s(j,k) / (Rd * T_surf ) * (1.0 - x/2. + x*x/3.) )

      !done.  
    
    END IF
 
  END DO
END DO
  
END SUBROUTINE calcslptwo

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
IF (ft == 2) THEN
  ALLOCATE(fl_wrfpres(nfl), STAT=AllocateStatus)
END IF
!IF (AllocateStatus /= 0) STOP "*** Not enough memory ***"

REWIND(2)
DO i = 1,nfl
  IF (ft == 0) THEN
    READ(2,FMT='(a)') fl_wrfout(i)
  END IF
  IF (ft == 1) THEN
    READ(2,FMT='(a)') fl_wrfxtr(i)
  END IF
  IF (ft == 2) THEN
    READ(2,FMT='(a)') fl_wrfpres(i)
  END IF
END DO

CLOSE(2)

END SUBROUTINE GenerateFilelist

!===============================================================================
! TODO: expand for monthly and seasonal data

SUBROUTINE CreateRefTimeArray(dt)

USE RefTimeVecs
USE NamelistHandling

IMPLICIT NONE

CHARACTER (LEN = 3), INTENT(IN) :: dt ! 1hr 3hr 6hr day mon sem

INTEGER :: i, j, k, l, counter
REAL(KIND=8) :: dtDecDay
INTEGER :: tstotYYYY, tstotMM, tstotDD, tstotHH
INTEGER :: tetotYYYY, tetotMM, tetotDD, tetotHH
REAL(KIND=8) :: tstot_singlenumber, tetot_singlenumber
REAL(KIND=8), DIMENSION(:), ALLOCATABLE :: tmp2D_singlenumber
REAL(KIND=8), DIMENSION(:,:), ALLOCATABLE :: tmp2D
INTEGER, DIMENSION(12) :: ndpm ! number of days per month
INTEGER :: ndOverall = 31 ! number of days initialized with the 31 days of Dec 1949, this is DIRTY
INTEGER :: ntspd  ! (n)umber (t)ime(s)teps (p)er (d)ay
REAL :: cpuTs, cpuTe

CALL CPU_TIME(cpuTs)

PRINT *, "CreateRefTimeArray subroutine"
PRINT *, "Overall start end end: ", tstot, " to ", tetot
PRINT *, "temporal resolution working on = ", dt
PRINT *, "temporal aggregation working on = "

SELECT CASE (dt)
CASE ('1hr')
  dtDecDay = 1.0 / 24.0_8
CASE ('3hr')
  dtDecDay = 0.125
CASE ('6hr')
  dtDecDay = 0.25
CASE ('day') ! always means or sums, centered at 12UTC per day
  dtDecDay = 1.0
CASE DEFAULT
  PRINT *, "invalid time interval specified"
  STOP
END SELECT
ntspd = INT(1.0 / dtDecDay)
PRINT *, "number of time steps per day (ntspd) = ", ntspd

! "tstot" contains the absolute starting point, protocol = 1949-12-01_00:00:00
READ( tstot, '(I4,1X,I2,1X,I2,1X,I2)' ) tstotYYYY, tstotMM, tstotDD, tstotHH
READ( tetot, '(I4,1X,I2,1X,I2,1X,I2)' ) tetotYYYY, tetotMM, tetotDD, tetotHH
PRINT *, tstotYYYY, tstotMM, tstotDD, tstotHH
PRINT *, tetotYYYY, tetotMM, tetotDD, tetotHH

! e.g., 1949-2101, too many steps here, cut later
DO i=tstotYYYY,tetotYYYY,1
  ndOverall = ndOverall + CheckForLeapyear( i )
END DO

! index, YYYY, MM, DD, hh
ALLOCATE( tmp2D( ndOverall*ntspd, 5 ) )
PRINT *, "number of date/time steps in the raw time ref array", SIZE(tmp2D) / 5

! create timesteps [decimal days], starting with 0.0 
DO i=0_8,ndOverall*ntspd-1,1
  tmp2D( i+1, 1 ) = i * dtDecDay
END DO

! fill up Y M D h date/time information
counter = 0
DO i=tstotYYYY,tetotYYYY,1
  ! if there is no-leapyear dataset, switch this here off
  ! here, also a 360day calendar can be implemented, just set ndpm(:) = 30
  IF ( CheckForLeapyear( i ) == 366 ) THEN 
    ndpm = (/31,29,31,30,31,30,31,31,30,31,30,31/)
  ELSE
    ndpm = (/31,28,31,30,31,30,31,31,30,31,30,31/)
  END IF
  DO j=1,12,1
    ! sort in on daily basis
    DO k=1,ndpm(j)
      tmp2D( counter*ntspd+1 : counter*ntspd+ntspd , 2) = i
      tmp2D( counter*ntspd+1 : counter*ntspd+ntspd , 3) = j
      tmp2D( counter*ntspd+1 : counter*ntspd+ntspd , 4) = k
      tmp2D( counter*ntspd+1 : counter*ntspd+ntspd , 5) = (/(l, l=0, 24-24/ntspd , 24/ntspd) /) ! 0,18,6 -> 0, 6, 12, 18
      counter = counter + 1
    END DO
  END DO
END DO

!PRINT "(5F10.6)", TRANSPOSE(tmp2D(1:10,:))

! the ref time vec as is now is most likely too big, starting, e.g., 19490-01-01_00, ending 2101-12-31_23 with 1hr data
! here do some subsetting
tstot_singlenumber = REAL(tstotYYYY,8)*1000000._8 + REAL(tstotMM,8)*10000._8 + REAL(tstotDD,8)*100._8 + REAL(tstotHH,8)
tetot_singlenumber = REAL(tetotYYYY,8)*1000000._8 + REAL(tetotMM,8)*10000._8 + REAL(tetotDD,8)*100._8 + REAL(tetotHH,8)
PRINT *, tstot_singlenumber, tetot_singlenumber

ALLOCATE( tmp2D_singlenumber( ndOverall*ntspd ) )
DO i=1,ndOverall*ntspd,1
  tmp2D_singlenumber(i) = tmp2D(i,2)*1000000._8 + tmp2D(i,3)*10000._8 + tmp2D(i,4)*100._8 + tmp2D(i,5)
END DO

counter=1_4
l=0_4
DO i=1_4,ndOverall*ntspd,1
  IF ( tmp2D_singlenumber(i) == tstot_singlenumber ) THEN
    j=counter
  END IF
  IF ( tmp2D_singlenumber(i) == tetot_singlenumber ) THEN
    k=counter
  END IF
  IF ( ( tmp2D_singlenumber(i) >= tstot_singlenumber ) .AND. &
       ( tmp2D_singlenumber(i) <= tetot_singlenumber ) ) THEN
    l = l + 1_4
  END IF
  counter = counter + 1_4
END DO

PRINT *, "subset bounds lower upper, # elements ", j, k, l
ALLOCATE( TimeRefArray( l , 6 ) )
TimeRefArray(:,1:5) = tmp2D(j:k,1:5)
TimeRefArray(:,6) = tmp2D_singlenumber(j:k)
TimeRefArray(:,1) = TimeRefArray(:,1) - TimeRefArray(1,1) ! offset the time information [decimal days] used later on in the netCDF file
PRINT *, "start = ", TimeRefArray(1,:)
PRINT *, "end = ", TimeRefArray(l,:)

CALL CPU_TIME(cpuTe)
PRINT '("CPU timing for reference date/time vector generation = ",F10.1," s")',cpuTe-cpuTs

DEALLOCATE(tmp2D, tmp2D_singlenumber)

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

!-------------------------------------------------------------------------------

END SUBROUTINE CreateRefTimeArray
