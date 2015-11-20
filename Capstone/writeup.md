## Capstone Project

Group: Derek Remund, Gene Tang

#### Task 2: Fraud Detection using Spark
#### Goal
The goal of this task is to determine fraudulent credit cards.  

####### Credit cards are determined to be fraudulent if they are used in more than one state as defined by the task.

We want to be able to visually show these things:
1)	Top 20 most fraudulent credit card numbers based on the number of states they were used
2)	Number of transactions that were fraudulent per states 
#### New and Existing Cassandra Tables
Looking at the existing schema, the most pertinent tables to use to satisfy the above queries are the following:
```
receipts_by_credit_card (transactions where credit cards were used)
stores (store information)
```
We can join data from both tables to see where they are used based on state.

In order to answer the above queries, we introduced two new tables that help to satisfy these queries.
Used to satisfy Query 1:
```
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
```
CREATE TABLE retail.fraudulent_credit_card_use_by_state (
    state text,
    num_transactions int,
    time_uuid timeuuid,
    PRIMARY KEY (state, num_transactions, time_uuid)
) WITH CLUSTERING ORDER BY (num_transactions ASC, time_uuid ASC)

Notes: We list the number of fraudulent transactions per state (identified by state and num_transactions).  Timeuuid is used to give uniqueness.
```

#### Detecting fraudulent credit card use with Spark.
RetailRollup was used as a basis for this FraudDetection Spark Class.

Using Scala the basic algorithm will be as follows:
```
1) Pull data from 'retail.receipts_by_credit_card' into an RDD.  We require the attributes 'store_id' and 'credit_card_number'.
2) Pull data from 'retail.stores' into an RDD.  We require the attributes 'store_id' and 'state'.
3) We join two RDD's based on 'store_id' to create another RDD
4) Using RDD from (3) we remove any duplicate elements.  This represents entries where the credit card was used in the same state which is not a fraudulent action.  
The output RDD from now represents a credit card use per state.  If the credit card exists more than once in this RDD, then it means that it has been used in more than one state and is therefore fraudulent.  
5) Count the number of times a credit card occurs within this RDD
6) Filter out credit card numbers that only occur once
7) Output RDD is a list of all credit cards that are fraudulent
```

The above algorithm can be performed using the following scala code:

1) Pull data from 'retail.receipts_by_credit_card' into a RDD with tuples (store_id, credit_card_number):
```
    val receiptsByCC = sc.cassandraTable("retail","receipts_by_credit_card")
    val creditCardByStoreID = receiptsByCC.map(r => (r.getInt("store_id"), r.getLong("credit_card_number")))
```

2) Pull data from 'retail.stores' into a RDD with tuples (store_id, state)
```
    // Create some general RDDs
    val stores = sc.cassandraTable("retail","stores").select("store_id","address",
      "address_2","address_3","city","state","zip","size_in_sf"
    ).as(FraudStore)
    val receiptsByCC = sc.cassandraTable("retail","receipts_by_credit_card")
    val storeState = stores.map(s => (s.store_id, s.state))
```

3) We join two RDD's based on 'store_id' as the key to create another RDD 
```
    val creditCardAndState = creditCardByStoreID.join(storeState).map({case (k,v) => (v._1, v._2)})
```

4) Using RDD from (3) we remove any duplicate elements. 
```
val distinctCreditCardAndState = creditCardAndState.distinct
```

5) Count the number of times a credit card occurs within this RDD
```
    val creditCardUsePerState = distinctCreditCardAndState.map({case (k,v) => (k,1)}).reduceByKey(_ + _)
```

6) Filter out credit card numbers that only occur once
```
    // Now go ahead and filter out all credit cards used only once (i.e. with a value of 1) as these aren't fraudulent
    val fradulentCC = creditCardUsePerState.filter{
      _ match {
        case (k,v) => v != 1
      }
    }
```

7) Output RDD from (6) into the appropriate Cassandra tables:

For 'num_times_fraud_cc_used_in_diff_state':
```
    fradulentCC.map({case (k,v) => ("dummy", k,v,TimeUuid())}).saveToCassandra("retail","num_times_fraud_cc_used_in_diff_state",SomeColumns("dummy","credit_card_number","count","time_uuid"))
```

For 'fraudulent_credit_card_use_by_state':
```
    creditCardAndState.join(fradulentCC).map({case (k,v) => (v._1, 1)}).reduceByKey(_ + _).map({case (k,v) => ("US-" + k, v, TimeUuid())})
      .saveToCassandra("retail","fraudulent_credit_card_use_by_state",SomeColumns("state","num_transactions","time_uuid"))

Notes: We join the fraudulent credit cards we know, back to the original transactions table.  We then count the number occurrences and the populate the table.
```

#### Displaying the information on the application.

Added the following entries to index.jinja2:

Query 1:
```
  <li>
    <a href="/gcharts/GeoChart/?url=/api/simplequery&options={height:600,region:'US',resolution:'provinces'}&q=select state,num_transactions from fraudulent_credit_card_use_by_state">
      Google Charts: Number of fraudulent credit cards used by State
    </a>
  </li>
```

Query 2:
```
  <li>
    <a href="/gcharts/Table/?url=/api/simplequery&q=select credit_card_number,count from num_times_fraud_cc_used_in_diff_state limit 20&order_column=count&order_direction=-1">
      Google Charts: Top 20 most fraudulent credit cards based on number of states used in
    </a>
  </li>
```

#### Future Extensions:

