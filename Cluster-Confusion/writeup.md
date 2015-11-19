## Cluster Confusion Lab

Group: Derek Remund, Gene Tang

### 1. Existing Architecture:

##### `nodetool status` Output:

```
root@node0:~# nodetool status
Datacenter: nearby
==================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address         Load       Tokens  Owns    Host ID                               Rack
UN  52.33.169.96    9.69 GB    1       ?       8cbb769b-39d1-4312-9669-02910bc37849  RAC1
UN  52.33.124.181   11.88 GB   1       ?       4f7607de-a6ff-4ebb-83c8-f9703a9b186c  RAC1
UN  52.11.89.205    6.11 GB    1       ?       c716cb53-41de-44b6-810e-684eadb0b3b8  RAC1
DN  52.32.41.24     8.98 GB    1       ?       8cae35ac-0f1b-481a-8ecd-03b6e62f79ae  RAC1
DN  52.33.253.121   7.42 GB    1       ?       d3b850f9-2134-40d0-9e03-9fe334c9dc67  RAC1
Datacenter: faraway
===================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address         Load       Tokens  Owns    Host ID                               Rack
UN  54.169.190.74   7.72 GB    1       ?       b8d1cdf0-894e-471d-ae99-c1512993637a  RAC1
UN  54.169.187.114  6.49 MB    1       ?       23ac7084-8237-428e-9868-6ada5a2c2488  RAC1
?N  172.31.3.194    11.11 GB   1       ?       97eb29ff-2d3a-4a25-994a-79743fe2eef4  RAC1
UN  54.169.186.166  10.88 GB   1       ?       b2feeb90-0e80-4690-a987-8cfedf27ec14  RAC1
```

##### `nodetool tpstats` Output:
```
root@node1:~# nodetool tpstats
Pool Name                	Active   Pending  	Completed   Blocked  All time blocked
MutationStage                 	0     	0      	11455     	0             	0
ReadStage                     	0     	0        	263     	0             	0
RequestResponseStage          	0     	0        	743     	0             	0
ReadRepairStage               	0     	0         	25     	0             	0
CounterMutationStage          	0     	0          	0     	0             	0
MiscStage                     	0     	0          	0     	0             	0
HintedHandoff                 	0     	0         	14     	0             	0
GossipStage                   	0     	0        	527     	0             	0
CacheCleanupExecutor          	0     	0          	0     	0             	0
InternalResponseStage         	0     	0          	0     	0             	0
CommitLogArchiver             	0     	0          	0     	0             	0
CompactionExecutor            	0     	0         	39     	0             	0
ValidationExecutor            	0     	0          	0     	0             	0
MigrationStage                	0     	0          	0     	0             	0
AntiEntropyStage              	0     	0          	0     	0             	0
PendingRangeCalculator        	0     	0         	11     	0             	0
Sampler                       	0     	0          	0     	0             	0
MemtableFlushWriter           	0     	0         	23     	0             	0
MemtablePostFlush             	0     	0         	40     	0             	0
MemtableReclaimMemory         	0     	0         	23     	0             	0

Message type       	Dropped
READ                     	0
RANGE_SLICE              	0
_TRACE                   	0
MUTATION                 	0
COUNTER_MUTATION         	0
BINARY                   	0
REQUEST_RESPONSE         	0
PAGED_RANGE              	0
READ_REPAIR              	0
```


##### Server Configurations:

All are AWS m3.large:

```
root@node0:/etc/cassandra# curl http://169.254.169.254/latest/meta-data/instance-type
m3.large
```

Thus, they have 2 vCPUs, 7.5GB RAM, and 32GB of SSD ephemeral storage.

### 2. Resolving Offline Nodes

#### Node 5 

**Symptom:** 

Reporting unknown status:
```
?N  172.31.3.194	11.11 GB   1   	?   	97eb29ff-2d3a-4a25-994a-79743fe2eef4  RAC1
```

**Diagnosis:**

Node 5 is the only node displaying a private IP address in `nodetool status`.  This suggests that the broadcast address is incorreclty set in `cassandra.yaml`:

Compare node5 to known working node0:
```
root@node5:/etc/cassandra# grep broadcast_address: /etc/cassandra/cassandra.yaml
#broadcast_address: 54.169.188.8
root@node0:~# grep broadcast_address: /etc/cassandra/cassandra.yaml
broadcast_address: 52.33.124.181
```

**Resolution:**

Uncomment the `broadcast_address` variable:
```
broadcast_address: 54.169.188.8

root@node5:/etc/cassandra# service cassandra restart
 * Restarting Cassandra cassandra
```

#### Node 3

**Symptom:** 

Reporting down status.

Attempt to start Cassandra:
```
root@node3:~# service cassandra start
```

Check `/var/log/cassandra/system.log`:

```
java.lang.RuntimeException: Cannot replace address with a node that is already bootstrapped
    	at org.apache.cassandra.service.StorageService.prepareToJoin(StorageService.java:774) ~[apache-cassandra-2.1.9.jar:2.1.9]
    	at org.apache.cassandra.service.StorageService.initServer(StorageService.java:720) ~[apache-cassandra-2.1.9.jar:2.1.9]
    	at org.apache.cassandra.service.StorageService.initServer(StorageService.java:611) ~[apache-cassandra-2.1.9.jar:2.1.9]
    	at org.apache.cassandra.service.CassandraDaemon.setup(CassandraDaemon.java:378) [apache-cassandra-2.1.9.jar:2.1.9]
    	at org.apache.cassandra.service.CassandraDaemon.activate(CassandraDaemon.java:537) [apache-cassandra-2.1.9.jar:2.1.9]
    	at org.apache.cassandra.service.CassandraDaemon.main(CassandraDaemon.java:626) [apache-cassandra-2.1.9.jar:2.1.9]
```

**Diagnosis:** 

`/etc/cassandra/cassandra-env.sh` has an erroneous replace flag:
```
JVM_OPTS="$JVM_OPTS -Dcassandra.replace_address=123.123.123.123"
```

**Resolution:** 

Remove the erroneous statement and start Cassandra:
```
root@node3:~# service cassandra start
```

Node3 is now running:

```
root@node0:~# nodetool status
Datacenter: nearby
==================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     	Load   	Tokens  Owns	Host ID                           	Rack
UN  52.33.169.96	9.69 GB	1   	?   	8cbb769b-39d1-4312-9669-02910bc37849  RAC1
UN  52.33.124.181   59.94 KB   1   	?   	f47e9832-df36-4b84-8b47-49eba615383f  RAC1
UN  52.11.89.205	6.11 GB	1   	?   	c716cb53-41de-44b6-810e-684eadb0b3b8  RAC1
UN  52.33.253.121   7.42 GB	1   	?   	d3b850f9-2134-40d0-9e03-9fe334c9dc67  RAC1
Datacenter: faraway
===================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     	Load   	Tokens  Owns	Host ID                           	Rack
UN  54.169.188.8	11.12 GB   1   	?   	97eb29ff-2d3a-4a25-994a-79743fe2eef4  RAC1
UN  54.169.190.74   7.72 GB	1   	?   	b8d1cdf0-894e-471d-ae99-c1512993637a  RAC1
UN  54.169.187.114  25 MB  	1   	?   	23ac7084-8237-428e-9868-6ada5a2c2488  RAC1
UN  54.169.186.166  10.88 GB   1   	?   	b2feeb90-0e80-4690-a987-8cfedf27ec14  RAC1
```

#### Node1

**Symptom:** 

Reporting down status.

```
DN  52.32.41.24 	8.98 GB	1   	?   	8cae35ac-0f1b-481a-8ecd-03b6e62f79ae  RAC1
```

Attempting to start Cassandra daemon results in Cassandra failure with the following in the logs:
```
ERROR [MemtableFlushWriter:8] 2015-11-16 00:55:47,052 CassandraDaemon.java:223 - Exception in thread Thread[MemtableFlushWriter:8,5,main]
java.lang.RuntimeException: Insufficient disk space to write 1144946 bytes
    	at org.apache.cassandra.io.util.DiskAwareRunnable.getWriteDirectory(DiskAwareRunnable.java:29) ~[apache-cassandra-2.1.9.jar:2.1.9]
    	at org.apache.cassandra.db.Memtable$FlushRunnable.runMayThrow(Memtable.java:332) ~[apache-cassandra-2.1.9.jar:2.1.9]
    	at org.apache.cassandra.utils.WrappedRunnable.run(WrappedRunnable.java:28) ~[apache-cassandra-2.1.9.jar:2.1.9]
    	at com.google.common.util.concurrent.MoreExecutors$SameThreadExecutorService.execute(MoreExecutors.java:297) ~[guava-16.0.jar:na]
    	at org.apache.cassandra.db.ColumnFamilyStore$Flush.run(ColumnFamilyStore.java:1154) ~[apache-cassandra-2.1.9.jar:2.1.9]
    	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142) ~[na:1.8.0_66]
    	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617) ~[na:1.8.0_66]
    	at java.lang.Thread.run(Thread.java:745) ~[na:1.8.0_66]
```

**Diagnosis:**

Insufficient disk space on the ephemeral disk:

```
root@node1:~# df -h
Filesystem                       Size  Used Avail Use% Mounted on
/dev/xvda                        9.8G  1.7G  7.6G  18% /
none                             4.0K     0  4.0K   0% /sys/fs/cgroup
udev                             3.7G   12K  3.7G   1% /dev
tmpfs                            752M  212K  752M   1% /run
none                             5.0M     0  5.0M   0% /run/lock
none                             3.7G     0  3.7G   0% /run/shm
none                             100M     0  100M   0% /run/user
/dev/mapper/vg--data-ephemeral0   30G   28G  4.0K 100% /mnt/ephemeral
```

**Resolution:**

Inspection of the data directory of Cassandra (/mnt/ephemeral/cassandra) reveals the directory is indeed full and an erroneous file “.hugefile” taking up the space on the ephermeral disk:
```
root@node1:/mnt/ephemeral# du -sklh *
29G	cassandra
16K	lost+found
root@node1:/mnt/ephemeral# cd cassandra/
root@node1:/mnt/ephemeral/cassandra# du -sklh *
135M	commitlog
10G	data
4.0K	saved_caches

root@node1:/mnt/ephemeral/cassandra# ls -la
total 19756576
drwxr-xr-x 5 cassandra cassandra        4096 Nov 16 22:02 .
drwxr-xr-x 4 root      root             4096 Nov 15 22:31 ..
drwxr-xr-x 2 cassandra cassandra        4096 Nov 16 22:15 commitlog
drwxr-xr-x 6 cassandra cassandra        4096 Nov 16 22:02 data
-rw-r--r-- 1 root      root      20230676480 Nov 16 00:55 .hugefile
drwxr-xr-x 2 cassandra cassandra        4096 Nov 16 22:02 saved_caches
```
Removing the .hugefile file will release the disk space for Cassandra to use.
```
root@node1:/mnt/ephemeral/cassandra# rm .hugefile
```

Restart Cassandra on node1 initiates the stream of data again.

Nodetool Status reports node1 is up:
```
root@node0:~# nodetool status
Datacenter: nearby
==================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     	Load   	Tokens  Owns	Host ID                           	Rack
UN  52.33.169.96	9.69 GB	1   	?   	8cbb769b-39d1-4312-9669-02910bc37849  RAC1
UN  52.33.124.181   59.94 KB   1   	?   	f47e9832-df36-4b84-8b47-49eba615383f  RAC1
UN  52.11.89.205	6.11 GB	1   	?   	c716cb53-41de-44b6-810e-684eadb0b3b8  RAC1
UN  52.32.41.24 	215.55 KB  1   	?   	fc20f78b-c29c-4d3d-8fd5-fcaffd3da630  RAC1
UN  52.33.253.121   7.42 GB	1   	?   	d3b850f9-2134-40d0-9e03-9fe334c9dc67  RAC1
Datacenter: faraway
===================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     	Load   	Tokens  Owns	Host ID                           	Rack
UN  54.169.188.8	11.12 GB   1   	?   	97eb29ff-2d3a-4a25-994a-79743fe2eef4  RAC1
UN  54.169.190.74   7.72 GB	1   	?   	b8d1cdf0-894e-471d-ae99-c1512993637a  RAC1
UN  54.169.187.114  25 MB  	1   	?   	23ac7084-8237-428e-9868-6ada5a2c2488  RAC1
UN  54.169.186.166  10.88 GB   1   	?   	b2feeb90-0e80-4690-a987-8cfedf27ec14  RAC1
```

#### Repair

Run `nodetool repair` on previously-down nodes to ensure all data is correctly synchronised once all nodes have been brought up.

### 3. Fixing Opscenter Keyspace

**Problem:** 

Opscenter reports that its keyspace is not using a DC-aware strategy.  This is counter to the use of multiple datacenters. 

**Resolution:**

Update the keyspace to use a more appropriate strategy:

```
cqlsh> desc keyspace "OpsCenter"

CREATE KEYSPACE "OpsCenter" WITH replication = {'class': 'NetworkTopologyStrategy', 'faraway': '1', 'nearby': '3'}  AND durable_writes = true;
```

### 4. Cluster Optimization

Initial cluster performance as tested with jmeter is quite poor:

```
root@workstation:~/labwork/jmetertest# jmeter -n -t confusion.jmx -l jmeter-log
Creating summariser <summary>
Created the tree successfully using confusion.jmx
Starting the test @ Mon Nov 16 20:54:07 UTC 2015 (1447707247661)
Waiting for possible shutdown message on port 4445

0: Write trades                                85 in    20s =    4.3/s Avg:   203 Min:   161 Max:  1593 Err:    85 (100.00%)
1: Write trades_by_tickerday                   84 in  18.4s =    4.6/s Avg:    90 Min:     1 Max:   678 Err:     0 (0.00%)
3: Write trades_by_datehour                    82 in    18s =    4.6/s Avg:   306 Min:   161 Max:   839 Err:     0 (0.00%)
4: Trade by id                                 47 in  19.4s =    2.4/s Avg:   493 Min:   162 Max:  1503 Err:     0 (0.00%)
5: 10 Minute Range By Ticker First 10          31 in    18s =    1.8/s Avg:   432 Min:   162 Max:  1243 Err:     0 (0.00%)
6: 10 Minute Count By Ticker                   33 in    16s =    2.1/s Avg:   472 Min:   162 Max:  1336 Err:     1 (3.03%)
7: 1 Minute Range By Hour First 10             40 in  17.4s =    2.3/s Avg:   869 Min:   164 Max:  5342 Err:     4 (10.00%)
summary:                                 +    402 in    20s =   20.1/s Avg:   340 Min:     1 Max:  5342 Err:    90 (22.39%) Active: 14 Started: 14 Finished: 0

0: Write trades                               294 in  30.2s =    9.7/s Avg:   186 Min:   160 Max:   350 Err:   294 (100.00%)
1: Write trades_by_tickerday                  293 in    30s =    9.8/s Avg:    86 Min:     0 Max:   322 Err:     0 (0.00%)
3: Write trades_by_datehour                   293 in  30.5s =    9.6/s Avg:   324 Min:   161 Max:   680 Err:     0 (0.00%)
4: Trade by id                                122 in  30.3s =    4.0/s Avg:   466 Min:   162 Max:  1120 Err:     0 (0.00%)
5: 10 Minute Range By Ticker First 10         152 in    31s =    4.9/s Avg:   485 Min:   162 Max:  1301 Err:     2 (1.32%)
6: 10 Minute Count By Ticker                  153 in  30.1s =    5.1/s Avg:   535 Min:   161 Max:  2180 Err:     2 (1.31%)
7: 1 Minute Range By Hour First 10            116 in  31.2s =    3.7/s Avg:  1053 Min:   162 Max:  5163 Err:    17 (14.66%)
summary:                                 +   1423 in  31.3s =   45.4/s Avg:   358 Min:     0 Max:  5163 Err:   315 (22.14%) Active: 18 Started: 18 Finished: 0
summary:                                 =   1825 in    50s =   36.5/s Avg:   354 Min:     0 Max:  5342 Err:   405 (22.19%)

0: Write trades                               299 in    30s =   10.0/s Avg:   181 Min:   160 Max:   406 Err:   299 (100.00%)
1: Write trades_by_tickerday                  300 in    30s =   10.0/s Avg:    96 Min:     0 Max:   304 Err:     0 (0.00%)
3: Write trades_by_datehour                   298 in  30.2s =    9.9/s Avg:   324 Min:   161 Max:   762 Err:     0 (0.00%)
4: Trade by id                                118 in  29.1s =    4.1/s Avg:   512 Min:   162 Max:  1166 Err:     0 (0.00%)
5: 10 Minute Range By Ticker First 10         127 in  30.3s =    4.2/s Avg:   491 Min:   162 Max:  1368 Err:     2 (1.57%)
6: 10 Minute Count By Ticker                  135 in  30.2s =    4.5/s Avg:   506 Min:   161 Max:  1437 Err:     4 (2.96%)
7: 1 Minute Range By Hour First 10            148 in    34s =    4.4/s Avg:  1195 Min:   161 Max:  6129 Err:    25 (16.89%)
summary:                                 +   1425 in    34s =   42.1/s Avg:   384 Min:     0 Max:  6129 Err:   330 (23.16%) Active: 18 Started: 18 Finished: 0
summary:                                 =   3250 in  80.1s =   40.6/s Avg:   367 Min:     0 Max:  6129 Err:   735 (22.62%)
```

We will explore several possible solutions.

#### Data Imbalances

**Problem:** 

Data is imbalanced across the cluster with some nodes holding signficantly more data than others:

```
root@node0:~# nodetool status
Datacenter: nearby
==================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     	Load   	Tokens  Owns	Host ID                           	Rack
UN  52.33.169.96	9.69 GB	1   	?   	8cbb769b-39d1-4312-9669-02910bc37849  RAC1
UN  52.33.124.181   59.94 KB   1   	?   	f47e9832-df36-4b84-8b47-49eba615383f  RAC1
UN  52.11.89.205	6.11 GB	1   	?   	c716cb53-41de-44b6-810e-684eadb0b3b8  RAC1
UN  52.32.41.24 	215.55 KB  1   	?   	fc20f78b-c29c-4d3d-8fd5-fcaffd3da630  RAC1
UN  52.33.253.121   7.42 GB	1   	?   	d3b850f9-2134-40d0-9e03-9fe334c9dc67  RAC1
Datacenter: faraway
===================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     	Load   	Tokens  Owns	Host ID                           	Rack
UN  54.169.188.8	11.12 GB   1   	?   	97eb29ff-2d3a-4a25-994a-79743fe2eef4  RAC1
UN  54.169.190.74   7.72 GB	1   	?   	b8d1cdf0-894e-471d-ae99-c1512993637a  RAC1
UN  54.169.187.114  25 MB  	1   	?   	23ac7084-8237-428e-9868-6ada5a2c2488  RAC1
UN  54.169.186.166  10.88 GB   1   	?   	b2feeb90-0e80-4690-a987-8cfedf27ec14  RAC1
```

The cluster is using single-token nodes with unevenly distributed token ranges, which can be seen with `nodetool ring` or simply by examining the Opscenter interface: http://cb889f1243b03baffe28-412ed90bcf7411fa0e77ed8d19b04771.r5.cf1.rackcdn.com/tokens.png

**Resolution:**

Rebalance cluster to use more evenly distributed tokens.

Per http://docs.datastax.com/en/datastax_enterprise/4.8/datastax_enterprise/deploy/deployCalcTokens.html, treat each datacenter as though it has its own complete ring.  We will use an offset of +100 to avoid collisions with future node addtions.

We will assign the following tokens:

```
Faraway DC
node5: -9223372036854775708
node6: -4611686018427387804 
node7: 100
node8: 4611686018427388004

Nearby DC
node0: -9223372036854775808
node1:  -5534023222112865485
node2:  -1844674407370955162
node3: 1844674407370955161
node4: 5534023222112865484
```

We utilize `nodetool` to move the nodes one at a time.  For example:

```
node5: nodetool move -- -9223372036854775708.
```

After nodes are moved, we run `nodetool cleanup` on each node to remove data no longer required by that node.

After token reallocation the ring has been balanced:

```
root@node0:~# nodetool ring

Datacenter: nearby
==========
Address     	Rack    	Status State   Load        	Owns            	Token                                  	 
                                                                           	5534023222112865484                    	 
52.33.124.181   RAC1    	Up 	Normal  7.95 GB     	?               	-9223372036854775808                   	 
52.32.41.24 	RAC1    	Up 	Normal  9.72 GB     	?               	-5534023222112865485                   	 
52.11.89.205	RAC1    	Up 	Normal  10.33 GB    	?               	-1844674407370955162                   	 
52.33.253.121   RAC1    	Up 	Normal  12.38 GB    	?               	1844674407370955161                    	 
52.33.169.96	RAC1    	Up 	Normal  7.83 GB     	?               	5534023222112865484                    	 

Datacenter: faraway
==========
Address     	Rack    	Status State   Load        	Owns            	Token                                  	 
                                                                           	4611686018427388004                    	 
54.169.188.8	RAC1    	Up 	Normal  7.73 GB     	?               	-9223372036854775708                   	 
54.169.186.166  RAC1    	Up 	Normal  9.94 GB     	?               	-4611686018427387804                   	 
54.169.190.74   RAC1    	Up 	Normal  10.17 GB    	?               	100                                    	 
54.169.187.114  RAC1    	Up 	Normal  9.49 GB     	?               	4611686018427388004
```

All nodes are now up with improved data distibution:

After token reallocation, data is now more evenly distributed:
```
root@node0:~# nodetool status
Datacenter: nearby
==================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     	Load   	Tokens  Owns	Host ID                           	Rack
UN  52.33.169.96	7.83 GB	1   	?   	b3a104f0-dc6f-4477-b673-879b23140114  RAC1
UN  52.33.124.181   7.95 GB	1   	?   	f47e9832-df36-4b84-8b47-49eba615383f  RAC1
UN  52.11.89.205	10.33 GB   1   	?   	c716cb53-41de-44b6-810e-684eadb0b3b8  RAC1
UN  52.32.41.24 	9.72 GB	1   	?   	fc20f78b-c29c-4d3d-8fd5-fcaffd3da630  RAC1
UN  52.33.253.121   12.38 GB   1   	?   	d3b850f9-2134-40d0-9e03-9fe334c9dc67  RAC1
Datacenter: faraway
===================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     	Load   	Tokens  Owns	Host ID                           	Rack
UN  54.169.188.8	7.73 GB	1   	?   	97eb29ff-2d3a-4a25-994a-79743fe2eef4  RAC1
UN  54.169.190.74   10.17 GB   1   	?   	b8d1cdf0-894e-471d-ae99-c1512993637a  RAC1
UN  54.169.187.114  9.49 GB	1   	?   	23ac7084-8237-428e-9868-6ada5a2c2488  RAC1
UN  54.169.186.166  9.94 GB	1   	?   	b2feeb90-0e80-4690-a987-8cfedf27ec14  RAC1

```

Performance has improved somewhat:

```
0: Write trades                               243 in    30s =    8.1/s Avg:   318 Min:   162 Max:   657 Err:     0 (0.00%)
1: Write trades_by_tickerday                  242 in    30s =    8.1/s Avg:    57 Min:     1 Max:   262 Err:     0 (0.00%)
3: Write trades_by_datehour                   241 in    30s =    8.1/s Avg:   193 Min:     1 Max:   532 Err:     0 (0.00%)
4: Trade by id                                257 in  30.4s =    8.5/s Avg:   238 Min:     3 Max:  1246 Err:     0 (0.00%)
5: 10 Minute Range By Ticker First 10         227 in    29s =    7.8/s Avg:   323 Min:     2 Max:  1595 Err:     0 (0.00%)
6: 10 Minute Count By Ticker                  221 in    30s =    7.4/s Avg:   321 Min:     2 Max:  1472 Err:     0 (0.00%)
7: 1 Minute Range By Hour First 10            197 in    30s =    6.7/s Avg:   296 Min:     1 Max:  1214 Err:     0 (0.00%)
summary:                                 +   1628 in    31s =   53.1/s Avg:   247 Min:     1 Max:  1595 Err:     0 (0.00%) Active: 18 Started: 18 Finished: 0
summary:                                 =   1701 in  37.3s =   45.6/s Avg:   249 Min:     1 Max:  1724 Err:     0 (0.00%)
```

#### Heap Configuration

**Problem:**

The `nearby` datacenter has poorly-configured heap values in `/etc/cassandra/cassandra-env.sh`:

```
MAX_HEAP_SIZE="6G"
HEAP_NEWSIZE="4G"
```

**Resolution:**

Given that these machines have two cores and 8GB of memory, fix these values (or althernatively comment out the options to allow for automatic calculation):

```
MAX_HEAP_SIZE="2G"
HEAP_NEWSIZE="200M"
```

After these changes another slight performance increase is observed:

```
0: Write trades                               309 in  30.3s =   10.2/s Avg:   331 Min:   162 Max:   639 Err:     0 (0.00%)
1: Write trades_by_tickerday                  309 in  30.1s =   10.3/s Avg:    52 Min:     1 Max:   166 Err:     0 (0.00%)
3: Write trades_by_datehour                   309 in  30.2s =   10.2/s Avg:   199 Min:     1 Max:   570 Err:     0 (0.00%)
4: Trade by id                                299 in  30.2s =    9.9/s Avg:   211 Min:     2 Max:  1124 Err:     0 (0.00%)
5: 10 Minute Range By Ticker First 10         304 in    31s =    9.9/s Avg:   330 Min:     1 Max:  1440 Err:     0 (0.00%)
6: 10 Minute Count By Ticker                  309 in  30.4s =   10.2/s Avg:   310 Min:     2 Max:  1738 Err:     0 (0.00%)
7: 1 Minute Range By Hour First 10            304 in    31s =    9.9/s Avg:   327 Min:     2 Max:  1271 Err:     0 (0.00%)
summary:                                 +   2143 in    31s =   69.2/s Avg:   251 Min:     1 Max:  1738 Err:     0 (0.00%) Active: 18 Started: 18 Finished: 0
summary:                                 =   3844 in  67.3s =   57.1/s Avg:   250 Min:     1 Max:  1738 Err:     0 (0.00%)
```

#### JMeter / `confusion.jmx` Optimizations

Running jmeter with the `readwrite.jmx` configuration results in far better performance than the `confusion.jmx` workload:

```
oot@workstation:~/labwork/jmetertest# jmeter -n -t readwrite.jmx
Creating summariser <summary>
Created the tree successfully using readwrite.jmx
Starting the test @ Tue Nov 17 16:02:05 UTC 2015 (1447776125020)
Waiting for possible shutdown message on port 4445

0: Write trades                             13559 in  23.5s =  578.1/s Avg:     1 Min:     0 Max:   118 Err:     0 (0.00%)
1: Write trades_by_tickerday                13554 in  23.4s =  580.3/s Avg:     1 Min:     0 Max:   120 Err:     0 (0.00%)
2: Write trades_by_datehour                 13554 in  23.3s =  580.7/s Avg:     1 Min:     0 Max:   118 Err:     0 (0.00%)
3: Trade by id                               3572 in  22.3s =  160.3/s Avg:     3 Min:     0 Max:   120 Err:     0 (0.00%)
4: 10 Minute Range By Ticker First 1         3639 in  22.2s =  163.9/s Avg:    12 Min:     0 Max:   415 Err:     0 (0.00%)
5: 1 Minute Range By Hour First 1            3581 in  22.3s =  160.9/s Avg:    16 Min:     0 Max:   425 Err:     0 (0.00%)
summary:                                 +  51459 in  23.5s = 2194.1/s Avg:     3 Min:     0 Max:   425 Err:     0 (0.00%) Active: 15 Started: 15 Finished: 0

0: Write trades                             27535 in    30s =  918.0/s Avg:     2 Min:     0 Max:   119 Err:     0 (0.00%)
1: Write trades_by_tickerday                27539 in    30s =  917.9/s Avg:     2 Min:     0 Max:   123 Err:     0 (0.00%)
2: Write trades_by_datehour                 27534 in    30s =  917.9/s Avg:     2 Min:     0 Max:   111 Err:     0 (0.00%)
3: Trade by id                              10154 in    30s =  338.5/s Avg:     3 Min:     0 Max:   107 Err:     0 (0.00%)
4: 10 Minute Range By Ticker First 1        10166 in  30.1s =  338.2/s Avg:    13 Min:     0 Max:   324 Err:     0 (0.00%)
5: 1 Minute Range By Hour First 1           10155 in  30.1s =  337.3/s Avg:    16 Min:     0 Max:   329 Err:     0 (0.00%)
summary:                                 + 113083 in  30.1s = 3755.8/s Avg:     4 Min:     0 Max:   329 Err:     0 (0.00%) Active: 18 Started: 18 Finished: 0
summary:                                 = 164542 in  53.5s = 3078.3/s Avg:     4 Min:     0 Max:   425 Err:     0 (0.00%)
```

This indicates that we should consider modifying the workload itself to improve performance while maintaining the spirit of the test.

**Problem:**

The operations in confusion.jmx are using higher consistency levels than necessary, including some operations using ALL or non-local QUORUM.  This is contributing unnecessary latency to our tests.

**Resolution:**

Take advantage of Cassandra's fast writes while maintaining consistency.  

Set read operation consistency levels to LOCAL_ONE:

```
<stringProp name="consistencyLevel">LOCAL_ONE</stringProp>
```
Set write operation consistency levels to LOCAL_QUORUM:
```
<stringProp name="consistencyLevel">LOCAL_QUORUM</stringProp>
```

After these changes there is a signficant, although not sufficient, improvement in our JMeter testing performance:

```
0: Write trades                               770 in    30s =   25.8/s Avg:    76 Min:     1 Max:   195 Err:     0 (0.00%)
1: Write trades_by_tickerday                  773 in    30s =   25.7/s Avg:    76 Min:     1 Max:   191 Err:     0 (0.00%)
3: Write trades_by_datehour                   772 in    30s =   25.7/s Avg:    79 Min:     1 Max:   170 Err:     0 (0.00%)
4: Trade by id                               1259 in  30.1s =   41.8/s Avg:    71 Min:     0 Max:   200 Err:     0 (0.00%)
5: 10 Minute Range By Ticker First 10        1248 in  30.1s =   41.4/s Avg:    71 Min:     0 Max:   193 Err:     0 (0.00%)
6: 10 Minute Count By Ticker                 1256 in  30.1s =   41.7/s Avg:    72 Min:     0 Max:   229 Err:     0 (0.00%)
7: 1 Minute Range By Hour First 10           1232 in    30s =   41.0/s Avg:    72 Min:     0 Max:   196 Err:     0 (0.00%)
summary:                                 +   7310 in  30.2s =  242.4/s Avg:    73 Min:     0 Max:   229 Err:     0 (0.00%) Active: 18 Started: 18 Finished: 0
summary:                                 =  59001 in   256s =  230.4/s Avg:    73 Min:     0 Max:  1496 Err:     0 (0.00%)
```

#### Change Load-Balancing Policy

**Problem:**

`confusion.jmx` is using round robin load balancing:

```
<stringProp name="loadBalancer">RoundRobin</stringProp>
```

This is not DC-aware and will result in poor performance as non-ideal coordinators are selected.

**Resolution:**

Change load balancing policy to TokenAware(DCAwareRoundRobin):
```
<stringProp name="loadBalancer">TokenAware(DCAwareRoundRobin)</stringProp>
```

After these changes our JMeter tests perform far more ideally:

```
0: Write trades                             13753 in    30s =  458.4/s Avg:     3 Min:     1 Max:   176 Err:     0 (0.00%)
1: Write trades_by_tickerday                13754 in    30s =  458.5/s Avg:     3 Min:     1 Max:   190 Err:     0 (0.00%)
3: Write trades_by_datehour                 13754 in    30s =  458.5/s Avg:     5 Min:     1 Max:   178 Err:     0 (0.00%)
4: Trade by id                               8241 in    30s =  274.7/s Avg:     4 Min:     0 Max:   143 Err:     0 (0.00%)
5: 10 Minute Range By Ticker First 10        8184 in    30s =  272.4/s Avg:    11 Min:     0 Max:   175 Err:     0 (0.00%)
6: 10 Minute Count By Ticker                 8243 in  30.1s =  273.9/s Avg:    13 Min:     0 Max:   624 Err:     0 (0.00%)
7: 1 Minute Range By Hour First 10           8183 in    30s =  272.6/s Avg:    13 Min:     0 Max:   223 Err:     0 (0.00%)
summary:                                 +  74112 in  30.1s = 2462.4/s Avg:     7 Min:     0 Max:   624 Err:     0 (0.00%) Active: 18 Started: 18 Finished: 0
summary:                                 = 157917 in    68s = 2339.0/s Avg:     6 Min:     0 Max:  1325 Err:     0 (0.00%)
```

### Interesting Observations

#### Different Compaction Strategies:

```
cqlsh> desc table stock;

CREATE KEYSPACE stock WITH replication = {'class': 'NetworkTopologyStrategy', 'faraway': '2', 'nearby': '3'}  AND durable_writes = true;

CREATE TABLE stock.trades_by_datehour (
	trade_date timestamp,
	date_hour int,
	trade_timestamp timestamp,
	trade_id int,
	ticker text,
	company_name text,
	description text,
	exchng text,
	extra_id uuid,
	price float,
	quantity int,
	PRIMARY KEY ((trade_date, date_hour), trade_timestamp, trade_id, ticker)
) WITH CLUSTERING ORDER BY (trade_timestamp ASC, trade_id ASC, ticker ASC)
	AND bloom_filter_fp_chance = 0.01
	AND caching = '{"keys":"ALL", "rows_per_partition":"NONE"}'
	AND comment = ''
	AND compaction = {'class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'}
	AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
	AND dclocal_read_repair_chance = 0.1
	AND default_time_to_live = 0
	AND gc_grace_seconds = 864000
	AND max_index_interval = 2048
	AND memtable_flush_period_in_ms = 0
	AND min_index_interval = 128
	AND read_repair_chance = 0.0
	AND speculative_retry = '99.0PERCENTILE';

CREATE TABLE stock.trades (
	trade_id int PRIMARY KEY,
	company_name text,
	description text,
	exchng text,
	extra_id uuid,
	price float,
	quantity int,
	ticker text,
	trade_date timestamp,
	trade_timestamp timestamp
) WITH bloom_filter_fp_chance = 0.01
	AND caching = '{"keys":"ALL", "rows_per_partition":"NONE"}'
	AND comment = ''
	AND compaction = {'class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'}
	AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
	AND dclocal_read_repair_chance = 0.1
	AND default_time_to_live = 0
	AND gc_grace_seconds = 864000
	AND max_index_interval = 2048
	AND memtable_flush_period_in_ms = 0
	AND min_index_interval = 128
	AND read_repair_chance = 1.0
	AND speculative_retry = '99.0PERCENTILE';

CREATE TABLE stock.trades_by_tickerday (
	ticker text,
	trade_date timestamp,
	trade_timestamp timestamp,
	trade_id int,
	company_name text,
	description text,
	exchng text,
	extra_id uuid,
	price float,
	quantity int,
	PRIMARY KEY ((ticker, trade_date), trade_timestamp, trade_id)
) WITH CLUSTERING ORDER BY (trade_timestamp ASC, trade_id ASC)
	AND bloom_filter_fp_chance = 0.01
	AND caching = '{"keys":"ALL", "rows_per_partition":"NONE"}'
	AND comment = ''
	AND compaction = {'sstable_size_in_mb': '10', 'class': 'org.apache.cassandra.db.compaction.LeveledCompactionStrategy'}
	AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
	AND dclocal_read_repair_chance = 0.1
	AND default_time_to_live = 0
	AND gc_grace_seconds = 864000
	AND max_index_interval = 2048
	AND memtable_flush_period_in_ms = 0
	AND min_index_interval = 128
	AND read_repair_chance = 0.0
	AND speculative_retry = '99.0PERCENTILE';
```

#### Cassandra-stress write provides over 2000 op/s performance.
Cassandra-stress write operations (using consistency level local_quorum) provides a performance level required from the cluster:

```
root@node0:~# cassandra-stress write n=100000 cl=quorum -node node0  	 
Unable to create stress keyspace: Keyspace names must be case-insensitively unique ("keyspace1" conflicts with "keyspace1")
Sleeping 2s...
Warming up WRITE with 50000 iterations...
INFO  17:42:01 Using data-center name 'nearby' for DCAwareRoundRobinPolicy (if this is incorrect, please provide the correct datacenter name with DCAwareRoundRobinPolicy constructor)
INFO  17:42:01 New Cassandra host /54.169.186.166:9042 added
INFO  17:42:01 New Cassandra host /52.33.169.96:9042 added
INFO  17:42:01 New Cassandra host /54.169.188.8:9042 added
INFO  17:42:01 New Cassandra host /52.11.89.205:9042 added
INFO  17:42:01 New Cassandra host /54.169.190.74:9042 added
INFO  17:42:01 New Cassandra host /52.33.253.121:9042 added
INFO  17:42:01 New Cassandra host /52.32.41.24:9042 added
INFO  17:42:01 New Cassandra host node0/172.31.30.208:9042 added
INFO  17:42:01 New Cassandra host /54.169.187.114:9042 added
Connected to cluster: Confusion 1
Datatacenter: faraway; Host: /54.169.186.166; Rack: RAC1
Datatacenter: nearby; Host: /52.33.169.96; Rack: RAC1
Datatacenter: faraway; Host: /54.169.188.8; Rack: RAC1
Datatacenter: nearby; Host: /52.11.89.205; Rack: RAC1
Datatacenter: faraway; Host: /54.169.190.74; Rack: RAC1
Datatacenter: nearby; Host: /52.33.253.121; Rack: RAC1
Datatacenter: nearby; Host: /52.32.41.24; Rack: RAC1
Datatacenter: nearby; Host: node0/172.31.30.208; Rack: RAC1
Datatacenter: faraway; Host: /54.169.187.114; Rack: RAC1
Failed to connect over JMX; not collecting these stats
Running WRITE with 200 threads for 100000 iteration
Failed to connect over JMX; not collecting these stats
type,  	total ops,	op/s,	pk/s,   row/s,	mean, 	med, 	.95, 	.99,	.999, 	max,   time,   stderr, errors,  gc: #,  max ms,  sum ms,  sdv ms,  	mb
total,      	2324,	2358,	2358,	2358,	78.3, 	8.3,   320.7,   385.5,   470.7,   487.5,	1.0,  0.00000,  	0,  	0,   	0,   	0,   	0,   	0
total,      	5516,	2221,	2221,	2221,	88.5, 	3.6,   324.9,   386.4,   470.9,   480.6,	2.4,  0.02116,  	0,  	0,   	0,   	0,   	0,   	0
total,      	8785,	2342,	2342,	2342,	87.3, 	1.9,   327.8,   385.6,   459.7,   466.8,	3.8,  0.01529,  	0,  	0,   	0,   	0,   	0,   	0
total,     	12065,	2291,	2291,	2291,	87.3, 	1.3,   328.7,   377.1,   421.3,   465.1,	5.3,  0.01158,  	0,  	0,   	0,   	0,   	0,   	0
total,     	14932,	2083,	2083,	2083,	92.3, 	1.3,   338.5,   380.1,   453.2,   485.6,	6.6,  0.01986,  	0,  	0,   	0,   	0,   	0,   	0
total,     	18085,	2286,	2286,	2286,	90.6, 	1.2,   335.5,   384.2,   459.6,   490.4,	8.0,  0.01662,  	0,  	0,   	0,   	0,   	0,   	0
total,     	21124,	2138,	2138,	2138,	91.6, 	1.4,   334.6,   391.6,   435.7,   504.3,	9.4,  0.01614,  	0,  	0,   	0,   	0,   	0,   	0
total,     	24130,	2219,	2219,	2219,	90.4, 	1.1,   349.8,   406.6,   441.5,   519.1,   10.8,  0.01421,  	0,  	0,   	0,   	0,   	0,   	0
total,     	27277,	2163,	2163,	2163,	91.8, 	1.0,   350.7,   418.5,   501.4,   523.0,   12.2,  0.01322,  	0,  	0,   	0,   	0,   	0,   	0
total,     	30305,	2235,	2235,	2235,	89.2, 	1.1,   350.0,   409.7,   480.2,   501.6,   13.6,  0.01190,  	0,  	0,   	0,   	0,   	0,   	0
total,     	33488,	2322,	2322,	2322,	86.9, 	1.1,   341.1,   389.8,   447.1,   456.2,   15.0,  0.01130,  	0,  	0,   	0,   	0,   	0,   	0
total,     	36559,	2302,	2302,	2302,	87.8, 	1.0,   339.8,   396.0,   441.3,   473.2,   16.3,  0.01056,  	0,  	0,   	0,   	0,   	0,   	0
total,     	39594,	2167,	2167,	2167,	90.9, 	1.1,   339.6,   388.9,   434.6,   446.2,   17.7,  0.01012,  	0,  	0,   	0,   	0,   	0,   	0
total,     	42818,	2350,	2350,	2350,	84.5, 	1.2,   329.8,   386.8,   449.0,   483.9,   19.1,  0.00995,  	0,  	0,   	0,   	0,   	0,   	0
total,     	45819,	2225,	2225,	2225,	91.7, 	1.1,   344.6,   395.7,   442.2,   475.1,   20.4,  0.00931,  	0,  	0,   	0,   	0,   	0,   	0
total,     	48916,	2278,	2278,	2278,	86.7, 	1.0,   344.2,   387.2,   447.9,   482.8,   21.8,  0.00877,  	0,  	0,   	0,   	0,   	0,   	0
total,     	52024,	2168,	2168,	2168,	92.9, 	1.0,   355.3,   403.0,   449.2,   495.4,   23.2,  0.00852,  	0,  	0,   	0,   	0,   	0,   	0
total,     	55148,	2222,	2222,	2222,	91.7, 	1.0,   346.3,   403.5,   464.6,   515.7,   24.6,  0.00807,  	0,  	0,   	0,   	0,   	0,   	0
total,     	58218,	2177,	2177,	2177,	89.4, 	1.2,   350.2,   410.0,   509.5,   556.8,   26.0,  0.00780,  	0,  	0,   	0,   	0,   	0,   	0
total,     	61448,	2278,	2278,	2278,	88.7, 	1.3,   348.3,   404.2,   462.7,   501.7,   27.4,  0.00746,  	0,  	0,   	0,   	0,   	0,   	0
total,     	64392,	2046,	2046,	2046,	97.0, 	1.1,   355.4,   409.8,   496.6,   515.8,   28.9,  0.00821,  	0,  	0,   	0,   	0,   	0,   	0
total,     	67585,	2246,	2246,	2246,	90.4, 	1.0,   347.8,   409.8,   456.3,   469.2,   30.3,  0.00784,  	0,  	0,   	0,   	0,   	0,   	0
total,     	70673,	2197,	2197,	2197,	90.1, 	1.0,   347.2,   404.0,   451.7,   468.1,   31.7,  0.00754,  	0,  	0,   	0,   	0,   	0,   	0
total,     	73644,	2165,	2165,	2165,	91.4, 	1.1,   344.9,   396.0,   441.2,   456.5,   33.1,  0.00733,  	0,  	0,   	0,   	0,   	0,   	0
total,     	76767,	2271,	2271,	2271,	89.3, 	1.0,   347.0,   403.4,   461.8,   470.3,   34.5,  0.00707,  	0,  	0,   	0,   	0,   	0,   	0
total,     	79872,	2209,	2209,	2209,	89.2, 	1.0,   347.9,   402.1,   452.9,   481.9,   35.9,  0.00681,  	0,  	0,   	0,   	0,   	0,   	0
total,     	82852,	2222,	2222,	2222,	90.4, 	1.0,   347.8,   405.4,   464.6,   479.9,   37.2,  0.00656,  	0,  	0,   	0,   	0,   	0,   	0
total,     	85944,	2182,	2182,	2182,	91.8, 	1.1,   345.4,   396.3,   447.8,   579.1,   38.6,  0.00637,  	0,  	0,   	0,   	0,   	0,   	0
total,     	88931,	2145,	2145,	2145,	93.0, 	1.2,   352.2,   409.8,   468.3,   473.4,   40.0,  0.00629,  	0,  	0,   	0,   	0,   	0,   	0
total,     	92161,	2260,	2260,	2260,	89.1, 	1.0,   351.5,   406.7,   461.9,   478.0,   41.4,  0.00610,  	0,  	0,   	0,   	0,   	0,   	0
total,     	95359,	2235,	2235,	2235,	88.9, 	1.1,   345.4,   398.4,   446.9,   471.2,   42.9,  0.00590,  	0,  	0,   	0,   	0,   	0,   	0
total,     	98432,	2217,	2217,	2217,	91.1, 	1.0,   343.2,   397.4,   437.6,   503.7,   44.3,  0.00572,  	0,  	0,   	0,   	0,   	0,   	0
total,    	100000,	1563,	1563,	1563,   115.0, 	1.8,   361.3,   412.2,   451.8,   457.7,   45.3,  0.01056,  	0,  	0,   	0,   	0,   	0,   	0


Results:
op rate               	: 2209 [WRITE:2209]
partition rate        	: 2209 [WRITE:2209]
row rate              	: 2209 [WRITE:2209]
latency mean          	: 90.1 [WRITE:90.1]
latency median        	: 1.2 [WRITE:1.2]
latency 95th percentile   : 339.9 [WRITE:339.9]
latency 99th percentile   : 394.6 [WRITE:394.6]
latency 99.9th percentile : 459.7 [WRITE:459.7]
latency max           	: 579.1 [WRITE:579.1]
Total partitions      	: 100000 [WRITE:100000]
Total errors          	: 0 [WRITE:0]
total gc count        	: 0
total gc mb           	: 0
total gc time (s)     	: 0
avg gc time(ms)       	: NaN
stdev gc time(ms)     	: 0
Total operation time  	: 00:00:45
END
```

This was a primary indicator that changes to `confusion.jmx` would be necessary.
