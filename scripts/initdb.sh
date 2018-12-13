#!/bin/sh

set -e

cd $(dirname $(readlink $0 || echo $0)); cd ..

sqlite3 db/transcode.db < db/init.sql
chmod 666 db/transcode.db
