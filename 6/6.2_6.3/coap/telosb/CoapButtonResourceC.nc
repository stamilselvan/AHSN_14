generic configuration CoapButtonResourceC(uint8_t uri_key) {
	provides interface CoapResource; 
} implementation {
	components new CoapButtonResourceP(uri_key) as 
CoapButtonResourceP; 
	CoapResource = CoapButtonResourceP;
	//Made Change here

	
        components UserButtonC;
        CoapButtonResourceP.Notify -> UserButtonC; 
}
