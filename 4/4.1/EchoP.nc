#include <lib6lowpan/ip.h>
#include <ctype.h>

module EchoP {
	uses {
		interface Boot;
		interface Leds;
		interface SplitControl as RadioControl;

		interface UDP as Echo;
	}
} implementation {

	uint64_t change_endianess(uint64_t in) {
		uint64_t out = 0;
		
		//out = in << 56;
		
		out = out + ((in << 56 ) & 0xff00000000000000U);
		out = out + ((in << 40 ) & 0x00ff000000000000U);
		out = out + ((in << 24 ) & 0x0000ff0000000000U);
		out = out + ((in << 8 ) & 0x000000ff00000000U);
		out = out + ((in >> 8 ) & 0x00000000ff000000U);
		out = out + ((in >> 24 ) & 0x0000000000ff0000U);
		out = out + ((in >> 40 ) & 0x000000000000ff00U); //0x000000000000ff00U
		out = out + ((in >> 56 ) & 0x00000000000000ffU);

		//out = out + (in >> 56);

		return out;
	}

	event void Boot.booted() {
		call RadioControl.start();
		call Echo.bind(7);
		call Leds.led1On();
	}

	event void Echo.recvfrom(struct sockaddr_in6 *from, void *data,
			  uint16_t len, struct ip6_metadata *meta) {
		char* str = data;
		uint64_t i;
		bool isNumber = TRUE;

		for (i = 0; i < len - 1; i++) {
			if (!isdigit(str[i])) {
				isNumber = FALSE;
				break;
			}
		}

		if (isNumber) {
			i = change_endianess((atoi(str)));
			call Echo.sendto(from, &i, sizeof(uint64_t));
		} else { 
			call Echo.sendto(from, data, len);
		}
	}

	event void RadioControl.startDone(error_t e) {}

	event void RadioControl.stopDone(error_t e) {}  
}
