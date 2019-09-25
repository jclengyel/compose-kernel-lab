echo " "
echo "This script will demonstrate the quick migration of a 3-chunk DBspace"
echo "from one set of devices to another using the mirror swapping feature."
echo "Your server should be running, and you will need to ensure that MIRROR"
echo "is set to 1 in memory first."
echo " "
echo "Press return to create the DBspace..."
read a
echo "Dropping (hopefully empty) test dbspace..."
dbaccess sysadmin -<<END > /dev/null 2>&1
execute function task("drop dbspace","ms_testdbs");
END
echo " "
echo "Creating ms_testdbs..."
dbaccess sysadmin -<<END
execute function task("create dbspace from storagepool","ms_testdbs",100000);
execute function task("create chunk from storagepool","ms_testdbs",100000);
execute function task("create chunk from storagepool","ms_testdbs",100000);
END

export DBDELIMITER=""
dbaccess sysmaster -<<END > /dev/null 2>&1
unload to /tmp/chunk_names.out select fname from syschunks c, sysdbspaces d
where c.dbsnum = d.dbsnum and d.name  = "ms_testdbs";
END
unset DBDELIMITER
OPATH1=`head -1 /tmp/chunk_names.out`
OPATH2=`head -2 /tmp/chunk_names.out | tail -1`
OPATH3=`tail -1 /tmp/chunk_names.out`

echo " "
onstat -d
echo " "
echo "You should see in the onstat -d output above that the ms_testdbs DBspace"
echo "contains the following 3 chunks:"
echo " "
echo $OPATH1
echo $OPATH2
echo $OPATH3
echo " "
echo "Now, enter the full paths to 3 new cooked chunks to which you'd like"
echo "your space migrated, one path on each line below:"
read NPATH1
read NPATH2
read NPATH3
echo " "
echo "Okay, I'm ready to move the dbspace to these new devices:"
echo " "
echo $NPATH1
echo $NPATH2
echo $NPATH3
echo " "
echo "Like any devices used for IDS chunks they will need to exist, with the"
echo "proper ownerships and permissions. Once that's the case, press return"
echo "to migrate the space without downtime."
read a

echo "$OPATH1 0 $NPATH1 0" > chunk_loc.out
echo "$OPATH2 0 $NPATH2 0" >> chunk_loc.out
echo "$OPATH3 0 $NPATH3 0" >> chunk_loc.out

onspaces -m ms_testdbs -f chunk_loc.out

dbaccess sysadmin -<<END
execute function task("modify space swap_mirrors","ms_testdbs");
execute function task("stop mirroring","ms_testdbs");
END

onstat -d
