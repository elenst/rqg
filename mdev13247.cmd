if [ -z "$BASEDIR_OLD" ] ; then
  echo "ERROR: define BASEDIR_OLD"
elif [ -z "$BASEDIR" ] ; then
  echo "ERROR: define BASEDIR"
else
  vardir=$BASEDIR/mysql-test/var

  perl ./runall-new.pl \
--threads=1 \
--queries=1 \
--duration=10 \
--seed=1499215641 \
--grammar=conf/mariadb/oltp.yy \
--gendata=mdev13247.zz \
--upgrade-test=crash \
--mysqld=--innodb-file-format=Barracuda \
--mysqld=--innodb-page-size=4K \
--basedir1=$BASEDIR_OLD \
--basedir2=$BASEDIR \
--vardir=$vardir

  echo
  echo "Old basedir: $BASEDIR_OLD"
  echo "Basedir:     $BASEDIR"
  echo "Vardir:      $vardir"
  echo
fi
