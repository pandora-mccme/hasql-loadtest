echo installing for user $USER
# Configure git
git config --global user.email "tester@testing"
git config --global user.name "Tester"
git config pull.ff only

sudo apt-get update

# Install general and dev packages
sudo apt-get install -y \
tmux htop vim \
strace valgrind gdb \
tmuxinator \
tcpdump wrk \
curl \
zsh

# Postgres
echo
echo Installing Postgres
sudo apt-get install -y postgresql postgresql-client
sudo systemctl enable postgresql 
sudo systemctl restart postgresql
sudo -u postgres psql -c "CREATE USER $USER WITH PASSWORD '$USER'"
sudo -u postgres createdb -O $USER $USER
psql < initdb.sql
# test: psql -c "select * from objects"

# PgBouncer
#echo
#echo Installing PgBouncer
#sudo apt-get install -y pgbouncer
#envsubst < pgbouncer/pgbouncer.ini | sudo tee /etc/pgbouncer/pgbouncer.ini | head 
#envsubst < pgbouncer/userlist.txt | sudo tee /etc/pgbouncer/userlist.txt | head
#sudo systemctl enable pgbouncer
#sudo systemctl restart pgbouncer
# test: psql -p 6432 -c "select * from objects"

# Haskell
echo
echo Installing Haskell
sudo apt-get install -y \
	ghc \
	haskell-stack \
	curl \
	librsvg2-2 \
	libpq5 \
	libtinfo5 \
	build-essential \
	locales \
	ca-certificates \
	zlib1g-dev
make build
