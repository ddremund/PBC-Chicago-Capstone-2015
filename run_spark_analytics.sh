#!/bin/bash

cqlsh -e "truncate retail.fraudulent_credit_card_use_by_state" capstone
cqlsh -e "truncate retail.num_times_fraud_cc_used_in_diff_state" capstone
cqlsh -e "truncate retail.fraudulent_cc_by_owner_state" capstone
cd /root/PBC-Chicago-Capstone-2015/spark
sbt assembly
dse spark-submit --class RollupRetail target/scala-2.10/spark-retail-assembly-1.1.jar
dse spark-submit --class FraudDetection target/scala-2.10/spark-retail-assembly-1.1.jar
