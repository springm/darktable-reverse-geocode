#!/usr/bin/python3

from collections import namedtuple
from geopy.geocoders import Nominatim
import json
import re
import sys
import time
import pandas as pd
from geopy.extra.rate_limiter import RateLimiter

locator = Nominatim(user_agent='darktableReverseGeocoder', timeout=30)
rgeocode = RateLimiter(locator.reverse, min_delay_seconds=1)

cmd_arg = " ".join(sys.argv[1:])

# nur zum Test: lädt nominatim-Antworten aus lokaler JSON-Datei
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
if cmd_arg in ["-t", "-test", "test"]:
    testrun()
else:
    location = {}
    if cmd_arg in ["United Kingdom", "Germany", "Italy"]:
        location = lrgeocode("41.902784 12.496366", language='en')
    else:
        location = rgeocode(cmd_arg, language='en')
    s = "where|%s|%s|%s|%s\n%s" % ( location.raw.get('address').get('country'),
                                    get_state( location.raw ),
                                    get_city( location.raw ),
                                    get_road( location.raw ),
                                    location.raw.get('display_name') )
    s = re.sub('^\|+', '', s)
    s = re.sub('\|+', '|', s)
    print(f"location: {s}", file=sys.stderr)
    print(s)
    # lon = sys.argv[1]
# lat = sys.argv[2]



# if lon == '-test':
#     coordinates = "45.4266424285667 12.3380322857028"
# else:
#     coordinates = lon + ' ' + lat

# location = locator.reverse(coordinates, language='en')
# #city = location["address"]["city"]
# print(location)

   # if city == nil then city = location["address"]["town"] end
   # local state = location["address"]["state"]
   # local country = location["address"]["country"]
   # local road = location["address"]["road"]
   # if road == nil then road = location["address"]["man_made"] end
   # if road == nil then road = location["address"]["neighborhood"] end
   # if road == nil then road = location["address"]["suburb"] end
   # if road == nil then road = '_road_not_found_' end

#print(json.dumps(location.raw, indent=4, sort_keys=True))

# {
#     "address": {
#         "ISO3166-2-lvl4": "IT-34",
#         "city": "Venezia",
#         "country": "Italia",
#         "country_code": "it",
#         "county": "Venezia",
#         "man_made": "Zitelle",
#         "neighbourhood": "Giudecca",
#         "postcode": "30170",
#         "road": "Fondamenta Zitelle",
#         "state": "Veneto",
#         "suburb": "Venezia-Murano-Burano",
#         "town": "Lido"
#     },
#     "boundingbox": [
#         "45.4266647",
#         "45.4267575",
#         "12.3378217",
#         "12.338003"
#     ],
#     "display_name": "Zitelle, Fondamenta Zitelle, Giudecca, Venezia-Murano-Burano, Lido, Venezia, Veneto, 30170, Italia",
#     "lat": "45.42671575",
#     "licence": "Data \u00a9 OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright",
#     "lon": "12.337924802851708",
#     "osm_id": 138802480,
#     "osm_type": "way",
#     "place_id": 133226838
# }



# local variables:
# compile-command: "python3 ./reverse_nominatim7.py 44.494135036005,11.341755720982"
# end:

