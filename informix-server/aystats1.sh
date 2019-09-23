echo " "
echo "IIUG 2019 Kernel Lab AYSTATS1 script"
echo " "
echo "Are you smarter than a tech supporter? Let's see! This script will"
echo "reinitialize your instance and corrupt something on disk. oncheck"
echo "will indicate the error. Your job will be to find *and fix* that problem"
echo "using tbpatch. Ready to go? Remember, this script will wipe out your"
echo "current instance. Press return to continue."
read a
echo "Shutting down instance..."
onmode -ky

echo " "
echo "Initializing instance from scratch..."
echo " "
oninit -iwy

# Creating unload file
cat > t.c <<END
main()
    {
    int i;

    for (i=0;i<1000;i++)
        printf("%d|Hello %d|\n",i,i);
    }
END
cc t.c -o t > /dev/null 2>&1
t > jctab.unl

# Creating database and table
dbaccess - -<<END
create database jc;
create table jctab (col1 int, col2 char(20));
load from jctab.unl insert into jctab;
create index jcind on jctab (col2);
END

# Determine the partnum of our jctab table
PARTNUM=`oncheck -pt jc:jctab | grep "Partition partnum" | head -1 | awk '{print $3}'`

# Sanity check PARTNUM
if [ $PARTNUM -le 1048577 -o $PARTNUM -ge 2097153 ]
then
    echo "Something went wrong (error 1). Please get jc :)"
    exit -1
fi

# Determine the physical offset of page 10 in the partition
PGNUM=`oncheck -pp $PARTNUM 10 | grep DATA | awk '{print $1}' | cut -c3-10`

# Sanity check PGNUM
if [ $PGNUM -le 100 -o $PGNUM -ge 1000000 ]
then
    echo "Something went wrong (error 2). Please get jc :)"
    exit -1
fi

ROOTPATH=`onstat -g cfg ROOTPATH | grep ROOTPATH | awk '{print $2}'`
if [ -f "$ROOTPATH" ]
then
    onmode -B reset
    sleep 2
    echo "If this script has generated no errors, press return to continue."
    echo "Otherwise interrupt it and get jc to help :)"
    read a
    tbpatch -d $ROOTPATH -o $PGNUM -b 0x604 -s "JC WAS HERE"
    echo "Script complete. Now run 'oncheck -cDI jc:jctab', find the problem,"
    echo "and fix it using tbpatch."
    echo "Have fun!"
else
    echo "Something went wrong (error 3). Please get jc :)"
    exit -1
fi
