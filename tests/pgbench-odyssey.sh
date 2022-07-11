#!/usr/bin/env bash
TEST_NAME="pgbench-odyssey"

. "pre.subr.sh"

rm -f logs/${TEST_NAME}*

PGHOST=localhost PGPORT=6432 pgbench -i debian
for rate in 1000 2000 3000 4000 5000 6000 7000; do
    th="true"; transaction="true"; release="true";
    PROFILE_URL="th=$th&transaction=$transaction&release=$release"
    PROFILE_TAG=$(echo $PROFILE_URL-rate-$rate | tr "&=" "-")

    echo "Processing $PROFILE_TAG"
    ./odyssey/build/sources/odyssey ./odyssey.conf > logs/$TEST_NAME-pooler-$PROFILE_TAG.log 2> logs/$TEST_NAME-pooler-$PROFILE_TAG.err & write_pid
    sleep 2
    POSTGRES="host=localhost port=6432 user=$USER password=$PGPASSWORD dbname=$USER" ./hasql-loadtest-template/bin/testing-service -p 9001 > logs/$TEST_NAME-server-9001-$PROFILE_TAG.log 2> logs/$TEST_NAME-server-9001-$PROFILE_TAG.err & write_pid
    (while true; do curl -s "http://localhost:9001/hasql/flag?$PROFILE_URL"; sleep 1; done) > /dev/null & write_pid
    PGHOST=localhost PGPORT=6432 pgbench --jobs=2 --client=2000 --time=60 --rate=$rate --no-vacuum --file=./sql/load.sql --report-latencies debian | tee logs/$TEST_NAME-pgbench-$PROFILE_TAG.log

    kill_pids || { echo "error terminating services" ; exit 1 ; }
    sleep 10
done
