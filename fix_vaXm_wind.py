import xarray as xr
import numpy as np
import sys
import numpy as np
import os
import shutil

def correct_va_wind_component(ua_file_path, va_wrong_file_path, geo_em_path):
    """
    Corrects the va component at the specified height (m). 
    It uses ua from one file and va_wrong from another, and corrects va 
    using the rotation info from the geo_em file (COSALPHA and SINALPHA), 
    masking out the relaxation zone as the geo_em file give the complete domain.

    Parameters:
        ua_file (str): Path to the postprocessed NetCDF file with correct ua.
        va_wrong_file (str): Path to the file with incorrect va.
        geo_em (str): Path to the geo_em file.
        
    Returns:
        va_wrong_file with corrected va_values
        
    To run:
        python fix_vaXm_wind.py ua_file va_wrong_file geo_em
    """

    # Load ua from correct file
    ds_ua = xr.open_dataset(ua_file_path)
    dirname, basename = os.path.split(ua_file_path)
    ua_var = basename.split("_", 1)
    ua = ds_ua[f'{ua_var[0]}']
    lat = ds_ua['lat']
    lon = ds_ua['lon']

    # Load va_wrong from the broken file
    ds_va = xr.open_dataset(va_wrong_file_path)
    dirname, basename = os.path.split(va_wrong_file_path)
    va_var = basename.split("_", 1)
    va_wrong = ds_va[f'{va_var[0]}']

    # Load geo_em fields
    ds_geo = xr.open_dataset(geo_em_path)
    sinalpha = ds_geo['SINALPHA'].squeeze()
    cosalpha = ds_geo['COSALPHA'].squeeze()
    xlat = ds_geo['XLAT_M'].squeeze()
    xlon = ds_geo['XLONG_M'].squeeze()

    # Find overlapping region between geo_em and postprocessed domain
    lat_min, lat_max = float(lat.min()), float(lat.max())
    lon_min, lon_max = float(lon.min()), float(lon.max())

    mask_lat = (xlat >= lat_min) & (xlat <= lat_max)
    mask_lon = (xlon >= lon_min) & (xlon <= lon_max)
    domain_mask = mask_lat & mask_lon

    idx_i, idx_j = np.where(domain_mask)
    i_min, i_max = idx_i.min(), idx_i.max()
    j_min, j_max = idx_j.min(), idx_j.max()

    # Slice SINALPHA and COSALPHA to match the postprocessed domain
    sinalpha_cut = sinalpha.isel(south_north=slice(i_min, i_max + 1),
                                 west_east=slice(j_min, j_max + 1))
    cosalpha_cut = cosalpha.isel(south_north=slice(i_min, i_max + 1),
                                 west_east=slice(j_min, j_max + 1))
                                 
    # Fill the array - from 2D to 3D
    sinalpha = np.broadcast_to(sinalpha_cut, va_wrong.shape)
    cosalpha = np.broadcast_to(cosalpha_cut, va_wrong.shape)

    # Compute corrected components
    denom = sinalpha + cosalpha
    uava2 = va_wrong / denom
    uava1 = (ua + va_wrong * sinalpha / denom) / cosalpha
    va_corrected = uava1 * sinalpha + uava2 * cosalpha
    
    return va_corrected


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python fix_vWind_interpolation.py <ua_file> <va_wrong_file> <geo_em_file>")
        sys.exit(1)

    ua_file = sys.argv[1]
    va_wrong_file = sys.argv[2]
    geo_em_file = sys.argv[3]

    # Fix va component
    va_fixed = correct_va_wind_component(ua_file, va_wrong_file, geo_em_file)
    
    # Backup the wrong file. Comment out if not necessary
    dirname, basename = os.path.split(va_wrong_file)
    va_var = basename.split("_", 1)
    if len(va_var) == 2:
        new_basename = f"{va_var[0]}wrong_{va_var[1]}"
    else:
        new_basename = f"{basename}.backup"  

    backup_path = os.path.join(dirname, new_basename)
    shutil.copy(va_wrong_file, backup_path)
    print(f"📝 Backed up original file to: {backup_path}")
    
    # Replace values directly in the existing NetCDF file
    ds_va = xr.open_dataset(va_wrong_file)
    ds_va.attrs['comment1'] = f'Derotation of {va_var[0]} corrected.'  # Add comment that the file if fixed. If not necessary commnet it out
    ds_va[f'{va_var[0]}'].data[:] = va_fixed.data                      # Replacing the values
    os.remove(va_wrong_file)                                           # Remove the original file to avoid permission problems
    ds_va.to_netcdf(va_wrong_file)                                     # Save to the original netcdf file
    print(f"✅ Corrected va written to: {va_wrong_file}")
    ds_va.close()
