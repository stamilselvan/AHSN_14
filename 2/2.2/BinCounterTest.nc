module BinCounterTest {
 uses interface Boot;
 uses interface BinCounter;
}
implementation {
	uint8_t counter;
	event void Boot.booted () {
		call BinCounter.start();
		counter = 0;
	}
	event void BinCounter.completed () {
		if (counter >= 32) {
			call BinCounter.stop();
		} else {
			counter ++;
		}
	}
	
}


