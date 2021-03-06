#!/usr/bin/env bash
TEST_NAME="pgbench-odyssey"

. "pre.subr.sh" || exit

rm -f logs/${TEST_NAME}*
PGHOST=localhost PGPORT=5432 pgbench -i debian
for rate in 100 200 500 1000 2000 3000 4000 5000 6000 7000; do
    th="true"; transaction="true"; release="true";
    PROFILE_URL="th=$th&transaction=$transaction&release=$release"
    PROFILE_TAG=$(echo $PROFILE_URL-rate-$rate | tr "&=" "-")

    echo "Processing $PROFILE_TAG"
    odyssey ./odyssey.conf > logs/$TEST_NAME-pooler-"$PROFILE_TAG".log 2> logs/$TEST_NAME-pooler-"$PROFILE_TAG".err & write_pid
    sleep 2
    POSTGRES="host=localhost port=6432 user=$USER password=$PGPASSWORD dbname=$USER connect_timeout=1" testing-service -p 9001 > logs/$TEST_NAME-server-9001-"$PROFILE_TAG".log 2> logs/$TEST_NAME-server-9001-"$PROFILE_TAG".err & write_pid
    curl_tester "http://localhost:9001/hasql/item?$PROFILE_URL" > /dev/null & write_pid
    PGHOST=localhost PGPORT=6432 pgbench --jobs=2 --client=2000 --time=60 --rate=$rate --no-vacuum --file=./sql/load.sql --report-latencies debian 2> logs/$TEST_NAME-pgbench-"$PROFILE_TAG".err | tee logs/$TEST_NAME-pgbench-"$PROFILE_TAG".log

    kill_pids || { echo "error terminating services" ; exit 1 ; }
    sleep 10
done
