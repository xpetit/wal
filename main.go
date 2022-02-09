package main

import (
	"database/sql"
	"fmt"
	"math/rand"
	"net/http"
	"net/url"
	"runtime"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

func check(a ...interface{}) {
	for _, v := range a {
		if err, ok := v.(error); ok && err != nil {
			panic(err)
		}
	}
}

func main() {
	db, err := sql.Open("sqlite3", "data.db?"+url.Values{
		"_busy_timeout": {"5000"},
		"_journal_mode": {"wal"},
		"_synchronous":  {"normal"},
	}.Encode())
	check(err)

	db.SetMaxOpenConns(runtime.NumCPU())

	check(db.Exec(`create table if not exists "tb" (
		"id"    integer not null primary key,
		"count" integer not null
	)`))

	rand.Seed(time.Now().UnixNano())
	var m sync.Mutex
	http.HandleFunc("/", func(rw http.ResponseWriter, r *http.Request) {
		m.Lock()
		id := rand.Intn(1_000_000)
		m.Unlock()
		tx, err := db.Begin()
		check(err)
		result, err := tx.Exec(`update "tb" set "count" = "count" + 1 where "id" = ?`, id)
		check(err)
		nb, err := result.RowsAffected()
		check(err)
		if nb == 0 {
			check(tx.Exec(`insert into "tb" ("id", "count") values (?, 1)`, id))
		}
		check(tx.Commit())
	})
	fmt.Println("listening to 8080")
	check(http.ListenAndServe(":8080", nil))
}
