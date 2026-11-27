import sqlite3
import json
import codecs

conn = sqlite3.connect('opengeo.sqlite')
cur = conn.cursor()

# The location I added is the FIRST line of where.data
MY_LOCATION = open("where.data", encoding="utf-8").readline().strip()
STARS = "*" * 60
mine_out = None

cur.execute('SELECT * FROM Locations')
fhand = codecs.open('where.js', 'w', "utf-8")
fhand.write("myData = [\n")
count = 0
for row in cur :
    data = str(row[1].decode())
    try: js = json.loads(str(data))
    except: continue

    if len(js['features']) == 0: continue

    try:
        lat = js['features'][0]['geometry']['coordinates'][1]
        lng = js['features'][0]['geometry']['coordinates'][0]
        where = js['features'][0]['properties']['display_name']
        where = where.replace("'", "")
    except:
        print('Unexpected format')
        print(js)

    try :
        mine = (row[0].decode() == MY_LOCATION)
        if mine :
            print(STARS)
            print('***  MY ADDED LOCATION:')
        print(where, lat, lng)
        if mine :
            print(STARS)
            mine_out = "["+str(lat)+","+str(lng)+", '"+where+"']"

        count = count + 1
        if count > 1 : fhand.write(",\n")
        output = "["+str(lat)+","+str(lng)+", '"+where+"']"
        fhand.write(output)
    except:
        continue

fhand.write("\n];\n")
# Lets where.html zoom into the location I added
if mine_out : fhand.write("myLocation = " + mine_out + ";\n")
cur.close()
fhand.close()
print(count, "records written to where.js")
print("Open where.html to view the data in a browser")

