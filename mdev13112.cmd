if [ -z "$BASEDIR" ] ; then
  echo "ERROR: define BASEDIR"
else
  vardir=$BASEDIR/mysql-test/var
  keys=$BASEDIR/mysql-test/std_data/keys.txt

  perl ./runall-new.pl \
--threads=1 \
--queries=100M \
--duration=30 \
--grammar=mdev13112.yy \
--gendata=mdev13112.zz \
--upgrade-test=crash \
--mysqld=--file-key-management \
--mysqld=--plugin-load-add=file_key_management.so \
--mysqld=--innodb-encrypt-tables \
--mysqld=--innodb-file-format=Barracuda \
--mysqld=--file-key-management-filename=$keys \
--basedir=$BASEDIR \
--vardir=$vardir

  echo
  echo "Basedir: $BASEDIR"
  echo "Vardir: $vardir"
  echo "Encryption keys: $keys"
  echo
fi
