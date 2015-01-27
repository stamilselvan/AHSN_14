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

		interface Read<uint16_t> as ReadPar;
		interface Read<uint16_t> as Light;

		interface ReadStream<uint16_t> as StreamPar;

		interface ShellCommand as ReadCmd;
		interface ShellCommand as StreamCmd;
		interface ShellCommand as ResetCmd;
		
		// added UDP Socket
		interface UDP as SenseSend;
	}
} implementation {

	enum {
		SAMPLE_RATE = 250,
		SAMPLE_SIZE = 10,
		NUM_SENSORS = 1,
		Read_PERIOD = 250, // ms
                LightPar_THRESHOLD = 0x10,
	};


	bool timerStarted = FALSE;
	uint8_t m_remaining = NUM_SENSORS;
	uint32_t m_seq = 0;
	uint16_t m_par,m_tsr,m_hum,m_temp;
	uint16_t m_parSamples[SAMPLE_SIZE];
	
	nx_struct sensing_report stats;
	struct sockaddr_in6 route_dest;
	m_light = 0;


	event void Boot.booted() {
		call RadioControl.start();
	}

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

	event void RadioControl.startDone(error_t e) {
		route_dest.sin6_port = htons(7000);
		inet_pton6(REPORT_DEST, &route_dest.sin6_addr);
		call SensorReadTimer.startPeriodic(Read_PERIOD);
	}

	task void report_light() {
		//stats.seqno++;
		stats.sender = TOS_NODE_ID;
		//stats.light = m_light;
		// we are not resetting the light or the lost status when the stolen alarm is set off
		// reset had to be done manually from the UDP shell command 'reset'.
		if(m_light < LightPar_THRESHOLD) {
			stats.is_lost = 1;
			call Leds.led0On();
			call SenseSend.sendto(&route_dest, &stats, sizeof(stats));
		}
	}

	task void checkStreamPar() {
		uint8_t i;
		char temp[8];
		char *reply_buf = call StreamCmd.getBuffer(128);
		int len = 0;

		if (reply_buf != NULL) {
			for (i = 0; i < SAMPLE_SIZE; i++) {
				len += sprintf(temp, "%d, ", m_parSamples[i]);
				strcat(reply_buf, temp);
			}  
			strcat(reply_buf, "\n");
		}
		call StreamCmd.write(reply_buf, len + 1);
	}

	event void SensorReadTimer.fired() {
		//call ReadPar.read();
		call Light.read();
	
	}

	event void ReadPar.readDone(error_t e, uint16_t data) {
		m_par = data;
		checkDone();
	}


	event void Light.readDone(error_t ok, uint16_t val) {
		if (ok == SUCCESS) {
			m_light = val;
			post report_light();
		}
	}

	event void StreamPar.readDone(error_t ok, uint32_t usActualPeriod) {
		if (ok == SUCCESS) {
			post checkStreamPar();
		}
	}

	event void StreamPar.bufferDone(error_t ok, uint16_t *buf,uint16_t count) {}

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
		
			stats.is_lost = 0;
			call Leds.led0Off();
			strcpy(reply_buf, "Node reset done!\n");
		
		return reply_buf;
	}
	
	event void RadioControl.stopDone(error_t e) {}

	event void SenseSend.recvfrom(struct sockaddr_in6 *from, void *data,
					uint16_t len, struct ip6_metadata *meta) {
		
	}

}
