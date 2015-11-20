import com.datastax.spark.connector._
import com.gilt.timeuuid._
import org.apache.spark.{SparkConf, SparkContext}

import scala.math.BigDecimal.RoundingMode

case class FraudStore(
                  store_id: Int,
                  address: String,
                  address_2: String,
                  address_3: String,
                  city: String,
                  state: String,
                  zip: Long,
                  size_in_sf: Int)

object FraudDetection {

  def main(args: Array[String]) {

//    Create Spark Context
    val conf = new SparkConf(true).setAppName("FraudDetection")

// We set master on the command line for flexibility
    val sc = new SparkContext(conf)

    // Create some general RDDs
    val stores = sc.cassandraTable("retail","stores").select("store_id","address",
      "address_2","address_3","city","state","zip","size_in_sf"
    ).as(FraudStore)
    val receiptsByCC = sc.cassandraTable("retail","receipts_by_credit_card")

    // Create an RDD with tuples mapping store_id to state
    val storeState = stores.map(s => (s.store_id, s.state))

    // Create an RDD with tupples mapping store_id with credit_card_number (representing a transaction at that store)
    val creditCardByStoreID = receiptsByCC.map(r => (r.getInt("store_id"), r.getLong("credit_card_number")))

    // Based on the store ID as a key, join two RDD's together and filter out the StoreID as it's no longer required.
    // This will create tuples in the format (credit_card_number, state (where the cc was used)).
    // Then filter out duplicates by using the distinct option.  This filters out cards that have been used more than once in the same state.
    val creditCardAndState = creditCardByStoreID.join(storeState).map({case (k,v) => (v._1, v._2)})
    val distinctCreditCardAndState = creditCardAndState.distinct

    // Now that we know there is only one element representing use of of  credit card per state
    // create a new RDD with tuples (credit_card_number, 1).  The '1' represents a usage of the credit card within a state
    // Following this, do a reduceByKey which will count the number of occurrences of that card use in each state.
    val creditCardUsePerState = distinctCreditCardAndState.map({case (k,v) => (k,1)}).reduceByKey(_ + _)

    // Now go ahead and filter out all credit cards used only once (i.e. with a value of 1) as these aren't fraudulent
    val fradulentCC = creditCardUsePerState.filter{
      _ match {
        case (k,v) => v != 1
      }
    }

    // Loads the number of times a Fraudulent Credit Card has been used in different states
    fradulentCC.map({case (k,v) => ("dummy", k,v,TimeUuid())}).saveToCassandra("retail","num_times_fraud_cc_used_in_diff_state",SomeColumns("dummy","credit_card_number","count","time_uuid"))

    // This loads data into cassandra table showing number of fraudulent credit cards used by state
    creditCardAndState.join(fradulentCC).map({case (k,v) => (v._1, 1)}).reduceByKey(_ + _).map({case (k,v) => ("US-" + k, v, TimeUuid())})
      .saveToCassandra("retail","fraudulent_credit_card_use_by_state",SomeColumns("state","num_transactions","time_uuid"))
    //creditCardByStoreStateCount.collect().foreach(println)
  }
}
//creditCardByStoreStateCount.map({case (k,v) => ("US-" + v, k, TimeUuid())}).saveToCassandra("retail","credit_card_usage_by_state",SomeColumns("state","credit_card","time_uuid"))
