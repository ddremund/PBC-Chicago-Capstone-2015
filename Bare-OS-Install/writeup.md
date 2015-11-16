### Bare Metal Install Lab

1. **Check Hardware**

  Check AWS instance metadata:

  ```
  [root@ip-172-31-39-112 cassandra]# curl http://169.254.169.254/latest/meta-data/
  m1.large
  ```

  m1.large instances have 2 vCPUs, 7.5GB RAM, and 2x420GB ephemeral magnetic instance storage per http://aws.amazon.com/ec2/previous-generation/.

  Confirm memory:
  ```
  [root@ip-172-31-39-112 cassandra]# vmstat -s grep  "total memory"
  7645700  total memory
  ```

  Confirm CPU count:
  ```
  [root@ip-172-31-39-112 cassandra]# cat /proc/cpuinfo | grep processor | wc -l
  2
  ```

  Confirm disks:
  ```
  [root@ip-172-31-39-112 /]# fdisk -l
  
  Disk /dev/xvda: 10.7 GB, 10737418240 bytes
  255 heads, 63 sectors/track, 1305 cylinders
  Units = cylinders of 16065 * 512 = 8225280 bytes
  Sector size (logical/physical): 512 bytes / 512 bytes
  I/O size (minimum/optimal): 512 bytes / 512 bytes
  Disk identifier: 0x00000000


  Disk /dev/xvdb: 450.9 GB, 450934865920 bytes
  255 heads, 63 sectors/track, 54823 cylinders
  Units = cylinders of 16065 * 512 = 8225280 bytes
  Sector size (logical/physical): 512 bytes / 512 bytes
  I/O size (minimum/optimal): 512 bytes / 512 bytes
  Disk identifier: 0x00000000


  Disk /dev/xvdc: 450.9 GB, 450934865920 bytes
  255 heads, 63 sectors/track, 54823 cylinders
  Units = cylinders of 16065 * 512 = 8225280 bytes
  Sector size (logical/physical): 512 bytes / 512 bytes
  I/O size (minimum/optimal): 512 bytes / 512 bytes
  Disk identifier: 0x00000000
  ```

2.  **Install Oracle JDK**

  Download:
  `wget --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept=securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u65-b17/jdk-8u65-linux-x64.rpm"`

  Install:
`rpm -ivh jdk-8u65-linux-x64.rpm`

  Check java version:
  ```
[root@ip-172-31-39-112 ~]# java -version
java version "1.8.0_65"
Java(TM) SE Runtime Environment (build 1.8.0_65-b17)
Java HotSpot(TM) 64-Bit Server VM (build 25.65-b01, mixed mode)
```

  Check if Oracle is the only Java installed:

  ```
[root@ip-172-31-39-112 ~]# sudo alternatives --config java

There is 1 program that provides 'java'.

  Selection    Command
-----------------------------------------------
*+ 1           /usr/java/jdk1.8.0_65/jre/bin/java
```

3. **Prepare Disks**

  Format disks:
  ```
  fdisk /dev/xvdb
  fdisk /dev/xvdc
  mkfs.ext4 /dev/xvdb1
  mkfs.ext4 /dev/xvdc1
  ```
  
  Mount disks and update fstab; use separate disks for data and commit log per best practices:
  ```
  mkdir /data
  mkdir /commitlog
  chown -R cassandra:cassandra /data /commitlog
  [root@ip-172-31-39-112 ~]# mount
/dev/xvda on / type ext3 (rw)
none on /proc type proc (rw)
none on /sys type sysfs (rw)
none on /dev/pts type devpts (rw,gid=5,mode=620)
none on /dev/shm type tmpfs (rw)
none on /proc/sys/fs/binfmt_misc type binfmt_misc (rw)
/dev/xvdb1 on /data type ext4 (rw)
/dev/xvdc1 on /commitlog type ext4 (rw)

[root@ip-172-31-39-112 ~]# cat /etc/fstab
LABEL=ROOT /         ext3    defaults        0 0
none       /dev/pts  devpts  gid=5,mode=620  0 0
none       /dev/shm  tmpfs   defaults        0 0
none       /proc     proc    defaults        0 0
none       /sys      sysfs   defaults        0 0
/dev/xvdb	/data	ext4	defaults 0 0
/dev/xvdc	/commitlog	ext4	defaults 0 0
```

4. **Check Secondary Node Connectivity**

  ```
  [root@ip-172-31-39-112 ~]# ping -c 5 172.31.46.20
PING 172.31.46.20 (172.31.46.20) 56(84) bytes of data.
64 bytes from 172.31.46.20: icmp_seq=1 ttl=64 time=2.76 ms
64 bytes from 172.31.46.20: icmp_seq=2 ttl=64 time=0.542 ms
64 bytes from 172.31.46.20: icmp_seq=3 ttl=64 time=0.593 ms
64 bytes from 172.31.46.20: icmp_seq=4 ttl=64 time=0.486 ms
64 bytes from 172.31.46.20: icmp_seq=5 ttl=64 time=0.530 ms

--- 172.31.46.20 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4002ms
rtt min/avg/max/mdev = 0.486/0.983/2.767/0.893 ms
```

5. **Prepare Software Environment**
  
  Check OS: 

  ```
[root@ip-172-31-39-112 ~]# uname -a
Linux ip-172-31-39-112 2.6.32-504.12.2.el6.centos.plus.x86_64 #1 SMP Thu Mar 12 18:39:03 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
```
  OS is not RHEL5 nor 64-bit Oracle Linux, so no EPEL or 32-bit glibc required.
  
  Update existing packages:
  
  ```
  [root@ip-172-31-39-112 ~]# yum update
Loaded plugins: security, versionlock
Setting up Update Process
rightscale-epel                                                                                     | 2.9 kB     00:00
No Packages marked for Update
```

6. **Install DSE**

  Confirm root:
  ```
  [root@ip-172-31-39-112 ~]# whoami
root
```

  Add DataStax Repo:
  
  ```
  vim /etc/ym.repos.d/datastax/repo
  
  baseurl=http://username:password@rpm.datastax.com/enterprise (urlencode @ sign in username)
  enabled=1
  gpgcheck=0
  ```
  
  Install DSE:
  ```
  yum install dse-full
  ```

7. **Configure Cassandra**
  ```
  vim /etc/dse/cassandra/cassandra.yaml
  ```

  Set cluster name: 
  ```
  cluster_name: 'Cluster 47'
  ```
  
  Set addresses: 
  ```
  listen_address: 172.31.39.112
  rpc_address: 172.31.39.112
  ```
  
  Set seeds: 
  ```
  - class_name: org.apache.cassandra.locator.SimpleSeedProvider
      parameters:
      - seeds: "172.31.39.112,172.31.46.20"
  ```
  
  Set virtual tokens: 
  ```
  num_tokens: 256
  ```
  
  Set snitch: 
  ```
  endpoint_snitch: Ec2Snitch
  ```
  
  Set directories:
  ```
  commitlog_directory: /var/lib/cassandra/commitlog
  data_file_directories:
      - /var/lib/cassandra/data
  ```

8. **Start DSE**
  
  ```
  [root@ip-172-31-39-112 cassandra]# service dse start
  ```
  
9. **Confirm cluster is in working order**
  
  ```
  [root@ip-172-31-39-112 cassandra]# nodetool status
  atacenter: us-west-2
=====================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address        Load       Tokens  Owns    Host ID                               Rack
UN  172.31.46.20   330.82 KB  256     ?       430042a6-f3b1-49c7-b062-c8834a5698a3  2a
UN  172.31.39.112  205.63 KB  256     ?       1939840f-989c-4cbb-8ea7-4b9026d24d42  2a
```
10. **Test Cluster**

  Write first:
  
  ```
  [root@ip-172-31-39-112 cassandra]# cassandra-stress write n=100000 -node 172.31.39.112
Unable to create stress keyspace: Keyspace names must be case-insensitively unique ("keyspace1" conflicts with "keyspace1")
Sleeping 2s...
Warming up WRITE with 50000 iterations...
Connected to cluster: Cluster 47
Datatacenter: us-west-2; Host: /172.31.46.20; Rack: 2a
Datatacenter: us-west-2; Host: /172.31.39.112; Rack: 2a
Failed to connect over JMX; not collecting these stats
Running WRITE with 200 threads for 100000 iteration
Failed to connect over JMX; not collecting these stats
type,      total ops,    op/s,    pk/s,   row/s,    mean,     med,     .95,     .99,    .999,     max,   time,   stderr, errors,  gc: #,  max ms,  sum ms,  sdv ms,      mb
total,          5721,    5721,    5721,    5721,    33.3,    30.5,    56.2,    66.4,    86.0,    94.1,    1.0,  0.00000,      0,      0,       0,       0,       0,       0
total,         12967,    6719,    6719,    6719,    29.9,    25.3,    62.0,   130.7,   145.1,   150.1,    2.1,  0.05675,      0,      0,       0,       0,       0,       0
total,         20567,    7273,    7273,    7273,    27.5,    24.5,    57.9,    72.3,    82.6,   107.8,    3.1,  0.05642,      0,      0,       0,       0,       0,       0
total,         28468,    7228,    7228,    7228,    27.7,    25.4,    62.0,    70.6,    88.8,   104.9,    4.2,  0.04637,      0,      0,       0,       0,       0,       0
total,         35590,    6867,    6867,    6867,    29.2,    28.4,    43.3,    53.4,    65.0,    72.0,    5.3,  0.03712,      0,      0,       0,       0,       0,       0
total,         43938,    7886,    7886,    7886,    25.4,    24.3,    42.1,    49.4,    67.0,    84.4,    6.3,  0.03888,      0,      0,       0,       0,       0,       0
total,         51657,    7317,    7317,    7317,    27.1,    23.1,    50.4,    59.2,    72.4,    89.7,    7.4,  0.03380,      0,      0,       0,       0,       0,       0
total,         59866,    7267,    7267,    7267,    26.4,    23.1,    50.4,    61.1,    97.4,    99.8,    8.5,  0.02976,      0,      0,       0,       0,       0,       0
total,         68383,    7969,    7969,    7969,    26.3,    23.3,    45.7,    77.2,    98.6,   113.4,    9.6,  0.02946,      0,      0,       0,       0,       0,       0
total,         76712,    8028,    8028,    8028,    24.7,    22.8,    48.2,    56.0,    70.2,    86.4,   10.6,  0.02867,      0,      0,       0,       0,       0,       0
total,         85033,    7690,    7690,    7690,    26.2,    20.3,    55.1,    62.0,    77.9,    84.2,   11.7,  0.02649,      0,      0,       0,       0,       0,       0
total,         94362,    9021,    9021,    9021,    22.1,    20.9,    45.0,    49.3,    71.7,    87.0,   12.7,  0.03037,      0,      0,       0,       0,       0,       0
total,        100000,    9898,    9898,    9898,    19.9,    19.3,    27.9,    34.2,    41.5,    53.5,   13.3,  0.03645,      0,      0,       0,       0,       0,       0


Results:
op rate                   : 7525 [WRITE:7525]
partition rate            : 7525 [WRITE:7525]
row rate                  : 7525 [WRITE:7525]
latency mean              : 26.5 [WRITE:26.5]
latency median            : 23.5 [WRITE:23.5]
latency 95th percentile   : 52.4 [WRITE:52.4]
latency 99th percentile   : 65.1 [WRITE:65.1]
latency 99.9th percentile : 119.5 [WRITE:119.5]
latency max               : 150.1 [WRITE:150.1]
Total partitions          : 100000 [WRITE:100000]
Total errors              : 0 [WRITE:0]
total gc count            : 0
total gc mb               : 0
total gc time (s)         : 0
avg gc time(ms)           : NaN
stdev gc time(ms)         : 0
Total operation time      : 00:00:13
END
```

  Read:
  ```
  [root@ip-172-31-39-112 cassandra]# cassandra-stress read n=100000 -node 172.31.39.112
Sleeping 2s...
Warming up READ with 50000 iterations...
Connected to cluster: Cluster 47
Datatacenter: us-west-2; Host: /172.31.46.20; Rack: 2a
Datatacenter: us-west-2; Host: /172.31.39.112; Rack: 2a
Failed to connect over JMX; not collecting these stats
Running with 4 threadCount
Running READ with 4 threads for 100000 iteration
Failed to connect over JMX; not collecting these stats
type,      total ops,    op/s,    pk/s,   row/s,    mean,     med,     .95,     .99,    .999,     max,   time,   stderr, errors,  gc: #,  max ms,  sum ms,  sdv ms,      mb
total,          2660,    2660,    2660,    2660,     1.5,     1.3,     2.6,     5.0,     8.8,     9.9,    1.0,  0.00000,      0,      0,       0,       0,       0,       0
total,          5541,    2873,    2873,    2873,     1.4,     1.2,     2.5,     5.3,     9.3,    14.2,    2.0,  0.02722,      0,      0,       0,       0,       0,       0
total,          8316,    2773,    2773,    2773,     1.4,     1.1,     3.1,     6.2,    11.6,    11.7,    3.0,  0.01836,      0,      0,       0,       0,       0,       0
total,         11317,    2977,    2977,    2977,     1.3,     1.1,     2.5,     5.2,     7.6,     8.1,    4.0,  0.02042,      0,      0,       0,       0,       0,       0
total,         14562,    3231,    3231,    3231,     1.2,     1.1,     2.0,     3.4,     6.6,     7.1,    5.0,  0.03026,      0,      0,       0,       0,       0,       0
total,         17549,    2976,    2976,    2976,     1.3,     1.1,     2.2,     5.3,    13.3,    14.1,    6.0,  0.02535,      0,      0,       0,       0,       0,       0
total,         20696,    3135,    3135,    3135,     1.2,     1.1,     2.1,     3.0,     7.8,     8.3,    7.0,  0.02391,      0,      0,       0,       0,       0,       0
total,         23982,    3246,    3246,    3246,     1.2,     1.1,     2.0,     2.9,    13.7,    14.8,    8.0,  0.02439,      0,      0,       0,       0,       0,       0
total,         27174,    3177,    3177,    3177,     1.2,     1.1,     2.1,     3.1,     6.3,     8.2,    9.0,  0.02260,      0,      0,       0,       0,       0,       0
total,         30418,    3228,    3228,    3228,     1.2,     1.1,     1.9,     2.7,     9.3,    12.1,   10.0,  0.02142,      0,      0,       0,       0,       0,       0
total,         33641,    3204,    3204,    3204,     1.2,     1.1,     1.9,     2.5,    51.4,    51.9,   11.1,  0.02144,      0,      0,       0,       0,       0,       0
total,         37026,    3373,    3373,    3373,     1.2,     1.1,     1.9,     2.5,     3.2,     5.7,   12.1,  0.02097,      0,      0,       0,       0,       0,       0
total,         40313,    3275,    3275,    3275,     1.2,     1.1,     2.0,     3.3,    10.2,    11.5,   13.1,  0.01973,      0,      0,       0,       0,       0,       0
total,         43509,    3185,    3185,    3185,     1.2,     1.1,     2.2,     3.5,     8.5,     9.5,   14.1,  0.01841,      0,      0,       0,       0,       0,       0
total,         46967,    3447,    3447,    3447,     1.1,     1.1,     1.8,     2.4,     6.1,     7.0,   15.1,  0.01834,      0,      0,       0,       0,       0,       0
total,         50418,    3433,    3433,    3433,     1.1,     1.0,     1.8,     2.4,    15.2,    16.4,   16.1,  0.01829,      0,      0,       0,       0,       0,       0
total,         53163,    2691,    2691,    2691,     1.5,     1.1,     2.0,     3.1,   172.3,   172.5,   17.1,  0.01724,      0,      0,       0,       0,       0,       0
total,         56228,    3027,    3027,    3027,     1.3,     1.1,     2.4,     6.0,    13.0,    16.2,   18.1,  0.01649,      0,      0,       0,       0,       0,       0
total,         59398,    3150,    3150,    3150,     1.2,     1.1,     2.0,     7.0,    10.6,    13.3,   19.1,  0.01563,      0,      0,       0,       0,       0,       0
total,         62321,    2901,    2901,    2901,     1.4,     1.1,     2.6,     6.4,    12.2,    14.8,   20.1,  0.01543,      0,      0,       0,       0,       0,       0
total,         65622,    3263,    3263,    3263,     1.2,     1.0,     2.0,     4.1,    12.7,    15.9,   21.1,  0.01477,      0,      0,       0,       0,       0,       0
total,         69147,    3513,    3513,    3513,     1.1,     1.0,     1.8,     2.3,     4.9,     5.1,   22.1,  0.01498,      0,      0,       0,       0,       0,       0
total,         72250,    3077,    3077,    3077,     1.3,     1.1,     1.9,     4.1,    18.7,    51.7,   23.1,  0.01440,      0,      0,       0,       0,       0,       0
total,         75687,    3420,    3420,    3420,     1.1,     1.1,     1.9,     2.5,     7.2,     8.2,   24.1,  0.01420,      0,      0,       0,       0,       0,       0
total,         79193,    3495,    3495,    3495,     1.1,     1.1,     1.8,     2.4,     5.1,     6.0,   25.1,  0.01414,      0,      0,       0,       0,       0,       0
total,         82693,    3486,    3486,    3486,     1.1,     1.0,     1.8,     2.4,     7.2,     9.2,   26.2,  0.01399,      0,      0,       0,       0,       0,       0
total,         86002,    3294,    3294,    3294,     1.2,     1.1,     1.9,     3.6,    11.0,    12.8,   27.2,  0.01354,      0,      0,       0,       0,       0,       0
total,         88398,    2381,    2381,    2381,     1.7,     1.1,     1.9,     5.3,   289.9,   290.9,   28.2,  0.01310,      0,      0,       0,       0,       0,       0
total,         91683,    3275,    3275,    3275,     1.2,     1.0,     2.2,     5.1,     7.7,     9.4,   29.2,  0.01266,      0,      0,       0,       0,       0,       0
total,         95110,    3410,    3410,    3410,     1.2,     1.1,     1.9,     2.3,     9.4,    10.4,   30.2,  0.01243,      0,      0,       0,       0,       0,       0
total,         98540,    3415,    3415,    3415,     1.1,     1.1,     1.8,     2.9,    10.6,    11.7,   31.2,  0.01216,      0,      0,       0,       0,       0,       0
total,        100000,    3437,    3437,    3437,     1.1,     1.1,     1.8,     2.3,     3.5,     3.7,   31.6,  0.01193,      0,      0,       0,       0,       0,       0


Results:
op rate                   : 3164 [READ:3164]
partition rate            : 3164 [READ:3164]
row rate                  : 3164 [READ:3164]
latency mean              : 1.2 [READ:1.2]
latency median            : 1.1 [READ:1.1]
latency 95th percentile   : 2.0 [READ:2.0]
latency 99th percentile   : 3.5 [READ:3.5]
latency 99.9th percentile : 8.5 [READ:8.5]
latency max               : 290.9 [READ:290.9]
Total partitions          : 100000 [READ:100000]
Total errors              : 0 [READ:0]
total gc count            : 0
total gc mb               : 0
total gc time (s)         : 0
avg gc time(ms)           : NaN
stdev gc time(ms)         : 0
Total operation time      : 00:00:31
Running with 8 threadCount
Running READ with 8 threads for 100000 iteration
Failed to connect over JMX; not collecting these stats
type,      total ops,    op/s,    pk/s,   row/s,    mean,     med,     .95,     .99,    .999,     max,   time,   stderr, errors,  gc: #,  max ms,  sum ms,  sdv ms,      mb
total,          4554,    4554,    4554,    4554,     1.8,     1.6,     3.0,     4.0,    13.2,    14.0,    1.0,  0.00000,      0,      0,       0,       0,       0,       0
total,          9039,    4471,    4471,    4471,     1.8,     1.5,     3.2,     4.5,    39.5,    40.7,    2.0,  0.00709,      0,      0,       0,       0,       0,       0
total,         13477,    4425,    4425,    4425,     1.8,     1.6,     3.2,     5.6,    12.5,    14.6,    3.0,  0.00908,      0,      0,       0,       0,       0,       0
total,         17819,    4327,    4327,    4327,     1.8,     1.6,     3.3,     5.8,     9.4,    12.6,    4.0,  0.01301,      0,      0,       0,       0,       0,       0
total,         22369,    4534,    4534,    4534,     1.7,     1.6,     3.1,     4.0,    14.0,    14.7,    5.0,  0.01093,      0,      0,       0,       0,       0,       0
total,         27253,    4869,    4869,    4869,     1.6,     1.5,     2.9,     3.6,     4.6,     5.5,    6.0,  0.01476,      0,      0,       0,       0,       0,       0
total,         31791,    4520,    4520,    4520,     1.7,     1.6,     3.2,     4.9,    12.0,    12.7,    7.0,  0.01278,      0,      0,       0,       0,       0,       0
total,         36575,    4761,    4761,    4761,     1.7,     1.5,     2.8,     4.0,    16.9,    17.5,    8.0,  0.01289,      0,      0,       0,       0,       0,       0
total,         41458,    4864,    4864,    4864,     1.6,     1.5,     2.6,     3.4,    13.9,    15.0,    9.0,  0.01337,      0,      0,       0,       0,       0,       0
total,         46007,    4531,    4531,    4531,     1.7,     1.4,     3.5,     4.5,    12.6,    14.3,   10.0,  0.01220,      0,      0,       0,       0,       0,       0
total,         50332,    4302,    4302,    4302,     1.8,     1.6,     3.1,     6.0,    43.7,    48.3,   11.0,  0.01152,      0,      0,       0,       0,       0,       0
total,         54904,    4550,    4550,    4550,     1.7,     1.6,     2.9,     5.0,    12.1,    13.8,   12.0,  0.01062,      0,      0,       0,       0,       0,       0
total,         59453,    4531,    4531,    4531,     1.7,     1.6,     3.4,     4.8,     9.4,    12.0,   13.0,  0.00989,      0,      0,       0,       0,       0,       0
total,         64034,    4553,    4553,    4553,     1.7,     1.6,     2.8,     4.4,    12.4,    13.8,   14.1,  0.00918,      0,      0,       0,       0,       0,       0
total,         68658,    4573,    4573,    4573,     1.7,     1.6,     2.8,     4.3,    11.5,    12.8,   15.1,  0.00858,      0,      0,       0,       0,       0,       0
total,         73268,    4588,    4588,    4588,     1.7,     1.6,     2.9,     4.2,     7.7,     9.5,   16.1,  0.00805,      0,      0,       0,       0,       0,       0
total,         77799,    4513,    4513,    4513,     1.7,     1.6,     3.1,     5.2,    11.9,    12.9,   17.1,  0.00760,      0,      0,       0,       0,       0,       0
total,         82273,    4448,    4448,    4448,     1.8,     1.6,     3.0,     6.1,    12.3,    13.4,   18.1,  0.00739,      0,      0,       0,       0,       0,       0
total,         86809,    4517,    4517,    4517,     1.7,     1.6,     2.7,     3.3,    28.2,    29.3,   19.1,  0.00705,      0,      0,       0,       0,       0,       0
total,         91674,    4843,    4843,    4843,     1.6,     1.5,     2.8,     3.8,     7.2,     9.0,   20.1,  0.00722,      0,      0,       0,       0,       0,       0
total,         96519,    4818,    4818,    4818,     1.6,     1.4,     3.2,     3.9,     5.1,     8.2,   21.1,  0.00722,      0,      0,       0,       0,       0,       0
total,        100000,    4553,    4553,    4553,     1.7,     1.6,     3.3,     4.3,     8.0,     9.0,   21.9,  0.00691,      0,      0,       0,       0,       0,       0


Results:
op rate                   : 4575 [READ:4575]
partition rate            : 4575 [READ:4575]
row rate                  : 4575 [READ:4575]
latency mean              : 1.7 [READ:1.7]
latency median            : 1.6 [READ:1.6]
latency 95th percentile   : 3.0 [READ:3.0]
latency 99th percentile   : 4.1 [READ:4.1]
latency 99.9th percentile : 12.6 [READ:12.6]
latency max               : 48.3 [READ:48.3]
Total partitions          : 100000 [READ:100000]
Total errors              : 0 [READ:0]
total gc count            : 0
total gc mb               : 0
total gc time (s)         : 0
avg gc time(ms)           : NaN
stdev gc time(ms)         : 0
Total operation time      : 00:00:21
Improvement over 4 threadCount: 45%
Running with 16 threadCount
Running READ with 16 threads for 100000 iteration
Failed to connect over JMX; not collecting these stats
type,      total ops,    op/s,    pk/s,   row/s,    mean,     med,     .95,     .99,    .999,     max,   time,   stderr, errors,  gc: #,  max ms,  sum ms,  sdv ms,      mb
total,          5620,    5622,    5622,    5622,     2.8,     2.6,     5.1,     7.5,    12.2,    13.8,    1.0,  0.00000,      0,      0,       0,       0,       0,       0
total,         10627,    4954,    4954,    4954,     3.2,     3.0,     5.7,     7.8,    11.4,    13.5,    2.0,  0.04465,      0,      0,       0,       0,       0,       0
total,         16374,    5720,    5720,    5720,     2.8,     2.6,     4.8,     7.1,    19.1,    21.9,    3.0,  0.03618,      0,      0,       0,       0,       0,       0
total,         22314,    5903,    5903,    5903,     2.7,     2.5,     4.6,     5.9,     7.6,     8.7,    4.0,  0.03230,      0,      0,       0,       0,       0,       0
total,         28164,    5819,    5819,    5819,     2.7,     2.5,     4.8,     6.7,    12.0,    14.3,    5.0,  0.02699,      0,      0,       0,       0,       0,       0
total,         33122,    4924,    4924,    4924,     3.2,     3.0,     5.6,     7.2,    18.4,    20.5,    6.0,  0.02882,      0,      0,       0,       0,       0,       0
total,         38998,    5842,    5842,    5842,     2.7,     2.6,     4.6,     6.2,    10.0,    13.3,    7.0,  0.02582,      0,      0,       0,       0,       0,       0
total,         44433,    5394,    5394,    5394,     2.9,     2.8,     5.1,     6.5,     8.3,    10.2,    8.0,  0.02290,      0,      0,       0,       0,       0,       0
total,         50836,    6362,    6362,    6362,     2.5,     2.4,     4.9,     6.5,     8.3,     9.6,    9.1,  0.02534,      0,      0,       0,       0,       0,       0
total,         56635,    5160,    5160,    5160,     3.1,     2.5,     5.3,     7.7,   122.4,   123.8,   10.2,  0.02288,      0,      0,       0,       0,       0,       0
total,         61932,    5264,    5264,    5264,     3.0,     2.8,     5.4,     7.0,    11.6,    12.9,   11.2,  0.02170,      0,      0,       0,       0,       0,       0
total,         67341,    5360,    5360,    5360,     3.0,     2.8,     5.1,     7.2,    15.6,    16.9,   12.2,  0.02010,      0,      0,       0,       0,       0,       0
total,         73360,    5984,    5984,    5984,     2.7,     2.5,     4.5,     6.1,     8.9,    10.3,   13.2,  0.01917,      0,      0,       0,       0,       0,       0
total,         79282,    5882,    5882,    5882,     2.7,     2.6,     4.7,     6.1,     9.3,    10.4,   14.2,  0.01804,      0,      0,       0,       0,       0,       0
total,         85311,    5977,    5977,    5977,     2.7,     2.5,     5.1,     7.1,    13.6,    15.7,   15.2,  0.01721,      0,      0,       0,       0,       0,       0
total,         91525,    6181,    6181,    6181,     2.6,     2.5,     4.8,     6.3,    10.3,    12.6,   16.2,  0.01697,      0,      0,       0,       0,       0,       0
total,         97186,    5630,    5630,    5630,     2.8,     2.6,     5.1,     6.8,    10.6,    11.9,   17.2,  0.01599,      0,      0,       0,       0,       0,       0
total,        100000,    5379,    5379,    5379,     2.9,     2.7,     5.3,     6.8,     9.4,    10.4,   17.7,  0.01544,      0,      0,       0,       0,       0,       0


Results:
op rate                   : 5635 [READ:5635]
partition rate            : 5635 [READ:5635]
row rate                  : 5635 [READ:5635]
latency mean              : 2.8 [READ:2.8]
latency median            : 2.6 [READ:2.6]
latency 95th percentile   : 4.9 [READ:4.9]
latency 99th percentile   : 6.5 [READ:6.5]
latency 99.9th percentile : 11.4 [READ:11.4]
latency max               : 123.8 [READ:123.8]
Total partitions          : 100000 [READ:100000]
Total errors              : 0 [READ:0]
total gc count            : 0
total gc mb               : 0
total gc time (s)         : 0
avg gc time(ms)           : NaN
stdev gc time(ms)         : 0
Total operation time      : 00:00:17
Improvement over 8 threadCount: 23%
Running with 24 threadCount
Running READ with 24 threads for 100000 iteration
Failed to connect over JMX; not collecting these stats
type,      total ops,    op/s,    pk/s,   row/s,    mean,     med,     .95,     .99,    .999,     max,   time,   stderr, errors,  gc: #,  max ms,  sum ms,  sdv ms,      mb
total,          5481,    5480,    5480,    5480,     4.4,     3.3,     6.9,    10.0,   170.1,   175.1,    1.0,  0.00000,      0,      0,       0,       0,       0,       0
total,         11776,    6250,    6250,    6250,     3.8,     3.6,     7.0,     9.4,    11.5,    13.4,    2.0,  0.01447,      0,      0,       0,       0,       0,       0
total,         17428,    5607,    5607,    5607,     4.3,     3.8,     8.5,    12.3,    30.2,    32.6,    3.0,  0.03586,      0,      0,       0,       0,       0,       0
total,         23474,    6005,    6005,    6005,     4.0,     3.7,     8.1,    11.1,    24.3,    26.9,    4.0,  0.02735,      0,      0,       0,       0,       0,       0
total,         29289,    5777,    5777,    5777,     4.1,     3.8,     7.5,    10.2,    22.6,    26.6,    5.0,  0.02389,      0,      0,       0,       0,       0,       0
total,         35625,    6284,    6284,    6284,     3.8,     3.5,     7.0,     9.8,    14.4,    18.4,    6.0,  0.02075,      0,      0,       0,       0,       0,       0
total,         41387,    5710,    5710,    5710,     4.2,     3.9,     7.7,    10.6,    13.3,    15.5,    7.0,  0.01964,      0,      0,       0,       0,       0,       0
total,         45829,    4399,    4399,    4399,     5.4,     4.1,     9.1,    19.0,   168.2,   170.2,    8.1,  0.02476,      0,      0,       0,       0,       0,       0
total,         52058,    6155,    6155,    6155,     3.9,     3.4,     7.8,    13.9,    18.0,    28.8,    9.1,  0.02233,      0,      0,       0,       0,       0,       0
total,         57757,    5656,    5656,    5656,     4.2,     3.9,     8.3,    13.3,    16.2,    28.5,   10.1,  0.02069,      0,      0,       0,       0,       0,       0
total,         64020,    6215,    6215,    6215,     3.8,     3.5,     7.2,     9.6,    12.8,    15.5,   11.1,  0.01924,      0,      0,       0,       0,       0,       0
total,         70576,    6487,    6487,    6487,     3.7,     3.5,     6.5,     8.7,    13.8,    16.9,   12.1,  0.01898,      0,      0,       0,       0,       0,       0
total,         76519,    5906,    5906,    5906,     4.0,     3.7,     7.9,    12.9,    16.8,    20.0,   13.1,  0.01756,      0,      0,       0,       0,       0,       0
total,         81459,    4879,    4879,    4879,     4.9,     4.7,     8.7,    11.6,    15.4,    16.1,   14.1,  0.02091,      0,      0,       0,       0,       0,       0
total,         88013,    6498,    6498,    6498,     3.7,     3.3,     6.6,     9.1,    17.3,    20.2,   15.1,  0.02071,      0,      0,       0,       0,       0,       0
total,         94320,    6257,    6257,    6257,     3.8,     3.5,     7.0,    11.0,    16.3,    22.3,   16.1,  0.01961,      0,      0,       0,       0,       0,       0
total,        100000,    6178,    6178,    6178,     3.9,     3.6,     7.1,    10.2,    15.2,    16.4,   17.0,  0.01853,      0,      0,       0,       0,       0,       0


Results:
op rate                   : 5866 [READ:5866]
partition rate            : 5866 [READ:5866]
row rate                  : 5866 [READ:5866]
latency mean              : 4.1 [READ:4.1]
latency median            : 3.7 [READ:3.7]
latency 95th percentile   : 7.5 [READ:7.5]
latency 99th percentile   : 10.6 [READ:10.6]
latency 99.9th percentile : 23.4 [READ:23.4]
latency max               : 175.1 [READ:175.1]
Total partitions          : 100000 [READ:100000]
Total errors              : 0 [READ:0]
total gc count            : 0
total gc mb               : 0
total gc time (s)         : 0
avg gc time(ms)           : NaN
stdev gc time(ms)         : 0
Total operation time      : 00:00:17
Improvement over 16 threadCount: 4%
Running with 36 threadCount
Running READ with 36 threads for 100000 iteration
Failed to connect over JMX; not collecting these stats
type,      total ops,    op/s,    pk/s,   row/s,    mean,     med,     .95,     .99,    .999,     max,   time,   stderr, errors,  gc: #,  max ms,  sum ms,  sdv ms,      mb
total,          6747,    6748,    6748,    6748,     5.3,     4.6,    11.3,    17.6,    27.0,    33.2,    1.0,  0.00000,      0,      0,       0,       0,       0,       0
total,         13722,    6892,    6892,    6892,     5.2,     4.9,     9.9,    13.9,    18.5,    21.2,    2.0,  0.00748,      0,      0,       0,       0,       0,       0
total,         21117,    7313,    7313,    7313,     4.9,     4.4,     9.6,    14.2,    20.8,    29.2,    3.0,  0.01983,      0,      0,       0,       0,       0,       0
total,         28005,    6826,    6826,    6826,     5.3,     5.0,    10.0,    13.3,    18.7,    23.1,    4.0,  0.01575,      0,      0,       0,       0,       0,       0
total,         34893,    6802,    6802,    6802,     5.3,     4.8,    10.0,    13.2,    16.5,    17.6,    5.0,  0.01318,      0,      0,       0,       0,       0,       0
total,         41419,    6462,    6462,    6462,     5.5,     5.2,    10.6,    15.1,    20.6,    24.6,    6.1,  0.01501,      0,      0,       0,       0,       0,       0
total,         47373,    5860,    5860,    5860,     6.1,     5.5,    11.8,    15.7,    19.9,    30.2,    7.1,  0.02339,      0,      0,       0,       0,       0,       0
total,         53721,    6262,    6262,    6262,     5.7,     5.3,    10.5,    14.5,    18.5,    20.8,    8.1,  0.02203,      0,      0,       0,       0,       0,       0
total,         61088,    7263,    7263,    7263,     4.9,     4.6,     9.0,    12.4,    18.5,    21.0,    9.1,  0.02165,      0,      0,       0,       0,       0,       0
total,         68278,    7112,    7112,    7112,     5.0,     4.5,     9.8,    14.2,    16.5,    21.3,   10.1,  0.02016,      0,      0,       0,       0,       0,       0
total,         74108,    5764,    5764,    5764,     6.2,     5.5,    11.9,    19.0,    23.3,    25.7,   11.1,  0.02260,      0,      0,       0,       0,       0,       0
total,         79764,    5603,    5603,    5603,     6.4,     5.8,    11.6,    16.8,    21.0,    22.6,   12.1,  0.02462,      0,      0,       0,       0,       0,       0
total,         86003,    6152,    6152,    6152,     5.9,     5.5,    10.7,    13.9,    18.3,    20.7,   13.1,  0.02334,      0,      0,       0,       0,       0,       0
total,         92229,    6171,    6171,    6171,     5.8,     5.7,    11.2,    14.2,    18.6,    23.6,   14.2,  0.02211,      0,      0,       0,       0,       0,       0
total,         98725,    6406,    6406,    6406,     5.6,     5.1,    10.9,    16.0,    22.3,    29.3,   15.2,  0.02069,      0,      0,       0,       0,       0,       0
total,        100000,    6455,    6455,    6455,     5.5,     5.1,    12.0,    17.9,    20.8,    21.5,   15.4,  0.01941,      0,      0,       0,       0,       0,       0


Results:
op rate                   : 6508 [READ:6508]
partition rate            : 6508 [READ:6508]
row rate                  : 6508 [READ:6508]
latency mean              : 5.5 [READ:5.5]
latency median            : 5.1 [READ:5.1]
latency 95th percentile   : 10.5 [READ:10.5]
latency 99th percentile   : 14.6 [READ:14.6]
latency 99.9th percentile : 20.4 [READ:20.4]
latency max               : 33.2 [READ:33.2]
Total partitions          : 100000 [READ:100000]
Total errors              : 0 [READ:0]
total gc count            : 0
total gc mb               : 0
total gc time (s)         : 0
avg gc time(ms)           : NaN
stdev gc time(ms)         : 0
Total operation time      : 00:00:15
Improvement over 24 threadCount: 11%
Running with 54 threadCount
Running READ with 54 threads for 100000 iteration
Failed to connect over JMX; not collecting these stats
type,      total ops,    op/s,    pk/s,   row/s,    mean,     med,     .95,     .99,    .999,     max,   time,   stderr, errors,  gc: #,  max ms,  sum ms,  sdv ms,      mb
total,          7417,    7417,    7417,    7417,     7.3,     6.5,    15.2,    25.6,    34.4,    49.9,    1.0,  0.00000,      0,      0,       0,       0,       0,       0
total,         14698,    7137,    7137,    7137,     7.6,     7.1,    14.5,    22.7,    30.9,    34.5,    2.0,  0.01360,      0,      0,       0,       0,       0,       0
total,         21949,    7119,    7119,    7119,     7.5,     6.6,    15.7,    23.6,    36.4,    56.1,    3.0,  0.01030,      0,      0,       0,       0,       0,       0
total,         26277,    4249,    4249,    4249,    12.7,    10.9,    21.6,   124.6,   128.6,   132.0,    4.1,  0.07951,      0,      0,       0,       0,       0,       0
total,         30570,    4203,    4203,    4203,    12.8,    12.2,    24.0,    32.4,    41.4,    45.4,    5.1,  0.09849,      0,      0,       0,       0,       0,       0
total,         36420,    5738,    5738,    5738,     9.4,     8.7,    18.3,    23.8,    30.2,    37.9,    6.1,  0.08361,      0,      0,       0,       0,       0,       0
total,         43363,    6818,    6818,    6818,     7.9,     7.3,    15.1,    21.0,    26.4,    32.2,    7.1,  0.07220,      0,      0,       0,       0,       0,       0
total,         50748,    7289,    7289,    7289,     7.4,     7.0,    13.5,    19.6,    26.1,    33.9,    8.1,  0.06509,      0,      0,       0,       0,       0,       0
total,         59047,    8192,    8192,    8192,     6.5,     5.9,    12.1,    15.7,    19.9,    22.8,    9.1,  0.06356,      0,      0,       0,       0,       0,       0
total,         66713,    7500,    7500,    7500,     7.2,     6.4,    13.5,    18.1,    23.7,    31.0,   10.2,  0.05805,      0,      0,       0,       0,       0,       0
total,         74099,    7298,    7298,    7298,     7.4,     6.9,    15.8,    21.3,    28.7,    30.5,   11.2,  0.05302,      0,      0,       0,       0,       0,       0
total,         80820,    6601,    6601,    6601,     8.1,     7.9,    14.7,    18.4,    24.0,    29.0,   12.2,  0.04866,      0,      0,       0,       0,       0,       0
total,         88267,    7272,    7272,    7272,     7.4,     7.1,    15.0,    18.9,    24.3,    26.5,   13.2,  0.04509,      0,      0,       0,       0,       0,       0
total,         94880,    6479,    6479,    6479,     8.3,     8.1,    15.4,    21.2,    28.2,    36.6,   14.2,  0.04205,      0,      0,       0,       0,       0,       0
total,        100000,    7302,    7302,    7302,     7.4,     7.2,    13.4,    17.5,    23.5,    25.3,   14.9,  0.03943,      0,      0,       0,       0,       0,       0


Results:
op rate                   : 6693 [READ:6693]
partition rate            : 6693 [READ:6693]
row rate                  : 6693 [READ:6693]
latency mean              : 8.0 [READ:8.0]
latency median            : 7.3 [READ:7.3]
latency 95th percentile   : 16.3 [READ:16.3]
latency 99th percentile   : 22.7 [READ:22.7]
latency 99.9th percentile : 36.0 [READ:36.0]
latency max               : 132.0 [READ:132.0]
Total partitions          : 100000 [READ:100000]
Total errors              : 0 [READ:0]
total gc count            : 0
total gc mb               : 0
total gc time (s)         : 0
avg gc time(ms)           : NaN
stdev gc time(ms)         : 0
Total operation time      : 00:00:14
Improvement over 36 threadCount: 3%
```
