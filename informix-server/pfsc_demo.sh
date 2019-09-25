#/bin/sh
# Demo script for Partition Free Space Cache

echo " "
echo "This script will demonstrate the new pfsc feature. To run this script"
echo "without the benefit of the new feature, set PFSC_BOOST to 0 in your"
echo "config file now. This parameter can be modified on the fly."
echo " "
echo "Your instance will be shut down and restarted. Before continuing, make"
echo "sure you've set the following parameters in your config file:"
echo " "
echo "MAX_FILL_DATA_PAGES 1"
echo "LTXEHWM             100"
echo "LTXHWM              100"
echo "CKPTINTVL           3600"
echo "BUFFERPOOL size=2K,buffers=1000,lrus=4,lru_min_dirty=50,lru_max_dirty=60"
echo "BUFFERPOOL size=4K,buffers=50000,lrus=64,lru_min_dirty=50.00,lru_max_dirty=60.00"
echo " "
echo "Press return to continue or interrupt to quit..."
read a

echo "Restarting instance ..."
onmode -ky
oninit

DBSPACE=test_dbs

if [ "`onstat -d | grep $DBSPACE`" = "" ]
then
  echo "Creating dbspace datadbs ..."
  dbaccess sysadmin -<<END
  execute function task("create dbspace from storagepool","$DBSPACE","3500 MB",4);
END
else
  echo "drop database db1" | dbaccess - - >/dev/null 2>&1
fi

cat > load.sql <<END
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
insert into tab1 select * from tab1_ext;
alter table tab1 type (standard);
END

cat > create.sql <<END
create database db1 in $DBSPACE with log;
create raw table tab1
  (
    id smallint ,
    chr1 char(3) ,
    chr2 char(1) ,
    vchr1 varchar(50,10) ,
    vchr2 varchar(250,10),
    vchr3 varchar(250,10)
   )
  lock mode row;
create external table tab1_ext sameas tab1 using (datafiles("DISK:tab1.unl"));
END

cat > tf1 <<END
1|bbb|A|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|
2|bbb|A|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|
3|bbb|A|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|
4|bbb|A|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|
5|bbb|A|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|
6|bbb|A|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|
7|bbb|A|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|
8|bbb|A| | | |
9|bbb|A| | | |
END

cat tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 > tf2
cat tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 > tf1
cat tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 > tf2
cat tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 > tf1
rm tf2
cat tf1 tf1 tf1 tf1 > tab1.unl
rm tf1

cat > tf1 <<END
1|bbb|A|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxa|
END

cat tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 > tf2
cat tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 > tf1
cat tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 tf1 > tf2
rm tf1
cat tf2 tf2 tf2 tf2 tf2 tf2 tf2 tf2 > tab1_small.unl
rm tf2

cat > insert.sh <<END1
dbaccess db1 -<<END2
load from tab1_small.unl  insert into tab1;
END2
END1

echo "Creating table and loading data ..."
dbaccess - create
dbaccess db1 load

ontape -s -L 0 -t /dev/null <<END

END

dbaccess sysadmin -<<END
execute function task("table shrink","tab1","db1");
database db1;
delete from tab1 where rowid < 1032705;
database sysadmin;
execute function task("table pfsc_boost enable","tab1","db1");
END

echo "Restarting instance ..."
onmode -ky
oninit
export DBDELIMITER=""
dbaccess db1 -<<END
unload to /tmp/nrows.out select count(*)::INTEGER from tab1;
END
unset DBDELIMITER

NROWS=`cat /tmp/nrows.out`
PARTNUM=`onstat -T | grep $NROWS | awk '{print $5}'`
if [ "${PARTNUM}x" == "x" ]
then
    echo "Error: Could not determine partnum of db1:tab1"
    exit 1
fi

# Wait for PFSC to finish being refreshed
while true
do
onstat -g pfsc | grep "B-" > /dev/null 2>&1
if [ $? -eq 0 ]
then
    break
fi
sleep 1
done

echo " "
echo "We're ready to run the test, which will fire off two small loads"
echo "simultaneously. The table has been carefully structured to force these"
echo "inserters to scan the entire table looking for space if a boosted pfsc"
echo "is not in use."
echo "Press return to continue...."
read a
cat > time1.sh <<END
time sh insert.sh 
END
sh time1.sh > time1.out 2>&1 &
sh time1.sh 

