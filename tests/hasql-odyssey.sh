#!/usr/bin/env bash
# name: hasql-odyssey
cd ~/hasql-loadtest
ulimit -n 1048576

kill_pids() {
    while read pid;
    do
    kill $pid
    done < var/pid
    cat /dev/null > var/pid
}

if test -s var/pid
then
    echo "var/pid is not empty!"
    exit 1
fi

# Cleanup logs
rm -f logs/*.log

trap 'kill_pids' EXIT

echo
for th in true false; do
    for transaction in true false; do
        for release in true false; do
            for rate in 1000 2000 3000 4000 5000; do
                PROFILE_URL="th=$th&transaction=$transaction&release=$release"
                PROFILE_TAG=$(echo $PROFILE_URL-rate-$rate | tr "&=" "-")
                echo
                echo "Processing $PROFILE_TAG"
                # Run sidecars
                ./odyssey/build/sources/odyssey ./odyssey.conf > logs/hasql-odyssey-pooler-$PROFILE_TAG.log 2> logs/hasql-odyssey-pooler-$PROFILE_TAG.err & echo $! >> var/pid
                sleep 1
                POSTGRES="host=localhost port=6432 user=$USER password=$PGPASSWORD dbname=$USER" ./hasql-loadtest-template/bin/testing-service -p 9000 > logs/hasql-odyssey-server-9000-$PROFILE_TAG.log 2> logs/hasql-odyssey-server-9000-$PROFILE_TAG.err & echo $! >> var/pid
                POSTGRES="host=localhost port=6432 user=$USER password=$PGPASSWORD dbname=$USER" ./hasql-loadtest-template/bin/testing-service -p 9001 > logs/hasql-odyssey-server-9001-$PROFILE_TAG.log 2> logs/hasql-odyssey-server-9001-$PROFILE_TAG.err & echo $! >> var/pid
                sleep 2
                (while true; do curl -s "http://localhost:9001/$PROFILE_URL"; sleep 1; done) > /dev/null & echo $! >> var/pid
                # Run main tester
                echo Running $PROFILE_TAG
                ./wrk2/wrk -d 60 -t 2 -c 2000 --rate 2000 "http://localhost:9000/hasql/flag?$PROFILE_URL" | tee logs/hasql-odyssey-wrk2-${PROFILE_TAG}.log
                
                MTIME=""
                MTIME_PREV=""
                while true;
                do
                    MTIME=$(stat logs/hasql-odyssey-server-9000-$PROFILE_TAG.log|grep Modify)
                    [ "$MTIME" = "$MTIME_PREV" ] && break
                    MTIME_PREV=$MTIME
                    sleep 10
                done

                kill_pids || { echo "error terminating services" ; exit 1 ; }

            done
        done
    done
done