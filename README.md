# WAL

```
git clone https://github.com/xpetit/wal
cd wal
docker build --tag github.com/xpetit/wal .
docker run --rm --name wal github.com/xpetit/wal
```

Output:

```
[...]
WAL file size: 71 MB
[...]
WAL file size: 140 MB
[...]
WAL file size: 209 MB
[...]
WAL file size: 279 MB
[...]
WAL file size: 350 MB
[...]
```

Uncommenting `db.SetMaxOpenConns(1)` in [main.go](main.go) fixes the issue, changing `--connections 2` to `--connections 1` in [script.sh](script.sh) as well.
