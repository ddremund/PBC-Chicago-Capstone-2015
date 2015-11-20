
CREATE KEYSPACE retail WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '1'}  AND durable_writes = true;

CREATE TABLE retail.inventory_per_store (
    store_id int,
    store_date timestamp,
    product_id text,
    inventory counter,
    PRIMARY KEY ((store_id, store_date), product_id)
) WITH CLUSTERING ORDER BY (product_id ASC)
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

CREATE TABLE retail.stores (
    store_id int PRIMARY KEY,
    address text,
    address_2 text,
    address_3 text,
    city text,
    size_in_sf int,
    state text,
    zip bigint
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
    AND read_repair_chance = 0.0
    AND speculative_retry = '99.0PERCENTILE';

CREATE TABLE retail.zipcodes (
    zipcode text,
    city text,
    lat float,
    long float,
    population bigint,
    state text,
    wages bigint,
    PRIMARY KEY (zipcode, city)
) WITH CLUSTERING ORDER BY (city ASC)
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

CREATE TABLE retail.products_by_id (
    product_id text PRIMARY KEY,
    category_id int,
    category_name text,
    features map<text, text>,
    long_description text,
    price decimal,
    release_date timestamp,
    short_description text,
    solr_query text,
    supplier_id int,
    supplier_name text,
    title text,
    url text
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
    AND read_repair_chance = 0.0
    AND speculative_retry = '99.0PERCENTILE';
CREATE CUSTOM INDEX retail_products_by_id_category_name_index ON retail.products_by_id (category_name) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_products_by_id_release_date_index ON retail.products_by_id (release_date) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_products_by_id_short_description_index ON retail.products_by_id (short_description) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_products_by_id_solr_query_index ON retail.products_by_id (solr_query) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_products_by_id_supplier_id_index ON retail.products_by_id (supplier_id) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_products_by_id_supplier_name_index ON retail.products_by_id (supplier_name) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_products_by_id_title_index ON retail.products_by_id (title) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';

CREATE TABLE retail.num_times_fraud_cc_used_in_diff_state (
    dummy text,
    count int,
    credit_card_number bigint,
    time_uuid timeuuid,
    PRIMARY KEY (dummy, count, credit_card_number, time_uuid)
) WITH CLUSTERING ORDER BY (count DESC, credit_card_number DESC, time_uuid ASC)
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

CREATE TABLE retail.products_by_category_name (
    category_name text,
    supplier_name text,
    title text,
    product_id text,
    category_id int,
    features map<text, text>,
    is_hot boolean static,
    long_description text,
    price decimal,
    release_date timestamp,
    short_description text,
    supplier_id int,
    url text,
    PRIMARY KEY (category_name, supplier_name, title, product_id)
) WITH CLUSTERING ORDER BY (supplier_name ASC, title ASC, product_id ASC)
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

CREATE TABLE retail.receipts_by_credit_card (
    credit_card_number bigint,
    receipt_timestamp timestamp,
    receipt_id bigint,
    credit_card_type text static,
    receipt_total decimal,
    store_id int,
    PRIMARY KEY (credit_card_number, receipt_timestamp, receipt_id)
) WITH CLUSTERING ORDER BY (receipt_timestamp DESC, receipt_id DESC)
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

CREATE TABLE retail.sales_by_date (
    dummy text,
    sales_date timestamp,
    receipts_total decimal,
    PRIMARY KEY (dummy, sales_date)
) WITH CLUSTERING ORDER BY (sales_date ASC)
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

CREATE TABLE retail.products_by_supplier (
    supplier_id int,
    title text,
    product_id text,
    category_id int,
    category_name text,
    features map<text, text>,
    long_description text,
    price decimal,
    release_date timestamp,
    short_description text,
    supplier_name text,
    url text,
    PRIMARY KEY (supplier_id, title, product_id)
) WITH CLUSTERING ORDER BY (title ASC, product_id ASC)
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

CREATE TABLE retail.sales_by_state (
    dummy text,
    receipts_total decimal,
    state text,
    region text,
    PRIMARY KEY (dummy, receipts_total, state)
) WITH CLUSTERING ORDER BY (receipts_total DESC, state ASC)
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

CREATE TABLE retail.real_time_analytics (
    series text,
    timewindow timestamp,
    quantities map<text, int>,
    PRIMARY KEY (series, timewindow)
) WITH CLUSTERING ORDER BY (timewindow DESC)
    AND bloom_filter_fp_chance = 0.01
    AND caching = '{"keys":"ALL", "rows_per_partition":"NONE"}'
    AND comment = ''
    AND compaction = {'class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'}
    AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
    AND dclocal_read_repair_chance = 0.1
    AND default_time_to_live = 3600
    AND gc_grace_seconds = 3600
    AND max_index_interval = 2048
    AND memtable_flush_period_in_ms = 0
    AND min_index_interval = 128
    AND read_repair_chance = 0.0
    AND speculative_retry = '99.0PERCENTILE';

CREATE TABLE retail.receipts_by_store_date (
    store_id int,
    receipt_date timestamp,
    register_id int,
    receipt_timestamp timestamp,
    receipt_id bigint,
    receipt_total decimal,
    PRIMARY KEY ((store_id, receipt_date), register_id, receipt_timestamp, receipt_id)
) WITH CLUSTERING ORDER BY (register_id ASC, receipt_timestamp ASC, receipt_id ASC)
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

CREATE TABLE retail.fraudulent_credit_card_use_by_state (
    state text,
    num_transactions int,
    time_uuid timeuuid,
    PRIMARY KEY (state, num_transactions, time_uuid)
) WITH CLUSTERING ORDER BY (num_transactions ASC, time_uuid ASC)
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

CREATE TABLE retail.suppliers (
    supplier_id int PRIMARY KEY,
    supplier_name text
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
    AND read_repair_chance = 0.0
    AND speculative_retry = '99.0PERCENTILE';

CREATE TABLE retail.receipts (
    receipt_id bigint,
    scan_id timeuuid,
    credit_card_number bigint static,
    credit_card_type text static,
    product_id text,
    product_name text,
    quantity int,
    receipt_timestamp timestamp static,
    receipt_total decimal static,
    register_id int static,
    store_id int static,
    total decimal,
    unit_price decimal,
    PRIMARY KEY (receipt_id, scan_id)
) WITH CLUSTERING ORDER BY (scan_id ASC)
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

CREATE TABLE retail.customers (
    customer_name text,
    zipcode text,
    credit_card_number bigint,
    PRIMARY KEY (customer_name, zipcode, credit_card_number)
) WITH CLUSTERING ORDER BY (zipcode ASC, credit_card_number ASC)
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
