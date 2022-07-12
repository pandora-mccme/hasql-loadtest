## Report on hasql performance with Odyssey pooler

### Purpose

At MCCME we develop hasql-based applications. Related part of the stack is the following: managed PostgreSQL instance at Yandex Cloud and [Odyssey](https://github.com/yandex/odyssey) set in transactional mode, Debian 11 as base image, hasql, hasql-th, hasql-transaction, servant.

While testing one of the services under load we observed external monitoring alerts for another service connected to the same database cluster.
We started to investigate (with testing-service from this repo as pressed service and pgbench) and formulated loose hypothesis that *hasql* holds connections longer than necessary or something like that.

Here we try to introduce reproducible research of the case.

### Methodology and how to reproduce

All experiments are conducted on special virtual machine. To connect use `ssh debian@pgtest.mathem.space`. We have collected all public keys available from collaborators of hasql, if your key is missed, contact us via v.guzeev@mathem.ru or e.kuzmichev@mathem.ru.

Tooling: `PostgreSQL` cluster, `Odyssey`, our own [testing service](https://github.com/pandora-mccme/hasql-loadtest-template), `pgbench` and `wrk2`.
Configuration can be browsed upon this repository. As it worths explicit mention, `max_connections = 100`.

PostgreSQL cluster is listening on port 5432 with Odyssey listening on port 6432. Two instances of testing service (called `beaver` and `user`) are run listening on ports 9000 and 9001 and connect database on port 6432.
`wrk` is used to generate load on beaver with specified target rps rate for rates in range `[50, 100, 200, 500, 1000, 2000, 3000, 4000, 5000]`. `pgbench` does the same with database alone.

Test suite is split into three parts.
`hasql-odyssey-plain` and `pgbench-odyssey` serve as baselines to test results of `hasql-odyssey`, the former excludes all database related tools from stack and the latter excludes all Haskell-related tools.

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

Statistics are collected with `scripts/compute_run.sh`. It is mounted as `~/bin/stats`. `stats`, `odyssey`, `testing-service` and `wrk` are all available in `PATH`.

Any sane action of virtual machine is allowed. Please be careful.
Database is accessible via `psql debian`.

### Results

Reader can extract all required data from logs at `~/logs` and monitor machine conditions interactively using `htop`.

We have specifically processed logs of `user` service for all rps rates into `.stat` files. We did not measure runs with `th=false` and `transaction=false`. You can explore logs via `stats` to ensure these flags does not affect performance.

Here are the collected statistics:

- `tail 50/*.stat`:

```
==> 50/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-50.log.stat <==
|  xxxxx x x                                                               |
|  xxxxx x x   x                                                           |
|  xxxxx x xx  x                                                           |
|  xxxxx x xx  x                                                           |
|  xxxxx x xx xxx x     x           x                                      |
|  xxxxx xxxxxxxxxxx  xxx   xxx   x xx     x    x x                       x|
||_MA__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2774   0.001148753     2.8711711   0.001439671   0.014966318    0.11314451

==> 50/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-50.log.stat <==
| xx                                                                       |
| xx x                                                                     |
| xx xxx                                                                   |
| xx xxx                                                                   |
| xxxxxx                                                                   |
| xxxxxx                                                                  x|
||A_|                                                                      |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2700   0.001115777     31.746946   0.001420966   0.022941002    0.62102367
```

- `tail 100/*.stat`:

```
==> 100/hasql-odyssey-plain-server-9001-th-true-transaction-true-release-true-rate-100.log.stat <==
|xxxxxxxxxx                                                                |
|xxxxxxxxxx                                                                |
|xxxxxxxxxxxx                                                              |
|xxxxxxxxxxxx  x                                                           |
|xxxxxxxxxxxx  x                                                           |
|xxxxxxxxxxxxx x  x                                                       x|
||_A_|                                                                     |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3664   0.001921253   0.032976325   0.002591732  0.0027149601 0.00074903944

==> 100/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-100.log.stat <==
|  xxxxxxx                                                                 |
|  xxxxxxx                                                                 |
|  xxxxxxx                                                                 |
|  xxxxxxxx                                                                |
|  xxxxxxxx                                   x                            |
|  xxxxxxxxx x   x                    x       x       x             x     x|
||_A__|                                                                    |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3247   0.001026666     3.8848665   0.001384475   0.012938594    0.12879013

==> 100/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-100.log.stat <==
|   xxxx       x                                                           |
|   xxxxx      x                                                           |
|   xxxxxx  x  x                                                           |
|   xxxxxxx xx x  x      x                                                 |
|   xxxxxxxxxxxx  xxxxxxxx x               x                               |
|   xxxxxxxxxxxx  xxxxxxxxxx x xxx       x xx         x     x             x|
||__A__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3036   0.001114709     3.2532165   0.001368653   0.019489311    0.14252476

==> 100/pgbench-odyssey-server-9001-th-true-transaction-true-release-true-rate-100.log.stat <==
| xxxxxxxxxxxxxxxxxxx x                                                    |
| xxxxxxxxxxxxxxxxxxx xx                                                   |
| xxxxxxxxxxxxxxxxxxxxxx                                                   |
| xxxxxxxxxxxxxxxxxxxxxx                                                   |
| xxxxxxxxxxxxxxxxxxxxxx                                                   |
| xxxxxxxxxxxxxxxxxxxxxxxx x     x   x    x        x             x        x|
||_MA__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 5636   0.001747873   0.035272935   0.002436079  0.0027584927  0.0013618326
```

- `tail 200/*.stat`:

```
==> 200/hasql-odyssey-plain-server-9001-th-true-transaction-true-release-true-rate-200.log.stat <==
|xxxxxxxxxxxxxxxxxxxxx x x                                                 |
|xxxxxxxxxxxxxxxxxxxxx x x                                                 |
|xxxxxxxxxxxxxxxxxxxxxxx x x                                               |
|xxxxxxxxxxxxxxxxxxxxxxx xxx    x x                                        |
|xxxxxxxxxxxxxxxxxxxxxxxxxxx   xx x                                        |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx x  xx        x        x               x|
| |__MA___|                                                                |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3851   0.001977655   0.012609275   0.002601583   0.002749713 0.00060505777

==> 200/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-200.log.stat <==
|  xx  x    x                                                              |
|  xx  x    x                                                              |
|  xx xx    x                                                              |
|  xx xx   xx                                                              |
|  xx xx x xx   x x  x                                                     |
|  xxxxx xxxxxx xxx  x   x                                                x|
||_A_|                                                                     |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2443   0.000985163     7.2792955   0.001373539    0.01797439    0.18998612

==> 200/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-200.log.stat <==
|   xx                                                                     |
|   xx                                                                     |
|   xx                                                                     |
|   xx                      x                                              |
|   xx x               x  x xx  x  x                                      x|
|   xx xx x x  x xx   xxxxx xx  x xx      xx  x  xx                       x|
||__A__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3024   0.001129816     4.5198929   0.001389069   0.019888008    0.20152841

==> 200/pgbench-odyssey-server-9001-th-true-transaction-true-release-true-rate-200.log.stat <==
| xxxxxxxxxxxxxxx                                                          |
| xxxxxxxxxxxxxxx                                                          |
| xxxxxxxxxxxxxxxx                                                         |
| xxxxxxxxxxxxxxxxxx   x                                                   |
| xxxxxxxxxxxxxxxxxx xxx x                 x                               |
| xxxxxxxxxxxxxxxxxx xxx xxx   x           x xx             x             x|
||_MA__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3487   0.001922461   0.037668706    0.00247709  0.0028420113  0.0015894466
```

- `tail 500/*.stat`:

```
==> 500/hasql-odyssey-plain-server-9001-th-true-transaction-true-release-true-rate-500.log.stat <==
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxx x                                           |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx                                           |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx                                           |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx          x x                             |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx x  xxx   x xxx xx   x                    |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx x  xxxxxxxxxxxxxxx  x                   x|
|  |___MA_____|                                                            |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3969   0.001959964   0.009222771   0.002575799    0.00266628 0.00055498699

==> 500/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-500.log.stat <==
|   xxxxxx  x                                                              |
|   xxxxxx  x                                                              |
|   xxxxxxx x  x    x                                                      |
|   xxxxxxxxx  xx x xxx  x                                                 |
|   xxxxxxxxx  xxxx xxx  x x                                               |
|   xxxxxxxxxx xxxxxxxxxxxxx  x        x   x    x        x            x   x|
||__A__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2725   0.000995272     2.2492419   0.001400817   0.015263403    0.10128469

==> 500/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-500.log.stat <==
|  x   xx                                                                  |
|  x   xx                                                                  |
|  x   xx  x  x                                                            |
|  xxx xx  x xx                                                            |
|  xxx xxx xxxx    x                                                       |
|  xxxxxxxxxxxxxxxxx  x                x                                  x|
||_A_|                                                                     |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2850   0.001139383     8.9109926     0.0013898   0.021392669    0.23102177

==> 500/pgbench-odyssey-server-9001-th-true-transaction-true-release-true-rate-500.log.stat <==
| xxxx                                                                     |
| xxxx                                                                     |
| xxxx                                                                     |
| xxxxx x                                                                  |
| xxxxx x      x                                                           |
| xxxxxxxx   xxx xx                                                       x|
||A_|                                                                      |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3237   0.001826199    0.22485668   0.002350847  0.0027912517  0.0044907072

```

- `tail 1000/*.stat`:

```
==> 1000/hasql-odyssey-plain-server-9001-th-true-transaction-true-release-true-rate-1000.log.stat <==
|xxxxxxxxxxxxxxxxxxxx xxxxx  xxx                                           |
|xxxxxxxxxxxxxxxxxxxx xxxxxx xxx      x                                    |
|xxxxxxxxxxxxxxxxxxxxxxxxxxx xxx x   xx x                                  |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx xx  xx x       x                          |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx xx xxx     x                          |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx xxx    xx                         x|
| |___MA____|                                                              |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 4023   0.001804823   0.011009041    0.00241076  0.0025711463 0.00063766331

==> 1000/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-1000.log.stat <==
|    xxxxxx x xx x                                                         |
|    xxxxxxxx xx x                                                         |
|    xxxxxxxx xxxx                                                         |
|    xxxxxxxx xxxx                                                         |
|    xxxxxxxxxxxxx      x   xx                                       x    x|
|    xxxxxxxxxxxxxxxxxxxxxx xx  x       x  xx  x   x     x           x  xxx|
||___MA___|                                                                |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2171   0.001094052     1.6805014   0.001355804   0.018145457    0.11284464

==> 1000/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-1000.log.stat <==
|   x                                                                      |
|   x   x                                                                  |
|   x  xx x x                   x                                          |
|   x  xx x x                   x                                          |
|   xx xx xxxx   xx  x xx       x  x                                       |
|   xx xx xxxxx  xx  x xxxx xxxxx xxx x     x x    x     x                x|
||__A__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2800   0.001109561     4.1935339   0.001357792   0.022238904    0.19105418

==> 1000/pgbench-odyssey-server-9001-th-true-transaction-true-release-true-rate-1000.log.stat <==
| xxxxx x                                                                  |
| xxxxx x                                                                  |
| xxxxxxx                                                                  |
| xxxxxxx                                                                  |
| xxxxxxx xx x  x                                                          |
| xxxxxxxxxxxxx x   x           x          x                              x|
||MA|                                                                      |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3892   0.001880262    0.20147042   0.002391502  0.0029581732  0.0044456413
```

- `tail 2000/*.stat`:

```
==> 2000/hasql-odyssey-plain-server-9001-th-true-transaction-true-release-true-rate-2000.log.stat <==
|xxxxxxxxxxxxxxxxxxx xx                                                    |
|xxxxxxxxxxxxxxxxxxx xx  x                                                 |
|xxxxxxxxxxxxxxxxxxx xx  x                                                 |
|xxxxxxxxxxxxxxxxxxx xx  x                                                 |
|xxxxxxxxxxxxxxxxxxxxxxx x x                                               |
|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx xx                 x         x         x|
||__MA__|                                                                  |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 4077   0.001821578   0.013034932   0.002249659  0.0024008097 0.00056339119

==> 2000/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-2000.log.stat <==
|  xxxxx            x                                                      |
|  xxxxxx           x                                                      |
|  xxxxxxx    x     x                                                      |
|  xxxxxxxxx xxx    x                                                      |
|  xxxxxxxxx xxx x  x          x                                           |
|  xxxxxxxxxxxxx x xxxxx   xx xx          x   x   x                       x|
||_MA_|                                                                    |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2578   0.001003249     2.8489037   0.001454711   0.014593769    0.10918187

==> 2000/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-2000.log.stat <==
|  xx      x                                                               |
|  xx      x                                                               |
|  xxxxx   xx                                                              |
|  xxxxx   xxx                                                             |
|  xxxxxxx xxx x  x              x      x                                  |
|  xxxxxxxxxxx x xx x     x    x x  x x x               xx                x|
||_MA_|                                                                    |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2844   0.001173013     5.2380944   0.001434426   0.020458713    0.20054256

==> 2000/pgbench-odyssey-server-9001-th-true-transaction-true-release-true-rate-2000.log.stat <==
|   xx                                                                     |
|   xx                                                                     |
|   xxx                                                                    |
|   xxx                                                                    |
|   xxx                                                                    |
|   xxxx      x         xx x x         x                                  x|
||__A___|                                                                  |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 737   0.001949884     10.432093   0.005671608   0.057737661    0.49768895
```

- `tail 3000/*.stat`:

```
==> 3000/hasql-odyssey-plain-server-9001-th-true-transaction-true-release-true-rate-3000.log.stat <==
| xxxxxxxxxxxxxxxxxxxxx xxx                                                |
| xxxxxxxxxxxxxxxxxxxxx xxx                                                |
| xxxxxxxxxxxxxxxxxxxxx xxx                                                |
| xxxxxxxxxxxxxxxxxxxxx xxx    xx                                          |
| xxxxxxxxxxxxxxxxxxxxxxxxxxxx xx x x                                      |
| xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx xxxx   xxx      x     x   x  x          x|
||__MA____|                                                                |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3748   0.001864976   0.014379487   0.002244482  0.0024658056 0.00076731757

==> 3000/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-3000.log.stat <==
|   xxx                                                                    |
|   xxx  xxx                                                               |
|   xxxxxxxxx                                                              |
|   xxxxxxxxx  xx     x                                                    |
|   xxxxxxxxxx xxx    x      xx         x                                  |
|   xxxxxxxxxxxxxx  x x x    xxx  x x   xx     x  x                       x|
||__A__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2401   0.001053394      2.856995   0.001374541   0.016976055    0.12382457

==> 3000/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-3000.log.stat <==
|   x                                                                      |
|   x                                                                      |
|   x                                                                      |
|   x                                                                      |
|   x                      x     x    xx                                   |
|   x     x        x   x   x x x x   xxx    x x  x x x x x   x      x  x xx|
||__A___|                                                                  |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 4203   0.001123565     4.0317962   0.001360546   0.015424374    0.19307121

==> 3000/pgbench-odyssey-server-9001-th-true-transaction-true-release-true-rate-3000.log.stat <==
|      x                                                                   |
|      x                                                                   |
|      x                                                                   |
|      xx              x            x                                      |
|      xxx        x   xx            x       x                              |
|      xxx  xx   xx xxxx  x   xx x  x xx   xxx     x                      x|
||_____M______A___________|                                                |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 102   0.003241721     5.9702139   0.008209687    0.57356069     1.1276251
```

- `tail 4000/*.stat`:

```
==> 4000/hasql-odyssey-plain-server-9001-th-true-transaction-true-release-true-rate-4000.log.stat <==
|xxxxxxxxxxxxxxx xx                                                        |
|xxxxxxxxxxxxxxx xx                                                        |
|xxxxxxxxxxxxxxx xxx                                                       |
|xxxxxxxxxxxxxxxxxxx xx  x                                                 |
|xxxxxxxxxxxxxxxxxxx xx  x                                                 |
|xxxxxxxxxxxxxxxxxxxxxx  xxxx          x                                  x|
||_MA__|                                                                   |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 4002   0.001820579   0.015644828   0.002268209  0.0024051665  0.0005234948

==> 4000/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-4000.log.stat <==
|   xxxxx  x        x                                                      |
|   xxxxx  x     x  x                                                      |
|   xxxxxxxxx    x  x     x                                                |
|   xxxxxxxxx x xx  x x x x                                                |
|   xxxxxxxxxxxxxx xxxx x x                                                |
|   xxxxxxxxxxxxxxxxxxxxxxxx  xx  x  x   x xx x                   x    x  x|
||__MA__|                                                                  |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2505   0.001038388     1.8689076    0.00140935   0.016262092   0.098032899

==> 4000/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-4000.log.stat <==
|  x                                                                       |
|  x                                                                       |
|  x                                                                       |
|  x                                                                       |
|  x  x x   x    x x       x                                               |
|  x  x xx  xxxx xxxxx    xx        x     x   xx                          x|
||_A_|                                                                     |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 5040   0.001131855     8.7066154   0.001403797   0.013509291    0.21537149

==> 4000/pgbench-odyssey-server-9001-th-true-transaction-true-release-true-rate-4000.log.stat <==
|       x                                                                  |
|       x                                                                  |
|       x                                                                  |
|       x                       x                                          |
|       x                       x            x                             |
|       xxx  x      x    x xxxx x  xxx x  x  x                            x|
||______M_____A____________|                                               |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x  77   0.003132168     7.9407549   0.005732652    0.76747453     1.5488408
```

- `tail 5000/*.stat`:

```
==> 5000/hasql-odyssey-plain-server-9001-th-true-transaction-true-release-true-rate-5000.log.stat <==
|xxxxxxxxxxxxxxxxxxxx                                                      |
|xxxxxxxxxxxxxxxxxxxxx                                                     |
|xxxxxxxxxxxxxxxxxxxxx x      x                                            |
|xxxxxxxxxxxxxxxxxxxxx x   x  x                                            |
|xxxxxxxxxxxxxxxxxxxxx xx  x  x                                            |
|xxxxxxxxxxxxxxxxxxxxxxxxx xx x x          x        x            x        x|
||__MA__|                                                                  |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 3967   0.001853306   0.013114451    0.00230237  0.0024527342 0.00054667763

==> 5000/hasql-odyssey-server-9001-th-true-transaction-true-release-false-rate-5000.log.stat <==
|    xxxx x                                                                |
|    xxxx xx                                                               |
|    xxxx xx        x                                                      |
|    xxxx xx      x x          x                                           |
|    xxxxxxx  xx  x x  x       x     x                                     |
|    xxxxxxxx xx xx x xxx xx  xx xx xxx   x xx x   x   x     x       xx   x|
||___A___|                                                                 |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 2412   0.001029086     1.8844792   0.001347435    0.01660936    0.11154062

==> 5000/hasql-odyssey-server-9001-th-true-transaction-true-release-true-rate-5000.log.stat <==
|  x                                                                       |
|  x                                                                       |
|  x                                                                       |
|  x                                                                       |
|  x             xxxx                                                      |
|  x x  xx       xxxxx  xxx      x        x  x       x                    x|
||_A|                                                                      |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 5605   0.001139456     9.1763156   0.001378405   0.012022664    0.21594571

==> 5000/pgbench-odyssey-server-9001-th-true-transaction-true-release-true-rate-5000.log.stat <==
|      x                                                                   |
|      x                                                                   |
|      x                                                                   |
|      x                         x                                         |
|      x   x                     x                                         |
|      xxxxx xx xx xx  xxxx  xx xxx    x   x                              x|
||_____M___A__________|                                                    |
+--------------------------------------------------------------------------+
    N           Min           Max        Median           Avg        Stddev
x 104   0.002663608     8.5998908   0.006403996    0.56586138     1.3344346
```

### Interpretation

From collected statistics we observe that with `hasql` random slowdowns in processing requests happen even on relatively low loads. You're free to take a look at state of `pg_stat_activity`and related tables during the test.

Also results on high RPS in comparison with `pgbench` seem to be evidence of `hasql` being unable to provide desired rps rate.

We are not ready to claim any interpretation from collected data (in particular if there is a solvable problem in hasql library) but initial observations are indeed reproduced. And we believe these results to be evidence in support of hypothesis.
