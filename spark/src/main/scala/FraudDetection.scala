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

    // Create an RDD with tuples mapping store_id to state
    val stores = sc.cassandraTable("retail","stores").select("store_id","address",
      "address_2","address_3","city","state","zip","size_in_sf"
    ).as(FraudStore)
    val storeState = stores.map(s => (s.store_id, s.state))

    // Create an RDD with tuples mapping store_id with credit_card_number (representing a transaction at that store)
    val receiptsByCC = sc.cassandraTable("retail","receipts_by_credit_card")
    val creditCardByStoreID = receiptsByCC.map(r => (r.getInt("store_id"), r.getLong("credit_card_number")))
    val creditCardByAmountSpent = receiptsByCC.map(r => (r.getLong("credit_card_number"), r.getDecimal("receipt_total")))


    // Create an RDD with customer credit card and where they live
    val customerCCNumAndState = sc.cassandraTable("retail", "customers").map(r => (r.getLong("credit_card_number"),r.getString("state")))

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

    // Load data showing where all the fraudulent credit cards come from by state
    customerCCNumAndState.join(fradulentCC).map({case (k,v) => (v._1,1)}).reduceByKey(_ + _).map({case (k,v) => ("US-" + k, v, TimeUuid())})
      .saveToCassandra("retail","fraudulent_cc_by_owner_state",SomeColumns("state","num_credit_cards","time_uuid"))

    // Determines the total amount spent per fraudulent creditcard and inserts it into appropriate table
    creditCardByAmountSpent.join(fradulentCC).map({case (k,v) => (k,v._1)}).reduceByKey(_ + _).map({case (k,v) => (k, v)})
      .saveToCassandra("retail","amount_spent_by_fraud_cc",SomeColumns("credit_card_number","amount_spent"))


    //myvalue.collect().foreach(println)
  }
}