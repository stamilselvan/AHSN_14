#include <lib6lowpan/ip.h>

#include <Timer.h>
#include "blip_printf.h"
#include "sensing.h"

module LightP {
	uses {
		interface Boot;
		interface Leds;
		interface SplitControl as RadioControl;
		interface Timer<TMilli> as SensorReadTimer;
		interface Timer<TMilli> as BlinkTimer;

		interface Read<uint16_t> as Temperature;

		interface ShellCommand as GetCmd;
		interface ShellCommand as SetCmd;
		
		interface UDP as SettingSend;
	}
} implementation {

	/* Initial values */
	enum {
		SAMPLE_PERIOD = 1024 * 5, // 
		TEMP_THRESHOLD = 9000,
		PRODUCT_ID = 1,	// 2 -> MILK
		BLINK_PERIOD = 512
	};

	nx_struct settings_report sreport;
	settings_t configure;
	bool isDevSync = FALSE;

	struct sockaddr_in6 multicast;
	struct sockaddr_in6 settings_multicast;
	uint8_t alternate_count = 0;

	// boot
	event void Boot.booted() {

		/* set the default values to the settings */
		memset(&sreport, 0, sizeof(sreport));
		memset(&configure, 0, sizeof(configure));

		configure.threshold = TEMP_THRESHOLD;
		configure.sample_period = SAMPLE_PERIOD;

		sreport.node_id = TOS_NODE_ID;
		sreport.product_id = PRODUCT_ID;
		sreport.temp = 0;

		settings_multicast.sin6_port = htons(4000);
		inet_pton6(MULTICAST, &settings_multicast.sin6_addr);
		call SettingSend.bind(4000);
	
		call RadioControl.start();
	}

	task void report_settings() {
		call Leds.led2Toggle();
		call SettingSend.sendto(&settings_multicast, &sreport, sizeof(sreport));
	}

	event void Temperature.readDone(error_t e, uint16_t data) {
		sreport.temp = (nx_uint16_t) data;
		
		if(sreport.temp > configure.threshold ){
			call BlinkTimer.startPeriodic(BLINK_PERIOD);
		}
		else if(call BlinkTimer.isRunning()) {
			call Leds.set(0);
			call BlinkTimer.stop();
		}

		post report_settings();
	}
	// radio
	event void RadioControl.startDone(error_t e) {
		call SensorReadTimer.startOneShot(configure.sample_period * 2);
	}

	event void RadioControl.stopDone(error_t e) {}

	//Timer
	event void SensorReadTimer.fired() {
		if(isDevSync) {
			call Temperature.read();
		}
		else {
			/* we are alone in the network */
			isDevSync = TRUE;
			call SensorReadTimer.startPeriodic(configure.sample_period);
		}
	}

	event void BlinkTimer.fired() {
		// setting the led to node_id and 0 alternatively for blinking effect
		call Leds.set((alternate_count%2 == 0) ? 7 : 0);
		++alternate_count % 2;	
	}


	event char *GetCmd.eval(int argc, char **argv) {
		char *ret = call GetCmd.getBuffer(50);

		if (ret != NULL) {
			switch (argc) {
				case 1:
					sprintf(ret, "\t[Period: %lu]\n\t[Threshold: %u]\n\t[Pro_ID: %u]\n\t[Temp:%u]\n", 
						configure.sample_period, configure.threshold, sreport.product_id, sreport.temp );
					break;
				case 2: 
					if (!strcmp("per",argv[1])) {
						sprintf(ret, "\t[Period: %lu]\n", configure.sample_period);
					} else if (!strcmp("th", argv[1])) {
						sprintf(ret, "\t[Threshold: %u]\n",configure.threshold);
					} else if (!strcmp("id", argv[1])) {
						sprintf(ret, "\t[Pro_ID: %u]\n", sreport.product_id);
					} else if(!strcmp("temp", argv[1])) {
						sprintf(ret, "\t[Temp: %u]\n", sreport.temp);
					} else {
						strcpy(ret, "Usage: get [per|th|id|temp|]\n");
					}
					break;
				default:
					strcpy(ret, "Usage: get [per|th|id|temp|]\n");
			}
		}
		return ret;
	}

	event char *SetCmd.eval(int argc, char **argv) {
		char *ret = call SetCmd.getBuffer(40);

		if (ret != NULL) {
			if (argc == 3) { 
				if (!strcmp("per",argv[1])) {
					configure.sample_period = atoi(argv[2]);
					call SensorReadTimer.startPeriodic(configure.sample_period + TOS_NODE_ID);
					sprintf(ret, ">>>Period changed to %lu\n", configure.sample_period);
				} else if (!strcmp("th", argv[1])) {
					configure.threshold = atoi(argv[2]);
					sprintf(ret, ">>>Threshold changed to %u\n", configure.threshold);
				} else if (!strcmp("id", argv[1])) {
					sreport.product_id = atoi(argv[2]);
					sprintf(ret, ">>>Pro_ID changed to %u\n", sreport.product_id);
				}  else {
					strcpy(ret,"Usage: set per|th|id [<sampleperiod ms>|<threshold>|<product id>]\n");
				}
			} else {
				strcpy(ret,"Usage: set per|th|id [<sampleperiod ms>|<threshold>|<product id>]\n");
			}
		}
		return ret;
	}

	event void SettingSend.recvfrom(struct sockaddr_in6 *from, void *data,
					uint16_t len, struct ip6_metadata *meta) {

		if(!isDevSync) {
			isDevSync = TRUE;
			call Leds.led1On();
			call SensorReadTimer.startPeriodic(configure.sample_period + TOS_NODE_ID);
		}
		
	}

}
