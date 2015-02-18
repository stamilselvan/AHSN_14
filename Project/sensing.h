#ifndef SENSING_H_
#define SENSING_H_


enum {
      AM_SENSING_REPORT = -1
};

typedef nx_struct settings {
	nx_uint16_t threshold;
	nx_uint32_t sample_period;
} settings_t;

nx_struct settings_report {
	 nx_uint8_t product_id;
	 nx_uint16_t temp;
	 nx_uint8_t node_id;
         nx_uint8_t warning;
};

#define REPORT_DEST "fec0::100"
#define MULTICAST "ff02::1"

#endif
