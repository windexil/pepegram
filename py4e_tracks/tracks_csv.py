import csv
import sqlite3

conn = sqlite3.connect('trackdb.sqlite')
cur = conn.cursor()

# Start from empty tables on every run
cur.executescript('''
DROP TABLE IF EXISTS Artist;
DROP TABLE IF EXISTS Genre;
DROP TABLE IF EXISTS Album;
DROP TABLE IF EXISTS Track;

CREATE TABLE Artist (
    id  INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
    name    TEXT UNIQUE
);

CREATE TABLE Genre (
    id  INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
    name    TEXT UNIQUE
);

CREATE TABLE Album (
    id  INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
    artist_id  INTEGER,
    title   TEXT UNIQUE
);

CREATE TABLE Track (
    id  INTEGER NOT NULL PRIMARY KEY
        AUTOINCREMENT UNIQUE,
    title TEXT  UNIQUE,
    album_id  INTEGER,
    genre_id  INTEGER,
    len INTEGER, rating INTEGER, count INTEGER
);
''')

fname = input('Enter file name: ')
if len(fname) < 1:
    fname = 'tracks.csv'

# Each line: title,artist,album,count,rating,len,genre
# e.g. Another One Bites The Dust,Queen,Greatest Hits,55,100,217103,Rock
with open(fname, newline='') as fh:
    for pieces in csv.reader(fh):
        if len(pieces) < 7:
            continue

        name = pieces[0]
        artist = pieces[1]
        album = pieces[2]
        count = int(pieces[3])
        rating = int(pieces[4])
        length = int(pieces[5])
        genre = pieces[6]

        cur.execute('INSERT OR IGNORE INTO Artist (name) VALUES ( ? )', (artist,))
        cur.execute('SELECT id FROM Artist WHERE name = ? ', (artist,))
        artist_id = cur.fetchone()[0]

        cur.execute('INSERT OR IGNORE INTO Genre (name) VALUES ( ? )', (genre,))
        cur.execute('SELECT id FROM Genre WHERE name = ? ', (genre,))
        genre_id = cur.fetchone()[0]

        cur.execute('INSERT OR IGNORE INTO Album (title, artist_id) VALUES ( ?, ? )',
                    (album, artist_id))
        cur.execute('SELECT id FROM Album WHERE title = ? ', (album,))
        album_id = cur.fetchone()[0]

        cur.execute('''INSERT OR REPLACE INTO Track
            (title, album_id, genre_id, len, rating, count)
            VALUES ( ?, ?, ?, ?, ?, ? )''',
                    (name, album_id, genre_id, length, rating, count))

conn.commit()

sqlstr = '''SELECT Track.title, Artist.name, Album.title, Genre.name
    FROM Track JOIN Genre JOIN Album JOIN Artist
    ON Track.genre_id = Genre.ID AND Track.album_id = Album.id
        AND Album.artist_id = Artist.id
    ORDER BY Artist.name LIMIT 3'''

for row in cur.execute(sqlstr):
    print(row)

cur.close()
