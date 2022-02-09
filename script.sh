#!/usr/bin/env sh

set -eu

openrc
sleep 3
litestream replicate -exec ./main data.db sftp://root:@localhost/replication &
sleep 3

for _ in $(seq 1 5); do
	wrk --duration 1s --threads 1 --connections 2 http://localhost:8080

	echo "Waiting 3 seconds"
	sleep 3

	echo "WAL file size: $(($(stat -c '%s' data.db-wal) / 1000000)) MB"
	echo
done

litestream restore -v -o data2.db sftp://root:@localhost/replication

sqlite3 data.db '.dump tb' > data.sql
sqlite3 data2.db '.dump tb' > data2.sql
diff data.sql data2.sql
