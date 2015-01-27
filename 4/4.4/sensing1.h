#ifndef SENSING1_H_
#define SENSING1_H_

enum {
      AM_SENSING_REPORT1 = -1
};

nx_struct sensing1_report {
  nx_uint16_t seqno;
  nx_uint16_t sender;
   nx_uint16_t light;
} ;

#define REPORT_DEST "fec0::100"

#endif
