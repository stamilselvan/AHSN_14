configuration TelosbC {

} implementation {
	components MainC,TelosbP;
	TelosbP.Boot -> MainC;

	components new TimerMilliC() as UpdateTimer;
	TelosbP.UpdateTimer -> UpdateTimer;

	components new ShellCommandC("read-par") as Sense;

	TelosbP.Sense -> Sense;

	components new HamamatsuS1087ParC() as LightPar;
	TelosbP.LightPar -> LightPar.Read;
}
