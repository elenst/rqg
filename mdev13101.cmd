if [ -z "$BASEDIR" ] ; then
  echo "ERROR: define BASEDIR"
else
  vardir=$BASEDIR/mysql-test/var
  keys=$BASEDIR/mysql-test/std_data/keys.txt

  perl ./runall-new.pl \
--threads=1 \
--queries=2 \
--duration=3 \
--grammar=mdev13101.yy \
--skip-gendata \
--upgrade-test=crash \
--mysqld=--file-key-management \
--mysqld=--plugin-load-add=file_key_management.so \
--mysqld=--innodb-encrypt-tables \
--mysqld=--innodb-encryption-threads=1 \
--mysqld=--file-key-management-filename=$keys \
--basedir=$BASEDIR \
--vardir=$vardir

  echo
  echo "Basedir: $BASEDIR"
  echo "Vardir: $vardir"
  echo "Encryption keys: $keys"
  echo
fi

