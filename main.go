package main

import (
	"database/sql"
	"fmt"
	"log"
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
	db.SetMaxIdleConns(runtime.NumCPU())

	check(db.Exec(`
		pragma wal_autocheckpoint = 0;
		create table "tb" (
			"id"    integer not null primary key,
			"count" integer not null
		);
		create table "tb2" (
			"id"    integer not null primary key,
			"count" integer not null
		);
		create table "tb3" (
			"id"    integer not null primary key,
			"count" integer not null
		);
	`))

	rand.Seed(time.Now().UnixNano())

	var wg sync.WaitGroup
	var i int
	var m sync.Mutex
	write := func(tb string) {
		m.Lock()
		id := rand.Intn(1_000_000)
		i++
		if i == 100 {
			i = 0
			wg.Wait()
			log.Println("attempting pragma wal_checkpoint(restart)")
			var failed bool
			check(db.QueryRow(`pragma wal_checkpoint(restart)`).Scan(&failed, new(int), new(int)))
			if failed {
				log.Println("pragma wal_checkpoint(restart) failed")
			} else {
				log.Println("pragma wal_checkpoint(restart) succeeded")
			}
		}
		m.Unlock()
		wg.Add(1)
		tx, err := db.Begin()
		check(err)
		result, err := tx.Exec(`update "`+tb+`" set "count" = "count" + 1 where "id" = ?`, id)
		check(err)
		nb, err := result.RowsAffected()
		check(err)
		if nb == 0 {
			check(tx.Exec(`insert into "`+tb+`" ("id", "count") values (?, 1)`, id))
		}
		check(tx.Commit())
		wg.Done()
	}
	http.HandleFunc("/tb", func(rw http.ResponseWriter, r *http.Request) { write("tb") })
	http.HandleFunc("/tb2", func(rw http.ResponseWriter, r *http.Request) { write("tb2") })
	http.HandleFunc("/tb3", func(rw http.ResponseWriter, r *http.Request) { write("tb3") })
	fmt.Println("listening to 8080")
	check(http.ListenAndServe(":8080", nil))
}
