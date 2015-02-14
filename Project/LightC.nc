#define NEW_PRINTF_SEMANTICS
#include "StorageVolumes.h"

configuration LightC {
}
implementation {

	components MainC, LightP, LedsC;
	LightP -> MainC.Boot;
	LightP.Leds -> LedsC;
	components IPStackC;
	components IPDispatchC;
	components UdpC;
	components UDPShellC;
	components RPLRoutingC;

	components StaticIPAddressTosIdC;

	LightP.RadioControl -> IPStackC;

	components new ShellCommandC("get") as GetCmd;
	components new ShellCommandC("set") as SetCmd;
	
	LightP.GetCmd -> GetCmd;
	LightP.SetCmd -> SetCmd;

	components new TimerMilliC() as SensorReadTimer;
	LightP.SensorReadTimer -> SensorReadTimer;
	components new TimerMilliC() as BlinkTimer;
	LightP.BlinkTimer -> BlinkTimer;

	components new UdpSocketC() as SettingSend;
	LightP.SettingSend -> SettingSend;

	components new UdpSocketC() as SyncNodes;
	LightP.SyncNodes -> SyncNodes;

	components new  SensirionSht11C() as TemperateHumiditySensor;
	LightP.Temperature -> TemperateHumiditySensor.Temperature;


#ifdef PRINTFUART_ENABLED
  /* This component wires printf directly to the serial port, and does
   * not use any framing.  You can view the output simply by tailing
   * the serial device.  Unlike the old printfUART, this allows us to
   * use PlatformSerialC to provide the serial driver.
   *
   * For instance:
   * $ stty -F /dev/ttyUSB0 115200
   * $ tail -f /dev/ttyUSB0
  */
  components SerialPrintfC;

  /* This is the alternative printf implementation which puts the
   * output in framed tinyos serial messages.  This lets you operate
   * alongside other users of the tinyos serial stack.
   */
  // components PrintfC;
  // components SerialStartC;
#endif
}
