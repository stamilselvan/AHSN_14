module TelosbP {
	uses {
		interface Leds;
		interface ShellCommand as LedDisplay;
		interface Boot;
		interface Timer<TMilli> as UpdateTimer;
	}
} implementation {

	uint16_t m_LightPar, m_LightTsr, m_temp, m_humid;

	event char *LedDisplay.eval(int argc, char **argv) {
		char *ret = call LedDisplay.getBuffer(16);
		
		if(argc > 1){
			call Leds.set(*argv[1]);
			strncpy(ret, "> Done!\n", 16);
			return ret;
		}
		else
			return "Plz enter 0-7\n";
	} 

	event void Boot.booted() {
		call UpdateTimer.startPeriodic(500);
	}

	void set_value(error_t error, uint16_t val,uint16_t* var) {
		if (error == SUCCESS)
		  *var = val;
		else
		 *var = 0xFFFF;
	}

	event void UpdateTimer.fired() {

	}

}
