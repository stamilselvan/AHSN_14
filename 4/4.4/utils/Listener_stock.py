
import socket
import Sensing
import re
import sys
import string
import MySQLdb
import time
# change the root password as per ur system
connection = MySQLdb.connect (host = "localhost", user = "root", passwd = "Vxpa8327", db = "inventory_list")

cursor = connection.cursor ()

cursor.execute ('CREATE TABLE IF NOT EXISTS humidity_table (nodeId VARCHAR(10) primary key not null, humidity VARCHAR(10))')


port = 7000
if __name__ == '__main__':

    s = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    s.bind(('', port))

    while True:
        data, addr = s.recvfrom(1024)
        if (len(data) > 0):

            rpt = Sensing.Sensing(data=data, data_length=len(data))
            #print rpt
	    nodeId_value = rpt.get_sender()
	    humidity_value = rpt.get_humidity()
	    print 'Format: {nodeId}, {humidity}'.format(nodeId=nodeId_value, humidity=humidity_value)
	    cursor.execute ('insert into humidity_table values("%s", "%s") ON DUPLICATE KEY UPDATE humidity = "%s"' % \
			 (nodeId_value, humidity_value, humidity_value))


	    connection.commit ()
