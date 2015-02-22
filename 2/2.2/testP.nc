module testP {
	uses interface Leds;
	uses interface Timer<TMilli> as Timer0;
   	provides interface BinCounter;

}

implementation {
	uint8_t counter = 0;
	event void Timer0.fired () {
		call Leds.set(counter);
		counter ++;
		signal BinCounter.completed();
	}

	command void BinCounter.start(){
    		call Timer0.startPeriodic(2000);
  	}
  
  	command void BinCounter.stop(){
    	call Timer0.stop();
		call Leds.led0Off();
		call Leds.led1Off();
		call Leds.led2Off();
  	}

}
	
