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

		interface Read<uint16_t> as Light;

		interface ReadStream<uint16_t> as StreamPar;

		interface ShellCommand as ReadCmd;
		interface ShellCommand as StreamCmd;
		interface ShellCommand as ResetCmd;
		
		// added UDP Socket
		interface UDP as TheftSend;
		interface UDP as SettingSend;


		interface Mount as ConfigMount;
		interface ConfigStorage;
	}
} implementation {

	enum {
		SAMPLE_RATE = 256, //us
		SAMPLE_SIZE = 10,
		SAMPLE_PERIOD = 256,
		NUM_SENSORS = 1,
		Read_PERIOD = 10000, // ms
        LIGHT_THRESHOLD = 0x03,
		SETTINGS_REQUEST = 1,
		SETTINGS_RESPONSE = 2,
		SETTINGS_USER = 4,
	};


	settings_t settings;
	nx_struct theft_report treport;
	nx_struct sensing_report stats;
	bool timerStarted = FALSE;
	uint8_t m_remaining = NUM_SENSORS;
	uint32_t m_seq = 0;
	uint16_t m_par,m_tsr,m_hum,m_temp;
	uint16_t m_parSamples[SAMPLE_SIZE];
	
	struct sockaddr_in6 route_dest;
	struct sockaddr_in6 multicast;
	m_light = 0;
	uint8_t stolen_node, alternate_count = 0;

	// boot
	event void Boot.booted() {
		call RadioControl.start();

		multicast.sin6_port = htons(7000);
		inet_pton6(MULTICAST, &multicast.sin6_addr);
		call TheftSend.bind(7000);
	}
	
	// radio
	event void RadioControl.startDone(error_t e) {
		route_dest.sin6_port = htons(7000);
		inet_pton6(REPORT_DEST, &route_dest.sin6_addr);
		//call SensorReadTimer.startPeriodic(Read_PERIOD);

		// for sampling sensor data
		call SensorReadTimer.startPeriodic(Read_PERIOD);
		call StreamPar.postBuffer(m_parSamples, SAMPLE_SIZE);
		call StreamPar.read(SAMPLE_RATE);
	}

	event void RadioControl.stopDone(error_t e) {}

	//Timer
	event void SensorReadTimer.fired() {
		call Light.read();	
	}

	event void BlinkTimer.fired() {
		call Leds.set((alternate_count%2 == 0) ? stolen_node : 0);
		++alternate_count % 2;	
	}


	//LightPar
	error_t checkDone() {
		int len;
		char *reply_buf = call ReadCmd.getBuffer(128); 
		if (--m_remaining == 0) {
			len = sprintf(reply_buf, "%ld %d %d %d %d\r\n", m_seq, m_par,m_tsr,m_hum,m_temp);
			m_remaining = NUM_SENSORS;
			m_seq++;
			call ReadCmd.write(reply_buf, len);
		}
		return SUCCESS;
	}


	//StreamPar
	task void checkStreamPar() {
		uint16_t i, tot;
		char temp[8];
		char *reply_buf = call StreamCmd.getBuffer(128);
		int len = 0;

		tot = 0;
		if (reply_buf != NULL) {
			
			for (i = 0; i < SAMPLE_SIZE; i++) {
				tot = tot +  m_parSamples[i];	
				len += sprintf(temp, "%d, ", m_parSamples[i]);	
				strcat(reply_buf, temp);
			} 

			i = tot / SAMPLE_SIZE;
			len += sprintf(temp, "Avg[%d, %d]\n", i, tot);
			strcat(reply_buf, temp);
			if(i < LIGHT_THRESHOLD) {
				call Leds.set(i%8);
				call TheftSend.sendto(&multicast, &treport, sizeof(treport));
			}
			call StreamCmd.write(reply_buf, len);
		}
		
	}


	event void StreamPar.readDone(error_t ok, uint32_t usActualPeriod) {
		if (ok == SUCCESS) {
			post checkStreamPar();
		}
	}

	event void StreamPar.bufferDone(error_t ok, uint16_t *buf,uint16_t count) {}


	
	//shell
	event char* ReadCmd.eval(int argc, char** argv) {
		char* reply_buf = call ReadCmd.getBuffer(18);
		if (timerStarted == FALSE) {
			strcpy(reply_buf, ">>>Start sampling\n");
			call SensorReadTimer.startPeriodic(SAMPLE_RATE);
			timerStarted = TRUE;
		} else {
			strcpy(reply_buf, ">>>Stop sampling\n");
			call SensorReadTimer.stop();
			timerStarted = FALSE;
		}
		return reply_buf;
	}

	event char* StreamCmd.eval(int argc, char* argv[]) {
		char* reply_buf = call StreamCmd.getBuffer(35);
		uint16_t sample_period = 10000; // us -> 100 Hz
		switch (argc) {
			case 2:
				sample_period = atoi(argv[1]);
			case 1: 
				sprintf(reply_buf, "sampleperiod of %d\n", sample_period);
				call StreamPar.postBuffer(m_parSamples, SAMPLE_SIZE);
				call StreamPar.read(sample_period);
				break;
			default:
				strcpy(reply_buf, "Usage: stream <sampleperiod/in us>\n");
		}
		return reply_buf;
	}

	event char* ResetCmd.eval(int argc, char* argv[]) {
		char* reply_buf = call ResetCmd.getBuffer(35);	
		if (argc > 1) {
			strcpy(reply_buf, "No arguments required\n");
		} else {
			stats.is_lost = 0;
			call BlinkTimer.stop();
			call Leds.set(0);
			strcpy(reply_buf, "Node reset done!\n");
		}	
		return reply_buf;
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
			//call Leds.set(stolen_node);
		}
		
	}
	
	event void SettingSend.recvfrom(struct sockaddr_in6 *from, void *data,
					uint16_t len, struct ip6_metadata *meta) {
		
	}

	//config	
	event void ConfigMount.mountDone(error_t e) {
		if (e != SUCCESS) {
			call Leds.led0On();
			call RadioControl.start();
		} else {
			if (call ConfigStorage.valid()) {
				call ConfigStorage.read(0, &settings, sizeof(settings));
			} else {
				settings.sample_period = SAMPLE_PERIOD;
				settings.threshold = LIGHT_THRESHOLD;
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


}
