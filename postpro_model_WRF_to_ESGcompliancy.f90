!===============================================================================
! BOP
!
! NAME:
!   postpro_model_WRF_to_ESGcompliancy.f90
!   See license information at the end of the preamble.
!
! VERSION (minimum):
!   v2013-08-09
!   see git log for revision details and history
!
! STATUS:
!   under development
!
! CURRENT / (FORMER) CODE OWNER(S):
!   Klaus Goergen | k.goergen@gmx.net | KGo | MIUB/JSC
!
! PURPOSE / DESCRIPTION:
!   This application postprocesses (standard) raw WRF simulation results into
!   CORDEX (and CMIP5) compliant NetCDF files in a dedicated directory tree.
!   See the references below for the specifications used for this program.
!   The code can easily be adjusted in case specifications change. The post-
!   processing is necessary in order to being able to upload, stage and
!   distribute RCM simulation results via the Earth System Grid infrastructure
!   adopted by CORDEX from CMIP5. Files which do not adhere to this are
!   rejected.
!
! CONVENTION:
!   crpgl_ucc_v01
!
! PRG.-LANGUAGE / ENVIRONMENT:
!   - >=F95 compiler
!   - used: gfortran 4.6.3, ifort 11.1
!   - Linux/UNIX OS (-> system calls)
!   - F95 ISO FORTRAN except "SYSTEM" intrinsic function
!
! REQUIREMENTS:
!   - FORTRAN95 compiler
!   - NetCDF F90 library (http://www.unidata.ucar.edu/software/netcdf/)
!     v4.x, used: v4.1.1 and 4.2.1.1 incl. HDF5 -> write NetCDF-4 classic model
!     format
!   - make *nix console application
!   - date *nix console application
!   - uuidgen *nix console application (http://www.uuidgen.com/)
!
! BUILDING:
!   a) command line:
!      gfortran -I/usr/include <prg>.f90 -L/usr/lib -lnetcdff -lnetcdf
!   b) Makefile:
!      make
!
! CATEGORY:
!   PostPro.RCM.WRF.
!
! CALLING SEQUENCE:
!   ./postpro_model_WRF_to_ESGcompliancy > log
!
! CALLED FROM:
!   Standalone command-line tool.
!
! LOCAL VARIABLES:
!   See the variable declarations at the beginning of the code.
!
! INPUTS:
!   - NML files, see the tools main directory, have to be adjusted.
!   - WRF static fields (geo_em*)
!   - WRF outputs (wrfout*)
!   - WRF outputs extremes (wrfxtrm*)
!   No optional inputs, no keyword parameters.
!
! FILES USED:
!   - See inputs.
!
! OUTPUTS:
!   - NetCDF files according to standard specification.
!   - No Optional outputs.
!
! RESTRICTIONS:
!   - No restrictions. No side effects.
!
! BUGS:
!   - None.
!
! PROCEDURE / FEATURES:
!   - The tool can produce all required variables, i.e. output NetCDF files as
!     defined in the CORDEX archive design specifications as available in
!     July/August 2013 in possibly one pass based on standard WRF simulation
!     outputs. No additional processing is needed. Also the reuiqred NetCDF-4
!     classic data model format is written immediately, no later conversion
!     needed.
!   - 3hr data is produced first. This is closest to outputs most groups have
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
!     information data is sorted into the resulting NetCDF files. This makes the
!     the tool rather robust and flexible, a tradeoff is the possibly longer
!     processing time due to the searches needed for the date and time matching.
!     However these searches are on subsets only and therefore fairly efficient.
!     It also means that the WRF outputs may cover any timespan, daily, monthly,
!     or any overlap of months and/or years and that they may come in filelists
!     even not temporally ordered.
!   - Currently only one input root directory is possible. If data is stored at
!     different locations symbolic links might have to be done beforehand.
!   - The static fields are treated independently by the tool.
!
! EXAMPLE:
!   ./postpro_model_WRF_to_ESGcompliancy > log
!
! MODIFICATION / REVISION HISTORY:
!   See either git log or NEWS for details.
!   2013-08-09_KGo v0.1
!
! TODO / PLANNED EXTENSIONS:
!   - Temporal aggregations, i.e. 6hr, day, mon, seas; all based on orginal
!     outputs
!   - Static fields processing
!   - All variables -> extension of namelist
!   - Variable-dependent processings, e.g. MSLP
!   - time_bnds and lvl vars and processing, ask Grigori about this 00,24 thing
!   - Import of alternative (to NML) ASCII file with long and standard names
!   - Add units to that ASCII file as well
!   - Not yet tested with EUR-11, i.e. large model outputs
!   - Additional variable in runctrl.vars.nml to control additional 3hr outputs
!     to have all vars in that format and have more vertical levels
!   - (OpenMP parallelism for the processing section)
!   - (Parallel NetCDF I/O where possible)
!
! REFERENCES (some reference tool format):
!   - CORDEX WRF group model identification and naming:
!     https://docs.google.com/spreadsheet/ccc?key=0ArYFyU35McvvdFBqaXdLcERjbFp3U
!     lBZcC1qbm53NFE#gid=0
!   - Standard specification / naming conventions (see NML files)
!     ... CMIP5, CORDEX, txt files
!
! CALLED PROCEDURES:
!   No external calls.
!
! PERFORMANCE:
!   EUR-44: 1min/yr > 3hr/150yr OR 1h/1yr65vars... + averaging, after each run
!
! LICENSE / COPYING:
!
!   Copyright (C) 2013 Klaus GOERGEN
!
!   This file is part of postpro_model_WRF_to_ESGcompliancy.
!
!   postpro_model_WRF_to_ESGcompliancy is free software: you can
!   redistribute it and/or modify it under the terms of the GNU
!   General Public License as published by the Free Software
!   Foundation, either version 3 of the License, or any later
!   version.
!
!   This program is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
!   GNU General Public License for more details.
!
!   You should have received a copy of the GNU General Public License
!   along with this program. If not, see <http://www.gnu.org/licenses/>.
!
! EOP
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
! passing allocatable arrays between main program and external subroutine

MODULE flhandling

  IMPLICIT NONE
  SAVE

  CHARACTER (len = 200):: tmpfileFL
  CHARACTER (len = 200), DIMENSION(:), ALLOCATABLE :: fl_wrfout
  CHARACTER (len = 200), DIMENSION(:), ALLOCATABLE :: fl_wrfxtr
  INTEGER :: ft

END MODULE flHandling

!-------------------------------------------------------------------------------
! index, Y, M, D, H, depending on the "frequency" of the dataset, i.e. time
! intervals

MODULE RefTimeVecs

  IMPLICIT NONE
  SAVE

  REAL, DIMENSION(:,:), ALLOCATABLE :: TimeRefArray
  !INTEGER :: Tyear_start, Tyear_end

END MODULE RefTimeVecs

!-------------------------------------------------------------------------------
! namelist handling

MODULE NameListHandling

  IMPLICIT NONE
  SAVE

  INTEGER, PARAMETER :: nvars = 3

  CHARACTER (len = 200) :: Conventions, contact, experiment_id, experiment, &
    driving_experiment, driving_model_id, driving_model_ensemble_member, &
    driving_experiment_name, institution, institute_id, model_id, &
    rcm_version_id, project_id, CORDEX_domain, product, references

  CHARACTER (len = 200) :: comment, institute_run_id

  CHARACTER (LEN = 100), DIMENSION(nvars):: var_wrf, var_cmip, standard_name, &
    long_name, units, filetype, cm3hr, cm6hr, cmDay, cmMon, cmSea, positive
  INTEGER, DIMENSION(nvars):: height, cordexID
  LOGICAL, DIMENSION(nvars):: time3hr, time6hr, timeDay, timeMon, timeSea, &
     interpolate

  CHARACTER (len = 200) :: DirInputSimResRoot, DirOutputPostProRoot, domain

  INTEGER ::  nx, ny, nz, xoffset, yoffset, xfocus, yfocus
  CHARACTER (len = 4) :: ts, te, tstot, tetot

  CHARACTER (len = 200) :: PnFnGeo

  NAMELIST / globalvars / Conventions, contact, experiment_id, experiment, &
    driving_experiment, driving_model_id, driving_model_ensemble_member, &
    driving_experiment_name, institution, institute_id, model_id, &
    rcm_version_id, project_id, CORDEX_domain, product, references

  NAMELIST / globalvars_additional / comment, institute_run_id

  NAMELIST / vars / var_wrf, var_cmip, standard_name, long_name, units, &
    height, time3hr, time6hr, timeDay, timeMon, timeSea, filetype, &
    cm3hr, cm6hr, cmDay, cmMon, cmSea, interpolate, cordexID, positive

  NAMELIST / filesystem / DirInputSimResRoot, DirOutputPostProRoot, domain

  NAMELIST / model_config / ts, te, nx, ny, nz, xoffset, yoffset, xfocus, &
    yfocus, tstot, tetot

  NAMELIST / static_fields / PnFnGeo

END MODULE NameListHandling

!===============================================================================

PROGRAM ppWRFCMIP

USE flhandling
USE RefTimeVecs
USE NameListHandling

USE netcdf

IMPLICIT NONE

!===============================================================================

INTERFACE

  SUBROUTINE generateFilelist
  END SUBROUTINE generateFilelist

  SUBROUTINE CreateRefTimeArray( dt )
    IMPLICIT NONE
    CHARACTER (LEN = 3), INTENT(IN) :: dt
  END SUBROUTINE CreateRefTimeArray

END INTERFACE

!===============================================================================
! filenames

CHARACTER (len = *), PARAMETER :: fnNMLexp = "runctrl.access13hist.nml"
CHARACTER (len = *), PARAMETER :: fnNMLvar = "runctrl.vars.nml_pr"  !"runctrl.vars.nml_vars_on_plevels" !"runctrl.vars.nml"

CHARACTER (len = *), PARAMETER :: PathFileNameInTEST = "testWRFin.nc"
CHARACTER (len = *), PARAMETER :: PathFileNameOutTEST = "testESGout.nc"

CHARACTER (len = 200) :: pn_out, fn_out, iflWRFin

!-------------------------------------------------------------------------------

! auxilliary vars, just needed during development
! INTEGER, PARAMETER :: nt = 8

! new NetCDF file
INTEGER :: ncid, ncidin
INTEGER :: lvl_dimid, lon_dimid, lat_dimid, rec_dimid, height_dimid, &
  nb2_dimid
INTEGER :: varid, x_varid, lon_varid, lat_varid, rlon_varid, rlat_varid, &
  rotated_pole_varid, height_varid, rec_varid, pp_varid, pb_varid, ph_varid, &
  phb_varid, qv_varid, theta_varid, t2_varid, recbnds_varid, rainnc_varid, &
  rainc_varid

! input data general query
INTEGER :: ncid_in, ndims_in, nvars_in, ngatts_in, unlimdimid_in !!!, formatp_in

! record variable in input data
INTEGER :: InVarIdRec, InDimLenRec !!!, InVarNdimsRec
CHARACTER (len = NF90_MAX_NAME) :: InDimNameRec !!!, InVarNameRec
!!!INTEGER, DIMENSION(NF90_MAX_VAR_DIMS) :: InDimIdsRec
CHARACTER (len = 19), DIMENSION(:), ALLOCATABLE :: InVarDataRec

! data
REAL, DIMENSION(:,:), ALLOCATABLE :: data_in, psl_in, t2_in, TimeRefArraySelYear, &
  Time_bnds, pr_in
REAL, DIMENSION(:,:,:), ALLOCATABLE :: pp_in, pb_in, ph_in, phb_in, qv_in, &
  theta_in, t_in, ph_fl, p_in, t_out, rainnc_in, rainc_in, GeoInLonLat
REAL, DIMENSION(:), ALLOCATABLE :: GeoInRLat, GeoInRLon, pout

! time and date handling
CHARACTER (len = 3), DIMENSION(:), ALLOCATABLE :: frequency
!!!INTEGER :: WRFfileNyears, WRFfileNmonths
INTEGER, DIMENSION(:), ALLOCATABLE :: InDateTimeYear, InDateTimeMonth, &
  InDateTimeDay, InDateTimeHour      !, WRFfileIyears, WRFfileImonths
CHARACTER (LEN=4) :: InDateTimeYearStr
!CHARACTER (LEN=2) :: InDateTimeMonthStr
INTEGER :: InDateTimeYearPrev = 0  !, InDateTimeMonthPrev = 0

CHARACTER (LEN = 100), DIMENSION(nvars) :: cell_methods

!-------------------------------------------------------------------------------
! statistics

REAL :: stat_mean, slope

!-------------------------------------------------------------------------------
! general

INTEGER :: i, sts, ivar, ifrq, ifl, it, counter, j, np, nl !!!j
!!!INTEGER :: AllocateStatus, DeAllocateStatus
LOGICAL :: FileExists   !, comb_flags
REAL :: cpuTs, cpuTe

!-------------------------------------------------------------------------------
! system calls

CHARACTER (len = *), PARAMETER :: cmdUUID = "uuidgen -t > tmpfileUUID"
CHARACTER (len = 37) :: trackingID

CHARACTER (len = *), PARAMETER :: cmdDate = "date -u +%Y-%m-%d-T%H:%M:%SZ > tmpfileDate"
CHARACTER (len = 21) :: creationDate

!===============================================================================

PRINT *, "============================================================"
PRINT *, "*** NML READING ***"
PRINT *, fnNMLexp
PRINT *, fnNMLvar

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

OPEN(2,FILE=fnNMLvar)
READ(UNIT=2,NML=vars)
CLOSE(2)

!-------------------------------------------------------------------------------
! allocate main data input array outside the loops based on nml entries
! dummy allocation of the ref time array -> has to maintain its values during
! several looping constructs and is de-allocated before the initial allocation

ALLOCATE( data_in( xfocus, yfocus ), STAT=sts )
IF (sts /= 0) STOP "*** Not enough memory ***"

ALLOCATE( TimeRefArraySelYear(2,2) )
ALLOCATE( Time_bnds(2,2) )  !SKn
!-------------------------------------------------------------------------------
! get the invariant vars which have to be added all the time
! lon, lat, rlon, rlat
! mass grid
! seperate file
! subset is double checked with orig geo_em file and previously postprocessed
! data; match up to the 5th digit
! geo files match

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
  START = (/ xoffset, yoffset, 1 /), COUNT = (/ xfocus, yfocus, 1 /)) !normal order: x y z t

sts = NF90_INQ_VARID(ncidin, "XLAT_M", varid)
sts = NF90_GET_VAR(ncidin, varid, GeoInLonLat(:, :, 2), &
  START = (/ xoffset, yoffset, 1 /), COUNT = (/ xfocus, yfocus, 1 /))

sts = NF90_INQ_VARID(ncidin, "CLONG", varid)
sts = NF90_GET_VAR(ncidin, varid, GeoInRLon(:), &
  START = (/ xoffset, 1, 1 /), COUNT = (/ xfocus, 1, 1 /))

sts = NF90_INQ_VARID(ncidin, "CLAT", varid)
sts = NF90_GET_VAR(ncidin, varid, GeoInRLat(:), &
  START = (/ 1, yoffset, 1 /), COUNT = (/ 1, yfocus, 1 /))

sts = NF90_CLOSE(ncidin)

!PRINT *, "rlon = "
!PRINT *, SHAPE(GeoInRLon)
!PRINT *, GeoInRLon
!
!PRINT *, "rlat = "
!PRINT *, SHAPE(GeoInRLat)
!PRINT *, GeoInRLat
!
!PRINT *, "GeoInLonLat = "
!PRINT *, SHAPE(GeoInLonLat)
!PRINT *, "lon = ", GeoInLonLat(:,:,1)
!PRINT *, "lat = ", GeoInLonLat(:,:,2)

!-------------------------------------------------------------------------------
! main loop over the different variables, namelist controlled

ALLOCATE ( frequency(6) )
frequency(1) = "3hr"
frequency(2) = "6hr"
frequency(3) = "day"
frequency(4) = "mon"
frequency(5) = "sem"
frequency(6) = "fx"

!DO ifrq = 1, SIZE(frequency), 1
DO ifrq = 1, 1, 1

  PRINT *, "============================================================"
  PRINT *, "freq = ", frequency(ifrq)

!-------------------------------------------------------------------------------

  SELECT CASE (frequency(ifrq))
  CASE ('3hr')
    cell_methods(:) = cm3hr(:)
  CASE ('6hr')
    cell_methods(:) = cm6hr(:)
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

!-------------------------------------------------------------------------------
! get a file list of all wrfout and wrfxtrm files
! use regex to refine the ls output and the filelist
! non-std, works for gfortran (fct & subroutine) + ifort

  PRINT *, "============================================================"
  PRINT *, "*** FILELIST CREATION ***"

  tmpfileFL = "tmpfileFL"

  PRINT *, "filelist search pattern = ", TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/" // "*/wrfout*nc"
  CALL SYSTEM("ls -1 " // TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/*/wrfout*{" // ts // ".." // te // "}*nc > " // tmpfileFL)
  ft = 0
  CALL generateFilelist

  PRINT *, "filelist search pattern = ", TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/" // "*/wrfxtrm*nc"
  CALL SYSTEM("ls -1 " // TRIM(DirInputSimResRoot) // "/" // TRIM(domain) // "/*/wrfxtrm*{" // ts // ".." // te // "}*nc > " // tmpfileFL)
  ft = 1
  CALL generateFilelist

  DO i=1,SIZE(fl_wrfout(:)),1
    PRINT '(100A)', fl_wrfout(i)
    PRINT '(100A)', fl_wrfxtr(i)
  END DO

!-------------------------------------------------------------------------------
! creation of the main reference array

  PRINT *, "============================================================"
  PRINT *, "*** TIME REFERENCE ARRAY ***"

  CALL CreateRefTimeArray( frequency(ifrq) )

  PRINT *, "size & shape of the TimRefArray = ", SIZE(TimeRefArray), &
    SHAPE(TimeRefArray)

!-------------------------------------------------------------------------------
! loop over the different variables

  !DO ivar = 1, nvars, 1
  DO ivar = 1, 1, 1

    PRINT *,"============================================================"
    PRINT *, "*** ", TRIM(var_cmip(ivar)), " ***"

!-------------------------------------------------------------------------------
! loop over the filelist per variable
! content of filelist is defined by filename patterns in system call

    !DO ifl = 1, SIZE(fl_wrfout), 1 ! operational: loop over complete filelist
    print *,' SIZE(fl_wrfout', SIZE(fl_wrfout)
    DO ifl = 1, 1, 1 ! testing: loop over specific entry in filelist

      CALL CPU_TIME(cpuTs)

      PRINT *, "------------------------------------------------------------"

      IF ( filetype(ivar) == "s" ) THEN
        iflWRFin = fl_wrfout(ifl)
      ELSE IF ( filetype(ivar) == "x" ) THEN
        iflWRFin = fl_wrfxtr(ifl)
      END IF

      PRINT '(100A)', TRIM(iflWRFin)

!-------------------------------------------------------------------------------
! which timespan is covered by the WRF outputs?
! assume timespan wrfout = timespan wrfxtrm
! this determines how many times the tool has to loop over the inputs
! also check how many years are covered by a single wrfout and wrfxtrm which
! determines the output file generation

      sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncid_in)
      sts = NF90_INQUIRE(ncid_in, ndims_in, nvars_in, ngatts_in, unlimdimid_in)
      sts = NF90_INQ_VARID(ncid_in, "Times", InVarIdRec)
      sts = NF90_INQUIRE_DIMENSION(ncid_in, unlimdimid_in, &
        NAME = InDimNameRec, LEN = InDimLenRec)
      ALLOCATE(InVarDataRec(InDimLenRec))
      sts = NF90_GET_VAR(ncid_in, InVarIdRec, InVarDataRec)
      sts = NF90_CLOSE(ncid_in)

      print *, InVarDataRec(1), " to ", InVarDataRec(InDimLenRec)

      ALLOCATE(InDateTimeYear(InDimLenRec))
      ALLOCATE(InDateTimeMonth(InDimLenRec))
      ALLOCATE(InDateTimeDay(InDimLenRec))
      ALLOCATE(InDateTimeHour(InDimLenRec))

      ! this is the temporal coverage of the WRF input data
      DO i = 1, SIZE(InVarDataRec), 1
        READ( InVarDataRec(i), '(I4,1X,I2,1X,I2,1X,I2)' ) InDateTimeYear(i), InDateTimeMonth(i), InDateTimeDay(i), InDateTimeHour(i)
      END DO

!-------------------------------------------------------------------------------
! check whether a file is needed at all
! check for first date
! for subsequent dates, just check whether it is the same as the previous one
! if this is not the case, then check whether file exists...
! if it does not exist (default case): create
! pathname is always needed

      ! loop over the individual timesteps in the WRF files...
      ! this may take some time but it is robust and also extremely large arrays
      ! might be used
      ! highly robust code
      DO it = 1, InDimLenRec, 1

        PRINT *, "----------------------------------------"
        PRINT *, "working on date in WRF input file = ", TRIM(InVarDataRec(it))
        PRINT *, "---"

!-------------------------------------------------------------------------------
! generate path and filename
! /hpc/shared/int/eva/ramod_WRF_CRPGL/WRFrv021rXXrcc3CpCdx/postpro/EUR-44/CRPGL/
! ECMWF-ERAINT/evaluation/r1i1p1/CRPGL-WRFARW331/v1
! evspsbl_EUR-44_ECMWF-ERAINT_evaluation_r1i1p1_CRPGL-WRFARW331_v1_3hr_
! 1989010100-1989123121

        ! output does not yet exist
        ! monthy check is basically not even possible, but does not do any harm
        ! this is a rerstriction for all those who might have a different file
        ! structure
        IF ( InDateTimeYearPrev /= InDateTimeYear(it) ) THEN !.AND. &
          !( InDateTimeMonthPrev /= InDateTimeMonth(it) ) ) THEN

          InDateTimeYearPrev = InDateTimeYear(it)

          PRINT *, "start of processing or new year encountered -> t ref. vec. and filecheck"

          !READ( InDateTimeYear(it), '(4A)' ) InDateTimeYearStr
          !READ( InDateTimeMonth(it), '(2A)' ) InDateTimeMonthStr
          WRITE (InDateTimeYearStr,'(I4.4)') InDateTimeYear(it)
          !WRITE (InDateTimeMonthStr,'(I2.2)') InDateTimeMonth(it)
          !PRINT *, InDateTimeYearStr, InDateTimeMonthStr

          pn_out = TRIM(CORDEX_domain)                 // "/" // &
                   TRIM(institute_id)                  // "/" // &
                   TRIM(driving_model_id)              // "/" // &
                   TRIM(driving_experiment_name)       // "/" // &
                   TRIM(driving_model_ensemble_member) // "/" // &
                   TRIM(model_id)                      // "/" // &
                   TRIM(rcm_version_id)                // "/" // &
                   TRIM(frequency(ifrq))               // "/" // &
                   TRIM(var_cmip(ivar))

          fn_out = TRIM(var_cmip(ivar))                // "_" // &
                   TRIM(CORDEX_domain)                 // "_" // &
                   TRIM(driving_model_id)              // "_" // &
                   TRIM(driving_experiment_name)       // "_" // &
                   TRIM(driving_model_ensemble_member) // "_" // &
                   TRIM(model_id)                      // "_" // &
                   TRIM(rcm_version_id)                // "_" // &
                   TRIM(frequency(ifrq))               // "_" // &
                   InDateTimeYearStr//"010100-"//InDateTimeYearStr//"12312100" // &
                   ".nc"

          PRINT *, "pn_out = ", TRIM(pn_out)
          PRINT *, "fn_out = ", TRIM(fn_out)

!-------------------------------------------------------------------------------
! extract the time info from the ref array which fits the respective year
            ! ...as there is no "WHERE" the way I need it in F95, use loops
            ! this is needed whenever a new netcdf file is to be used, also if
            ! this file exists already
!        READ( InVarDataRec(i), '(I4,1X,I2,1X,I2,1X,I2)' ) InDateTimeYear(it), InDateTimeMonth(it), InDateTimeDay(it), InDateTimeHour(it)

          DEALLOCATE( TimeRefArraySelYear )

          print *, "DEALLOCATE( TimeRefArraySelYear )" 

          DEALLOCATE( Time_bnds ) !SKn 

          print *, "DEALLOCATE( Time_bnds )"

          counter = 0
          PRINT *, SIZE(TimeRefArray, 1)
          PRINT *, SHAPE(TimeRefArray, 1)
          DO i = 1, SIZE(TimeRefArray, 1), 1
            IF ( TimeRefArray(i,2) == InDateTimeYear(it)) THEN
              counter = counter + 1
            END IF
          END DO
          ! holds data of exactly 1 year
          PRINT *, "timesteps in the time ref. subset = ", counter
          ALLOCATE( TimeRefArraySelYear( counter, 5 ) ) ! index, y, m, d, h

          print *, "ALLOCATE( TimeRefArraySelYear( counter, 5 ) )", TimeRefArraySelYear( counter, 5 )

          ! find the matching elements of the respecitve year and copy them

          ALLOCATE( Time_bnds( 2, counter ) )

          print *, "ALLOCATE( Time_bnds( 2, counter ) )", Time_bnds( 2, counter )

          counter = 0
          DO i = 1, SIZE(TimeRefArray, 1), 1
            IF ( TimeRefArray(i,2) == InDateTimeYear(it)) THEN
              counter = counter + 1
              TimeRefArraySelYear(counter,1:5) = TimeRefArray(i,1:5)
            END IF
          END DO

          !PRINT '(F9.3,1X,F5.0,1X,F3.0,1X,F3.0,1X,F3.0)', TRANSPOSE( TimeRefArraySelYear(:,:) )

!-------------------------------------------------------------------------------
! check for existance of the file and generate file if needed

          INQUIRE( FILE=TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) // "/" // TRIM(fn_out), EXIST=FileExists )

          ! could exist already from a previous run of tool and due to multiple
          ! months in a file (i.e. 1 WRF output file may cover several months)
          IF ( FileExists ) THEN

            PRINT *, "path and file exist, continue filling"

          ELSE

            PRINT *, "path and file do not yet exist, create path and NetCDF file first"
            PRINT '(150A)', "path = ", TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out)

            CALL SYSTEM("mkdir -p " // TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) )

!-------------------------------------------------------------------------------
! non-std, works for gfortran (fct & subroutine) + ifort
! comment lines in the NetCDF file global attribute definition
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
! create NetCDF file
! NF90_CLASSIC_MODEL = NetCDF4_classic
! NF90_HDF5 = NetCDF4 based on HDF5
! NF90_CLOBBER = old NetCDF
! sts = NF90_CREATE(PathFileNameOutTEST, NF90_HDF5, ncid)

            !comb_flags = IOR(NF90_HDF5, NF90_CLASSIC_MODEL)
            sts = NF90_CREATE(TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) // "/" // TRIM(fn_out), IOR(NF90_HDF5, NF90_CLASSIC_MODEL), ncid)

            ! always included
            sts = NF90_DEF_DIM(ncid, "rlon", xfocus, lon_dimid)
            sts = NF90_DEF_DIM(ncid, "rlat", yfocus, lat_dimid)
            sts = NF90_DEF_DIM(ncid, "height", 1, height_dimid)
            sts = NF90_DEF_DIM(ncid, "time", NF90_UNLIMITED, rec_dimid)
            sts = NF90_DEF_DIM(ncid, "nb2", 2, nb2_dimid)


            ! always included
            sts = nf90_def_var(ncid, "lon", NF90_DOUBLE, (/ lon_dimid, lat_dimid /), lon_varid)
            sts = nf90_put_att(ncid, lon_varid, "standard_name", "longitude")
            sts = nf90_put_att(ncid, lon_varid, "long_name", "longitude")
            sts = nf90_put_att(ncid, lon_varid, "units", "degrees_east")

            ! always included
            sts = nf90_def_var(ncid, "lat", NF90_DOUBLE, (/ lon_dimid, lat_dimid /), lat_varid)
            sts = nf90_put_att(ncid, lat_varid, "standard_name", "latitude")
            sts = nf90_put_att(ncid, lat_varid, "long_name", "latitude")
            sts = nf90_put_att(ncid, lat_varid, "units", "degrees_north")

            ! always included
            sts = nf90_def_var(ncid, "rlon", NF90_DOUBLE, (/ lon_dimid /), rlon_varid)
            sts = nf90_put_att(ncid, rlon_varid, "standard_name", "grid_longitude")
            sts = nf90_put_att(ncid, rlon_varid, "long_name", "longitude in rotated pole grid")
            sts = nf90_put_att(ncid, rlon_varid, "units", "degrees")
            sts = nf90_put_att(ncid, rlon_varid, "axis", "X")

            ! always included
            sts = nf90_def_var(ncid, "rlat", NF90_DOUBLE, (/ lat_dimid /), rlat_varid)
            sts = nf90_put_att(ncid, rlat_varid, "standard_name", "grid_latitude")
            sts = nf90_put_att(ncid, rlat_varid, "long_name", "latitude in rotated pole grid")
            sts = nf90_put_att(ncid, rlat_varid, "units", "degrees")
            sts = nf90_put_att(ncid, rlat_varid, "axis", "Y")

            ! always included
            ! restriction to one domain only
            sts = nf90_def_var(ncid, "rotated_pole", NF90_CHAR, rotated_pole_varid)
            sts = nf90_put_att(ncid, rotated_pole_varid, "grid_mapping_name", "rotated_latitude_longitude")
            sts = nf90_put_att(ncid, rotated_pole_varid, "grid_north_pole_latitude", "39.25")
            sts = nf90_put_att(ncid, rotated_pole_varid, "grid_north_pole_longitude", "-162.0")

            ! depends whether height is set in the nml
            IF ( height(ivar) /= -999 ) THEN
              sts = nf90_def_var(ncid, "height", NF90_DOUBLE, (/ height_dimid /), height_varid)
              sts = nf90_put_att(ncid, height_varid, "standard_name", "height")
              sts = nf90_put_att(ncid, height_varid, "long_name", "height")
              sts = nf90_put_att(ncid, height_varid, "units", "m")
              sts = nf90_put_att(ncid, height_varid, "positive", "up")
              sts = nf90_put_att(ncid, height_varid, "axis", "Z")
            END IF

            !missing: time_bnds, depends

            !missing: lvl, depends

            ! always included
            sts = nf90_def_var(ncid, "time", NF90_DOUBLE, (/ rec_dimid /), rec_varid)
            sts = nf90_put_att(ncid, rec_varid, "standard_name", "time")
            sts = nf90_put_att(ncid, rec_varid, "long_name", "time")
            sts = nf90_put_att(ncid, rec_varid, "units", "days since 1949-12-01 00:00:00")
            sts = nf90_put_att(ncid, rec_varid, "calendar", "standard")
            sts = nf90_put_att(ncid, rec_varid, "axis", "T")

            ! for mean variables
            sts = nf90_def_var(ncid, "time_bnds", NF90_DOUBLE, (/ nb2_dimid, rec_dimid /), recbnds_varid)
            sts = nf90_put_att(ncid, recbnds_varid, "standard_name", "time_bnds")
            sts = nf90_put_att(ncid, recbnds_varid, "long_name", "time_bnds")
            sts = nf90_put_att(ncid, recbnds_varid, "units", "days since 1949-12-01 00:00:00")
            sts = nf90_put_att(ncid, recbnds_varid, "calendar", "standard")
            sts = nf90_put_att(ncid, recbnds_varid, "axis", "T")

            print *,'rec_varid', rec_varid
            print *,'recbnds_varid', recbnds_varid


            ! always included
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
            sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "comment", comment)
            sts = NF90_PUT_ATT(ncid, NF90_GLOBAL, "institute_run_id", institute_run_id)

            ! always included
            IF ( height(ivar) /= -999 ) THEN
              sts = nf90_def_var(ncid, var_cmip(ivar), NF90_FLOAT, (/ lon_dimid, lat_dimid, height_dimid, rec_dimid /), x_varid)
            ELSE
              sts = nf90_def_var(ncid, var_cmip(ivar), NF90_FLOAT, (/ lon_dimid, lat_dimid, rec_dimid /), x_varid)
            END IF
            sts = nf90_put_att(ncid, x_varid, "standard_name", standard_name(ivar))
            sts = nf90_put_att(ncid, x_varid, "long_name", long_name(ivar))
            sts = nf90_put_att(ncid, x_varid, "units", units(ivar))
            IF ( positive(ivar) /= '-999' ) THEN
              sts = nf90_put_att(ncid, x_varid, "positive", positive(ivar))
            END IF
            sts = nf90_put_att(ncid, x_varid, "cell_methods", "time: "//TRIM(cell_methods(ivar)))
            sts = nf90_put_att(ncid, x_varid, "coordinates", "lon lat")
            sts = nf90_put_att(ncid, x_varid, "grid_mapping", "Rotated_Pole")

            sts = NF90_ENDDEF(ncid)

            ! add time, whole year from above
            IF ( cell_methods(ivar) == "point" ) THEN
              print*, 'cell_methods:', cell_methods(ivar)
              sts = NF90_PUT_VAR(ncid, rec_varid, TimeRefArraySelYear(:,1) )
            END IF
            IF ( cell_methods(ivar) == "mean" ) THEN
              print*, 'cell_methods:', cell_methods(ivar)
              sts = NF90_PUT_VAR(ncid, rec_varid, (TimeRefArraySelYear(:,1)+1.5/24.) )

              print *, 'sts NF90_PUT_VAR time', sts

              !print*, 'TimeRefArraySelYear(:,1)', TimeRefArraySelYear(:,1)
              !print*, 'TimeRefArraySelYear(:,2)', TimeRefArraySelYear(:,2)
              !print*, 'TimeRefArraySelYear(:,3)', TimeRefArraySelYear(:,3)
              !print*, 'TimeRefArraySelYear(:,4)', TimeRefArraySelYear(:,4)
              !print*, 'TimeRefArraySelYear(:,5)', TimeRefArraySelYear(:,5)


              Time_bnds(1,:) = TimeRefArraySelYear(:,1)
              Time_bnds(2,:) = TimeRefArraySelYear(:,1)+3.0/24.


              print*, 'recbnds_varid', recbnds_varid

              !print*, 'Time_bnds(:,:)', Time_bnds(:,:)
              sts = NF90_PUT_VAR(ncid, recbnds_varid, Time_bnds(:,:), START = (/ 1, 1 /) , COUNT = (/ 2, SIZE(Time_bnds(1,:)) /) ) !SKn: check PUT_VAR does not work!!!

              print *, 'sts NF90_PUT_VAR time_bnds', sts
            END IF
            !print *,'TimeRefArraySelYear(:,1)', TimeRefArraySelYear(:,1)
             


            sts = NF90_PUT_VAR(ncid, lon_varid, GeoInLonLat(:,:,1), &
              START = (/ 1, 1, 1 /), COUNT = (/ xfocus, yfocus, 1 /) )
            sts = NF90_PUT_VAR(ncid, lat_varid, GeoInLonLat(:,:,2), &
              START = (/ 1, 1, 2 /), COUNT = (/ xfocus, yfocus, 1 /) )
            sts = NF90_PUT_VAR(ncid, rlon_varid, GeoInRLon )
            sts = NF90_PUT_VAR(ncid, rlat_varid, GeoInRLat )

            ! add time_bnds, calc here

            ! add height from NML
            IF ( height(ivar) /= -999 ) THEN
              sts = NF90_PUT_VAR(ncid, height_varid, height(ivar) )
            END IF

            sts = NF90_CLOSE(ncid)

          END IF ! file exists y/n

        END IF ! checking with previous year and month

!-------------------------------------------------------------------------------
! match timestep of WRFin with the subset of the ref time vec which belong to
! the NetCDF file of the year currently open to receive data
! NOT SURE WHETHER THIS IS NEEDED AT ALL, THIS IS THE WRONG DIRECTION ???
! see whether the current time of the timestep fits anywhere in the

        PRINT *, "reading WRF sim. res. = ", TRIM(InVarDataRec(it)), it
        !PRINT *, SIZE(TimeRefArraySelYear,1)
        !PRINT *, SHAPE(TimeRefArraySelYear)
        !PRINT *, "current transferred input time: ", InDateTimeYear(it), InDateTimeMonth(it), InDateTimeDay(it), InDateTimeHour(it)

        counter = 0
        DO i = 1, SIZE(TimeRefArraySelYear,1),1 ! time content of the WRF file

          counter = counter + 1

          !PRINT '(F9.3,1X,F5.0,1X,F3.0,1X,F3.0,1X,F3.0)',TimeRefArraySelYear(i,1),TimeRefArraySelYear(i,2),TimeRefArraySelYear(i,3),TimeRefArraySelYear(i,4),TimeRefArraySelYear(i,5)

          IF ( ( TimeRefArraySelYear(i,2) == InDateTimeYear(it)  ) .AND. &
               ( TimeRefArraySelYear(i,3) == InDateTimeMonth(it) ) .AND. &
               ( TimeRefArraySelYear(i,4) == InDateTimeDay(it)   ) .AND. &
               ( TimeRefArraySelYear(i,5) == InDateTimeHour(it)  ) ) THEN
            EXIT
          END IF

        END DO

        PRINT *, "index where in the NC file the WRF data is sorted in = ", &
          counter

!-------------------------------------------------------------------------------
! read orig WRF outpouts
! there is always a corresponding time-slot in the NC file
! extracted time from above
! "it" controls it all: timestep in the individual WRF file

        sts = NF90_OPEN(iflWRFin, NF90_NOWRITE, ncidin)

        !IF ( var_cmip(ivar) == "psl" ) THEN

        IF ( (var_cmip(ivar) == "psl") .or. (height(ivar) == 850) &
              .or.(height(ivar) == 500) .or. (height(ivar) == 200)) THEN

          ALLOCATE( pp_in( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( pb_in( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( ph_in( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( phb_in( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( theta_in( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( qv_in( xfocus, yfocus, 40  ), STAT=sts )
          ALLOCATE( t_in( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( ph_fl( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( psl_in ( xfocus, yfocus ), STAT=sts )
          ALLOCATE( t2_in ( xfocus, yfocus ), STAT=sts )          

          ALLOCATE( p_in( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( pp_in( xfocus, yfocus, 40 ), STAT=sts )
          ALLOCATE( t_out( xfocus, yfocus, 3 ), STAT=sts )
          ALLOCATE( pout( 3 ), STAT=sts ) 


          print *,'read vars for psl calculation'

          sts = NF90_INQ_VARID(ncidin, "P", pp_varid)
          sts = NF90_INQ_VARID(ncidin, "PB", pb_varid)
          sts = NF90_INQ_VARID(ncidin, "PH", ph_varid)
          sts = NF90_INQ_VARID(ncidin, "PHB", phb_varid)
          sts = NF90_INQ_VARID(ncidin, "T", theta_varid)
          sts = NF90_INQ_VARID(ncidin, "QV", qv_varid)

          sts = NF90_INQ_VARID(ncidin, "T2", t2_varid)

          sts = NF90_GET_VAR(ncidin, t2_varid, t2_in(:,:), &
            START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
          
          sts = NF90_GET_VAR(ncidin, pp_varid, pp_in(:,:,:), &
            START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, 40, 1 /) )          

          !print * ,'xoffset', xoffset
          !print * ,'yoffset', yoffset
          !print * ,'xfocus', xfocus
          !print * ,'yfocus', yfocus

          sts = NF90_GET_VAR(ncidin, pb_varid, pb_in(:,:,:), &
            START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, 40, 1 /) )

          !print *,'got pb_in'

          sts = NF90_GET_VAR(ncidin, ph_varid, ph_in(:,:,:), &
            START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, 40, 1 /) )

          !print *,'got ph_in'

          sts = NF90_GET_VAR(ncidin, phb_varid, phb_in(:,:,:), &
            START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, 40, 1 /) )

          !print *,'got phb_in'

          sts = NF90_GET_VAR(ncidin, theta_varid, theta_in(:,:,:), &
            START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, 40, 1 /) )

          !print *,'got theta_in'
  
          sts = NF90_GET_VAR(ncidin, qv_varid, qv_in(:,:,:), &
            START = (/ xoffset, yoffset, 1, it /), COUNT = (/ xfocus, yfocus, 40, 1 /) )

          !print *,'got qv_in'

        ELSE IF (var_cmip(ivar) == "pr") THEN 

          ALLOCATE( rainnc_in ( xfocus, yfocus, 2 ), STAT=sts )
          ALLOCATE( rainc_in ( xfocus, yfocus, 2 ), STAT=sts )
          ALLOCATE( pr_in ( xfocus, yfocus ), STAT=sts )

          sts = NF90_INQ_VARID(ncidin, "RAINNC", rainnc_varid)
          sts = NF90_INQ_VARID(ncidin, "RAINC", rainc_varid)

          sts = NF90_GET_VAR(ncidin, rainnc_varid, rainnc_in(:,:,:), &
            START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 2 /) )   !read two timesteps to calculate 3hr sum

          sts = NF90_GET_VAR(ncidin, rainc_varid, rainc_in(:,:,:), &
            START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 2 /) )


        ELSE
          sts = NF90_INQ_VARID(ncidin, TRIM(var_wrf(ivar)), varid)

          sts = NF90_GET_VAR(ncidin, varid, data_in(:,:), &
            START = (/ xoffset, yoffset, it /), COUNT = (/ xfocus, yfocus, 1 /) )
        END IF

        sts = NF90_CLOSE(ncidin)

!-------------------------------------------------------------------------------
! some analysis of the data

        print *,"shape of array" , SHAPE(data_in)
        print *,"size of array" , SIZE(data_in)
!
!       stat_mean = SUM(data_in(:,:,5))/(MAX(1,SIZE(data_in(:,:,5))))
!       PRINT *, stat_mean
        stat_mean = SUM(data_in(:,:))/SIZE(data_in(:,:))
        PRINT *, stat_mean

!-------------------------------------------------------------------------------
! processing

!       ***psl***   ***vars on pressure levels***        
        IF ( (var_cmip(ivar) == "psl") .or. (height(ivar) == 850) &
              .or.(height(ivar) == 500) .or. (height(ivar) == 200)) THEN

          ph_fl(:,:,1) = ((ph_in(:,:,1)+phb_in(:,:,1))+(ph_in(:,:,2)+phb_in(:,:,2)))/2./9.81

          !print *, 'ph_in(10,20,1)+phb_in(10,20,1)/9.81', (ph_in(10,20,1)+phb_in(10,20,1))/9.81
          !print *, 'ph_fl(10,20,1)', ph_fl(10,20,1)

          t_in(:,:,:) = (theta_in(:,:,:)+300.)*((pp_in(:,:,:)+pb_in(:,:,:))/100000.)**(287./1004.)

          !print *, 't_in(10,20,1)', t_in(10,20,1)

          psl_in(:,:) = (pp_in(:,:,1)+pb_in(:,:,1))*((t_in(:,:,1)*(1.+0.61*qv_in(:,:,1))+0.0065*ph_fl(:,:,1))/(t_in(:,:,1)*(1+0.61*qv_in(:,:,1))))**(9.81/(287.*0.0065))

          !print *, 'psl_in(10,20)', psl_in(10,20)

          !print *, 'SHAPE(psl_in)', SHAPE(psl_in)
          !data_in(:,:) = psl_in(:,:)

          !print *, 'data_in(10,20)', data_in(10,20)  

          pout = (/ 85000.,50000.,20000. /)

          p_in = pp_in+pb_in

           
          !DO np = 1,3     !SKn: could loop over heigts per variable or calculate t850, t500, t200 as individual variables 

          IF (height(ivar) == 850) THEN
            np = 1
          ELSE IF (height(ivar) == 500) THEN
            np = 2
          ELSE IF (height(ivar) == 200) THEN
            np = 3
          END IF

          print *,'np', np      

          DO i = 1,xfocus
            DO j = 1,yfocus
              DO nl = 1,40 - 1
                !print *, 'i,j,nl', i, j, nl
                !print *, 'pout(np)', pout(np)
                !print *, 'p_in(i,j,nl)',p_in(i,j,nl)
                IF (pout(np).lt.p_in(i,j,nl) .and. pout(np).gt.p_in(i,j,nl+1)) then
                  !print *,'hello'
                  slope = (t_in(i,j,nl)-t_in(i,j,nl+1))/ (p_in(i,j,nl)-p_in(i,j,nl+1))
                  !print *, 'slope, i,j,nl', slope, i, j, nl
                  t_out(i,j,np) = t_in(i,j,nl+1) + slope* (pout(np)-p_in(i,j,nl+1))

                END IF
              END DO
            END DO
          END DO
          !END DO
          !print *,'t_out(10,20,np)', t_out(10,20,np)
         
          data_in(:,:) = t_out(:,:,np)

        END IF



!       ***pr***
        IF (var_cmip(ivar) == "pr") THEN 

          pr_in(:,:) = ((rainnc_in(:,:,2) + rainc_in(:,:,2)) - (rainnc_in(:,:,1) + rainc_in(:,:,1)))/(3.*3600.) !unit [mm/3hr] to [kg m-2 s-1]

          data_in(:,:) = pr_in(:,:)

        END IF


!-------------------------------------------------------------------------------
! write data to NetCDF file

        print *,'write data to NetCDF file'
        print *,'fn_out',fn_out
        sts = NF90_OPEN( TRIM(DirOutputPostProRoot) // "/" // TRIM(pn_out) // "/" // TRIM(fn_out), NF90_WRITE, ncid )
        IF (sts/=0) EXIT
        !print *, 'NF90_OPEN',  sts
        sts = NF90_INQ_VARID(ncid, TRIM(var_cmip(ivar)), x_varid)
        !print *, 'NF90_INQ_VARID', ncid
        !print *, 'var_cmip(ivar)', var_cmip(ivar)
        !print *, 'x_varid', x_varid
        IF ( height(ivar) /= -999 ) THEN
          sts = NF90_PUT_VAR( ncid, x_varid, data_in(:,:),  &
            START=(/ 1, 1, 1, counter /), COUNT = (/ xfocus, yfocus, 1, 1 /) )
        ELSE
          sts = NF90_PUT_VAR( ncid, x_varid, data_in(:,:),  &
            START=(/ 1, 1, counter /), COUNT = (/ xfocus, yfocus, 1 /) )
        END IF

        !print *,'NF90_PUT_VAR', sts
        !print *, 'ncid', ncid
        !print *, 'x_varid', x_varid
        !print *, 'data_in(50:52,50:52)', data_in(50:52,50:52)
        sts = NF90_CLOSE(ncid)

        print *, pn_out//"/"//fn_out
        print *, TRIM(var_cmip(ivar)), xfocus, yfocus, counter, ncid, x_varid

!-------------------------------------------------------------------------------

      END DO !it i-time WRF indiv file loop

!-------------------------------------------------------------------------------
! next WRF file contains different number of output intervals

      DEALLOCATE(InVarDataRec)

      DEALLOCATE(InDateTimeYear)
      DEALLOCATE(InDateTimeMonth)
      DEALLOCATE(InDateTimeDay)
      DEALLOCATE(InDateTimeHour)

!-------------------------------------------------------------------------------

      PRINT *, "------------------------------------------------------------"
      CALL CPU_TIME(cpuTe)
      PRINT '("CPU timing for 1 WRF file (e.g. 1 month worth of data) = ",F6.3," sec")',cpuTe-cpuTs

    END DO !ifl - specific WRF input file, filelist loop

    InDateTimeYearPrev = 0

  END DO !nvars - variable loop

END DO !ifrq - different temporal aggregations

!===============================================================================

END PROGRAM ppWRFCMIP

!===============================================================================

SUBROUTINE generateFilelist

USE flhandling

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

END SUBROUTINE generateFilelist

!===============================================================================

SUBROUTINE CreateRefTimeArray(dt)

USE RefTimeVecs
USE NameListHandling

IMPLICIT NONE

CHARACTER (LEN = 3), INTENT(IN) :: dt

INTEGER :: i, j, k, l, counter
REAL :: dtDecDay
INTEGER :: tstotYYYY, tstotMM, tstotDD, tstotHH
INTEGER :: tetotYYYY, tetotMM, tetotDD, tetotHH
!!!INTEGER :: ndpy
INTEGER, DIMENSION(12) :: ndpm
INTEGER :: ndOverall = 31 ! these are the 31 days of Dec 1949
INTEGER :: ntspd ! number of timesteps per time-interval

PRINT *, "CreateRefTimeArray"
!PRINT *, dt

SELECT CASE (dt)
CASE ('3hr')
  dtDecDay = 0.125
  ntspd = 1.0 / dtDecDay
CASE DEFAULT
  PRINT *, "invalid time interval specified"
  STOP
END SELECT

! "tstot" contains the absolute starting point, 1949-12-01_00:00:00
READ( tstot, '(I4,1X,I2,1X,I2,1X,I2)' ) tstotYYYY, tstotMM, tstotDD, tstotHH
READ( tetot, '(I4,1X,I2,1X,I2,1X,I2)' ) tetotYYYY, tetotMM, tetotDD, tetotHH

! get the overall number of days within the considered timespan
DO i=tstotYYYY+1,tetotYYYY,1
  ndOverall = ndOverall + CheckForLeapyear( i )
END DO
!PRINT *, "number of days, overall = ", ndOverall

ALLOCATE( TimeRefArray( ndOverall*ntspd, 5 ) ) ! index, y, m, d, h         y,x
!PRINT *, "size and shape of the TimRefArray = ", SIZE(TimeRefArray), &
!  SHAPE(TimeRefArray)

! fill up the decimal days
DO i=0,ndOverall*ntspd-1,1
  TimeRefArray( i+1, 1 ) = i * dtDecDay
END DO

! handle the Dec 1949, too complicated to have this in the upcoming loop
! overall start is at 1949-12-01_00:00:00
TimeRefArray( 1:31*8, 2 ) = 1949.
TimeRefArray( 1:31*8, 3 ) = 12.
DO i=1,31,1
  TimeRefArray( i*8-7:i*8, 4 ) = i
  TimeRefArray( i*8-7:i*8, 5 ) = (/(j, j=0, 21, 3)/) !00  03 06 09 12 15 18 21
END DO

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

      TimeRefArray( 31*8 + counter*ntspd-7 : 31*8 + counter*ntspd , 2) = i
      TimeRefArray( 31*8 + counter*ntspd-7 : 31*8 + counter*ntspd , 3) = j
      TimeRefArray( 31*8 + counter*ntspd-7 : 31*8 + counter*ntspd , 4) = k
      TimeRefArray( 31*8 + counter*ntspd-7 : 31*8 + counter*ntspd , 5) = (/(l, l=0, 21, 3)/)

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
