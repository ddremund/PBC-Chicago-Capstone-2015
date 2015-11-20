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
<img src="https://ab7f2ee757dab14f977f-412ed90bcf7411fa0e77ed8d19b04771.ssl.cf1.rackcdn.com/solr1.tiff" width=560 alt="Searching receipts by product"/>  

The results can be filtered by the `quantity` facet:  
<img src="https://ab7f2ee757dab14f977f-412ed90bcf7411fa0e77ed8d19b04771.ssl.cf1.rackcdn.com/solr3.tiff" width=582 alt="Filter by quantity"/>  

From the results page the details of any individual receipt can quickly be accessed:  
<img src="https://ab7f2ee757dab14f977f-412ed90bcf7411fa0e77ed8d19b04771.ssl.cf1.rackcdn.com/solr2.tiff" width=889 alt="Receipt detail"/>  

Similarly, the details of any product result are just a click away:  
<img src="https://ab7f2ee757dab14f977f-412ed90bcf7411fa0e77ed8d19b04771.ssl.cf1.rackcdn.com/solr4.tiff" width=733 alt="Searching receipts by product"/>  


#### Task 2: Fraud Detection using Spark
##### Goal
The goal of this task is to determine fraudulent credit cards.  Credit cards are determined to be fraudulent if they are used in more than one state as defined by the task.

The goal can be adapted by asking the question:

###### Give me the top 20 most fraudulent credit card numbers grouped by state

##### New and Existing Cassandra Tables
Looking at the existing schema, the most pertinent tables to use to satisfy the above queries are the following:
```
receipts_by_credit_card (transactions where credit cards were used)
stores (store information)
```
We can join data from both tables to see where they are used based on state.

In order to the above query, we introduced a new table to hold the output data

```CQL
CREATE TABLE retail.num_times_fraud_cc_used_in_diff_state (
    dummy text,
    count int,
    credit_card_number bigint,
    time_uuid timeuuid,
    PRIMARY KEY (dummy, count, credit_card_number, time_uuid)
) WITH CLUSTERING ORDER BY (count DESC, credit_card_number DESC, time_uuid ASC)

Table Notes: We use a dummy partition key and order based on count.  Count is the number of times that credit card was used in a different state.
The timeuuid is used to give uniqueness to the primary key.  We recognise that use of a dummy partition key is not ideal, as this creates a
very wide row.  In future, we could check the largest value using the MAX() function in newer versions of cassandra, or do it at the application level.
```

##### Detecting fraudulent credit card using with Spark.
RetailRollup was used as a basis for this FraudDetection Spark Class.

Using Scala, the algorithm is as follows:

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

3) Join two RDD's based on 'store_id' as the key to create another RDD 
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

##### Displaying the information on the application.

Added the following entries to index.jinja2:
```jinja
  <li>
    <a href="/gcharts/GeoChart/?url=/api/simplequery&options={height:600,region:'US',resolution:'provinces'}&q=select state,num_transactions from fraudulent_credit_card_use_by_state">
      Google Charts: Number of fraudulent credit cards used by State
    </a>
  </li>
```
With the following corresponding table:

<img src="http://ceb0fc79be137b6f61e0-035db44ce48f9c179089b6a765245cb7.r19.cf6.rackcdn.com/graph2.PNG" width=200/ alt="most fraudulent credit card by count of state they were used in">  

##### Extensions:

###### Integration into Customer Table 
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

<img src="http://ceb0fc79be137b6f61e0-035db44ce48f9c179089b6a765245cb7.r19.cf6.rackcdn.com/graph3.PNG" width=733/ alt="Amount spent on fraud credit cards">  


###### Amount spent by Fraud Credit Cards   

Businesses want to know how much was spent on fraud so they can account for these in their reporting (and ultimately their bottom line).

We implement a table here to show how much each fraud credit card has spent.

Our new CQL table for this query is as follows.  It is a simple table outlining the credit card number and the amount spent per credit card.

```cql
CREATE TABLE retail.amount_spent_by_fraud_cc (
    credit_card_number bigint,
    amount_spent decimal,
    PRIMARY KEY (credit_card_number, amount_spent)
) WITH CLUSTERING ORDER BY (amount_spent ASC)
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

We utilise the following scala code to perform the calculation:
``` scala
    val creditCardByAmountSpent = receiptsByCC.map(r => (r.getLong("credit_card_number"), r.getDecimal("receipt_total")))
   creditCardByAmountSpent.join(fradulentCC).map({case (k,v) => (k,v._1)}).reduceByKey(_ + _).map({case (k,v) => (k, v)})
      .saveToCassandra("retail","amount_spent_by_fraud_cc",SomeColumns("credit_card_number","amount_spent"))
```

This code effectively maps the fraud credit credit number to the transaction amount and then performs a reduceByKey() to count up the total amount spent per creditcard.

Our Python application is updated in index.jinja2:
```jinja
</li>
    <li>
     <a href="/gcharts/Table/?url=/api/simplequery&q=select credit_card_number,amount_spent from amount_spent_by_fraud_cc&order_column=amount_spent&order_direction=-1">
     Google Charts: Total amount spent per fraudulent credit card
    </a>
</li>
```

And our output table looks like the following:

<img src="http://ceb0fc79be137b6f61e0-035db44ce48f9c179089b6a765245cb7.r19.cf6.rackcdn.com/graph4.PNG" width=200/ alt="amount spent on each fraud credit card">  

###### Determining number of fraud credit card transactions per state

In this extension we want to answer the question "How many fraudulent credit card transactions by state?".

We introduce a new table to cater for this query:

```CQL
CREATE TABLE retail.fraudulent_credit_card_use_by_state (
    state text,
    num_transactions int,
    time_uuid timeuuid,
    PRIMARY KEY (state, num_transactions, time_uuid)
) WITH CLUSTERING ORDER BY (num_transactions ASC, time_uuid ASC)

Notes: We list the number of fraudulent transactions per state (identified by state and num_transactions).  Timeuuid is used to give uniqueness.
```

Using the core code, we can populate the table by using the following code.  This code simply rejoins the fraudulent credit card list that we know against the original RDD of transactions.  It then counts the number of times these transactions occurred by state, using the reduceByKey() method.

For 'fraudulent_credit_card_use_by_state':
```scala
    creditCardAndState.join(fradulentCC).map({case (k,v) => (v._1, 1)}).reduceByKey(_ + _).map({case (k,v) => ("US-" + k, v, TimeUuid())})
      .saveToCassandra("retail","fraudulent_credit_card_use_by_state",SomeColumns("state","num_transactions","time_uuid"))

Notes: We join the fraudulent credit cards we know, back to the original transactions table.  We then count the number occurrences and the populate the table.
```

The Python application code is updated:

```jinja
  <li>
    <a href="/gcharts/Table/?url=/api/simplequery&q=select credit_card_number,count from num_times_fraud_cc_used_in_diff_state limit 20&order_column=count&order_direction=-1">
      Google Charts: Top 20 most fraudulent credit cards based on number of states used in
    </a>
  </li>
```

And the presentation of the table can be shown here:
<img src="http://ceb0fc79be137b6f61e0-035db44ce48f9c179089b6a765245cb7.r19.cf6.rackcdn.com/graph1.PNG" width=733/ alt="number of fraudulent credit cards used per state">  


 

##### Unimplemented Extensions:
1) The model could be extended to account for the number of fraudulent credit cards by date.  This could be achieved by group credit card receipts by date and matching against the fraudulent credit card list.

2) A new fraud detection needs to be implemented.  The current assumption and implementation is very poor.  We could do fraud detection based on timeframe and previous behaviours.



#### Task 3: Implement `customers` Table
##### Goal
The goal of this task is to create a customer table that provides basic customer info while also linking customers to their receipts.

##### Schema Analysis
The existing `retail` keyspace includes several tables storing receipt data.  The `receipts_by_credit_card` table is particularly interesting here:
```CQL
CREATE TABLE retail.receipts_by_credit_card (
    credit_card_number bigint,
    receipt_timestamp timestamp,
    receipt_id bigint,
    credit_card_type text static,
    receipt_total decimal,
    store_id int,
    PRIMARY KEY (credit_card_number, receipt_timestamp, receipt_id)
) WITH CLUSTERING ORDER BY (receipt_timestamp DESC, receipt_id DESC)
```

Using only a credit card number we can pull up all the associated receipts.  We will use this link to provide the ability to associate customers with previous purchases.  

We considered a variety of options, including a `set<bigint>` column of receipt_ids, or having separate customer summary tables along with a fully denormalized customer receipts table.  However, the typical workload for a store should mean that pulling all receipts for a customer is relatively rare, and we will use Solr indexing for customer search.  It should be fine to construct a customer table that allows us to then query for their receipts using their credit card number if required.

##### Table and Index Creation

Thus we construct a new `retail.customers` table:
```CQL
CREATE TABLE retail.customers (
    customer_name text,
    state text,
    city text,
    zipcode text,
    credit_card_number bigint,
    solr_query text,
    PRIMARY KEY (customer_name, state, city, zipcode, credit_card_number)
) WITH CLUSTERING ORDER BY (state ASC, city ASC, zipcode ASC, credit_card_number ASC)
```

The extra location attributes will help us with faceting when determining just what customer we are looking for in the search UI.

To provide search capabilities we construct a Solr index schema.
###### customers.xml
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

    <field name="customer_name"  type="text" indexed="true"  stored="true"/>
    <field name="state" type="string" indexed="true" stored="true"/>
    <field name="city" type="string" indexed="true" stored="true"/>
    <field name="zipcode"  type="string" indexed="true"  stored="true"/>
    <field name="credit_card_number" type="bigint" indexed="true" stored="true"/>
 </fields>

<defaultSearchField>customer_name</defaultSearchField>
<uniqueKey>(customer_name,state,city,zipcode,credit_card_number)</uniqueKey>

</schema>
```

We then create our index:
```
dsetool create_core retail.customers schema=customers.xml solrconfig=solrconfig.xml reindex=true
```

The index has now been added to the `customers` table.
```CQL
CREATE TABLE retail.customers (
    customer_name text,
    state text,
    city text,
    zipcode text,
    credit_card_number bigint,
    solr_query text,
    PRIMARY KEY (customer_name, state, city, zipcode, credit_card_number)
) WITH CLUSTERING ORDER BY (state ASC, city ASC, zipcode ASC, credit_card_number ASC)
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
CREATE CUSTOM INDEX retail_customers_solr_query_index ON retail.customers (solr_query) USING 'com.datastax.bdp.search.solr.Cql3SolrSecondaryIndex';
```

##### Populating Zipcodes
The `retail` keyspace already contains a `zipcodes` table:
```CQL
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
```
However, it is currently empty.  We do have a pip-delimited CSV file containing zipcode data, so we use that to populate the table:
```CQL
COPY retail.zipcodes (zipcode, city, state, lat, long, population, wages) FROM '../csv/zipcodes.csv' WITH delimiter = '|';
```

##### Populating Customers
In order to properly link customers to receipts and provide a sampling of the associated workload, we modify the supplied `scans.jmx` file to add several pieces.

Parse customer names:
```XML
<hashTree/>
    <CSVDataSet guiclass="TestBeanGUI" testclass="CSVDataSet" testname="CSV Customers" enabled="true">
        <stringProp name="filename">../csv/4000names.csv</stringProp>
            <stringProp name="fileEncoding"></stringProp>
        <stringProp name="variableNames">customer_name</stringProp>
        <stringProp name="delimiter"></stringProp>
        <boolProp name="quotedData">false</boolProp>
        <boolProp name="recycle">true</boolProp>
        <boolProp name="stopThread">false</boolProp>
        <stringProp name="shareMode">shareMode.all</stringProp>
    </CSVDataSet>
<hashTree/>
```
Parse zip codes:
```XML
<hashTree/>
    <CSVDataSet guiclass="TestBeanGUI" testclass="CSVDataSet" testname="CSV zipcodes" enabled="true">
        <stringProp name="filename">../csv/zipcodes.csv</stringProp>
        <stringProp name="fileEncoding"></stringProp>
        <stringProp name="variableNames">zipcode,city,state,lat,long,population,wages</stringProp>
        <stringProp name="delimiter">|</stringProp>
        <boolProp name="quotedData">false</boolProp>
        <boolProp name="recycle">true</boolProp>
        <boolProp name="stopThread">false</boolProp>
        <stringProp name="shareMode">shareMode.all</stringProp>
    </CSVDataSet>
<hashTree/>
```
Insert customer for each receipt:
```XML
<CassandraSampler guiclass="TestBeanGUI" testclass="CassandraSampler" testname="Insert Customer" enabled="true">
    <stringProp name="sessionName">cc</stringProp>
    <stringProp name="queryType">Prepared Statement</stringProp>
    <stringProp name="query">insert into customers (customer_name, city, state, zipcode, credit_card_number) values (?,?,?,?,?)</stringProp>
    <stringProp name="queryArguments">${customer_name},${city},${state},${zipcode},${credit_card_number}</stringProp>
    <stringProp name="variableNames"></stringProp>
    <stringProp name="resultVariable"></stringProp>
    <stringProp name="consistencyLevel">ONE</stringProp>
    <stringProp name="batchSize"></stringProp>
</CassandraSampler>
```
Running JMeter using our updated `scans.jmx` gives us some customer data to work with:
```
jmeter -n -t scans.jmx
```

##### Constructing Search UI
We will modify the existing python web application to expose our new customer functionality.  First we create a new Jinja template to provide the UI for search.  This template provides a table for the search results as well as a sidebar for further filtering by state, city, and zipcode.

###### search_receipts.jinja2
```jinja
{% extends "/base.jinja2" %}

{% block head %}
{% endblock %}

{% block body %}
      Solr Search of Customers by Name:<br>
     <div id="solr_div">

    <form action="/web/search_customers">
      <input type="text" name="s">
      <input type="submit" value="Search">
    </form>
    </div>
<br>
    <section>
    <div id="facet" style="float:left;width:20%">
    Narrow Results By:<br><br>

{% if states %}
  <b>State:</b><br>

  {% for state in states %}
  {% set new_filter_by = 'state:"' + state.name + '"'%}
  {% if filter_by %}
    {% set new_filter_by = filter_by + " AND " + new_filter_by %}
  {% endif %}

  <a href="{{ makeURL("/web/search_customers","s", search_term, "filter_by", new_filter_by) }}">{{ state.name }}:</a>&nbsp;{{ state.amount}}<br>
  {% endfor %}
  <br>
{% endif %}

{% if cities %}
  <b>City:</b><br>

  {% for city in cities %}
  {% set new_filter_by = 'city:"' + city.name + '"'%}
  {% if filter_by %}
    {% set new_filter_by = filter_by + " AND " + new_filter_by %}
  {% endif %}

  <a href="{{ makeURL("/web/search_customers","s", search_term, "filter_by", new_filter_by) }}">{{ city.name }}:</a>&nbsp;{{ city.amount}}<br>
  {% endfor %}
  <br>
{% endif %}

{% if zipcodes %}
  <b>Zipcode:</b><br>

  {% for zipcode in zipcodes %}
  {% set new_filter_by = 'zipcode:"' + zipcode.name + '"'%}
  {% if filter_by %}
    {% set new_filter_by = filter_by + " AND " + new_filter_by %}
  {% endif %}

  <a href="{{ makeURL("/web/search_customers","s", search_term, "filter_by", new_filter_by) }}">{{ zipcode.name }}:</a>&nbsp;{{ zipcode.amount}}<br>
  {% endfor %}
  <br>
{% endif %}

    </div>
    <div id="list_div" style="float:right;width:80%">
        <br>
        <table border="1">
        <th>&nbsp;Customer Name&nbsp;</th>
        <th>&nbsp;State&nbsp;</th>
        <th>&nbsp;City&nbsp;</th>
        <th>&nbsp;Zipcode&nbsp;</th>
        <th>&nbsp;CC Number&nbsp;</th>
        <th>&nbsp;All Receipts&nbsp;</th>
        {% if customers %}
            {% for customer in customers %}

                {% set zip_new_filter_by = 'zipcode:"' + customer.zipcode + '"'%}
                  {% if filter_by %}
                    {% set zip_new_filter_by = filter_by + " AND " + zip_new_filter_by %}
                  {% endif %}
                {% set city_new_filter_by = 'city:"' + customer.city + '"'%}
                  {% if filter_by %}
                    {% set city_new_filter_by = filter_by + " AND " + city_new_filter_by %}
                  {% endif %}
                {% set state_new_filter_by = 'state:"' + customer.state + '"'%}
                  {% if filter_by %}
                    {% set state_new_filter_by = filter_by + " AND " + state_new_filter_by %}
                  {% endif %}

                <tr>
                <td>&nbsp;{{ customer.customer_name }}</td>
                <td><a href="{{ makeURL("/web/search_customers","s", search_term, "filter_by", state_new_filter_by) }}">&nbsp;{{ customer.state }}</a></td>
                <td><a href="{{ makeURL("/web/search_customers","s", search_term, "filter_by", city_new_filter_by) }}">&nbsp;{{ customer.city }}</a></td>
                <td><a href="{{ makeURL("/web/search_customers","s", search_term, "filter_by", zip_new_filter_by) }}">&nbsp;{{ customer.zipcode }}</a></td>
                <td>&nbsp;{{ customer.credit_card_number }}</td>
                <td><a href="/web/credit_card?cc_no={{ customer.credit_card_number }}">&nbsp;Receipt List</a></td>
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
@web_api.route('/search_customers')
def search_customers():

    search_term = request.args.get('s')

    if not search_term:
        return render_template('search_customers.jinja2',
                               customers = None)

    filter_by = request.args.get('filter_by')

    solr_query = '"q":"customer_name:%s"' % search_term.replace('"','\\"').encode('utf-8')

    if filter_by:
        solr_query += ',"fq":"%s"' % filter_by.replace('"','\\"').encode('utf-8')

    query = "SELECT * FROM customers WHERE solr_query = '{%s}' LIMIT 300" % solr_query

    # get the response
    results = cassandra_helper.session.execute(query)

    facet_query = 'SELECT * FROM customers WHERE solr_query = ' \
                  '\'{%s,"facet":{"field":["state","city","zipcode"]}}\' ' % solr_query

    facet_results = cassandra_helper.session.execute(facet_query)
    facet_string = facet_results[0].get("facet_fields")

    # convert the facet string to an ordered dict because solr sorts them desceding by count, and we like it!
    facet_map = json.JSONDecoder(object_pairs_hook=OrderedDict).decode(facet_string)

    return render_template('search_customers.jinja2',
                           search_term = search_term,
                           states = filter_facets(facet_map['state']),
                           cities = filter_facets(facet_map['city']),
                           zipcodes = filter_facets(facet_map['zipcode']),
                           customers = results,
                           filter_by = filter_by)
```
Finally, we expose our new functionality to the user by linking to it from the `index.jinja2` template:
```html
<li>
    <a href="/web/search_customers">Search for Customers</a>
</li>
```

Our new UI allows searching of customers by name:   
<img src="https://9c6a626b21c9461a6fe9-87f24ae4b76a6d93e356191fc0695acc.ssl.cf1.rackcdn.com/customers1.tiff" width=740 alt="Searching customers by name"/>  
The results can be filtered by the state, city, or zipcode.  

Clicking the "Receipts List" link pulls all the receipts for that customer card:   
<img src="https://9c6a626b21c9461a6fe9-87f24ae4b76a6d93e356191fc0695acc.ssl.cf1.rackcdn.com/customers2.tiff" width=1020 alt="CC Receipt List"/>  

From there we can access the details of an individual receipt:  
<img src="https://9c6a626b21c9461a6fe9-87f24ae4b76a6d93e356191fc0695acc.ssl.cf1.rackcdn.com/customers3.tiff" width=1012 alt="Receipt detail"/>  
