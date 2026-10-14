

int main(void)
{
	config_usart2(72000000U, 9600);
	config_SPI_1();
	config_ADXL();
	// GPIO_InitPin(GPIOA, 5, GPIO_OUTPUT_PP_50MHZ, GPIO_LOW);
	Serial_Print("Demarrage du STM32");
	Serial_Println("");

	int valeur = 42;

	Serial_Print("Valeur = %d", valeur);
	Serial_Println("");

	uint8_t data[SIZE_FIFO] = {0};
	while (1)
	{
		Serial_Print("--------------------- LECTURE PIN ---------------------\r\n");

		Serial_Print("Wartermark = %1d  overrun = %1d", GPIO_ReadPin(GPIOA, 10), GPIO_ReadPin(GPIOA, 11));
		Serial_Println("");

		if (GPIO_ReadPin(GPIOA, 10))
		{
			uint8_t fifo_status;
			uint8_t nb_mesures;

			lire_regADXL(ADXL345_FIFO_STATUS, &fifo_status);
			nb_mesures = fifo_status & 0x3F;
			Serial_Print("--------------------- LECTURE AXE ---------------------\r\n");

			for (uint8_t i = 0; i < nb_mesures; i++)
			{
				lire_multiple_regADXL(ADXL345_DATAX0, 6, data);

				int16_t axe_x = (int16_t)(((uint16_t)data[1] << 8) | data[0]);
				int16_t axe_y = (int16_t)(((uint16_t)data[3] << 8) | data[2]);
				int16_t axe_z = (int16_t)(((uint16_t)data[5] << 8) | data[4]);
				axe_x = ADXL_ConvertTo_ms2(axe_x, 4);
				axe_y = ADXL_ConvertTo_ms2(axe_y, 4);
				axe_z = ADXL_ConvertTo_ms2(axe_z, 4);
				Serial_Print("axe x %4d m/s2 | axe y %4d m/s2 | axe z %4d m/s2 ", axe_x, axe_y, axe_z);
				Serial_Print(" | nbr mesure %3d  ", nb_mesures);
				// Serial_Print("%4d %4d %4d %4d", axe_x, axe_y, axe_z, nb_mesures);

				Serial_Println("");
			}
		}
		else
		{
		}
		// static int time = 1000;
		// GPIOA->BSRR = (1U << 5);
		// delay_ms(time);

		// GPIOA->BRR = (1U << 5);
		// delay_ms(time);
	}
}