# Visualisation ADXL345 – Processing 4

Application prête à ouvrir dans **Processing 4 (mode Java)**. Le seul fichier de code est `Visualisation_ADXL345.pde`. Nécessite la bibliothèque **Serial** de Processing.

## Connexion

- STM32 **PA2 / USART2 TX** → **RX** de l'adaptateur USB–UART **TTL 3,3 V** (ou le port série virtuel ST-LINK s'il est câblé vers USART2).
- **GND** STM32 → **GND** de l'adaptateur.
- Ne pas utiliser un port RS-232 à tensions ±12 V. Pour ce tableau de bord, le TX du convertisseur n'est pas nécessaire.
- Fermer tout moniteur série ou autre programme qui occupe le même port COM.
- Démarrer le firmware STM32, ouvrir Processing, exécuter le sketch, puis **cliquer sur « Sélectionner le port COM »**. Le bouton **R** rafraîchit la liste.

## Fonctionnalités

1. Trois indicateurs instantanés pour **X**, **Y**, **Z**, en **g** et en **m/s²**, avec trois barres centrées sur zéro.
2. Un graphique d'historique des **650 dernières mesures**, avec pour abscisse **le numéro réel de trame complète reçue** (et non le temps).
3. Compteurs des trames reçues et des erreurs de synchronisation détectées.
4. `R` : rafraîchir les ports, `E` : effacer les graphiques / compteurs, `T` : activer / désactiver une **simulation clairement indiquée** afin de tester l'interface sans carte.

La gravité est incluse dans les accélérations affichées : un capteur immobile montrera généralement une norme proche de **1 g**.

## Format UART accepté

`F0 XH XL YH YL ZH ZL`, **9600 bauds, 8N1**. Tous les octets de charge utile ont le bit 7 à zéro. Le premier octet est `0xF0` et est unique dans la trame. Pour chaque axe :

```
raw13 = (H << 7) | L
if ((raw13 & 0x1000) != 0) raw13 -= 0x2000
acceleration_g = raw13 * 0.0039
acceleration_m_s2 = acceleration_g * 9.80665
```

Ces formules correspondent **exactement** au découpage dans `ADXL_Split13Bits()` du code STM32 fourni.

## Vérification de la logique STM32

Le `main.c` du ZIP fourni initialise PA2 (TX) en fonction alternative push-pull et PA3 (RX) en entrée flottante ; USART2 est en 8N1, 9600 bauds. Le calcul du registre BRR est cohérent si HCLK=72 MHz et PCLK1=36 MHz (APB1 divisé par 2) : `BRR = 0x0EA6`.

La FIFO d'émission 32 octets protège les trames de 7 octets contre les écritures partielles. `FIFO_ServiceUSART2()` dépile un octet uniquement si `TXE=1`. Capacité théorique continue : `9600 / (10 * 7) ≈ 137 trames/s`, supérieure aux 100 mesures/s demandées.

**Réserves :**
- Le code STM32 ne remonte **aucun compteur de pertes/overrun** au PC. Il est possible d'ignorer une mesure lorsque la FIFO UART n'a pas 7 places, et de perdre des mesures lors d'un overrun de la FIFO ADXL345.
- Ne pas injecter `Serial_Print()` ou d'autres textes ASCII sur USART2 en même temps que les trames binaires.
- L'application ne peut vérifier que les valeurs reçues ; elle ne peut pas garantir que le firmware exécuté sur la carte correspond au code du ZIP.
- Le fichier ZIP contient encore `SPI1->CR1 = (0b001 << 3)` (prédiviseur /4). La correction SPI évoquée dans la discussion n'est **pas** présente dans cette version de `main.c`. Ce point ne concerne pas directement le décodage UART de Processing.

## Essai sans matériel

Appuyer sur **T** dans Processing pour afficher des données simulées et tester les deux graphiques. Appuyer à nouveau sur **T** pour revenir à la réception réelle.
