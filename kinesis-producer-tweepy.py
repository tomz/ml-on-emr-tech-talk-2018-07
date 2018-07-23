from tweepy import Stream
from tweepy import OAuthHandler
from tweepy.streaming import StreamListener
import sys
import boto3
import os
from datetime import datetime
import calendar
import random
import time
import simplejson as json

stream_name = 'tomz-test'

kinesis_client = boto3.client('kinesis', region_name='us-east-1')

#consumer key, consumer secret, access token, access secret.
consumerKey=os.environ["TWITTER_CONSUMER_KEY"]
consumerSecret=os.environ["TWITTER_CONSUMER_SECRET"]
accessToken=os.environ["TWITTER_ACCESS_KEY"]
accessSecret=os.environ["TWITTER_ACCESS_SECRET"]

class listener(StreamListener):

    def on_data(self, data):
        #all_data = json.loads(data)
        #tweet = all_data["text"]        
        #username = all_data["user"]["screen_name"]
        #print((username,tweet))
        #print(tweet)
        print(data.rstrip())

        put_response = kinesis_client.put_record(
                        StreamName=stream_name,
                        Data=data,
                        PartitionKey="fake")

        time.sleep(0.05)
        return True

    def on_error(self, status):
        print status

auth = OAuthHandler(consumerKey, consumerSecret)
auth.set_access_token(accessToken, accessSecret)

track = sys.argv[1].split(',') #if len(sys.argv) > 1 else ["amazon","aws"] 
twitterStream = Stream(auth, listener())
twitterStream.filter(track=track,languages=["en"])
