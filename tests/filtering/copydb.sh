#! /bin/bash

set -x
set -e

# This script expects the following environment variables to be set:
#
#  - PGCOPYDB_SOURCE_PGURI
#  - PGCOPYDB_TARGET_PGURI
#  - PGCOPYDB_TARGET_TABLE_JOBS
#  - PGCOPYDB_TARGET_INDEX_JOBS


#
# pgcopydb list tables include a retry loop, so we use that as a proxy to
# depend on the source/target Postgres images to be ready
#
pgcopydb list tables --source ${PGCOPYDB_SOURCE_PGURI}
pgcopydb list tables --source ${PGCOPYDB_TARGET_PGURI}

psql -d ${PGCOPYDB_SOURCE_PGURI} -1 -f /usr/src/pagila/pagila-schema.sql
psql -d ${PGCOPYDB_SOURCE_PGURI} -1 -f /usr/src/pagila/pagila-data.sql

# pgcopydb copy db uses the environment variables
pgcopydb copy-db --filters /usr/src/pgcopydb/include.ini

# now compare the output of running the SQL command with what's expected
# as we're not root when running tests, can't write in /usr/src
mkdir -p /tmp/results

find .

pgopts="--single-transaction --no-psqlrc --expanded"

for f in ./sql/*.sql
do
    t=`basename $f .sql`
    r=/tmp/results/${t}.out
    e=./expected/${t}.out
    psql -d "${PGCOPYDB_TARGET_PGURI}" ${pgopts} --file ./sql/$t.sql &> $r
    test -f $e || cat $r
    diff $e $r || exit 1
done
