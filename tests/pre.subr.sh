cd ~/hasql-loadtest

ulimit -n 1048576

write_pid() {
    echo $! >> var/pid
}

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

trap 'kill_pids' EXIT

# $1 - log address
wait_mtime() {
    MTIME=""
    MTIME_PREV=""
    while true;
    do
        MTIME=$(stat $1|grep Modify)
        if [ "$MTIME" = "$MTIME_PREV" ]
        then
            break
        else
            echo "Waiting for transactions to finish"
        fi
        MTIME_PREV=$MTIME
        sleep 10
    done
}