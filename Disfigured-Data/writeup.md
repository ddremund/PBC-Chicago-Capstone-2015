## Disfigured Data Lab
​
Group: Derek Remund, Gene Tang
​
### 1. Existing Data Model:

Data model has two tables, one for attachments and one for message info:

```
cqlsh:stupormail> desc attachments

CREATE TABLE stupormail.attachments (
    user text,
    mailbox text,
    msgdate timestamp,
    message_id text,
    filename text,
    bytes blob,
    content_type text,
    PRIMARY KEY (user, mailbox, msgdate, message_id, filename)
) WITH CLUSTERING ORDER BY (mailbox ASC, msgdate ASC, message_id ASC, filename ASC)
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

cqlsh:stupormail> desc email

CREATE TABLE stupormail.email (
    user text,
    mailbox text,
    msgdate timestamp,
    message_id text,
    bcclist set<text>,
    body text,
    cclist set<text>,
    fromlist set<text>,
    is_read boolean,
    subject text,
    tolist set<text>,
    PRIMARY KEY (user, mailbox, msgdate, message_id)
) WITH CLUSTERING ORDER BY (mailbox ASC, msgdate DESC, message_id ASC)
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
```

### 2. Existing Queries :

0. Get mailboxes for a given user:  
  `select mailbox from email where user = ? limit 1000` 

1. Get count of unread:  
  `select is_read from email where user = ? and mailbox = ? limit 10000`

2. Get 20 most recent in a given mailbox:  
  `select msgdate, fromlist, message_id,subject from email where user = ? and mailbox = ?  limit 20`

3. Determine if msg has attachments:  
  `select filename from attachments where user = ? and mailbox = ? and msgdate = ? limit 1`

4. List next 20 in given mailbox:   
  `select msgdate, fromlist, message_id,subject from email where user = ? and (mailbox, msgdate, message_id) > (?,?,?) limit 20`

  Note: This should actually be:  
  `select msgdate, fromlist, message_id, subject from email where user = ? and mailbox = ? and (msgdate, message_id) > (?,?) limit 20`

5. Read one message with body:  
  `select msgdate, fromlist, message_id, subject, body from email where user = ? and mailbox = ? and msgdate = ? and message_id = ?`

6. Mark message as read:  
  `update email set is_read = true where user = ? and mailbox = ? and msgdate = ? and message_id = ?`

7. List the atts for a given message:  
  `select filename from attachments where user = ? and mailbox = ? and msgdate = ? and message_id = ?`

8. Open the given attachment:  
  `select content_type, bytes from attachments where user = ? and mailbox = ? and msgdate = ? and message_id = ? and filename = ?`

9. Delete the given message:
  ```
  begin unlogged batch
    delete from email where user = ? and mailbox = ? and msgdate = ? and message_id = ?
    delete from attachments where user = ? and mailbox = ? and msgdate = ? and message_id = ?
  apply batch
  ```
  
10. Write Email:
  ```
  insert into email (user,mailbox,msgdate,message_id,subject,body) values (?,?,dateof(now()),?,?,?)
  ```
  
### 3. Initial JMeter Performance:
  
```
root@node0:~/disfigured# jmeter -n -t disfigured.jmx
Creating summariser <summary>
Created the tree successfully using disfigured.jmx
Starting the test @ Tue Nov 17 21:47:23 UTC 2015 (1447796843404)
Waiting for possible shutdown message on port 4445

0: Get mailboxes for a given user              31 in     5s =    6.2/s Avg:    96 Min:    44 Max:   312 Err:     0 (0.00%)
1: Get count of unread                         31 in     5s =    6.4/s Avg:    17 Min:     2 Max:   150 Err:     0 (0.00%)
2: Get 20 most recent in given mailbox         31 in     5s =    6.5/s Avg:     5 Min:     2 Max:    17 Err:     0 (0.00%)
3: Determine if msg has attachments          1097 in   5.4s =  203.9/s Avg:     4 Min:     1 Max:    73 Err:     0 (0.00%)
4: List the next 20 in the given mailbox       41 in     5s =    8.5/s Avg:     7 Min:     3 Max:    43 Err:     0 (0.00%)
5: Read one message with body                 167 in     5s =   33.8/s Avg:     4 Min:     1 Max:    18 Err:     0 (0.00%)
6: Mark message as read                       167 in     5s =   33.9/s Avg:     3 Min:     1 Max:    56 Err:     0 (0.00%)
7: List the atts for the given message        167 in     5s =   33.9/s Avg:     4 Min:     1 Max:    32 Err:     0 (0.00%)
8: Write email                                328 in   5.4s =   61.1/s Avg:     6 Min:     0 Max:   274 Err:     0 (0.00%)
9: Delete the given message                     7 in   4.3s =    1.6/s Avg:     8 Min:     2 Max:    42 Err:     0 (0.00%)
summary:                                 +   2067 in     6s =  370.9/s Avg:     6 Min:     0 Max:   312 Err:     0 (0.00%) Active: 5 Started: 5 Finished: 0

0: Get mailboxes for a given user             413 in    30s =   13.9/s Avg:   239 Min:    37 Max:   864 Err:     0 (0.00%)
1: Get count of unread                        412 in    30s =   13.9/s Avg:    35 Min:     0 Max:  1211 Err:     4 (0.97%)
2: Get 20 most recent in given mailbox        412 in    30s =   13.9/s Avg:    11 Min:     0 Max:   128 Err:     4 (0.97%)
3: Determine if msg has attachments         19140 in    30s =  637.9/s Avg:     9 Min:     0 Max:   300 Err:   217 (1.13%)
4: List the next 20 in the given mailbox      716 in    30s =   23.9/s Avg:    14 Min:     3 Max:   244 Err:     0 (0.00%)
5: Read one message with body                2829 in    30s =   94.3/s Avg:    10 Min:     0 Max:   242 Err:    30 (1.06%)
6: Mark message as read                      2828 in    30s =   94.3/s Avg:     9 Min:     0 Max:   119 Err:    30 (1.06%)
7: List the atts for the given message       2827 in    30s =   94.3/s Avg:     9 Min:     0 Max:   246 Err:    30 (1.06%)
8: Write email                               2017 in    30s =   67.2/s Avg:    10 Min:     0 Max:   254 Err:     0 (0.00%)
9: Delete the given message                   144 in    30s =    4.8/s Avg:     9 Min:     0 Max:    47 Err:     3 (2.08%)
summary:                                 +  31738 in    30s = 1057.8/s Avg:    13 Min:     0 Max:  1211 Err:   318 (1.00%) Active: 25 Started: 25 Finished: 0
summary:                                 =  33805 in    36s =  950.5/s Avg:    12 Min:     0 Max:  1211 Err:   318 (0.94%)

0: Get mailboxes for a given user             488 in  30.3s =   16.1/s Avg:   471 Min:    48 Max:  1782 Err:     0 (0.00%)
1: Get count of unread                        489 in  30.4s =   16.1/s Avg:    57 Min:     0 Max:  1040 Err:     3 (0.61%)
2: Get 20 most recent in given mailbox        487 in    30s =   16.3/s Avg:    22 Min:     0 Max:   115 Err:     3 (0.62%)
3: Determine if msg has attachments         21243 in  30.1s =  705.3/s Avg:    21 Min:     0 Max:   482 Err:   113 (0.53%)
4: List the next 20 in the given mailbox      782 in    30s =   26.1/s Avg:    28 Min:     5 Max:   190 Err:     0 (0.00%)
5: Read one message with body                3149 in    30s =  105.2/s Avg:    22 Min:     0 Max:   252 Err:    15 (0.48%)
6: Mark message as read                      3149 in    30s =  105.1/s Avg:    22 Min:     0 Max:   198 Err:    15 (0.48%)
7: List the atts for the given message       3147 in    30s =  105.0/s Avg:    21 Min:     0 Max:   426 Err:    15 (0.48%)
8: Write email                               1706 in    30s =   56.9/s Avg:    25 Min:     1 Max:   805 Err:     0 (0.00%)
9: Delete the given message                   149 in  29.4s =    5.1/s Avg:    21 Min:     4 Max:    84 Err:     0 (0.00%)
summary:                                 +  34789 in  30.4s = 1142.8/s Avg:    28 Min:     0 Max:  1782 Err:   164 (0.47%) Active: 41 Started: 41 Finished: 0
summary:                                 =  68594 in    66s = 1046.1/s Avg:    20 Min:     0 Max:  1782 Err:   482 (0.70%)

0: Get mailboxes for a given user             471 in  30.1s =   15.6/s Avg:   480 Min:    18 Max:  1873 Err:     0 (0.00%)
1: Get count of unread                        471 in    30s =   15.7/s Avg:    60 Min:     0 Max:  2401 Err:     4 (0.85%)
2: Get 20 most recent in given mailbox        471 in    30s =   15.7/s Avg:    27 Min:     1 Max:   276 Err:     4 (0.85%)
3: Determine if msg has attachments         21975 in  30.1s =  730.7/s Avg:    26 Min:     0 Max:   451 Err:   119 (0.54%)
4: List the next 20 in the given mailbox      820 in    30s =   27.3/s Avg:    33 Min:     4 Max:   263 Err:     0 (0.00%)
5: Read one message with body                3239 in  30.1s =  107.8/s Avg:    27 Min:     0 Max:   260 Err:    18 (0.56%)
6: Mark message as read                      3238 in    30s =  107.8/s Avg:    27 Min:     0 Max:   266 Err:    18 (0.56%)
7: List the atts for the given message       3240 in  30.1s =  107.8/s Avg:    26 Min:     0 Max:   322 Err:    18 (0.56%)
8: Write email                               1578 in  30.1s =   52.5/s Avg:    30 Min:     5 Max:   542 Err:     0 (0.00%)
9: Delete the given message                   169 in    30s =    5.7/s Avg:    26 Min:     1 Max:   123 Err:     1 (0.59%)
summary:                                 +  35672 in  30.2s = 1179.6/s Avg:    33 Min:     0 Max:  2401 Err:   182 (0.51%) Active: 41 Started: 41 Finished: 0
summary:                                 = 104266 in    96s = 1091.1/s Avg:    25 Min:     0 Max:  2401 Err:   664 (0.64%)

0: Get mailboxes for a given user             414 in  30.4s =   13.6/s Avg:   506 Min:    46 Max:  1667 Err:     0 (0.00%)
1: Get count of unread                        414 in    30s =   13.9/s Avg:    92 Min:     0 Max:  2814 Err:     2 (0.48%)
2: Get 20 most recent in given mailbox        416 in    30s =   13.9/s Avg:    29 Min:     0 Max:   601 Err:     2 (0.48%)
3: Determine if msg has attachments         21493 in    30s =  715.6/s Avg:    27 Min:     0 Max:   329 Err:   102 (0.47%)
4: List the next 20 in the given mailbox      813 in    30s =   27.1/s Avg:    32 Min:     8 Max:   230 Err:     0 (0.00%)
5: Read one message with body                3205 in    30s =  106.9/s Avg:    27 Min:     0 Max:   236 Err:    15 (0.47%)
6: Mark message as read                      3207 in    30s =  106.8/s Avg:    27 Min:     0 Max:   232 Err:    15 (0.47%)
7: List the atts for the given message       3207 in    30s =  106.9/s Avg:    26 Min:     0 Max:   232 Err:    15 (0.47%)
8: Write email                               1490 in    30s =   49.7/s Avg:    29 Min:     0 Max:   214 Err:     1 (0.07%)
9: Delete the given message                   161 in    30s =    5.4/s Avg:    26 Min:     1 Max:    88 Err:     1 (0.62%)
summary:                                 +  34820 in  30.4s = 1143.6/s Avg:    33 Min:     0 Max:  2814 Err:   153 (0.44%) Active: 41 Started: 41 Finished: 0
summary:                                 = 139086 in   126s = 1107.7/s Avg:    27 Min:     0 Max:  2814 Err:   817 (0.59%)

0: Get mailboxes for a given user             442 in  31.4s =   14.1/s Avg:   610 Min:    75 Max:  3055 Err:     0 (0.00%)
1: Get count of unread                        442 in    30s =   14.8/s Avg:    94 Min:     1 Max:  3254 Err:     4 (0.90%)
2: Get 20 most recent in given mailbox        442 in    30s =   14.8/s Avg:    29 Min:     0 Max:   474 Err:     4 (0.90%)
3: Determine if msg has attachments         21305 in  30.1s =  708.7/s Avg:    25 Min:     0 Max:   529 Err:   120 (0.56%)
4: List the next 20 in the given mailbox      794 in    30s =   26.6/s Avg:    33 Min:     7 Max:   258 Err:     0 (0.00%)
5: Read one message with body                3175 in    30s =  105.8/s Avg:    26 Min:     0 Max:   243 Err:    21 (0.66%)
6: Mark message as read                      3173 in    30s =  105.8/s Avg:    26 Min:     0 Max:   203 Err:    21 (0.66%)
7: List the atts for the given message       3172 in    30s =  105.7/s Avg:    25 Min:     0 Max:   202 Err:    21 (0.66%)
8: Write email                               1493 in    30s =   49.7/s Avg:    29 Min:     4 Max:  1086 Err:     0 (0.00%)
9: Delete the given message                   160 in    30s =    5.4/s Avg:    23 Min:     0 Max:    88 Err:     1 (0.62%)
summary:                                 +  34598 in  31.4s = 1100.2/s Avg:    34 Min:     0 Max:  3254 Err:   192 (0.55%) Active: 41 Started: 41 Finished: 0
summary:                                 = 173684 in   156s = 1116.5/s Avg:    28 Min:     0 Max:  3254 Err:  1009 (0.58%)
```

### 3. Suggested New Data Model and Queries:

Query-driven analysis was performed to suggest the following new data model and updated queries.  The model was changed from two tables to four, and some standard rules were followed where applicable and workable:
1. Entity and relationship types map to tables
2. Key attributes map to primary key columns
3. Equality search attributes map to partition keys
4. Inequality search attributes map to clustering columns
5. Ordering attributes map to clustering columns

Attempts were made to stick to one-to-one request-to-partition ratios where possible.

Tradeoffs were made for performance, complexity, and space utilization.  For example, a separate message bodies table with partition key containing `message_id` would have potentially been more performant for the query retrieving complete messages, rather than reusing `messages_by_user_mailbox`.  However, this would have required additional maintenance of referential integrity at the application layer, as well as potentially-signficant ballooning of storage utilization in production.  Thus for mangaement, application, and storage simplicity it was decided that messages would remain partitioned by `(user, mailbox)` for retrival.  

#### New Tables:

##### `attachments_by_user_mailbox`
This table is used for the following `select` queries:
- Determine if msg has attachments
- List the attachements for a given message
- Open the given attachment

The `user` and `mailbox` fields are used as partition keys to locate data in a more optimal fashion. `msgdate` and `message_id` are used as clustering columns for uniqueness.  Finally, the `filename` attribute is used as a clustering column to define attachments, thereby differentiating this from other message tables.  

In production we might create another table to actually store the bytes of the attachments, using `filename` as part of the partition key.  This would make sense if the workload commonly had single files being pulled out of the database.  However, if the application pulled all of the files for a message prior to them being individually opened by the client then the existing table would suffice.  Either way, the point is moot for this exercise as the brief was to not handle the actual bytes as part of the test workload.

The table is also written to by the "Delete the given message" query.  The workload's "Write message" query does not write emails with attachments.

```
CREATE TABLE stupormail2.attachments_by_user_mailbox (
    user text,
    mailbox text,
    msgdate timestamp,
    message_id text,
    filename text,
    content_type text,
    PRIMARY KEY ((user, mailbox, msgdate), message_id, filename)
) WITH CLUSTERING ORDER BY (message_id ASC, filename ASC)
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
    ```
    
##### `mailboxes_by_user`
This table is used to satisfy the "Get mailboxes by user" query.  Therefore we partion on `user` and cluster by `mailbox` to make it easy to retrieve a sorted list of mailboxes for a particular user.  For the purpose of this test this table is also written to by "Write email" query, although some logic at the application layer would obviously be used typically to create a new mailbox.

```
CREATE TABLE stupormail2.mailboxes_by_user (
    user text,
    mailbox text,
    PRIMARY KEY (user, mailbox)
) WITH CLUSTERING ORDER BY (mailbox ASC)
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
```

##### `messages_by_user_mailbox`
This table is used for the following `select` queries:
- Get 20 most recent in a given mailbox
- List next 20 in a given mailbox
- Read one messge with body

The `user` and `mailbox` columns are used for partioning.  Equality matches are also done on `msgdate` and `message_id`, but we chose to keep them as clustering columns to allow this table to be used flexibly for multiple queries.  As noted previously we considered using separate tables for message summaries and actual message bodies, but chose to stick with a single table for this workload.  Thus several additional non-key attributes are provided in this table.

The table is also written to by the "Delete the given message" and "Write email" queries.
```
CREATE TABLE stupormail2.messages_by_user_mailbox (
    user text,
    mailbox text,
    msgdate timestamp,
    message_id text,
    body text,
    fromlist set<text>,
    subject text,
    PRIMARY KEY ((user, mailbox), msgdate, message_id)
) WITH CLUSTERING ORDER BY (msgdate DESC, message_id ASC)
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
    ```
##### `is_read_by_user_mailbox`
This table is used to satisfy the following `select` queries:
-  Get count of unread
-  Mark message as read

Both queries retrieve data based on `user` and `mailbox`, so they make up the partition key.  The `is_read` field is used as the first clustering column to facilitate quick retrieval of a list of unread messages.  The `msgdate` and `message_id` columns help ensure uniqueness.  We also considered using a counter column in the `mailboxes_by_user` table to store the unread message value, but not knowing the constraints around absolute accuracy of unread count we decided to stick with aggregation to count unread messages, either using `count` queries or at the application layer.

The table is also written to via the "Delete the given message" and "Write email" queries.
```
CREATE TABLE stupormail2.is_read_by_user_mailbox (
    user text,
    mailbox text,
    is_read boolean,
    msgdate timestamp,
    message_id text,
    PRIMARY KEY ((user, mailbox), is_read, msgdate, message_id)
) WITH CLUSTERING ORDER BY (is_read ASC, msgdate DESC, message_id DESC)
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
    ```

#### New queries

0. Get mailboxes for a given user:
  `select mailbox from mailboxes_by_user where user = ? limit 1000;`  
This query now has a table designed specifically for it.

1. Get count of unread:  
  `select count(*) from is_read_by_user_mailbox where user = ? and mailbox = ? and is_read = true`  
We've decided to perform the counting of unread items directly in the workload this time.  This is in contrast to the original workload which simply retrieved the rows (and also didn't appear to actually solve for getting the correct unread count).

2. Get 20 most recent in a given mailbox:  
  `select msgdate, fromlist, message_id, subject from messages_by_user_mailbox where user = ? and mailbox = ?  limit 20`  
This query reads messages_by_user_mailbox and matches based on user and mailbox.  It pulls the attributes as required by the original query.

3. Determine if msg has attachments:  
  `select filename from attachments_by_user_mailbox where user = ? and mailbox = ? and msgdate = ? limit 1`  
This query is based off assumptions made by the original data model and JMeter test plan.  It matches based on user and mailbox as per other queries, however, it only matches based on msgdate and not message_id as would be required in “real life”.  In this scenario, it means that people can only receive one email with attachments in a single point in time.

4. List next 20 in given mailbox:   
  `select msgdate, fromlist, message_id, subject from messages_by_user_mailbox where user = ? and mailbox = ? and (msgdate, message_id) > (?,?) limit 20`

5. Read one message with body:  
  `select msgdate, fromlist, message_id, subject, body from messages_by_user_mailbox where user = ? and mailbox = ? and msgdate = ? and message_id = ?`

6. Mark message as read:
  ```
  begin batch
	delete from is_read_by_user_mailbox where user = ? and mailbox = ? and is_read = false and msgdate = ? and message_id = ?
	insert into is_read_by_user_mailbox (user, mailbox, is_read, msgdate, message_id) values (?, ?, true, ?, ?)
  apply batch
  ```
  In this query we remove an email and readd that email back into the table with the is_read attribute set to true.  This is done in this fashion as the is_read attribute is part of the primary key.

7. List the atts for a given message:  
  `select filename from attachments_by_user_mailbox where user = ? and mailbox = ? and msgdate = ? and message_id = ?`  
A new table has been created for attachments.  Emails will have attachments if a filename for that email exists.  This is an assumption, but an assumption made by the original data model and test plan.

8. Open the given attachment:  
  `select content_type from attachments_by_user_mailbox where user = ? and mailbox = ? and msgdate = ? and message_id = ? and filename = ?`  
We use a batch statement to ensure referential integrity of the data model when data is inserted into the model.  An important assumption we make is that the dateof(now()) function gives the same time for both queries in the batch statement for insertion of data into the appropriate tables.  

9. Delete the given message:
  ```
  begin unlogged batch
	delete from is_read_by_user_mailbox where is_read = true and user = ? and mailbox = ? and msgdate = ? and message_id = ?
	delete from is_read_by_user_mailbox where is_read = false and user = ? and mailbox = ? and msgdate = ? and message_id = ?
	delete from attachments_by_user_mailbox where user = ? and mailbox = ? and msgdate = ? and message_id = ?
	delete from messages_by_user_mailbox where user = ? and mailbox = ? and msgdate  = ? and message_id = ?
  apply batch
  ```
  In order to attain referential integrity within the data model, we run a batch query to ensure a deletion of an email is reflected across the entire data model.
  
10. Write Email:
  ```
  begin batch
	insert into messages_by_user_mailbox (user, mailbox, msgdate, message_id, subject, body) values (?,?,dateof(now()),?,?,?)
	insert into is_read_by_user_mailbox (user,mailbox,is_read,msgdate,message_id) values (?,?,false,dateof(now()),?)
	insert into mailboxes_by_user (user, mailbox) values (?,?)
  apply batch
  ```
    In order to attain referential integrity within the data model, we run a batch query to ensure a insertion of an email is reflected across the entire data model.  Note that we allow new mailboxes to be created through mail insertion, but this may not be correct for the application in the "real world".
  
  ### 3.  JMeter Performance With New Model
  
  ```
  0: Get mailboxes for a given user            3306 in    30s =  110.3/s Avg:     3 Min:     0 Max:    33 Err:     0 (0.00%)
1: Get count of unread                       3306 in    30s =  110.3/s Avg:     2 Min:     0 Max:    36 Err:    29 (0.88%)
2: Get 20 most recent in given mailbox       3306 in    30s =  110.3/s Avg:     3 Min:     0 Max:    85 Err:    29 (0.88%)
3: Determine if msg has attachments         47566 in    30s = 1585.1/s Avg:     2 Min:     0 Max:    83 Err:   156 (0.33%)
4: List the next 20 in the given mailbox     1581 in    30s =   52.8/s Avg:     3 Min:     0 Max:    81 Err:     0 (0.00%)
5: Read one message with body                6931 in    30s =  231.3/s Avg:     3 Min:     0 Max:    80 Err:    24 (0.35%)
6: Mark message as read                      6931 in    30s =  231.3/s Avg:     2 Min:     0 Max:    33 Err:    24 (0.35%)
7: List the atts for the given message       6931 in    30s =  231.3/s Avg:     2 Min:     0 Max:    81 Err:    24 (0.35%)
8: Write email                               5022 in    30s =  167.5/s Avg:     3 Min:     0 Max:    79 Err:     3 (0.06%)
9: Delete the given message                   344 in    30s =   11.5/s Avg:     2 Min:     0 Max:    15 Err:     3 (0.87%)
summary:                                 +  85224 in    30s = 2840.0/s Avg:     2 Min:     0 Max:    85 Err:   292 (0.34%) Active: 41 Started: 41 Finished: 0
summary:                                 = 166541 in    66s = 2541.9/s Avg:     2 Min:     0 Max:   150 Err:   506 (0.30%)

0: Get mailboxes for a given user            3252 in    30s =  108.5/s Avg:     3 Min:     0 Max:    96 Err:     0 (0.00%)
1: Get count of unread                       3252 in    30s =  108.5/s Avg:     2 Min:     0 Max:    27 Err:    27 (0.83%)
2: Get 20 most recent in given mailbox       3252 in    30s =  108.5/s Avg:     3 Min:     0 Max:    92 Err:    27 (0.83%)
3: Determine if msg has attachments         46705 in    30s = 1556.4/s Avg:     2 Min:     0 Max:    92 Err:   134 (0.29%)
4: List the next 20 in the given mailbox     1567 in    30s =   52.3/s Avg:     3 Min:     0 Max:    87 Err:     8 (0.51%)
5: Read one message with body                6761 in    30s =  225.5/s Avg:     3 Min:     0 Max:    96 Err:    18 (0.27%)
6: Mark message as read                      6761 in    30s =  225.5/s Avg:     2 Min:     0 Max:    95 Err:    18 (0.27%)
7: List the atts for the given message       6761 in    30s =  225.5/s Avg:     2 Min:     0 Max:    88 Err:    18 (0.27%)
8: Write email                               4972 in    30s =  165.8/s Avg:     3 Min:     0 Max:   231 Err:     3 (0.06%)
9: Delete the given message                   341 in    30s =   11.5/s Avg:     2 Min:     0 Max:    15 Err:     1 (0.29%)
summary:                                 +  83624 in    30s = 2786.6/s Avg:     2 Min:     0 Max:   231 Err:   254 (0.30%) Active: 41 Started: 41 Finished: 0
summary:                                 = 250165 in    96s = 2619.0/s Avg:     2 Min:     0 Max:   231 Err:   760 (0.30%)
```
