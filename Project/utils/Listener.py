
import socket
import Sensing
import re
import sys
import string
import MySQLdb
import time
import thread

connection = MySQLdb.connect (host = "explorea.org", user = "snp", passwd = "tinySTOCK", db = "snp")

cursor = connection.cursor ()


cursor.execute ('CREATE TABLE IF NOT EXISTS product (nodeId VARCHAR(10) primary key not null, productId VARCHAR(10), temperature VARCHAR(10), warning VARCHAR(1))')

port = 4000
name = "defaule"

def feeder( threadName, delay):

    s = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    s.bind(('', port))
    while True:
        data, addr = s.recvfrom(1024)
        if (len(data) > 0):

            rpt = Sensing.Sensing(data=data, data_length=len(data))
	    nodeId = rpt.get_node_id()
	    productId = rpt.get_product_id()
	    temperature = rpt.get_temp()
	    warning = rpt.get_warning()
	    #print rpt
	    print 'Format: {nodeId}, {productId}, {temperature}, {warning}'.format(nodeId=nodeId, productId=productId, temperature=temperature, warning=warning)
	    cursor.execute ('insert into product values("%s", "%s", "%s", "%s") ON DUPLICATE KEY UPDATE temperature = "%s", warning = "%s"' % \
				(nodeId, productId, temperature, warning, temperature, warning))
	    connection.commit ()


def print_time( threadName, delay):
      while True:
      	 time.sleep(delay)
     	 print "clearing db"
     	 cursor.execute('truncate table product')


if __name__ == '__main__':

  # Create two threads as follows
  try:
   thread.start_new_thread( feeder, ("Thread-1", 2) )
   thread.start_new_thread( print_time, ("Thread-2", 15, ) )
  except:
   print "Error: unable to start thread"

  while 1:
   pass


