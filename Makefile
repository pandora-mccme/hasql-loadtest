install:
	ln -sf $(PWD)/tmuxinator/hasql-odyssey.yml $(HOME)/.config/tmuxinator
	ln -sf $(PWD)/tmuxinator/pgbench-odyssey.yml $(HOME)/.config/tmuxinator
	ln -sf $(PWD)/odyssey/build/sources/odyssey $(HOME)/bin/odyssey
	ln -sf $(PWD)/hasql-loadtest-template/bin/testing-service $(HOME)/bin/testing-service
	ln -sf $(PWD)/wrk2/wrk $(HOME)/bin/wrk
