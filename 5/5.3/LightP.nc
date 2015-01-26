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

		interface ReadStream<uint16_t> as StreamPar;

		interface ShellCommand as ResetCmd;
		interface ShellCommand as GetCmd;
		interface ShellCommand as SetCmd;
		
		// added UDP Socket
		interface UDP as TheftSend;
		interface UDP as SettingSend;

		interface Mount as ConfigMount;
		interface ConfigStorage;
	}
} implementation {

	enum {
		SAMPLE_SIZE = 10,
		NUM_SENSORS = 1,
		SETTINGS_REQUEST = 1,
		SETTINGS_RESPONSE = 2,
		SETTINGS_USER = 4,
	};

	/* Initial values */
	enum {
		LIGHT_THRESHOLD = 10,
		SAMPLE_TIME = 10240, // ms
		SAMPLE_PERIOD = 1024, // us
	};

	nx_struct theft_report treport;
	nx_struct settings_report sreport;

	uint16_t m_parSamples[SAMPLE_SIZE];
	
	struct sockaddr_in6 multicast;
	struct sockaddr_in6 settings_multicast;
	uint8_t stolen_node, alternate_count = 0;

	// boot
	event void Boot.booted() {

		/* set the default values to the settings */
		sreport.settings.threshold = LIGHT_THRESHOLD;
		sreport.settings.sample_time = SAMPLE_TIME;
		sreport.settings.sample_period = SAMPLE_PERIOD;

		multicast.sin6_port = htons(7000);
		inet_pton6(MULTICAST, &multicast.sin6_addr);
		call TheftSend.bind(7000);
		
		settings_multicast.sin6_port = htons(4000);
		inet_pton6(MULTICAST, &settings_multicast.sin6_addr);
		call SettingSend.bind(4000);
	
		call ConfigMount.mount();
	}

	//config	
	event void ConfigMount.mountDone(error_t e) {
		if (e != SUCCESS) {
			call Leds.led0On();
			call RadioControl.start();
		} else {
			if (call ConfigStorage.valid()) {
				call ConfigStorage.read(0, &sreport.settings, sizeof(sreport.settings));
			} else {
				sreport.settings.threshold = LIGHT_THRESHOLD;
				sreport.settings.sample_time = SAMPLE_TIME;
				sreport.settings.sample_period = SAMPLE_PERIOD;
				call RadioControl.start();
			}
		}
	}

	event void ConfigStorage.readDone(storage_addr_t addr, void* buf, storage_len_t len, error_t e) {
		call RadioControl.start();
	}

	event void ConfigStorage.writeDone(storage_addr_t addr, void* buf, storage_len_t len, error_t e) {
		call ConfigStorage.commit();
	}

	event void ConfigStorage.commitDone(error_t error) {}

	task void report_settings() {
		call SettingSend.sendto(&settings_multicast, &sreport, sizeof(sreport));
		// write only the config settings
		call ConfigStorage.write(0, &sreport.settings, sizeof(sreport.settings));
	}
	
	// radio
	event void RadioControl.startDone(error_t e) {
		call SensorReadTimer.startPeriodic(sreport.settings.sample_time);
		sreport.type = SETTINGS_REQUEST;
		post report_settings();
	}

	event void RadioControl.stopDone(error_t e) {}



	//Timer
	event void SensorReadTimer.fired() {
		call StreamPar.postBuffer(m_parSamples, SAMPLE_SIZE);
		call StreamPar.read(sreport.settings.sample_period);
	}

	event void BlinkTimer.fired() {
		// setting the led to node_id and 0 alternatively for blinking effect
		call Leds.set((alternate_count%2 == 0) ? stolen_node : 0);
		++alternate_count % 2;	
	}

	//StreamPar
	task void checkStreamPar() {
		uint16_t i, tot, id;
		char temp[8];
		treport.who = TOS_NODE_ID;
		id = treport.who;
		tot = 0;
			
			for (i = 0; i < SAMPLE_SIZE; i++) 
				tot = tot +  m_parSamples[i];	
				
			i = tot / SAMPLE_SIZE;

			if(i < sreport.settings.threshold) {
				if (id <= 7) {
					call BlinkTimer.stop();
					call Leds.set(id);
				} else {
					stolen_node = id%8 + 1;
					// Blink LEDs	
					call BlinkTimer.startPeriodic(500);	
				}
				call TheftSend.sendto(&multicast, &treport, sizeof(treport));
			} 
		
	}


	event void StreamPar.readDone(error_t ok, uint32_t usActualPeriod) {
		if (ok == SUCCESS) {
			post checkStreamPar();
		}
	}

	event void StreamPar.bufferDone(error_t ok, uint16_t *buf,uint16_t count) {}

	event char* ResetCmd.eval(int argc, char* argv[]) {
		char* reply_buf = call ResetCmd.getBuffer(35);	
		
		if (argc > 1) 
			strcpy(reply_buf, "No arguments required\n");
		else 
			strcpy(reply_buf, "Node reset done!\n");

		call BlinkTimer.stop();
		call Leds.set(0);
		return reply_buf;
	}

	event char *GetCmd.eval(int argc, char **argv) {
		char *ret = call GetCmd.getBuffer(40);
		settings_t *settings;	
		settings = &sreport.settings;

		if (ret != NULL) {
			switch (argc) {
				case 1:
					sprintf(ret, "\t[Period: %lu]\n\t[Threshold: %u]\n\t[Time: %lu]\n", settings->sample_period, settings->threshold,settings->sample_time);
					break;
				case 2: 
					if (!strcmp("per",argv[1])) {
						sprintf(ret, "\t[Period: %lu]\n", settings->sample_period);
					} else if (!strcmp("th", argv[1])) {
						sprintf(ret, "\t[Threshold: %u]\n",settings->threshold);
					} else if (!strcmp("ti", argv[1])) {
						sprintf(ret, "\t[Time: %lu]\n",settings->sample_time);
					} else {
						strcpy(ret, "Usage: get [per|th|ti]\n");
					}
					break;
				default:
					strcpy(ret, "Usage: get [per|th|ti]\n");
			}
		}
		return ret;
	}

	event char *SetCmd.eval(int argc, char **argv) {
		char *ret = call SetCmd.getBuffer(40);
		settings_t *settings;	
		settings = &sreport.settings;
		if (ret != NULL) {
			if (argc == 3) { 
				sreport.type = SETTINGS_USER;
				sreport.sender = TOS_NODE_ID;
				if (!strcmp("per",argv[1])) {
					settings->sample_period = atoi(argv[2]);
					sprintf(ret, ">>>Period changed to %lu\n",settings->sample_period);
					post report_settings();
				} else if (!strcmp("th", argv[1])) {
					settings->threshold = atoi(argv[2]);
					sprintf(ret, ">>>Threshold changed to %u\n",settings->threshold);
					post report_settings();
				} else if (!strcmp("ti", argv[1])) {
					settings->sample_time = atoi(argv[2]);
					sprintf(ret, ">>>Time changed to %lu\n",settings->sample_time);
					post report_settings();
				}  else {
					strcpy(ret,"Usage: set per|th|ti [<sampleperiod in us>|<threshold>|<sampletime in ms>]\n");
				}
			} else {
				strcpy(ret,"Usage: set per|th|ti [<sampleperiod in us>|<threshold>|<sampletime in ms>]\n");
			}
		}
		return ret;
	}

	//udp
	event void TheftSend.recvfrom(struct sockaddr_in6 *from, void *data,
					uint16_t len, struct ip6_metadata *meta) {
		uint16_t id;
		memcpy(&treport, data, sizeof(treport));
		id = treport.who;
		if (id <= 7) {
			call BlinkTimer.stop();
			call Leds.set(id);
		} else {
			stolen_node = id%8 + 1;
			// Blink LEDs	
			call BlinkTimer.startPeriodic(500);	
		}
		
	}
	
	event void SettingSend.recvfrom(struct sockaddr_in6 *from, void *data,
					uint16_t len, struct ip6_metadata *meta) {

		nx_struct settings_report temp_sreport;
		memcpy(&temp_sreport, data, sizeof(temp_sreport));
		if (temp_sreport.type == SETTINGS_REQUEST) {
			// report settings with type SETTINGS_RESPONSE
			sreport.type = SETTINGS_RESPONSE;
			post report_settings();
		} else {
			/* 
			 * Some other node has provided settings
			 * Copy those values to local node.
			 */
			memcpy(&sreport, data, sizeof(sreport));

			sreport.settings.threshold = temp_sreport.settings.threshold;
			sreport.settings.sample_time = temp_sreport.settings.sample_time;
			sreport.settings.sample_period = temp_sreport.settings.sample_period;

			call SensorReadTimer.startPeriodic(sreport.settings.sample_time);
			call ConfigStorage.write(0, &sreport.settings, sizeof(sreport.settings));
		}
	}

}
