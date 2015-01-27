
import socket
import Sensing1
import re
import sys

port = 8000

if __name__ == '__main__':

    s = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    s.bind(('', port))

    while True:
        data, addr = s.recvfrom(1024)
        if (len(data) > 0):

            rpt = Sensing1.Sensing(data=data, data_length=len(data))

            print addr
            print rpt

