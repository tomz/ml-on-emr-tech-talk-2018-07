from __future__ import print_function

import sys, time, boto3, os
import simplejson as json

from pyspark import SparkContext
from pyspark.streaming import StreamingContext
from pyspark.streaming.kinesis import KinesisUtils, InitialPositionInStream
from pyspark.sql import SparkSession
from pyspark.sql.types import IntegerType
from pyspark.sql.functions import udf, from_json, col, expr

def get_sentiment_comprehend(text):
  try:
    comprehend = boto3.client(service_name='comprehend', region_name='us-east-1')
    response = comprehend.detect_sentiment(Text=text, LanguageCode='en')
    sentiment_str = response["Sentiment"]
    if sentiment_str == "POSITIVE":
      sentiment = 1
    elif sentiment_str == "NEGATIVE":
      sentiment = -1
    elif sentiment_str == "NEUTRAL":
      sentiment = 0
    else:
      sentiment = -99
  except:
    sentiment = -99
  return sentiment

def get_sentiment_sagemaker(text):
  try:
    sagemaker = boto3.client('runtime.sagemaker', region_name='us-east-1')
    endpoint_name='sagemaker-mxnet-py2-cpu-2017-12-01-21-37-29-539'
    result = sagemaker.invoke_endpoint(
      EndpointName=endpoint_name,
      Body=json.dumps([text])
      )
    sentiment = json.loads(result["Body"].read())[0]
  except:
    sentiment = -99
  return sentiment

def get_sentiment_local(text):
  # TODO call local end point
  return -99

#func_udf = udf(get_sentiment_local, IntegerType())
#func_udf = udf(get_sentiment_sagemaker, IntegerType())
func_udf = udf(get_sentiment_comprehend, IntegerType())


if __name__ == "__main__":
  if len(sys.argv) != 8:
    print(
      "Usage: kinesis_spark_structured_streaming_tweets_sentiment.py <app-name> <stream-name> <endpoint-url> <region-name> <interval> <format> <output-location>",
      file=sys.stderr)
    sys.exit(-1)

  appName = "Python Kinesis Structured Streaming Tweet Sentiments"
  interval = '60 seconds' # every 1m

  streamName = "tomz-test"
  endpointUrl = "https://kinesis.us-east-1.amazonaws.com"
  regionName = "us-east-1"
  
  awsAccessKeyId=os.environ["AWS_ACCESS_KEY_ID"]
  awsSecretKey=os.environ["AWS_SECRET_KEY"]
  
  outputFormat = "json" # "parquet"
  outputLocation = "s3://tomzeng-perf2/data/tweets-with-sentiments-structured-streaming."+outputFormat+"/"

  appName, streamName, endpointUrl, regionName, interval, outputFormat, outputLocation = sys.argv[1:]  

  spark = SparkSession \
    .builder \
    .appName(appName) \
    .enableHiveSupport() \
    .getOrCreate()
        
  kinesisDF = spark \
    .readStream \
    .format("kinesis") \
    .option("streamName", streamName) \
    .option("initialPosition", "earliest") \
    .option("region", regionName) \
    .option("awsAccessKeyId", awsAccessKeyId) \
    .option("awsSecretKey", awsSecretKey) \
    .option("endpointUrl", endpointUrl) \
    .load()

  # read a sample json document
  tweets_sample = spark.read.json("s3://tomzeng-perf2/data/sample-tweets.json")

  # get the schema from the sample json
  json_schema = tweets_sample.schema

  sentimentDF = kinesisDF \
    .selectExpr("cast (data as STRING) jsonData") \
    .select(from_json("jsonData",json_schema).alias("tweets")) \
    .select("tweets.*") \
    .withColumn('sentiment',func_udf(col('text'))) \
    .withColumn('year', expr('year(to_date(from_unixtime(timestamp_ms/1000)))')) \
    .withColumn('month', expr('month(to_date(from_unixtime(timestamp_ms/1000)))')) \
    .withColumn('day', expr('day(to_date(from_unixtime(timestamp_ms/1000)))')) \
    .withColumn('hour', expr('cast(from_unixtime(unix_timestamp(from_unixtime(timestamp_ms/1000), "yyyy-MM-dd HH:mm:ss"), "HH") as int)')) \
    .writeStream \
    .partitionBy("year","month","day","hour") \
    .format(outputFormat) \
    .option("checkpointLocation", "/outputCheckpoint") \
    .trigger(processingTime=interval) \
    .start(outputLocation)

  sentimentDF.awaitTermination()

