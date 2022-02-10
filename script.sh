#!/usr/bin/env sh

set -eu

openrc
sleep 3
# ./main &
litestream replicate -exec ./main data.db sftp://root:@localhost/replication &
sleep 3

for _ in $(seq 1 3); do
	wrk --latency --duration 20s --connections 400 --timeout 10s http://localhost:8080/tb &
	pid=$!
	wrk --latency --duration 20s --connections 400 --timeout 10s http://localhost:8080/tb2 &
	pid2=$!
	wrk --latency --duration 20s --connections 400 --timeout 10s http://localhost:8080/tb3
	wait $pid
	wait $pid2

	echo "Waiting 3 seconds"
	sleep 3

	echo "WAL file size: $(($(stat -c '%s' data.db-wal) / 1000000)) MB"
	echo
done

litestream restore -v -o data2.db sftp://root:@localhost/replication

sqlite3 data.db '.dump tb tb2 tb3' > data.sql
sqlite3 data2.db '.dump tb tb2 tb3' > data2.sql
diff data.sql data2.sql
