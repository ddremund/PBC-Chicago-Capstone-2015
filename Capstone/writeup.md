## Capstone Project

Group: Derek Remund, Gene Tang

#### Task 1: Receipt Search via Solr
##### Goal
The goal of this task is to allow the searching of receipts by product name/title.   

Product title provides both brand and model in a freeform text field.  Searching this field is the most flexible way to find receipts for purchasers of a specific product or set of products. 

The `retail.receipts` table is initially structured as follows:
```CQL
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
    solr_query text,
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
```

The `product_name` column is equivalent to `title` in other product tables.

##### Create Index

The first task is to create a Solr index on the `receipts` table and index our fields.  We need to account for types like `timeuuid` and `bigint` by including the mappings in the `<types>` section of our XML file.  We index several fields to allow for faceting and to make future functionality additions easier.

###### receipts.xml:
```XML
<?xml version="1.0" encoding="UTF-8" ?>

<schema name="tracks" version="1.5">
 <types>
  <fieldType name="string" class="solr.StrField"/>
  <fieldType name="text" class="solr.TextField">
     <analyzer>
        <tokenizer class="solr.StandardTokenizerFactory"/>
        <filter class="solr.LowerCaseFilterFactory"/>
     </analyzer>
  </fieldType>
  <fieldType name="int"     class="solr.IntField"/>
  <fieldType name="bigint"  class="solr.BCDLongField"/>
  <fieldType name="uuid"    class="solr.UUIDField"/>
  <fieldType name="timeuuid" class="solr.UUIDField"/>
  <fieldType name="decimal" class="com.datastax.bdp.search.solr.core.types.DecimalStrField"/>
  <fieldType name="long"    class="solr.SortableLongField"/>
  <fieldType name="float"   class="solr.SortableFloatField"/>
  <fieldType name="date"    class="org.apache.solr.schema.TrieDateField"/>
 </types>
 <fields>

    <field name="receipt_id"  type="bigint" indexed="true"  stored="true"/>
    <field name="scan_id"  type="timeuuid" indexed="true"  stored="true"/>
    <field name="product_name"  type="text" indexed="true"  stored="true"/>
    <field name="product_id"  type="string" indexed="true"  stored="true"/>
    <field name="unit_price"  type="decimal" indexed="true"  stored="true"/>
    <field name="quantity" type="int" indexed="true" stored="true"/>
 </fields>

<defaultSearchField>product_name</defaultSearchField>
<uniqueKey>(receipt_id,scan_id)</uniqueKey>
```

We can now create our index:
```
dsetool create_core retail.receipts schema=receipts.xml solrconfig=solrconfig.xml reindex=true
```

The index has now been added to the `receipts` table.
```CQL
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
    solr_query text,
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
CREATE CUSTOM INDEX retail_receipts_product_id_index ON retail.receipts (product_id) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_receipts_product_name_index ON retail.receipts (product_name) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_receipts_quantity_index ON retail.receipts (quantity) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_receipts_solr_query_index ON retail.receipts (solr_query) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
CREATE CUSTOM INDEX retail_receipts_unit_price_index ON retail.receipts (unit_price) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
```

##### Application Updates

We will modify the existing python web application to expose our new search functionality.  First we create a new Jinja template to provide the UI for search.  This template provides a table for the search results as well as a sidebar for further filtering quantity of a product purchased.

###### search_receipts.jinja2
```jinja
{% extends "/base.jinja2" %}

{% block head %}
{% endblock %}

{% block body %}
      Solr Search of Receipts by Product:<br>
     <div id="solr_div">

    <form action="/web/search_receipts">
      <input type="text" name="s">
      <input type="submit" value="Search">
    </form>
    </div>
<br>
    <section>
    <div id="facet" style="float:left;width:20%">
    Narrow Results By:<br><br>
{% if quantities %}
  <b>Quantity:</b><br>

  {% for quantity in quantities %}
  {% set new_filter_by = 'quantity:"' + quantity.name + '"'%}
  {% if filter_by %}
    {% set new_filter_by = filter_by + " AND " + new_filter_by %}
  {% endif %}

  <a href="{{ makeURL("/web/search_receipts","s", search_term, "filter_by", new_filter_by) }}">{{ quantity.name }}:</a>&nbsp;{{ quantity.amount}}<br>
  {% endfor %}
  <br>
{% endif %}

    </div>
    <div id="list_div" style="float:right;width:80%">
        <br>
        <table border="1">
        <th>Receipt ID</th>
        <th>Quantity</th>
        <th>Product Title</th>
        <th>Details</th>
        {% if receipts %}
            {% for receipt in receipts %}
                <tr>
                <td><a href="/web/receipt?receipt_id={{ receipt.receipt_id }}">{{ receipt.receipt_id }}</a></td>
                <td>{{ receipt.quantity }}</td>
                <td>{{ receipt.product_name }}</td>
                <td><a href="/web/product?product_id={{ receipt.product_id }}">details</a></td>
                </tr>
            {% endfor %}
        {% endif %}
        </table>
</div>
</section>
{% endblock %}

{% block tail %}
{% endblock %}
```
Now that we have a target template we can write the route handler logic into the `web.py`:
```python
@web_api.route('/search_receipts')
def search_receipts():

    search_term = request.args.get('s')

    if not search_term:
        return render_template('search_receipts.jinja2',
                               receipts = None)

    filter_by = request.args.get('filter_by')

    solr_query = '"q":"product_name:%s"' % search_term.replace('"','\\"').encode('utf-8')

    if filter_by:
        solr_query += ',"fq":"%s"' % filter_by.replace('"','\\"').encode('utf-8')

    query = "SELECT * FROM receipts WHERE solr_query = '{%s}' LIMIT 300" % solr_query

    # get the response
    results = cassandra_helper.session.execute(query)

    facet_query = 'SELECT * FROM receipts WHERE solr_query = ' \
                  '\'{%s,"facet":{"field":["supplier_name","quantity"]}}\' ' % solr_query

    facet_results = cassandra_helper.session.execute(facet_query)
    facet_string = facet_results[0].get("facet_fields")

    # convert the facet string to an ordered dict because solr sorts them desceding by count, and we like it!
    facet_map = json.JSONDecoder(object_pairs_hook=OrderedDict).decode(facet_string)

    return render_template('search_receipts.jinja2',
                           search_term = search_term,
                           quantities = filter_facets(facet_map['quantity']),
                           suppliers = filter_facets(facet_map['supplier_name']),
                           receipts = results,
                           filter_by = filter_by)
```
Finally, we expose our new functionality to the user by linking to it from the `index.jinja2` template:
```html
<li>
    <a href="/web/search_receipts">Search Receipts by Product</a>
</li>
```
Our new UI allows searching of receipts by freeform product title:  
<img src="https://ab7f2ee757dab14f977f-412ed90bcf7411fa0e77ed8d19b04771.ssl.cf1.rackcdn.com/solr1.tiff" width=560/ alt="Searching receipts by product">  

The results can be filtered by the `quantity` facet:  
<img src="https://ab7f2ee757dab14f977f-412ed90bcf7411fa0e77ed8d19b04771.ssl.cf1.rackcdn.com/solr3.tiff" width=582/ alt="Filter by quantity">  

From the results page the details of any individual receipt can quickly be accessed:  
<img src="https://ab7f2ee757dab14f977f-412ed90bcf7411fa0e77ed8d19b04771.ssl.cf1.rackcdn.com/solr2.tiff" width=889/ alt="Receipt detail">  

Similarly, the details of any product result are just a click away:  
<img src="https://ab7f2ee757dab14f977f-412ed90bcf7411fa0e77ed8d19b04771.ssl.cf1.rackcdn.com/solr4.tiff" width=733/ alt="Searching receipts by product">  


#### Task 2: Fraud Detection using Spark
##### Goal
The goal of this task is to determine fraudulent credit cards.  

###### Credit cards are determined to be fraudulent if they are used in more than one state as defined by the task.

We want to be able to visually show these things:
1)	Top 20 most fraudulent credit card numbers based on the number of states they were used
2)	Number of transactions that were fraudulent per states 
##### New and Existing Cassandra Tables
Looking at the existing schema, the most pertinent tables to use to satisfy the above queries are the following:
```
receipts_by_credit_card (transactions where credit cards were used)
stores (store information)
```
We can join data from both tables to see where they are used based on state.

In order to answer the above queries, we introduced two new tables that help to satisfy these queries.

Used to satisfy Query 1:
```CQL
CREATE TABLE retail.num_times_fraud_cc_used_in_diff_state (
    dummy text,
    count int,
    credit_card_number bigint,
    time_uuid timeuuid,
    PRIMARY KEY (dummy, count, credit_card_number, time_uuid)
) WITH CLUSTERING ORDER BY (count DESC, credit_card_number DESC, time_uuid ASC)

Notes: We use a dummy partition key and order based on count.  Count is the number of times that credit card was used in a different state.
The timeuuid is used to give uniqueness to the primary key.  We recognise that use of a dummy partition key is not ideal, as this creates a
very wide row.  In future, we could check the largest value using the MAX() function in newer versions of cassandra, or do it at the application level.
```
Used to satisfy Query 2:
```CQL
CREATE TABLE retail.fraudulent_credit_card_use_by_state (
    state text,
    num_transactions int,
    time_uuid timeuuid,
    PRIMARY KEY (state, num_transactions, time_uuid)
) WITH CLUSTERING ORDER BY (num_transactions ASC, time_uuid ASC)

Notes: We list the number of fraudulent transactions per state (identified by state and num_transactions).  Timeuuid is used to give uniqueness.
```

##### Detecting fraudulent credit card using with Spark.
RetailRollup was used as a basis for this FraudDetection Spark Class.

Using Scala the basic algorithm will be as follows:

1.  Pull data from 'retail.receipts_by_credit_card' into an RDD.  We require the attributes 'store_id' and 'credit_card_number'.
2.  Pull data from 'retail.stores' into an RDD.  We require the attributes 'store_id' and 'state'.
3.  We join two RDD's based on 'store_id' to create another RDD
4.  Using RDD from (3) we remove any duplicate elements.  This represents entries where the credit card was used in the same state which is not a fraudulent action.  
The output RDD from now represents a credit card use per state.  If the credit card exists more than once in this RDD, then it means that it  has been used in more than one state and is therefore fraudulent.  
5.  Count the number of times a credit card occurs within this RDD
6.  Filter out credit card numbers that only occur once
7.  Output RDD is a list of all credit cards that are fraudulent


The above algorithm can be performed using the following scala code:

1) Pull data from 'retail.receipts_by_credit_card' into a RDD with tuples (store_id, credit_card_number):
```scala
    val receiptsByCC = sc.cassandraTable("retail","receipts_by_credit_card")
    val creditCardByStoreID = receiptsByCC.map(r => (r.getInt("store_id"), r.getLong("credit_card_number")))
```

2) Pull data from 'retail.stores' into a RDD with tuples (store_id, state)
```scala
    // Create some general RDDs
    val stores = sc.cassandraTable("retail","stores").select("store_id","address",
      "address_2","address_3","city","state","zip","size_in_sf"
    ).as(FraudStore)
    val storeState = stores.map(s => (s.store_id, s.state))
```

3) We join two RDD's based on 'store_id' as the key to create another RDD 
```scala
    val creditCardAndState = creditCardByStoreID.join(storeState).map({case (k,v) => (v._1, v._2)})
```

4) Using RDD from (3) we remove any duplicate elements. 
```scala
    val distinctCreditCardAndState = creditCardAndState.distinct
```

5) Count the number of times a credit card occurs within this RDD
```scala
    val creditCardUsePerState = distinctCreditCardAndState.map({case (k,v) => (k,1)}).reduceByKey(_ + _)
```

6) Filter out credit card numbers that only occur once
```scala
    // Now go ahead and filter out all credit cards used only once (i.e. with a value of 1) as these aren't fraudulent
    val fradulentCC = creditCardUsePerState.filter{
      _ match {
        case (k,v) => v != 1
      }
    }
```

7) Output RDD from (6) into the appropriate Cassandra tables:

For 'num_times_fraud_cc_used_in_diff_state':
```scala
    fradulentCC.map({case (k,v) => ("dummy", k,v,TimeUuid())}).saveToCassandra("retail","num_times_fraud_cc_used_in_diff_state",SomeColumns("dummy","credit_card_number","count","time_uuid"))
```

For 'fraudulent_credit_card_use_by_state':
```scala
    creditCardAndState.join(fradulentCC).map({case (k,v) => (v._1, 1)}).reduceByKey(_ + _).map({case (k,v) => ("US-" + k, v, TimeUuid())})
      .saveToCassandra("retail","fraudulent_credit_card_use_by_state",SomeColumns("state","num_transactions","time_uuid"))

Notes: We join the fraudulent credit cards we know, back to the original transactions table.  We then count the number occurrences and the populate the table.
```

##### Displaying the information on the application.

Added the following entries to index.jinja2:

Query 1:
```jinja
  <li>
    <a href="/gcharts/GeoChart/?url=/api/simplequery&options={height:600,region:'US',resolution:'provinces'}&q=select state,num_transactions from fraudulent_credit_card_use_by_state">
      Google Charts: Number of fraudulent credit cards used by State
    </a>
  </li>
```

Query 2:
```jinja
  <li>
    <a href="/gcharts/Table/?url=/api/simplequery&q=select credit_card_number,count from num_times_fraud_cc_used_in_diff_state limit 20&order_column=count&order_direction=-1">
      Google Charts: Top 20 most fraudulent credit cards based on number of states used in
    </a>
  </li>
```

Corresponding images for these queries can be seen here:

Query 1:

<img src="http://ceb0fc79be137b6f61e0-035db44ce48f9c179089b6a765245cb7.r19.cf6.rackcdn.com/graph1.PNG" width=733/ alt="number of fraudulent credit cards used per state">  


Query 2:

<img src="http://ceb0fc79be137b6f61e0-035db44ce48f9c179089b6a765245cb7.r19.cf6.rackcdn.com/graph2.PNG" width=200/ alt="most fraudulent credit card by count of state they were used in">  


##### Future Extensions:

###### Customer Table Extension
An extension was added to the Spark Fraud Detection, combining the work from the addition of the customers table.  This extension allows us to determine which state has the most owners of fraudulent credit cards.  

The extension was took the existing fraudulent credit card list and matched it against the owner based on the state they lived in.  Joins were performed on the credit card number itself, as this is unique to a customer:

```scala
    customerCCNumAndState.join(fradulentCC).map({case (k,v) => (v._1,1)}).reduceByKey(_ + _).map({case (k,v) => ("US-" + k, v, TimeUuid())})
      .saveToCassandra("retail","fraudulent_cc_by_owner_state",SomeColumns("state","num_credit_cards","time_uuid"))
```

Data was inserted into a table created for the query:

```cql
CREATE TABLE retail.fraudulent_cc_by_owner_state (
    state text,
    num_credit_cards int,
    time_uuid timeuuid,
    PRIMARY KEY (state, num_credit_cards, time_uuid)
) WITH CLUSTERING ORDER BY (num_credit_cards ASC, time_uuid ASC)
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


The UI was extended using the following code in index.jinja2:

```jinja
<li>
    <a href="/gcharts/GeoChart/?url=/api/simplequery&options={height:600,region:%27US%27,resolution:%27provinces%27}&q=select%20state,num_credit_cards%20from%20fraudulent_cc_by_owner_state">
     Google Charts: Number of fraudulent credit card owners in each State
    </a>
</li>
```

The output graph is as follows:

<img src="http://ceb0fc79be137b6f61e0-035db44ce48f9c179089b6a765245cb7.r19.cf6.rackcdn.com/graph3.PNG" width=733/ alt="Number of fraudulent credit card owners by state">  


###### Fraudulent Credit Card's by Date
The model could be extended to account for the number of fraudulent credit cards by date.

This could be achieved by group credit card receipts by date and matching against the fraudulent credit card list.
