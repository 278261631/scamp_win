"""
generate_test_catalogs.py - Generate test FITS catalogs for SCAMP testing

Creates two simulated FITS-LDAC format catalogs with known astrometric
offsets for testing SCAMP's alignment capabilities.
"""

import numpy as np
import os
import struct

try:
    from astropy.io import fits
    from astropy.table import Table
except ImportError:
    print("ERROR: astropy package is required.")
    print("Install with: pip install astropy")
    exit(1)

def create_ldac_catalog(filename, ra_center, dec_center, rotation_deg, 
                        n_stars=100, pixel_scale=0.2, image_size=2048):
    """
    Create a simulated FITS-LDAC catalog for SCAMP testing.
    
    Parameters:
    -----------
    filename : str
        Output FITS filename
    ra_center : float
        Center RA in degrees
    dec_center : float
        Center Dec in degrees
    rotation_deg : float
        Rotation angle in degrees
    n_stars : int
        Number of stars to simulate
    pixel_scale : float
        Pixel scale in arcsec/pixel
    image_size : int
        Image size in pixels
    """
    
    np.random.seed(42 + hash(filename) % 1000)
    
    # Generate random star positions in image coordinates
    x_image = np.random.uniform(100, image_size - 100, n_stars)
    y_image = np.random.uniform(100, image_size - 100, n_stars)
    
    # Generate random magnitudes (realistic distribution)
    mag_auto = np.random.uniform(14, 20, n_stars)
    mag_err = 0.02 * 10 ** (0.2 * (mag_auto - 15))
    
    # Generate flux values (arbitrary units)
    flux_auto = 10 ** ((25 - mag_auto) / 2.5)
    flux_err = flux_auto * mag_err / 1.086
    
    # Generate shape parameters (FWHM, ellipticity)
    fwhm_image = np.random.uniform(2.5, 4.5, n_stars)
    a_world = np.random.uniform(0.2, 0.5, n_stars)
    b_world = a_world * np.random.uniform(0.7, 1.0, n_stars)
    theta_world = np.random.uniform(0, 180, n_stars)
    
    # Generate flags (mostly 0, some with minor issues)
    flags = np.random.choice([0, 0, 0, 0, 0, 0, 0, 1, 2], n_stars)
    
    # Calculate errors on positions
    errx_win = np.random.uniform(0.02, 0.1, n_stars)
    erry_win = np.random.uniform(0.02, 0.1, n_stars)
    errtheta_win = np.random.uniform(10, 45, n_stars)
    
    # Calculate RA/Dec from pixel coordinates
    # Simple tangent projection
    crpix1 = image_size / 2
    crpix2 = image_size / 2
    cd1_1 = -pixel_scale / 3600.0
    cd1_2 = 0.0
    cd2_1 = 0.0
    cd2_2 = pixel_scale / 3600.0
    
    # Apply rotation
    cos_r = np.cos(np.radians(rotation_deg))
    sin_r = np.sin(np.radians(rotation_deg))
    
    x_rel = x_image - crpix1
    y_rel = y_image - crpix2
    
    # World coordinates (RA, Dec in degrees)
    ra = ra_center + (cd1_1 * cos_r - cd1_2 * sin_r) * x_rel + (cd1_1 * sin_r + cd1_2 * cos_r) * y_rel
    dec = dec_center + (cd2_1 * cos_r - cd2_2 * sin_r) * x_rel + (cd2_1 * sin_r + cd2_2 * cos_r) * y_rel
    
    # Create primary HDU (empty)
    primary_hdu = fits.PrimaryHDU()
    
    # Create image header for LDAC_IMHEAD
    header = fits.Header()
    header['SIMPLE'] = 'T'
    header['BITPIX'] = -32
    header['NAXIS'] = 2
    header['NAXIS1'] = image_size
    header['NAXIS2'] = image_size
    header['CTYPE1'] = 'RA---TAN'
    header['CTYPE2'] = 'DEC--TAN'
    header['CRVAL1'] = ra_center
    header['CRVAL2'] = dec_center
    header['CRPIX1'] = image_size / 2
    header['CRPIX2'] = image_size / 2
    header['CD1_1'] = -pixel_scale / 3600.0 * cos_r
    header['CD1_2'] = pixel_scale / 3600.0 * sin_r
    header['CD2_1'] = -pixel_scale / 3600.0 * sin_r
    header['CD2_2'] = -pixel_scale / 3600.0 * cos_r
    header['CDELT1'] = -pixel_scale / 3600.0
    header['CDELT2'] = pixel_scale / 3600.0
    header['CROTA2'] = rotation_deg
    header['EQUINOX'] = 2000.0
    header['EXPTIME'] = 300.0
    header['FILTER'] = 'R'
    header['MAGZERO'] = 25.0
    header['AIRMASS'] = 1.2
    header['PHOT_C'] = 25.0
    header['PHOT_K'] = 0.1
    header['OBJECT'] = 'TEST_FIELD'
    header['TELESCOP'] = 'TEST'
    header['INSTRUME'] = 'TEST_CAM'
    header['QRUNID'] = 1
    
    # Convert header to string
    header_str = header.tostring(sep='', endcard=True, padding=True)
    
    # Create LDAC_IMHEAD extension
    imhead_col = fits.Column(name='Field Header Card', format='2880A', 
                              array=[header_str[:2880]])
    imhead_hdu = fits.BinTableHDU.from_columns([imhead_col])
    imhead_hdu.name = 'LDAC_IMHEAD'
    
    # Create LDAC_OBJECTS extension with star catalog
    objects_table = Table()
    objects_table['NUMBER'] = np.arange(1, n_stars + 1, dtype=np.int32)
    objects_table['XWIN_IMAGE'] = x_image.astype(np.float64)
    objects_table['YWIN_IMAGE'] = y_image.astype(np.float64)
    objects_table['ERRAWIN_IMAGE'] = errx_win.astype(np.float64)
    objects_table['ERRBWIN_IMAGE'] = erry_win.astype(np.float64)
    objects_table['ERRTHETAWIN_IMAGE'] = errtheta_win.astype(np.float64)
    objects_table['MAG_AUTO'] = mag_auto.astype(np.float32)
    objects_table['MAGERR_AUTO'] = mag_err.astype(np.float32)
    objects_table['FLUX_AUTO'] = flux_auto.astype(np.float32)
    objects_table['FLUXERR_AUTO'] = flux_err.astype(np.float32)
    objects_table['FWHM_IMAGE'] = fwhm_image.astype(np.float32)
    objects_table['A_WORLD'] = a_world.astype(np.float32)
    objects_table['B_WORLD'] = b_world.astype(np.float32)
    objects_table['THETA_WORLD'] = theta_world.astype(np.float32)
    objects_table['FLAGS'] = flags.astype(np.int32)
    objects_table['X_WORLD'] = ra.astype(np.float64)
    objects_table['Y_WORLD'] = dec.astype(np.float64)
    
    objects_hdu = fits.BinTableHDU(objects_table)
    objects_hdu.name = 'LDAC_OBJECTS'
    
    # Create HDU list and write to file
    hdul = fits.HDUList([primary_hdu, imhead_hdu, objects_hdu])
    hdul.writeto(filename, overwrite=True)
    
    print(f"Created: {filename}")
    print(f"  Stars: {n_stars}")
    print(f"  Center: RA={ra_center:.4f} deg, Dec={dec_center:.4f} deg")
    print(f"  Rotation: {rotation_deg:.2f} deg")
    print(f"  Pixel scale: {pixel_scale} arcsec/pixel")
    print(f"  Image size: {image_size}x{image_size} pixels")
    
    return filename

def main():
    """Generate two test catalogs with known offsets."""
    
    print("=" * 60)
    print("SCAMP Test Catalog Generator")
    print("=" * 60)
    print()
    
    # Create test_data directory
    os.makedirs('test_data', exist_ok=True)
    
    # Catalog 1: Reference catalog (no rotation)
    # Centered at RA=180.0, Dec=0.0
    print("Creating catalog 1 (reference)...")
    create_ldac_catalog(
        filename='test_data/test_cat1.fits',
        ra_center=180.0,
        dec_center=0.0,
        rotation_deg=0.0,
        n_stars=150,
        pixel_scale=0.2,
        image_size=2048
    )
    print()
    
    # Catalog 2: Shifted and rotated catalog
    # Shifted by ~30 arcsec in RA and ~20 arcsec in Dec, rotated 2 degrees
    print("Creating catalog 2 (shifted/rotated)...")
    create_ldac_catalog(
        filename='test_data/test_cat2.fits',
        ra_center=180.00833,  # ~30 arcsec shift
        dec_center=0.00556,   # ~20 arcsec shift
        rotation_deg=2.0,
        n_stars=150,
        pixel_scale=0.2,
        image_size=2048
    )
    print()
    
    print("=" * 60)
    print("Test catalogs created successfully!")
    print("=" * 60)
    print()
    print("Files created:")
    print("  test_data/test_cat1.fits - Reference catalog")
    print("  test_data/test_cat2.fits - Shifted/rotated catalog")
    print()
    print("Expected alignment:")
    print("  RA offset: ~30 arcsec")
    print("  Dec offset: ~20 arcsec")
    print("  Rotation: ~2 degrees")

if __name__ == '__main__':
    main()
