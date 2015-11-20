#!/bin/bash
web-python/run &
dse spark-submit --class HotProductsStream sparkstreaming/target/scala-2.10/spark-streaming-retail-assembly-1.1.jar

