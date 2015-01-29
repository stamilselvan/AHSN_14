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

typedef nx_struct settings {
  nx_uint16_t threshold;
  nx_uint32_t sample_time;
  nx_uint32_t sample_period;
} settings_t;

nx_struct settings_report {
 nx_uint16_t sender;
 nx_uint8_t type;
 settings_t settings;
};

nx_struct theft_report {
 nx_uint16_t who;
};




#define REPORT_DEST "fec0::100"
#define MULTICAST "ff02::1"

#endif
