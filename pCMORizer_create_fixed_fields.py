# -*- coding: utf-8 -*-                                                         

""" Part of CMORization: Generate te fx netCDF files, CORDEX-FPSCONV specs. """         

import os

import numpy as np
import xarray as xr
import f90nml

__author__ = "Heimo TRUHETZ, HTr, Wegener-Center/Uni Graz"
__copyright__ = "Copyright 2023"
__credits__ = [""]
__license__ = "MIT"
__version__ = "20231116"
__maintainer__ = "Klaus GOERGEN, KGo"
__email__ = "k.goergen@fz-juelich.de"
__status__ = "Release"

################################################################################
# read CMORizer namelist and static field raw data
# tool is entirely controlled via CMORizer runctrl namelist
################################################################################

nml = f90nml.read('runctrl.current.nml_template_d01_BB')
#nml = f90nml.read('runctrl.current.nml_template_d02_BB')
#nml = f90nml.read('runctrl.current.nml_template_d01_CA')
#nml = f90nml.read('runctrl.current.nml_template_d02_CA')
#nml = f90nml.read('runctrl.current.nml_template_d01_DA')
#nml = f90nml.read('runctrl.current.nml_template_d02_DA')

xoffset = nml['model_config']['xoffset']
xfocus = nml['model_config']['xfocus']
yoffset = nml['model_config']['yoffset']
yfocus = nml['model_config']['yfocus']

DS = xr.open_dataset(nml['static_fields']['pnfngeo'])
POLE_LAT = DS.attrs['POLE_LAT']
POLE_LON = DS.attrs['POLE_LON']
if POLE_LON > 0.0:
    POLE_LON = POLE_LON - 180.0

################################################################################
# orog, Surface Altitude, [m]
################################################################################

# r0i0p0 is not mandatory and less consistent
dir_name = nml['globalvars']['project_id'] + '/' + nml['globalvars']['product'] + '/' + \
    nml['globalvars']['cordex_domain'] + '/' + nml['globalvars']['institute_id'] + '/' + \
    nml['globalvars']['driving_model_id'] + '/' + nml['globalvars']['experiment_id'] + '/' + \
    nml['globalvars']['driving_model_ensemble_member'] + '/' + nml['globalvars']['model_id'] + '/' + \
    nml['globalvars']['rcm_version_id'] + '/' + 'fx' + '/'

print(dir_name)

orog = DS[['HGT_M','XLAT_M','XLONG_M','CLAT','CLONG','MAPFAC_M','LANDUSEF']].isel(west_east=slice(xoffset,xoffset+xfocus),
        south_north=slice(yoffset,yoffset+yfocus)).rename({'HGT_M':'orog', 'XLAT_M':'lat', 'XLONG_M':'lon', 
            'CLAT':'rlat', 'CLONG':'rlon'}).squeeze()

ds = xr.Dataset(
        data_vars=dict(
            orog=(["rlat", "rlon"],orog.orog.values,{ 
                "standard_name": "surface_altitude",
                "long_name": "Surface Altitude",
                "units": "m",
                "coordinates": "lat lon",
                "grid_mapping": "rotated_pole",
                "missing_value": np.float32(1.e+20),
                "_FillValue": 1.e+20
                }
            ),
            rlon=(["rlon"],np.double(orog.rlon.values[0,:].flatten()),{
                "standard_name": "grid_longitude",
                "long_name": "Longitude in rotated pole grid",
                "units": "degrees",
                "axis": "X"
                }
            ),
            rlat=(["rlat"],np.double(orog.rlat.values[:,0].flatten()),{
                "standard_name": "grid_latitude",
                "long_name": "Latitude in rotated pole grid",
                "units": "degrees",
                "axis": "Y"
                 }
            )
        ),
        coords=dict(
            lon=(["rlat", "rlon"],np.double(orog.lon.values),{
                "standard_name": "longitude",
                "long_name": "Longitude",
                "units": "degrees_east"
                }
            ),
            lat=(["rlat", "rlon"],np.double(orog.lat.values),{
                "standard_name": "latitude",
                "long_name": "Latitude",
                "units": "degrees_north"
                }
            )
        ),
        attrs={
            "Conventions": nml['globalvars']['conventions'],
            "conventionsURL": nml['globalvars']['conventionsURL'],
            "contact": nml['globalvars']['contact'],
            "creation_date": os.popen("date -u +%Y-%m-%d-T%H:%M:%SZ").read()[0:21],
            "experiment": nml['globalvars']['experiment'],
            "experiment_id": nml['globalvars']['experiment_id'],
            "driving_experiment": nml['globalvars']['driving_experiment'],
            "driving_model_id": nml['globalvars']['driving_model_id'],
            "driving_model_ensemble_member": nml['globalvars']['driving_model_ensemble_member'],
            "driving_experiment_name": nml['globalvars']['driving_experiment_name'],
            "frequency": 'fx',
            "institution": nml['globalvars']['institution'],
            "institute_id": nml['globalvars']['institute_id'],
            "model_id": nml['globalvars']['model_id'],
            "rcm_version_id": nml['globalvars']['rcm_version_id'],
            "project_id": nml['globalvars']['project_id'],
            "CORDEX_domain": nml['globalvars']['CORDEX_domain'],
            "product": nml['globalvars']['product'],
            "references": nml['globalvars']['references'],
            "tracking_id": os.popen("uuidgen").read()[0:36],
            "title": nml['globalvars_additional']['title'],
            "comment": nml['globalvars_additional']['comment'],
            "institute_run_id": nml['globalvars_additional']['institute_run_id'],
            "nesting_levels": nml['globalvars_additional']['nesting_levels'],
            "comment_nesting": nml['globalvars_additional']['comment_nesting'],
            "comment_1nest": nml['globalvars_additional']['comment_1nest'],
            "comment_2nest": nml['globalvars_additional']['comment_2nest']
            }
        )

f_name = 'orog_' + nml['globalvars']['cordex_domain'] + '_' + nml['globalvars']['driving_model_id'] + '_' + \
    nml['globalvars']['experiment_id'] + '_' + nml['globalvars']['driving_model_ensemble_member'] + '_' + nml['globalvars']['model_id'] + '_' + \
    nml['globalvars']['rcm_version_id'] + '_' + 'fx' + '.nc'

print(f_name)

os.system("mkdir -p " + dir_name + 'orog/')

ds.to_netcdf(dir_name + 'orog/' + f_name, mode = 'w', format = 'NETCDF4_CLASSIC', encoding = {
    'orog': {'zlib':True, 'complevel':1},
    'rlon': {'_FillValue': None},
    'rlat': {'_FillValue': None},
    'lon' : {'_FillValue': None},
    'lat' : {'_FillValue': None}
    #'rotated_pole': {'dtype':'str'} 
    })

ds.close()

################################################################################
# areacella, Atmosphere Grid-Cell Area, [m2]
################################################################################

ds = ds.rename({'orog':'areacella'})

DX = orog.attrs['DX']  # grid spacing in m
DY = orog.attrs['DY']  # grid spacing in m

ds.areacella.values = np.float32(DX*DY/orog.MAPFAC_M.values)

ds.areacella.attrs = { 
    "standard_name": "cell_area",
    "long_name": "Atmosphere Grid-Cell Area",
    "units": "m2",
    "coordinates": "lon lat",
    "grid_mapping": "rotated_pole",
    "missing_value": np.float32(1.e+20),
    "_FillValue": 1.e+20
    }

f_name = 'areacella_' + nml['globalvars']['cordex_domain'] + '_' + nml['globalvars']['driving_model_id'] + '_' + \
    nml['globalvars']['experiment_id'] + '_' + nml['globalvars']['driving_model_ensemble_member'] + '_' + nml['globalvars']['model_id'] + '_' + \
    nml['globalvars']['rcm_version_id'] + '_' + 'fx' + '.nc'

print(f_name)

os.system("mkdir -p " + dir_name + 'areacella/')

ds.to_netcdf(dir_name + 'areacella/' + f_name, mode = 'w', format = 'NETCDF4_CLASSIC', encoding = {
    'areacella': {'zlib':True, 'complevel':1},
    'rlon': {'_FillValue': None},
    'rlat': {'_FillValue': None},
    'lon' : {'_FillValue': None},
    'lat' : {'_FillValue': None}
#    'rotated_pole': {'dtype':'str'} 
    })

ds.close()

################################################################################
# sftlf, Land Area Fraction, [%]
################################################################################

ds = ds.rename({'areacella':'sftlf'})

landseamask = np.absolute(np.float32(orog.LANDUSEF.values[16,:,:])-1.)
riverslakesmask = np.absolute(np.float32(orog.LANDUSEF.values[20,:,:])-1.)
ds.sftlf.values = np.float32((landseamask * riverslakesmask) * 100.)

ds.sftlf.attrs = {
    "standard_name": "land_area_fraction",
    "long_name": "Land Area Fraction",
    "units": "%",
    "coordinates": "lon lat",
    "grid_mapping": "rotated_pole",
    "missing_value": np.float32(1.e+20),
    "_FillValue": 1.e+20
    }

f_name = 'sftlf_' + nml['globalvars']['cordex_domain'] + '_' + nml['globalvars']['driving_model_id'] + '_' + \
    nml['globalvars']['experiment_id'] + '_' + nml['globalvars']['driving_model_ensemble_member'] + '_' + nml['globalvars']['model_id'] + '_' + \
    nml['globalvars']['rcm_version_id'] + '_' + 'fx' + '.nc'

print(f_name)

os.system("mkdir -p " + dir_name + 'sftlf/')

ds.to_netcdf(dir_name + 'sftlf/' + f_name, mode = 'w', format = 'NETCDF4_CLASSIC', encoding = {
    'sftlf': {'zlib':True, 'complevel':1},
    'rlon': {'_FillValue': None},
    'rlat': {'_FillValue': None},
    'lon' : {'_FillValue': None},
    'lat' : {'_FillValue': None}
#    'rotated_pole': {'dtype':'str'} 
    })

ds.close()

################################################################################
# sftgif, Fraction of Grid Cell Covered with Glacier, [%]
################################################################################

ds = ds.rename({'sftlf':'sftgif'})

ds.sftgif.values = np.float32(orog.LANDUSEF.values[14,:,:])*100.

ds.sftgif.attrs = {
    "standard_name": "land_ice_area_fraction",
    "long_name": "Fraction of Grid Cell Covered with Glacier",
    "units": "%",
    "coordinates": "lon lat",
    "grid_mapping": "rotated_pole",
    "missing_value": np.float32(1.e+20),
    "_FillValue": 1.e+20
    }

f_name = 'sftgif_' + nml['globalvars']['cordex_domain'] + '_' + nml['globalvars']['driving_model_id'] + '_' + \
    nml['globalvars']['experiment_id'] + '_' + nml['globalvars']['driving_model_ensemble_member'] + '_' + nml['globalvars']['model_id'] + '_' + \
    nml['globalvars']['rcm_version_id'] + '_' + 'fx' + '.nc'

print(f_name)

os.system("mkdir -p " + dir_name + 'sftgif/')

ds.to_netcdf(dir_name + 'sftgif/' + f_name, mode = 'w', format = 'NETCDF4_CLASSIC', encoding = {
    'sftgif': {'zlib':True, 'complevel':1},
    'rlon': {'_FillValue': None},
    'rlat': {'_FillValue': None},
    'lon' : {'_FillValue': None},
    'lat' : {'_FillValue': None}
#    'rotated_pole': {'dtype':'str'} 
    })

ds.close()

################################################################################
# mrsofc, Capacity of Soil to Store Water, [kg m-2]
################################################################################

################################################################################
# rootd, Maximum Root Depth, [m]
################################################################################
