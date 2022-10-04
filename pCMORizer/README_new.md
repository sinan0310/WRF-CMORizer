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
! 2019-07-14_KGo
! urgent todos wrt mrlsl and tsl
! add proper depth bounds, right now only the thickness is given, this is wrong
! mask the ocean areas: missing values
!
! 2019-08-13_KGo
! refinement of the CORDEX archive design DRS to aacount for complex nesting
! setups as we use them with the FPS; discussion during EGU2019 FPS CPCM 
! splinter meeting
! Changes for one-way, on-the-fly, double nest as used by the WRF groups:
! - RCMVersionID in path and filename: v1... -> x1n2v1 for the ALP-3 run
! - global attributes, for the ALP-3 run, add:
!   rcm_version_id = same string as before in the DRS
!   rcm_model_id = 
!   rcm_domain = 
!   rcm_institute = 
! Not fully clarified whether this is the right understanding. 
! Do not implement yet. Stay with the old system.
! See e-mail to Stefan SOBOLOWSKI from 2019-08-13.
!
! NAME:
!   WRF_CMORizer.f90
!
! VERSION:
!   v0.4 (= git tag) as of 2019-02-03
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
!     * mrsol -> mrlsl -- working on this one, variable OK, vertical coord not
!     * clbvi
!     * clgvi
!     * (ic_lightning) needs special parametrisation / online diagnostic
!     * (cg_lightning)
!     * (total_lightning)
!     All other variables are covered by namelists and implemented.
!
!   - Additional vars implemented:
!     * tsl -- working on this one, variable OK, vertical coord not
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
!   - Laurin Herbsthofer | laurin.herbsthofer@gmx.at | LAh | former WEGC
! 
! SUPPORT AND TESTING:
!   - Kirsten WARRACH-SAGI, Josipa MILOVAC, et al.
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
!     * gfortran v7.2.0
!     * ifort v17.0.2, watch out: proven NOT to work with ifort v15
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
!   - Different vertical interpolation options for calculating variables on 
!     predefined pressure levels, see vint_type variable
!     * 0 = linear in p for all 3D variables
!     * 1 = linear in log(p) for geopotential height and specific humidity to achieve
!           comparability to CCLM (HTr)
!   - Performance: Tries to use compiler optimisations (see Makefile) and OpenMP
!     to speed up loops.
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
! BUGS & FIXES:
!   - bug_v0.4_2018041700 
!     File affected: WRF_CMORizer.f90
!     Reported by: k.goergen@fz-juelich.de
!     Date: 2018-04-17
!     Information relayed to: cordex-fps-cpcm-wrf@googlegroups.com
!     "Before rolling out the tool, I found that
!     there were some issues of system call and the way the file list was
!     generated; so I replaced it using 'find' but without the '| sort',
!     rather last minute. Although the tool reads all dates and times from the
!     input and sorts in data accordingly, in case the 'cell method' is 'mean'
!     and two output intervals are needed and the end of file 0 is reached,
!     the next file in the filelist is used as file 1 to calculate the mean
!     from the last output timestep in file 0 and the first in file 1; without
!     the 'sort', file 1 is most likely the wrong file. (I know one may run
!     WRF with overlap at the end of a wrfout, but this is not always done).
!     See a note on this in the "restrictions" section of the preamble. A next
!     version will double check this."
!   - fix_v0.4_2018041700
!     File affected: WRF_CMORizer.f90
!     Fix by: k.goergen@fz-juelich.de
!     Date: 2018-04-17
!     Information relayed to: cordex-fps-cpcm-wrf@googlegroups.com
!     Find the 3 lines like this (around lines 1200ff):
!     CALL SYSTEM("find " // TRIM(DirInputSimResRoot) // "/ -name wrfout*" //
!     TRIM(domain) // "*" // TRIM(fl_filter) // "*.nc > " // tmpfileFL)
!     and add the "| sort", like so:
!     CALL SYSTEM("find " // TRIM(DirInputSimResRoot) // "/ -name wrfout*" //
!     TRIM(domain) // "*" // TRIM(fl_filter) // "*.nc | sort > " // tmpfileFL)
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
!     * [ ] temporal averaging, merge Aris // double check the find command > sorted?
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
