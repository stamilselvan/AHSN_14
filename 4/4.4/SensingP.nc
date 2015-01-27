#include <lib6lowpan/ip.h>
#include "sensing.h"
#include "sensing1.h"

module SensingP {
	uses {
		interface Boot;
		interface Leds;
		interface SplitControl as RadioControl;
		interface UDP as SenseSend;
		interface Timer<TMilli> as SenseTimer1;
		interface Timer<TMilli> as SenseTimer;
		interface Read<uint16_t> as Humidity;
		interface Read<uint16_t> as LightPar;
	}

} implementation {

	enum {
		SENSE_PERIOD_L = 128, // ms
		SENSE_PERIOD = 500

	};

	nx_struct sensing_report stats;
	nx_struct sensing1_report stats1;
	struct sockaddr_in6 route_dest;
	struct sockaddr_in6 route_dest1;
	m_humidity = 0;
	m_lightpar = 0;

	event void Boot.booted() {
		call RadioControl.start();
	}

	event void RadioControl.startDone(error_t e) {
		route_dest.sin6_port = htons(7000);
		route_dest1.sin6_port = htons(8000);
		inet_pton6(REPORT_DEST, &route_dest.sin6_addr);
		inet_pton6(REPORT_DEST, &route_dest1.sin6_addr);
		call SenseTimer.startPeriodic(SENSE_PERIOD);
		call SenseTimer1.startPeriodic(SENSE_PERIOD_L);
	}

	task void report_humidity() {
		stats.seqno++;
		stats.sender = TOS_NODE_ID;
		stats.humidity = m_humidity;
		call SenseSend.sendto(&route_dest, &stats, sizeof(stats));
	}

	task void report_lightpar() {
		stats1.seqno++;
		stats1.sender = TOS_NODE_ID;
		stats1.light= m_lightpar;		
		call SenseSend.sendto(&route_dest1, &stats1, sizeof(stats1));
	}

	event void SenseSend.recvfrom(struct sockaddr_in6 *from, 
			void *data, uint16_t len, struct ip6_metadata *meta) {}

	event void SenseTimer.fired() {
		call Humidity.read();
		call LightPar.read();
	}

	event void SenseTimer1.fired() {
		//call Humidity.read();
		call LightPar.read();
	}

	event void Humidity.readDone(error_t ok, uint16_t val) {
		if (ok == SUCCESS) {
			m_humidity = val;
			post report_humidity();
		}
	}

	event void LightPar.readDone(error_t ok, uint16_t val) {
		if (ok == SUCCESS) {
			m_lightpar = val;
			post report_lightpar();
		}
	}

	event void RadioControl.stopDone(error_t e) {}
}
