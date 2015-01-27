module TelosbP {
	uses {
		interface Leds;
		interface ShellCommand as Sense;
		interface Read<uint16_t> as LightPar;
		
		interface Boot;
		interface Timer<TMilli> as UpdateTimer;
	}
} implementation {

	uint16_t m_LightPar;

	enum {
		Read_PERIOD = 250, // ms
		LightPar_THRESHOLD = 0x10,
	};

	event void Boot.booted() {
		call UpdateTimer.startPeriodic(Read_PERIOD);
	}

	event void UpdateTimer.fired() {
		call LightPar.read();
	}

	void set_value(error_t error, uint16_t val,uint16_t* var) {
		if (error == SUCCESS)
		  *var = val;
		else
		 *var = 0xFFFF;
	}

	event void LightPar.readDone(error_t error, uint16_t val) {
		set_value(error,val,&m_LightPar);
	}

	event char *Sense.eval(int argc, char **argv) {
		char *ret = call Sense.getBuffer(100);
		if (ret != NULL) {
			sprintf(ret, "\t[LightPar: %d]\n",m_LightPar);
		}
		return ret;
	} 

}
