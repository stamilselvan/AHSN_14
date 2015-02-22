configuration testC {}
implementation {
	components testP, MainC, LedsC, BinCounterTest;
	components new TimerMilliC() as Timer0;	

	BinCounterTest -> MainC.Boot;
	testP.Leds -> LedsC;
	testP.Timer0 -> Timer0;
	BinCounterTest.BinCounter -> testP.BinCounter;
	


}
