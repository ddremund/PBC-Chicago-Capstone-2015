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

5. **Install DSE**

  Confirm root:
  ```
  [root@ip-172-31-39-112 ~]# whoami
root
```

  Add DataStax Repo:
  `vim /etc/ym.repos.d/datastax/repo`
  ```
  baseurl=http://username:password@rpm.datastax.com/enterprise (urlencode @ sign in username)
  enabled=1
  gpgcheck=0
  ```
  
  Install DSE:
  
  `yum install dse-full`

6. **Configure Cassandra**
  
  `vim /etc/dse/cassandra/cassandra.yaml`

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

7. **Start DSE**
  
  ```
  [root@ip-172-31-39-112 cassandra]# service dse start
  ```
  
8. **Confirm cluster is in working order**
  
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
