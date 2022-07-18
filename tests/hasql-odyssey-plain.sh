#!/usr/bin/env bash

TEST_NAME="hasql-odyssey-plain"
# name: hasql-odyssey

. "pre.subr.sh"

rm -f logs/${TEST_NAME}*
for rate in 100 200 500 1000 2000 3000 4000 5000; do
    th="true"; transaction="true"; release="true"
    PROFILE_URL="th=$th&transaction=$transaction&release=$release"
    PROFILE_TAG=$(echo $PROFILE_URL-rate-$rate | tr "&=" "-")
    printf "\nProcessing %s-%s\n" "$TEST_NAME" "$PROFILE_TAG"
    # Run sidecars
    odyssey ./odyssey.conf > logs/$TEST_NAME-pooler-"$PROFILE_TAG".log 2> logs/$TEST_NAME-pooler-"$PROFILE_TAG".err & write_pid
    sleep 1
    POSTGRES="host=localhost port=6432 user=$USER password=$PGPASSWORD dbname=$USER connect_timeout=1" testing-service -p 9000 > logs/$TEST_NAME-server-9000-"$PROFILE_TAG".log 2> logs/$TEST_NAME-server-9000-"$PROFILE_TAG".err & write_pid
    POSTGRES="host=localhost port=6432 user=$USER password=$PGPASSWORD dbname=$USER connect_timeout=1" testing-service -p 9001 > logs/$TEST_NAME-server-9001-"$PROFILE_TAG".log 2> logs/$TEST_NAME-server-9001-"$PROFILE_TAG".err & write_pid
    sleep 2
    curl_tester "http://localhost:9001/hasql/item?$PROFILE_URL" > /dev/null & write_pid
    # Run main tester
    wrk -d 60 -t 2 -c 2000 --rate 2000 "http://localhost:9000/plain" | tee logs/$TEST_NAME-wrk2-"${PROFILE_TAG}".log
    
    wait_mtime logs/$TEST_NAME-server-9000-"$PROFILE_TAG".log

    kill_pids || { echo "error terminating services" ; exit 1 ; }

    sleep 10

done
