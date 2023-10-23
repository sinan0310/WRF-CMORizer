import numpy as np
import xarray as xa
import cftime
import sys
import os
import f90nml
from glob import glob
#from pyproj import Geod

# read namelist file
nml = f90nml.read('runctrl.current.nml_template_d02_DA')

xoffset = nml['model_config']['xoffset']
xfocus = nml['model_config']['xfocus']
yoffset = nml['model_config']['yoffset']
yfocus = nml['model_config']['yfocus']

DS = xa.open_dataset(nml['static_fields']['pnfngeo'])
POLE_LAT = DS.attrs['POLE_LAT']
POLE_LON = DS.attrs['POLE_LON']
if POLE_LON > 0.0:
    POLE_LON = POLE_LON - 180.0

# orog

# file name

dir_name = nml['globalvars']['project_id'] + '/' + nml['globalvars']['product'] + '/' + \
    nml['globalvars']['cordex_domain'] + '/' + nml['globalvars']['institute_id'] + '/' + \
    nml['globalvars']['driving_model_id'] + '/' + nml['globalvars']['experiment_id'] + '/' + \
    'r0i0p0' + '/' + nml['globalvars']['model_id'] + '/' + \
    nml['globalvars']['rcm_version_id'] + '/' + 'fx' + '/'


orog = DS[['HGT_M','XLAT_M','XLONG_M','CLAT','CLONG','MAPFAC_M']].isel(west_east=slice(xoffset,xoffset+xfocus),
        south_north=slice(yoffset,yoffset+yfocus)).rename({'HGT_M':'orog', 'XLAT_M':'lat', 'XLONG_M':'lon', 
            'CLAT':'rlat', 'CLONG':'rlon'}).squeeze()

#corners = DS[['XLAT_C','XLONG_C']].isel(west_east_stag=slice(xoffset,xoffset+xfocus+1), 
#        south_north_stag=slice(yoffset,yoffset+yfocus+1)).squeeze()

#U = DS[['XLAT_U','XLONG_U']].isel(west_east_stag=slice(xoffset,xoffset+xfocus+1), 
#        south_north=slice(yoffset,yoffset+yfocus)).squeeze()
#V = DS[['XLAT_V','XLONG_V']].isel(west_east=slice(xoffset,xoffset+xfocus), 
#        south_north_stag=slice(yoffset,yoffset+yfocus+1)).squeeze()


ds = xa.Dataset(
        data_vars=dict(
            orog=(["rlat", "rlon"],orog.orog.values,{ 
                "standard_name": "surface_altitude",
                "long_name": "Surface Altitude",
                "units": "m",
                "coordinates": "lon lat",
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
            "tracking_id": os.popen("uuidgen -t").read()[0:36],
            "title": nml['globalvars_additional']['title'],
            "comment": nml['globalvars_additional']['comment'],
            "nesting_levels": nml['globalvars_additional']['nesting_levels'],
            "comment_nesting": nml['globalvars_additional']['comment_nesting'],
            "comment_1nest": nml['globalvars_additional']['comment_1nest'],
            "comment_2nest": nml['globalvars_additional']['comment_2nest']
            }
        )

 
f_name = 'orog_' + nml['globalvars']['cordex_domain'] + '_' + nml['globalvars']['driving_model_id'] + '_' + \
    nml['globalvars']['experiment_id'] + '_' + 'r0i0p0' + '_' + nml['globalvars']['model_id'] + '_' + \
    nml['globalvars']['rcm_version_id'] + '_' + 'fx' + '.nc'

os.system("mkdir -p " + dir_name + 'orog/')

ds.to_netcdf(dir_name + 'orog/' + f_name, mode = 'w', format = 'NETCDF4_CLASSIC', encoding = {
    'orog': {'zlib':True, 'complevel':1},
    'rlon': {'_FillValue': None},
    'rlat': {'_FillValue': None},
    'lon' : {'_FillValue': None},
    'lat' : {'_FillValue': None}
#    'rotated_pole': {'dtype':'str'} 
    })

ds.close()

# areacella

ds = ds.rename({'orog':'areacella'})

#print(ds)

DX = orog.attrs['DX']   # grid spacing in m
DY = orog.attrs['DY']   # grid spacing in m

ds.areacella.values = np.float32(DX*DY/orog.MAPFAC_M.values)

# modify attributes
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
    nml['globalvars']['experiment_id'] + '_' + 'r0i0p0' + '_' + nml['globalvars']['model_id'] + '_' + \
    nml['globalvars']['rcm_version_id'] + '_' + 'fx' + '.nc'

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


