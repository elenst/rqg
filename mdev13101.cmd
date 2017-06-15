if [ -z "$BASEDIR" ] ; then
  echo "ERROR: define BASEDIR"
else
  vardir=$BASEDIR/mysql-test/var
  keys=$BASEDIR/mysql-test/std_data/keys.txt
  echo "Basedir: $BASEDIR"
  echo "Vardir: $vardir"
  echo "Encryption keys: $keys\n"

  perl ./runall-new.pl \
--threads=1 \
--duration=60 \
--grammar=conf/mariadb/oltp.yy \
--gendata-advanced \
--skip-gendata \
--upgrade-test=crash \
--mysqld=--innodb-page-size=8K \
--mysqld=--file-key-management \
--mysqld=--plugin-load-add=file_key_management.so \
--mysqld=--innodb-encrypt-tables \
--mysqld=--innodb-encrypt-log \
--mysqld=--innodb-encryption-threads=4 \
--mysqld=--file-key-management-filename=$keys \
--basedir=$BASEDIR \
--vardir=$vardir
fi

