# Darktable Reverse Geocode

## Preface

I very often track my movements with a GPS logger ,and during rawfile import, I write those coordinates into the raw file by means of exiftool. Now coordinates are nice and allow to see the image location on a map, but I want to see the postal-like address in the metadata of the image.

The openstreetmap-Nominatim servers allow reverse geocoding without all the privacy implications of google maps at al., and there is a very nice python module to query nominatim with a pair of coordinates and get back address data.

## Implementation
Darktable Reverse Geocode uses two scripts, a lua script to interface with darktable, and a python script to do the communication with Nominatim and the formatting of the tagstring to be added to the image metadata in darktable.

### auto_reverse_geocode.lua

This script sets itself up to run after each single import of an image, alternatively a keyboard shortcut can be registered.

In the preferences dialog of darktable, the name and location of the reverse-geocoder python script can be set. 

### reverse-geocode-nominatim.py
This script does the communication with the Nominatim server. It relies on the geopy framework. In the current form, the pandas library is loaded as well

It is called with a coordinate pair as arguments and returns a lightroom styled tag string. When called with the argument -t (for testing), it should return two text lines:
'''where|Italy|Emilia-Romagna|Bologna|Malpighi
Malpighi, Saragozza-Porto, Bologna, Emilia-Romagna, 40121-40141, Italy'''

## TODO
  * Settings dialogue for the lua part
  * Cleanup of the python script: Move development and test relevant parts into a dedicated module.
