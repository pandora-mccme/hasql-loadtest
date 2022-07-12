## Report on research on hasql performance with Odyssey pooler

### Statement of purpose

We at MCCME run bunch of hasql-based applications. Related part of the stack is the following: Yandex Cloud with managed PostgreSQL instance and Odyssey set in transactional mode, workers on Debian 11, hasql, hasql-th, hasql-transaction, servant.

During testing of behaviour of one of services under load we observed external monitoring alerts on another service depending on the same database cluster.
We started to investigate (with testing-service from this repo as pressed service and pgbench) and formulated loose hypothesis that hasql does hold connections longer than necessary or something like that.

In this repo we try to introduce reproducible research of the case. We are not ready to claim any interpreted results from collected data (in particular if there is a solvable problem in hasql library) but initial observations are indeed reproduced.

### Methodology and how to reproduce

Configuration can be browsed upon this repository.

All experiments are conducted on special virtual machine. To connect use `ssh debian@pgtest.mathem.space`. We have collected all public keys available from collaborators of hasql, if your key is missed, contact us via v.guzeev@mathem.ru or e.kuzmichev@mathem.ru.

Tooling: `PostgreSQL` cluster, `Odyssey`, our own [testing service](https://github.com/pandora-mccme/hasql-loadtest-template), `pgbench` and `wrk2`.

PostgreSQL cluster is listening on port 5432 with Odyssey listening on port 6432. Two instances of testing service (called `beaver` and `user`) are run listening on ports 9000 and 9001 and connect database on port 6432.
`wrk` is used to generate load on beaver with specified target rps rate. `pgbench` does the same with database alone.

Test suite is split into three parts.
`hasql-odyssey-plain` and `pgbench-odysses` serve as baselines to test results of `hasql-odyssey`, the former exclude all database related tools from stack and the latter excludes all Haskell-related tools.

In `hasql-odyssey-plain` `wrk` beats handler which does not query database. This baseline is needed to exclude general misconfiguration of system, e.g. low value of `ulimit -n`.
`hasql-odyssey` beats database via `beaver` with `SELECT 't'::bool` with various settings. Id est it can use `hasql-th` with explicitly non-prepared statements or not, use `hasql-transaction` with explicitly set read-only transactions with `ReadCommitted` isolation level or not, and it can explicitly release connections of leave it to pooler.
`pgbench-odyssey` beats database with the same query.

Simultaneously with `beaver` load generation, there is a process periodically asking `user` for a bit more complex data in single thread.

As we need to measure how is `user` performance affected by high-volume application on the same cluster we collect all logs and measure basic statistics of response time for requests to `user`.

To run standard test suite from `~` run
```
cd hasql-loadtest/tests
./hasql-odyssey-plain.sh
./hasql-odyssey.sh
./pgbench-odyssey.sh
```

We have tmux installed to maintain shared terminal sessions.

We were also planning to perform same tests with `pgbouncer` and on a raw database. But it was postponed due to lack of time. `pgbouncer` is not properly configured yet.

### Results



### Interpretation
