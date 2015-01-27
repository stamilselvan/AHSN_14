#ifndef SENSING_H_
#define SENSING_H_

enum {
      AM_SENSING_REPORT = -1
};

nx_struct sensing_report {
  //nx_uint16_t seqno;
  nx_uint16_t sender;
  //nx_uint16_t light;
  //nx_bool iis_lost;
  nx_uint16_t is_lost;
} ;

#define REPORT_DEST "fec0::100"

#endif
