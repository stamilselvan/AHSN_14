configuration TelosbC {

} implementation {
	components MainC,LedsC,TelosbP;
	TelosbP.Boot -> MainC;
	TelosbP.Leds -> LedsC;

	components new TimerMilliC() as UpdateTimer;
	TelosbP.UpdateTimer -> UpdateTimer;

	components new ShellCommandC("Display") as LedDisplay;
	TelosbP.LedDisplay -> LedDisplay;
}


