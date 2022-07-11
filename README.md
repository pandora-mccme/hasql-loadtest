# hasql load testing

## Usage
At project root:
```
tmuxinator
```

## Components
* **postgresql** started as [service](https://docs.github.com/en/actions/using-containerized-services/creating-postgresql-service-containers)
* **odyssey** as main pooler
* **pgbouncer** as alternative pooler
* haskell testing server stored in this repo
* **yandex-tank**
* **pgbench** for comparison
* github actions to run all tests

Odyssey config is located at ./odyssey.conf
