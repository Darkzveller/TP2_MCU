# TP2 MCU — Acquisition des accélérations avec le STM32F103RB et l'ADXL345

**Polytech Sorbonne — Électronique et Informatique — S7 — Microcontrôleur 2**  
**Année universitaire : 2026-2027**  
**Enseignant : Francis BRAS**  
**Auteur : Youssef EL KATTOUFI**

## 1. Présentation du TP

Dans ce TP, le but était de mettre en place une chaîne complète d'acquisition de mesures à partir d'un accéléromètre **ADXL345**, puis d'exploiter les données avec une carte **NUCLEO STM32-F103RB** et un affichage sur ordinateur.

L'idée était de récupérer les accélérations sur les trois axes **X, Y et Z**, de comprendre les trames échangées avec le capteur, puis de les envoyer vers le PC pour pouvoir les visualiser. Le but n'était pas juste d'avoir trois valeurs affichées, mais aussi de voir comment les informations circulent entre le capteur, le STM32 et Processing.

J'ai écrit et modifié le programme C avec **Visual Studio Code**, puis utilisé **Keil µVision** pour le compiler et le téléverser sur le STM32. Pour l'observation des signaux, j'ai utilisé **PulseView** avec un analyseur logique. Enfin, j'ai réalisé l'interface d'affichage sur **Processing**.

J'ai fait les essais progressivement : d'abord la configuration des GPIO et du SPI, ensuite la lecture des registres de l'ADXL345, la récupération des accélérations, l'envoi des trames UART et enfin leur affichage sur ordinateur.

## 2. Fonctionnement général

La chaîne de communication est la suivante :

```text
       Mesures sur les axes X, Y et Z
                     │
                     ▼
                ADXL345
                     │
              SPI (4 fils)
        CS / SCK / MOSI / MISO
                     │
                     ▼
         NUCLEO STM32-F103RB
                     │
             USART2 / UART
                9600 bauds
                     │
                     ▼
                 PC
       Processing : X, Y, Z,
       courbes et trames reçues
```

L'analyseur logique est branché **en parallèle sur les mêmes lignes SPI** que celles reliant le STM32 à l'ADXL345. Il permet de surveiller les échanges sans créer un second bus. J'ai également suivi les signaux INT1 et INT2 du capteur.

## 3. Matériel et logiciels utilisés

### Matériel

- Carte **NUCLEO STM32-F103RB**.
- Accéléromètre **ADXL345**.
- Plaque d'essai **Labdec**, fils de connexion et alimentation adaptée au montage.
- Analyseur logique pour les signaux SPI et les interruptions.
- Ordinateur relié à la carte pour la programmation et la visualisation des données.

J'ai commencé à câbler le TP2 pendant que j'avançais encore sur le TP1. Je faisais donc les deux TP en parallèle pour gagner du temps. C'est pour cela que certaines photos du montage montrent également des LED, des DIP-switchs ou des PCF8574 qui ne sont pas utilisés pour la lecture de l'ADXL345.

### Logiciels

| Outil | Utilisation dans le TP |
| --- | --- |
| **Visual Studio Code** | Écriture et modification du code C. |
| **Keil µVision** | Ouverture du projet, compilation, débogage et téléversement du programme. |
| **Processing** | Réception des trames UART et affichage des accélérations X/Y/Z. |
| **PulseView** | Acquisition et décodage des chronogrammes SPI et UART. |

## 4. Organisation du projet

### 4.1. Emplacement sur mon ordinateur

Le dossier du TP est rangé dans mon arborescence de cours :

```text
H:\Mon Drive\2026-2027_polytech_sorbonne\S7\UE_Informatique\Micro_controleur2\TP_2
```

Cette organisation permet de conserver au même endroit le sujet, le programme STM32, l'interface Processing, les captures et le compte rendu.

### 4.2. Arborescence principale

Voici l'organisation du dossier **TP_2** d'après mon inventaire du **18/10/2026**. J'ai regroupé les sous-dossiers volumineux pour que l'ensemble reste lisible.

```text
TP_2/
│
├── Projet_keil_initialiser_STM32_F103RB-main/    # Projet STM32 en C sous Keil
├── Visualisation_ADXL345/                        # Interface Processing et export Windows
├── Session_pulse_view/                           # Sessions et captures de l'analyseur logique
├── Piece_presentation_rapport/                   # Dossier des éléments de présentation du rapport
│
├── ADXL345.h                                      # Définitions des registres ADXL345
├── ADXL345.pdf                                    # Documentation de l'accéléromètre
├── TP2.pdf                                        # Sujet du TP au format PDF
├── TP2.docx                                       # Sujet du TP au format Word
├── Tutoriel_prise_en_main.pdf                     # Tutoriel de prise en main
├── Tutoriel_USART.pdf                             # Tutoriel sur la liaison série
├── utiliser lanalyseur logique 8ch 24MHz-20260925.zip
│                                                  # Documentation / ressources de l'analyseur
├── Branchement_analyzer_to_mpu.xlsx               # Correspondance des fils et voies analysées
├── preuve.pptx                                    # Présentation regroupant des éléments de preuve
│
├── Nucleo_Schematic.pdf                           # Schéma de la carte NUCLEO
├── User manuel UM1724 NUCLEO-F103RB.pdf           # Manuel de la carte NUCLEO
├── RESUME_STM32F103xx.pdf                         # Résumé de la documentation STM32F103
├── stm32f103xx_UM.pdf                             # Manuel de référence STM32
├── stm32f103errata.pdf                            # Errata du microcontrôleur
│
├── Visualisation_ADXL345.pdez                     # Archive du sketch Processing
├── TP2_MCU2.docx                                  # Compte rendu modifiable
├── TP2_MCU2.pdf                                   # Compte rendu exporté en PDF
├── TP_2_micro_controleur2.gsheet                  # Raccourci Google Sheets
├── git_push.bat                                   # Script local de commandes Git
├── .gitignore                                     # Exclusions Git
└── README.md                                      # Présentation et mode d'emploi du projet
```

**Précision :** les noms des éléments de la racine viennent de l'inventaire actuel. Les contenus détaillés ci-dessous ont été vérifiés dans l'archive du projet. Le contenu de `Piece_presentation_rapport/`, ajouté dans l'inventaire récent, n'était pas disponible dans cette archive : je ne vais donc pas inventer la liste de ses fichiers.

### 4.3. Projet Keil : `Projet_keil_initialiser_STM32_F103RB-main/`

C'est dans ce dossier que se trouve le programme exécuté par le STM32. Le fichier le plus important est **`main.c`**, dans lequel j'ai regroupé les configurations, la communication avec l'ADXL345, la FIFO logicielle et l'envoi UART.

```text
Projet_keil_initialiser_STM32_F103RB-main/
│
├── main.c                              # Programme principal du STM32
├── ADXL345.h                           # Adresses et constantes des registres du capteur
├── tp2_micro_controleur_2.uvprojx      # Projet Keil à ouvrir
├── tp2_micro_controleur_2.uvoptx       # Options locales du projet Keil
├── tp2_micro_controleur_2.uvguix.elkat # Préférences de l'interface Keil
├── tp2_micro_controleur_2.elkat        # Fichier de session / données Keil
├── poubelle.c                          # Fichier C annexe, non utilisé pour décrire le TP
├── Tuto_initialisation.pdf             # Document d'aide à l'initialisation
├── .gitignore
├── git_push.bat
│
├── RTE/                                # Fichiers de support STM32/CMSIS du projet
│   ├── _Target_1/RTE_Components.h
│   └── Device/STM32F103RB/
│       ├── RTE_Device.h
│       ├── startup_stm32f10x_md.s
│       └── system_stm32f10x.c
│
├── DebugConfig/                        # Configuration de débogage
├── Driver_stlink/                      # Archive de pilotes/outils ST-LINK
├── Objects/                            # Fichiers produits par la compilation (.o, .axf, etc.)
├── Listings/                           # Fichiers de listing et carte mémoire (.lst, .map)
└── terminalMecatro2020ok/              # Utilitaire terminal Windows et ses bibliothèques
```

**À quoi servent les fichiers principaux ?**

- **`main.c`** : contient la configuration du SPI1, des GPIO, de l'USART2, de l'ADXL345 et le traitement des mesures. C'est ce fichier qu'il faut lire en premier pour comprendre le programme.
- **`ADXL345.h`** : regroupe les adresses symboliques des registres (`POWER_CTL`, `FIFO_STATUS`, `DATAX0`, etc.). Il est utilisé par `main.c`. Il existe aussi une copie à la racine de `TP_2`.
- **`tp2_micro_controleur_2.uvprojx`** : permet d'ouvrir directement le projet dans Keil, sans recréer manuellement les fichiers et le microcontrôleur cible.
- **`RTE/`** : contient les fichiers de démarrage et de configuration nécessaires au projet STM32.
- **`Objects/` et `Listings/`** : contiennent les résultats de compilation. Ce ne sont pas les fichiers dans lesquels j'écris le programme.
- **`DebugConfig/`** : stocke les paramètres de débogage du projet.
- **`Driver_stlink/`** : fournit des ressources liées au pilote ST-LINK.
- **`terminalMecatro2020ok/`** : contient un exécutable de terminal et ses dépendances ; il est distinct de l'affichage Processing.
- **`poubelle.c`** : fichier annexe conservé dans le dossier. Le fonctionnement présenté dans le rapport repose sur `main.c`, pas sur ce fichier.

### 4.4. Interface Processing : `Visualisation_ADXL345/`

```text
Visualisation_ADXL345/
│
├── Visualisation_ADXL345.pde          # Version principale du programme Processing
├── Old/                               # Anciennes versions conservées
│   ├── Visualisation_ADXL345_V0.pde
│   ├── Visualisation_ADXL345_V1.pde
│   └── Visualisation_ADXL345_V2.pde
│
└── windows-amd64/                     # Export Windows prêt à lancer
    ├── Visualisation_ADXL345.exe      # Programme exécutable
    ├── java/                          # Environnement Java inclus dans l'export
    ├── lib/                           # Bibliothèques nécessaires à l'application
    └── source/                        # Copie du code source exporté
```

La version que j'utilise pour la visualisation est **`Visualisation_ADXL345.pde`** à la racine de ce dossier. Les fichiers du sous-dossier `Old/` correspondent aux versions précédentes du programme. Je les ai conservés pour pouvoir retrouver les modifications réalisées au cours du développement.

Le dossier `windows-amd64/` contient une version exportée pour Windows. Pour lancer cette version, il faut **conserver l'ensemble du dossier**, et pas seulement copier le fichier `.exe`, puisqu'il utilise aussi les bibliothèques et l'environnement Java présents à côté.

Le fichier **`Visualisation_ADXL345.pdez`**, placé à la racine du TP, est une archive du sketch Processing comprenant notamment la version principale et les versions précédentes.

### 4.5. Captures PulseView : `Session_pulse_view/`

```text
Session_pulse_view/
│
├── Config_spi/
│   ├── config_spi.sr                  # Acquisition PulseView
│   ├── config_spi.pvs                 # Configuration de la session PulseView
│   ├── config_spi_digital.txt         # Données exportées
│   ├── config_spi_hexa.txt            # Données hexadécimales exportées
│   ├── config_spi_chronoVu_la8_native_format.kdt
│   ├── config_spi_microsoft_wav_file.wav
│   └── Message_0.jpg ... Message_6.jpg
│
├── Data_spi/
│   ├── data_spi.sr                    # Acquisition des lectures SPI
│   ├── data_spi.pvs                   # Configuration de la session PulseView
│   ├── data_spi.txt                   # Export des données
│   ├── data_spi_hex.txt               # Export des octets hexadécimaux
│   ├── data_spi_chrono.kdt
│   ├── data_spi_excel.wav
│   └── Message_0.jpg ... Message_6.jpg
│
└── UART/
    ├── UART.sr                        # Acquisition PulseView UART
    ├── UART.pvs                       # Configuration de la session PulseView
    ├── UART_digital.txt               # Export numérique
    ├── UART_hexa.txt                  # Export hexadécimal
    ├── UART_chrono.kdt
    ├── UART_Micro.wav
    └── Photo_preuve.jpg               # Capture utilisée comme preuve
```

J'ai séparé les captures selon ce que je voulais vérifier : d'abord la configuration du capteur, ensuite les lectures SPI, puis la transmission UART. Cela permet de retrouver plus facilement les chronogrammes présentés dans le rapport.

Les fichiers **`.sr`** sont des acquisitions à rouvrir dans PulseView ; les fichiers **`.pvs`** gardent la configuration associée. Les **`.jpg`** sont des captures d'écran, tandis que les fichiers texte et hexadécimaux sont des exports pour relire les échanges sans forcément rouvrir toute la session. Les autres fichiers (`.kdt`, `.wav`) sont des exports complémentaires conservés avec les acquisitions.

### 4.6. Documents, présentation et preuves

- **`TP2.pdf` et `TP2.docx`** : le sujet qui sert de référence pour le travail demandé.
- **`ADXL345.pdf`** : la documentation du capteur pour comprendre ses registres et ses modes de fonctionnement.
- **`Branchement_analyzer_to_mpu.xlsx`** : le tableau de correspondance entre les voies de l'analyseur et les fils mesurés. La ligne d'horloge peut y être appelée `SCL`, mais dans ce TP en SPI il s'agit de **SCK**.
- **`Nucleo_Schematic.pdf` et `User manuel UM1724 NUCLEO-F103RB.pdf`** : schéma et manuel de la carte.
- **`RESUME_STM32F103xx.pdf`, `stm32f103xx_UM.pdf` et `stm32f103errata.pdf`** : documentation et errata du STM32.
- **`Tutoriel_prise_en_main.pdf` et `Tutoriel_USART.pdf`** : supports utilisés pour la prise en main et la communication série.
- **`preuve.pptx`** : présentation de preuves/captures conservée avec les documents du TP.
- **`TP2_MCU2.docx`** : mon compte rendu, dans une version que je peux encore modifier.
- **`TP2_MCU2.pdf`** : version PDF du rapport.
- **`Piece_presentation_rapport/`** : dossier destiné aux éléments de présentation ; son contenu exact n'a pas pu être vérifié dans l'archive consultée.
- **`TP_2_micro_controleur2.gsheet`** : fichier de raccourci vers une feuille Google Sheets, et non un fichier source du microcontrôleur.
- **`.gitignore`** : indique certains fichiers locaux à ne pas suivre dans Git.
- **`git_push.bat`** : enchaîne `git status`, `git add .`, `git commit` et `git push` depuis le dossier où il est lancé. À utiliser seulement après avoir vérifié les fichiers à envoyer.

## 5. Bilan des entrées/sorties du STM32

Les huit broches utilisées par le programme C pour ce TP sont les suivantes :

| Broche STM32 | Signal | Direction | Configuration / utilisation |
| --- | --- | --- | --- |
| **PA2** | USART2_TX | Sortie | Fonction alternative push-pull, 10 MHz ; envoi vers le PC. |
| **PA3** | USART2_RX | Entrée | Entrée flottante ; réception configurée mais non exploitée dans la boucle principale. |
| **PA4** | CS | Sortie | Push-pull, 10 MHz ; sélection du capteur active à 0, au repos à 1. |
| **PA5** | SCK | Sortie | Fonction alternative push-pull, 10 MHz ; horloge du SPI1. |
| **PA6** | MISO | Entrée | Entrée flottante ; données envoyées par l'ADXL345 vers le STM32. |
| **PA7** | MOSI | Sortie | Fonction alternative push-pull, 10 MHz ; commande du STM32 vers l'ADXL345. |
| **PA10** | INT1 | Entrée | Entrée flottante ; surveillance du signal WATERMARK. |
| **PA11** | INT2 | Entrée | Entrée flottante ; surveillance du signal OVERRUN. |

Les signaux **CS, SCK, MOSI et MISO** constituent le bus SPI du montage. Les broches **INT1 et INT2** indiquent des événements du capteur. Il faut également relier les masses des appareils entre elles, et respecter l'alimentation du module ADXL345 utilisé.

Pour l'analyseur logique, j'ai utilisé les voies suivantes :

| Voie de l'analyseur | Signal surveillé | Broche STM32 |
| --- | --- | --- |
| CH1 | SCK | PA5 |
| CH2 | CS | PA4 |
| CH3 | MOSI | PA7 |
| CH4 | MISO | PA6 |
| CH5 | INT2 | PA11 |
| CH6 | INT1 | PA10 |

L'analyseur est branché **sur les lignes déjà reliées au capteur**. Il sert seulement à les observer.

## 6. Configuration utilisée dans le programme C

### 6.1. SPI1

Le SPI1 est configuré en **maître**, avec un échange sur **8 bits**, le bit de poids fort transmis en premier et un **CS piloté manuellement** par la broche PA4.

- **Mode SPI 3** : `CPOL = 1` et `CPHA = 1`.
- **Diviseur d'horloge** : 64.
- **Fréquence SPI** : 1,125 MHz si l'horloge du périphérique est à 72 MHz.
- **CS** : niveau bas pendant la transaction, niveau haut au repos.

Dans `main.c`, la fonction `config_SPI_1()` règle le périphérique, tandis que `gere_cs()` permet de sélectionner et désélectionner l'ADXL345.

### 6.2. Registres de l'ADXL345

La fonction `config_ADXL()` écrit les paramètres suivants. Le tableau indique les **valeurs finales effectivement écrites dans le code**, pas seulement ce qui est annoncé dans les commentaires.

| Registre | Valeur finale | Rôle |
| --- | --- | --- |
| `POWER_CTL` | `0x08` | Passage en mode mesure. |
| `DATA_FORMAT` | `0x0B` | Plage ±16 g, résolution complète (*FULL_RES*), SPI 4 fils. |
| `BW_RATE` | `0x0A` | Fréquence de mesure de 100 Hz. |
| `FIFO_CTL` | `0x90` | FIFO en mode Stream, WATERMARK à 16 mesures. |
| `INT_MAP` | `0x01` | WATERMARK sur INT1 et OVERRUN sur INT2. |
| `INT_ENABLE` | `0x03` | Activation de WATERMARK et OVERRUN. |
| `ACT_INACT_CTL` | `0x77` | Contrôle des axes pour l'activité et l'inactivité. |
| `THRESH_ACT` | `0x10` | Seuil d'activité d'environ 1 g. |
| `THRESH_INACT` | `0x08` | Seuil d'inactivité d'environ 0,5 g. |
| `TIME_INACT` | `0x01` | Durée d'inactivité de 1 seconde. |
| `THRESH_TAP` | `0x50` | Seuil TAP d'environ 5 g. |
| `DUR` | `0x10` | Durée TAP d'environ 10 ms. |
| `LATENT` | `0x00` | Latence TAP nulle. |
| `TAP_AXES` | `0x00` | Axes TAP désactivés dans l'état final. |
| `THRESH_FF` | `0x09` | Seuil de chute libre d'environ 0,56 g. |
| `TIME_FF` | `0x0A` | Durée de chute libre de 50 ms. |

Deux détails m'ont posé question pendant la vérification : `TAP_AXES` reçoit d'abord `0x07`, puis `0x00`, donc **la dernière écriture désactive les axes TAP**. De même, le commentaire de `TIME_FF` parle de 100 ms, mais la valeur `10` correspond bien à **50 ms** (10 × 5 ms). J'ai conservé dans ce README ce qui est réellement configuré.

Le programme prépare des paramètres pour plusieurs types de détection, mais **seules les interruptions WATERMARK et OVERRUN sont activées** dans `INT_ENABLE`. Je ne présente donc pas ici une alarme de choc fonctionnelle, puisque ce n'est pas ce que fait le programme actuel.

### 6.3. FIFO et acquisition

Le programme utilise deux mémoires distinctes :

1. La **FIFO interne de l'ADXL345**, qui garde les mesures acquises. En mode Stream, le seuil WATERMARK est fixé à 16 mesures.
2. Une **FIFO logicielle de 32 octets**, `fifo_tx`, pour stocker les octets à transmettre vers l'ordinateur.

Dans la boucle principale, le STM32 surveille **PA10**. Lorsque WATERMARK est actif et qu'il reste au moins sept places dans `fifo_tx`, il lit `FIFO_STATUS`, puis récupère **une mesure composée de X, Y et Z**. Il prépare ensuite une trame et essaie d'envoyer progressivement les octets disponibles. Le signal OVERRUN est également lu sur **PA11**, mais il n'y a pas encore de traitement spécifique associé dans la boucle.

Pour lire une mesure, le STM32 envoie la commande SPI **`0xF2`** : lecture (`0x80`) + lecture multiple (`0x40`) + adresse du registre `DATAX0` (`0x32`). Les six octets suivants permettent de reconstruire les valeurs X, Y et Z, deux octets par axe.

### 6.4. USART2 et trames vers Processing

J'ai utilisé l'**USART2 à 9600 bauds**, au format **8N1** : 8 bits de données, pas de parité et 1 bit de stop. Chaque octet est précédé d'un bit de start.

Les trois valeurs d'accélération sont conservées sur **13 bits signés**, puis découpées en six octets : six bits de poids fort et sept bits de poids faible pour chaque axe. Avec l'en-tête, cela fait **sept octets par trame** :

```text
┌────────┬────────┬────────┬────────┬────────┬────────┬────────┐
│  0xF0  │   XH   │   XL   │   YH   │   YL   │   ZH   │   ZL   │
└────────┴────────┴────────┴────────┴────────┴────────┴────────┘
  En-tête       X             Y             Z
```

- `0xF0` permet de reconnaître le début d'une nouvelle trame.
- `XH/XL`, `YH/YL` et `ZH/ZL` contiennent les valeurs des trois axes.
- `ZL` est le **dernier octet**, mais il n'existe pas de deuxième octet spécial de fin de trame dans ce protocole.

Un exemple observé sur PulseView est :

```text
F0 00 18 3F 6B 3E 02
```

Le programme Processing recherche l'en-tête, récupère les six octets suivants et reconstitue les trois valeurs signées. Les mesures sont ensuite converties en **g**, avec une sensibilité nominale de **3,9 mg/LSB**, puis en **m/s²**.

## 7. Affichage Processing

Le programme `Visualisation_ADXL345.pde` sert à vérifier que les mesures reçues sont cohérentes et à les suivre plus facilement qu'avec une simple liste d'octets.

Il affiche :

- les accélérations actuelles sur **X, Y et Z**, en g et en m/s² ;
- une courbe d'évolution pour chaque axe ;
- un historique circulaire des **650 dernières mesures**, donc supérieur aux 500 demandées ;
- la dernière trame UART reçue, octet par octet ;
- une représentation des octets MISO **reconstitués à partir de l'UART**. Ce n'est pas une capture directe du bus SPI ;
- le nombre de trames reçues et les erreurs de synchronisation.

J'ai aussi prévu un **mode DEMO** pour vérifier l'affichage sans montage, mais il est différent de la lecture réelle sur un port série. Pour une démonstration du TP, il faut donc sélectionner le port COM associé au STM32, et non laisser l'interface en mode démonstration.

### Raccourcis de l'interface

- **R** : actualiser / afficher les ports série disponibles.
- **E** : effacer l'historique affiché.
- **T** : activer ou désactiver le mode démonstration.

## 8. Comment lancer le projet

### 8.1. Programme STM32

1. Brancher la carte NUCLEO au PC et vérifier les connexions du capteur.
2. Ouvrir **Keil µVision**.
3. Charger le fichier `Projet_keil_initialiser_STM32_F103RB-main/tp2_micro_controleur_2.uvprojx`.
4. Vérifier la cible **STM32F103RB** et la configuration ST-LINK du projet.
5. Lancer la compilation, corriger les éventuels messages d'erreur, puis téléverser le programme sur la carte.
6. Vérifier que la communication SPI avec l'ADXL345 fonctionne avant de passer à l'affichage sur PC.

Le code se trouve dans `main.c`. J'ai utilisé VS Code pour l'éditer, mais **la compilation et le téléversement** sont réalisés depuis Keil.

### 8.2. Interface Processing

**Depuis les sources :**

1. Ouvrir Processing avec la bibliothèque série disponible.
2. Ouvrir `Visualisation_ADXL345/Visualisation_ADXL345.pde`.
3. Démarrer le programme.
4. Choisir le port COM correspondant à la liaison série STM32, configurée à **9600 bauds**.
5. Attendre les trames commençant par `0xF0`, puis incliner le capteur pour suivre les variations des axes.

**Depuis l'application Windows exportée :**

Ouvrir `Visualisation_ADXL345/windows-amd64/Visualisation_ADXL345.exe` en conservant les dossiers `java/` et `lib/` à côté de l'exécutable.

### 8.3. Analyseur logique

1. Brancher les voies sur **SCK, CS, MOSI et MISO** en parallèle du montage, ainsi que la masse commune.
2. Si nécessaire, brancher également **INT1 et INT2**.
3. Ouvrir les acquisitions `Session_pulse_view/Config_spi/`, `Data_spi/` ou `UART/` dans PulseView.
4. Utiliser le décodage SPI pour repérer les commandes (`0xB9`, `0xF2`) et les octets de retour, puis le décodage UART pour vérifier les trames transmises.

Le signal `0xB9` correspond à la lecture du registre `FIFO_STATUS` (`0x39`), tandis que `0xF2` correspond à la lecture multiple à partir de `DATAX0` (`0x32`).

## 9. Vérifications et chronogrammes

Les captures présentées dans mon compte rendu servent à faire le lien entre les instructions du programme C et les signaux réellement observés :

- **SPI** : la commande est visible sur MOSI et la réponse du capteur sur MISO. La sélection du capteur se fait avec CS, pendant que SCK cadence les bits.
- **FIFO_STATUS** : la commande `0xB9` permet de vérifier le nombre de mesures présentes dans la FIFO. Dans une capture commentée du rapport, la réponse `0x10` correspond à 16 entrées.
- **Lecture des axes** : avec `0xF2`, le STM32 récupère six octets. Le premier octet simultané à l'envoi de la commande n'est pas une mesure utile.
- **UART** : la capture montre une trame commençant par `0xF0`, suivie des six octets X/Y/Z.
- **Durée d'un bit UART** : à 9600 bauds, la valeur théorique est `1 / 9600`, soit environ **104,17 µs**. J'ai estimé environ **103 µs** sur une capture agrandie, ce qui est cohérent avec la configuration.

En comparant différentes acquisitions SPI, on remarque que certains octets changent. Cela montre que les valeurs lues évoluent au cours du temps. Par contre, **ces changements seuls ne prouvent pas une inclinaison volontaire** : pour cela, il faudrait présenter un relevé avant et après avoir déplacé le capteur, ou le montrer clairement dans la vidéo.

## 10. Difficultés rencontrées et utilisation de l'IA

Pendant le TP, je n'ai pas tout réalisé d'un seul coup. J'ai avancé en vérifiant une partie du système à la fois, puis en reliant les éléments ensemble.

Au début, j'avais tendance à poser des questions assez générales à l'IA, en lui demandant de faire quelque chose sans forcément lui donner toutes les informations. Petit à petit, je me suis rendu compte que je devais expliquer davantage ce que je voulais obtenir et surtout comparer ses réponses avec l'énoncé, le code C et les chronogrammes.

L'IA m'a surtout aidé à discuter des choix de programmation, à comprendre certaines fonctions et à préparer des explications techniques. Je ne me suis pas contenté de reprendre une réponse sans la confronter au fonctionnement de mon montage.

J'ai également dû faire attention à ne pas confondre :

- les **données SPI mesurées** avec les octets **MISO reconstruits par Processing** à partir d'une trame UART ;
- la **FIFO du capteur** avec la **FIFO logicielle** utilisée pour la transmission ;
- les paramètres réellement écrits dans les registres avec certains commentaires du code, notamment pour `TAP_AXES` et `TIME_FF`.

Je n'ai plus l'historique complet des prompts utilisés. Je préfère donc l'indiquer plutôt que d'en inventer des citations exactes. Les échanges ont principalement concerné la configuration du STM32, la lecture de l'ADXL345, la transmission UART, les chronogrammes et la manière de présenter le travail dans le rapport.

## 11. Compte rendu et vidéo de démonstration

Le compte rendu est disponible dans :

- [`TP2_MCU2.docx`](TP2_MCU2.docx) : version modifiable ;
- [`TP2_MCU2.pdf`](TP2_MCU2.pdf) : version à consulter ou à rendre.

Il regroupe l'introduction, le montage, le bilan E/S, les tableaux de configuration, l'explication du programme, Processing et les chronogrammes commentés.

**Vidéo de démonstration : [lien grosfichiers.ch à ajouter après dépôt de la vidéo]**

Le professeur demande un **plan-séquence** montrant le câblage matériel, les signaux analysés dans PulseView, l'interface Processing et la modification des accélérations lorsque le capteur est incliné. La vidéo doit être mise à disposition sur **[grosfichiers.ch](https://www.grosfichiers.ch/)** pour conserver une fenêtre de téléchargement suffisamment longue. **Un lien Google Docs ou GitHub ne remplace pas le lien de téléchargement de la vidéo.**

## 12. Remarques sur l'état actuel du projet

Le fonctionnement principal présenté ici est **l'acquisition des accélérations et leur visualisation**. Le code prévoit aussi des réglages liés à l'activité, à l'inactivité, aux chocs et à la chute libre, mais ces fonctions ne doivent pas être confondues avec une application complète d'alarme.

Quelques points restent à garder en tête :

- `TAP_AXES` se termine à `0x00`, donc les axes de détection TAP ne restent pas activés.
- `TIME_FF = 10` correspond à 50 ms, même si un commentaire du C évoque 100 ms.
- `SIZE_FIFO` est défini deux fois dans le `main.c` examiné. La compilation retrouvée indiquait **0 erreur et 1 avertissement** ; il serait préférable de conserver une seule définition.
- La lecture du signal OVERRUN est présente, mais son traitement n'est pas encore développé.
- Le mode DEMO de Processing est utile pour tester l'interface ; il ne constitue pas à lui seul une preuve de mesure réelle.
- Le lien vidéo reste à compléter une fois la démonstration déposée.

Au final, l'objectif de ce TP était surtout de comprendre une chaîne d'acquisition complète : **capteur → SPI → STM32 → UART → Processing**, et de pouvoir vérifier les échanges à l'aide de l'analyseur logique plutôt que de se fier uniquement à ce qui s'affiche sur l'ordinateur.
