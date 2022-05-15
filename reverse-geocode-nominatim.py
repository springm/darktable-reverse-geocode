#!/usr/bin/python3

import argparse
import json
import re
import sys
import time
import pandas as pd
from collections import namedtuple
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter

locator = Nominatim(user_agent='darktableReverseGeocoder', timeout=30)
rgeocode = RateLimiter(locator.reverse, min_delay_seconds=1)

# only for testing. nominatim answers get loaded from locale json file
def lrgeocode(coordinates, *args,**kwargs):
    with open('nominatim_location.json','r+') as file:
        file_data = json.load(file)
        #return( { "raw" : file_data["locations"][coordinates] })
        dictionary = { "raw" : file_data["locations"][coordinates] }
        object_name = namedtuple("location", dictionary.keys())(*dictionary.values())
        return object_name

def get_state(location):
    address = location.get("address")
    s = ( address.get("state") or address.get("territory") or address.get("state_district")
          or address.get("region") or address.get("district") or address.get("province")
          or address.get("archipelago") or address.get("island") or address.get("county") )
    if not s:
        ss = location.get('display_name')
        e = ss.split(', ')
        if len(e)>5:
            s = e[-3]
    return s

def get_city(location):
    address = location.get("address")
    s = ( address.get("city") or address.get("town") or address.get("district")
          or address.get("municipality") or address.get("village") or address.get("neighbourhood") )
    if not s and not get_state(location) == address.get("county"):
        s = address.get("county")
    return s

def get_road(location):
    address = location.get("address")
    s = ( address.get("road") or address.get("neighbourhood") or address.get("locality")
          or address.get("suburb") or address.get("hamlet") or address.get("man_made")
          or address.get("municipality") )
    if not s and not get_city(location) == address.get("village"):
        s =  address.get("village")
    if address.get("country_code") == "af":
        s = address.get("village")
    return s

def simplify_display_address(s):
    e = s.split(', ')
    if len(e)>3:
        last = e.pop()
        e.pop()
        e.append(last)
        return(", ".join(e[1:]))
    else:
        return s

def testrun():    
    df = pd.read_csv('capitals.csv')
    for index, row in df.iterrows():
        if row['Country'] == 'Antarctica':
            continue
        #    location = rgeocode(f"{row['Latitude']} {row['Longitude']}", language='en')
        location = lrgeocode(f"{row['Latitude']} {row['Longitude']}", language='en')
        country = location.raw.get('address').get('country')
        print(get_road( location.raw ),end=", ")
        print(get_city( location.raw ),end=", ")
        print(get_state( location.raw ),end=", ")
        print(country)
        print(simplify_display_address(location.raw.get('display_name'))) 
        print("")

# ------------------------------------------------------------- main ---

parser = argparse.ArgumentParser(description='Reverse Geocoder for Nominatim')

parser.add_argument('coords', 
                    nargs='*', 
                    help='specify 2 or 0 coordinates'
)
parser.add_argument('--lang', dest='language', type=str, help='Preferred language for address information')
parser.add_argument('--prefix', dest='locstring_prefix', type=str,
                    help='prefix for hierarchical location information')
parser.add_argument('--test', dest='test', type=str, help='Argument to trigger test run')
parser.add_argument("--italy", dest='italy', default=False, action="store_true",
                    help="Mock argument to use Italian test coordinates")

args = parser.parse_args()
coords = ""
if not args.italy and not args.test and len(args.coords) != 2:
    parser.error('expected 2 coordinate arguments')
else:
    coords = " ".join(args.coords)

if args.test:
    testrun()
else:
    location = {}
    if args.italy:
         location = rgeocode("41.902784 12.496366", language=args.language)
    else:
        location = rgeocode(coords, language=args.language)
    s = f"{args.locstring_prefix}|%s|%s|%s|%s\n%s" % ( location.raw.get('address').get('country'),
                                    get_state( location.raw ),
                                    get_city( location.raw ),
                                    get_road( location.raw ),
                                    location.raw.get('display_name') )
    s = re.sub('^\|+', '', s)
    s = re.sub('\|+', '|', s)
    print(f"location: {s}", file=sys.stderr)
    print(s)

# local variables:
# compile-command: "python3 ./reverse_nominatim7.py -lang de -prefix where 44.494135036005,11.341755720982"
# end:

