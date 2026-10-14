import processing.serial.*;

// ==============================================================
// ADXL345 + STM32F103RB — Tableau de bord UART Processing 4
// USART2 : 9600 bauds, 8N1
// Trame exacte du code STM32 : F0 XH XL YH YL ZH ZL
// XH/YH/ZH : bits [12..7] (6 bits), XL/YL/ZL : bits [6..0]
// Les valeurs sont signees sur 13 bits, en complement a deux.
// ==============================================================

final int BAUDRATE = 9600;
final float G_PAR_LSB = 0.0039f;    // ADXL345 FULL_RES : 3,9 mg/LSB nominal
final float G_TERRESTRE = 9.80665f;
final int HISTORIQUE = 650;        // Nombre de mesures affichees sur le graphique

// Palette sobre (ARGB)
final int FOND      = 0xFF0E1420;
final int PANNEAU   = 0xFF192232;
final int PANNEAU2  = 0xFF202D40;
final int BLANC     = 0xFFF5F7FA;
final int TEXTE2    = 0xFFAAB8CC;
final int GRILLE    = 0xFF344357;
final int AXE_X     = 0xFF54CEBF;
final int AXE_Y     = 0xFF8FA7F8;
final int AXE_Z     = 0xFFF1B779;
final int[] COULEURS = { AXE_X, AXE_Y, AXE_Z };
final String[] NOMS = { "X", "Y", "Z" };

Serial liaison;
String[] portsDisponibles = new String[0];
String portActuel = "";
String messagePort = "Choisir un port COM en haut a droite";
boolean menuPortsOuvert = false;
boolean demonstration = false;

// Recepteur binaire. -1 : recherche de l'en-tete F0.
int positionDonnees = -1;
int[] donnees = new int[6];
long erreursTrame = 0;
int derniereReceptionMs = -1;

// Derniere mesure + historique circulaire
float[] actuelG = new float[3];
float[][] historiqueG = new float[3][HISTORIQUE];
int prochaineCase = 0;
int mesuresStockees = 0;
long nombreMesures = 0;
int dernierPasDemoMs = 0;

// Affichage de la derniere trame UART (octets vraiment recus sur le PC).
// Une trame est constituee de F0 puis des 6 octets bruts XH XL YH YL ZH ZL.
final String[] LIBELLES_OCTETS = { "ENTETE", "XH", "XL", "YH", "YL", "ZH", "ZL" };
int[] derniereTrameUART = new int[7];
int[] referenceTrameUART = new int[7];
boolean trameDisponible = false;
boolean referenceDisponible = false;
long numeroReference = 0;
int[] brutActuel = new int[3];
final int HAUTEUR_FENETRE = 1130;

void settings() {
  size(1280, HAUTEUR_FENETRE);
}

void setup() {
  frameRate(60);
  surface.setTitle("ADXL345 | Mesures d'acceleration UART et visualisation des trames");
  textFont(createFont("SansSerif", 15, true));
  actualiserPorts();
}

void draw() {
  if (demonstration) {
    alimenterDemonstration();
  } else {
    lireUART();
  }

  background(FOND);
  dessinerEntete();

  float marge = 36;
  float espacement = 16;
  float largeurCarte = (width - 2 * marge - 2 * espacement) / 3.0f;
  float echelle = echelleGraphique();

  for (int axe = 0; axe < 3; axe++) {
    dessinerCarteAxe(marge + axe * (largeurCarte + espacement),
      122, largeurCarte, 228, axe, echelle);
  }

  dessinerHistorique(36, 370, width - 72, 310, echelle);
  dessinerTrameUART(36, 698, width - 72, 350);
  dessinerPiedDePage();

  // Le menu deroulant doit rester devant les courbes.
  if (menuPortsOuvert) {
    dessinerMenuPorts();
  }
}

// ===================== COMMUNICATION ==========================

void actualiserPorts() {
  try {
    portsDisponibles = Serial.list();
    if (portsDisponibles == null) portsDisponibles = new String[0];
    if (portsDisponibles.length == 0 && liaison == null) {
      messagePort = "Aucun port detecte : verifier l'adaptateur USB-UART";
    }
  } catch (Exception ex) {
    portsDisponibles = new String[0];
    messagePort = "Recherche de ports impossible : " + ex.getMessage();
  }
}

void connecter(String nomPort) {
  fermerPort();
  demonstration = false;
  reinitialiserMesures();

  try {
    // Par defaut, Processing Serial utilise 8N1, sans controle de flux.
    liaison = new Serial(this, nomPort, BAUDRATE);
    liaison.clear();
    portActuel = nomPort;
    messagePort = "Port ouvert, attente des trames F0...";
  } catch (Exception ex) {
    liaison = null;
    portActuel = "";
    messagePort = "Impossible d'ouvrir " + nomPort + " : " + ex.getMessage();
  }
}

void fermerPort() {
  if (liaison != null) {
    try { liaison.stop(); } catch (Exception ignored) { }
    liaison = null;
  }
  portActuel = "";
}

void lireUART() {
  if (liaison == null) return;

  try {
    // On lit les octets BRUTS. Ne pas utiliser readStringUntil('\n') :
    // le message STM32 n'est PAS une ligne ASCII.
    int maxi = 8192;
    while (liaison.available() > 0 && maxi-- > 0) {
      int octet = liaison.read();
      if (octet >= 0) traiterOctet(octet & 0xFF);
    }
  } catch (Exception ex) {
    fermerPort();
    messagePort = "Port deconnecte : " + ex.getMessage();
  }
}

void traiterOctet(int octet) {
  if (positionDonnees == -1) {
    if (octet == 0xF0) positionDonnees = 0;
    return;
  }

  // Dans le protocole STM32, TOUS les octets utiles ont b7 = 0.
  // Un octet > 0x7F dans le corps signale une perte de synchronisation.
  // XH/YH/ZH ne contiennent que six bits ; XL/YL/ZL sept bits.
  // Cela elimine egalement des trames corrompues dont b7 reste pourtant a 0.
  if ((octet & 0x80) != 0 || ((positionDonnees % 2) == 0 && octet > 0x3F)) {
    erreursTrame++;
    positionDonnees = (octet == 0xF0) ? 0 : -1;
    return;
  }

  donnees[positionDonnees++] = octet;
  if (positionDonnees == 6) {
    int x = decoderSigne13(donnees[0], donnees[1]);
    int y = decoderSigne13(donnees[2], donnees[3]);
    int z = decoderSigne13(donnees[4], donnees[5]);
    ajouterMesure(x, y, z);
    enregistrerTrameUART(donnees);
    positionDonnees = -1;
    derniereReceptionMs = millis();
    messagePort = "Trames recues correctement";
  }
}

int decoderSigne13(int octetFort, int octetFaible) {
  int valeur = ((octetFort & 0x3F) << 7) | (octetFaible & 0x7F);
  if ((valeur & 0x1000) != 0) valeur -= 0x2000;  // Extension du signe
  return valeur;
}

// Le tableau ne montre PAS les octets du bus SPI, qui n'arrivent pas au PC.
// Il montre exactement la trame binaire USART2 recue, apres verification F0.
void enregistrerTrameUART(int[] chargeUtile) {
  derniereTrameUART[0] = 0xF0;
  for (int i = 0; i < 6; i++) {
    derniereTrameUART[i + 1] = chargeUtile[i] & 0xFF;
  }
  trameDisponible = true;
  if (!referenceDisponible) memoriserReference();
}

void memoriserReference() {
  if (!trameDisponible) return;
  arrayCopy(derniereTrameUART, referenceTrameUART);
  referenceDisponible = true;
  numeroReference = nombreMesures;
}

// Pour le mode demonstration, encoder la trame exactement comme le STM32.
void enregistrerTrameSimulee(int x, int y, int z) {
  int[] brut = { x, y, z };
  int[] chargeUtile = new int[6];
  for (int a = 0; a < 3; a++) {
    int signe13 = brut[a] & 0x1FFF;
    chargeUtile[2 * a] = (signe13 >> 7) & 0x3F;
    chargeUtile[2 * a + 1] = signe13 & 0x7F;
  }
  enregistrerTrameUART(chargeUtile);
}

void ajouterMesure(int x, int y, int z) {
  int[] brut = { x, y, z };
  for (int a = 0; a < 3; a++) brutActuel[a] = brut[a];
  for (int a = 0; a < 3; a++) {
    actuelG[a] = brut[a] * G_PAR_LSB;
    historiqueG[a][prochaineCase] = actuelG[a];
  }
  prochaineCase = (prochaineCase + 1) % HISTORIQUE;
  if (mesuresStockees < HISTORIQUE) mesuresStockees++;
  nombreMesures++;
}

void reinitialiserMesures() {
  nombreMesures = 0;
  mesuresStockees = 0;
  prochaineCase = 0;
  positionDonnees = -1;
  erreursTrame = 0;
  derniereReceptionMs = -1;
  trameDisponible = false;
  referenceDisponible = false;
  numeroReference = 0;
  for (int i = 0; i < 7; i++) {
    derniereTrameUART[i] = 0;
    referenceTrameUART[i] = 0;
  }
  for (int a = 0; a < 3; a++) {
    actuelG[a] = 0;
    brutActuel[a] = 0;
  }
}

// ====================== GRAPHIQUES ============================

void dessinerEntete() {
  fill(BLANC);
  textAlign(LEFT, CENTER);
  textSize(27);
  text("ADXL345", 36, 43);
  fill(TEXTE2);
  textSize(13);
  text("Acceleration 3 axes | STM32F103RB | USART2 - 9600 bauds", 36, 80);

  // Selection du port serie
  float bx = width - 348;
  float by = 27;
  float bw = 260;
  float bh = 42;
  String titrePort = demonstration ? "DEMO / choisir COM" :
    (portActuel.length() > 0 ? portActuel : "Selectionner le port COM");
  if (titrePort.length() > 31) titrePort = titrePort.substring(0, 28) + "...";
  bouton(bx, by, bw, bh, titrePort + "  v", menuPortsOuvert);
  bouton(width - 77, by, 41, bh, "R", menuPortsOuvert);

  fill(demonstration ? AXE_Z : (liaison != null ? AXE_X : TEXTE2));
  ellipse(39, 105, 8, 8);
  fill(TEXTE2);
  textSize(12);
  String statut = demonstration ? "Simulation - aucune donnee reelle" : messagePort;
  if (liaison != null && derniereReceptionMs >= 0 && millis() - derniereReceptionMs > 2000) {
    statut = "Port ouvert, mais aucune trame complete depuis plus de 2 s";
  }
  text(statut, 50, 104);
}

void dessinerCarteAxe(float x, float y, float w, float h, int axe, float echelle) {
  dessinerPanneau(x, y, w, h);

  // Nom de l'axe.
  fill(COULEURS[axe]);
  noStroke();
  ellipse(x + 28, y + 31, 11, 11);
  fill(TEXTE2);
  textAlign(LEFT, CENTER);
  textSize(14);
  text("AXE " + NOMS[axe], x + 45, y + 31);

  // Les deux accelerations sont affichees avec EXACTEMENT la meme taille.
  // On garde la taille initiale de la mesure en g (31 points).
  textAlign(LEFT, CENTER);
  fill(BLANC);
  textSize(31);
  text(nf(actuelG[axe], 1, 3) + " g", x + 25, y + 77);

  // Fleche de conversion : acceleration (g) x 9,81 = acceleration (m/s²).
  float flecheX = x + 36;
  float hautFleche = y + 103;
  float basFleche = y + 132;
  stroke(COULEURS[axe]);
  strokeWeight(2.5f);
  line(flecheX, hautFleche, flecheX, basFleche);
  line(flecheX, basFleche, flecheX - 6, basFleche - 7);
  line(flecheX, basFleche, flecheX + 6, basFleche - 7);
  noStroke();
  fill(COULEURS[axe]);
  textSize(15);
  text("\u00d7 9,81", x + 54, y + 118);

  // Valeur en m/s² : meme taille (31) et meme couleur que la valeur en g.
  fill(BLANC);
  textSize(31);
  text(nf(actuelG[axe] * G_TERRESTRE, 1, 3) + " m/s\u00b2", x + 25, y + 164);

  // Barre horizontale d'amplitude, centree sur zero.
  float debut = x + 26;
  float fin = x + w - 26;
  float centre = (debut + fin) / 2;
  float largeurDemi = (fin - debut) / 2;
  float curseur = constrain(actuelG[axe] / echelle, -1, 1) * largeurDemi;
  float barreY = y + 204;

  noStroke();
  fill(PANNEAU2);
  rect(debut, barreY - 6, fin - debut, 12, 7);
  fill(COULEURS[axe]);
  if (curseur >= 0) {
    rect(centre, barreY - 6, max(1, curseur), 12, 5);
  } else {
    rect(centre + curseur, barreY - 6, max(1, -curseur), 12, 5);
  }
  stroke(BLANC, 130);
  strokeWeight(1);
  line(centre, barreY - 10, centre, barreY + 10);
  noStroke();
}

void dessinerHistorique(float x, float y, float w, float h, float echelle) {
  dessinerPanneau(x, y, w, h);
  textAlign(LEFT, CENTER);
  fill(BLANC);
  textSize(20);
  text("Evolution des accelerations", x + 26, y + 32);
  fill(TEXTE2);
  textSize(12);
  text("Abscisse : numero d'echantillon recu   |   Ordonnee : acceleration (g)", x + 26, y + 56);

  float lx = x + 77;
  float rx = x + w - 28;
  float ty = y + 89;
  float by = y + h - 54;
  float pw = rx - lx;
  float ph = by - ty;

  // Grille Y et graduations
  textAlign(RIGHT, CENTER);
  textSize(12);
  for (int i = 0; i <= 4; i++) {
    float valeur = echelle * (1.0f - i * 0.5f);
    float yy = ty + i * ph / 4;
    stroke(GRILLE);
    strokeWeight(1);
    line(lx, yy, rx, yy);
    noStroke();
    fill(TEXTE2);
    text(nf(valeur, 1, 1), lx - 12, yy);
  }

  // Grille X : numero d'echantillon, PAS le temps.
  long premierNumero = nombreMesures - mesuresStockees + 1;
  textAlign(CENTER, CENTER);
  for (int i = 0; i <= 5; i++) {
    float xx = lx + i * pw / 5;
    stroke(GRILLE);
    line(xx, ty, xx, by);
    noStroke();
    fill(TEXTE2);
    long num = (mesuresStockees > 0) ?
      (premierNumero + (long)((mesuresStockees - 1) * i / 5.0f)) : 0;
    text(Long.toString(num), xx, by + 19);
  }

  // Courbes des 650 derniers echantillons (ordre chronologique).
  if (mesuresStockees >= 2) {
    noFill();
    strokeWeight(2);
    for (int axe = 0; axe < 3; axe++) {
      stroke(COULEURS[axe]);
      beginShape();
      for (int i = 0; i < mesuresStockees; i++) {
        int idx = (prochaineCase - mesuresStockees + i + HISTORIQUE) % HISTORIQUE;
        float xx = lx + i * pw / (mesuresStockees - 1);
        float yy = map(historiqueG[axe][idx], echelle, -echelle, ty, by);
        vertex(xx, constrain(yy, ty, by));
      }
      endShape();
    }
    noStroke();
  } else {
    fill(TEXTE2);
    textAlign(CENTER, CENTER);
    textSize(16);
    text("En attente des premieres mesures UART...", (lx + rx) / 2, (ty + by) / 2);
  }

  // Legende
  float legendeX = x + w - 230;
  for (int a = 0; a < 3; a++) {
    fill(COULEURS[a]);
    ellipse(legendeX + a * 70, y + 34, 9, 9);
    fill(TEXTE2);
    textAlign(LEFT, CENTER);
    textSize(13);
    text(NOMS[a], legendeX + a * 70 + 13, y + 34);
  }
}

float echelleGraphique() {
  // Echelle automatique, en conservant toujours au moins +/- 2 g.
  float maximum = 0.0f;
  for (int a = 0; a < 3; a++) {
    maximum = max(maximum, abs(actuelG[a]));
    for (int i = 0; i < mesuresStockees; i++) {
      maximum = max(maximum, abs(historiqueG[a][i]));
    }
  }
  return max(2.0f, ceil((maximum * 1.15f) * 2.0f) / 2.0f);
}

void dessinerPiedDePage() {
  fill(TEXTE2);
  textAlign(LEFT, CENTER);
  textSize(13);
  text("Trames recues : " + Long.toString(nombreMesures), 37, 1078);
  text("Erreurs de synchronisation : " + Long.toString(erreursTrame), 283, 1078);
  float norme = sqrt(actuelG[0] * actuelG[0] + actuelG[1] * actuelG[1] + actuelG[2] * actuelG[2]);
  text("Norme : " + nf(norme, 1, 3) + " g", 626, 1078);
  text("R : ports  B : reference  E : effacer  T : demo", width - 393, 1078);
  textSize(11);
  fill(TEXTE2);
  text("UART observe sur PC ; SPI reconstitue a titre explicatif. Gravite incluse dans les mesures.", 37, 1106);
}

void dessinerPanneau(float x, float y, float w, float h) {
  noStroke();
  fill(PANNEAU);
  rect(x, y, w, h, 14);
}

void bouton(float x, float y, float w, float h, String texte, boolean actif) {
  noStroke();
  fill(actif ? PANNEAU : PANNEAU2);
  rect(x, y, w, h, 8);
  textAlign(CENTER, CENTER);
  textSize(13);
  fill(BLANC);
  text(texte, x + w / 2, y + h / 2);
}

// ====================== TRAME UART EN DIRECT =====================

String octetHex(int valeur) {
  return hex(valeur & 0xFF, 2);
}

String octetBinaire(int valeur) {
  return binary(valeur & 0xFF, 8);
}

String trameTexte(int[] octets) {
  String resultat = "";
  for (int i = 0; i < octets.length; i++) {
    if (i > 0) resultat += " ";
    resultat += octetHex(octets[i]);
  }
  return resultat;
}

String reconstruireMISO_SPI() {
  // L'octet MISO recu pendant F2 est indetermine pour cette commande.
  // Les six octets de donnees sont reconstitues par extension de signe
  // de la mesure UART 13 bits, dans l'ordre faible puis fort pour chaque axe.
  String resultat = "--";
  for (int a = 0; a < 3; a++) {
    int signe16 = brutActuel[a] & 0xFFFF;
    resultat += " " + octetHex(signe16 & 0xFF);
    resultat += " " + octetHex((signe16 >> 8) & 0xFF);
  }
  return resultat;
}

boolean surRectangle(float x, float y, float w, float h) {
  return mouseX >= x && mouseX < x + w && mouseY >= y && mouseY < y + h;
}

void dessinerTrameUART(float x, float y, float w, float h) {
  dessinerPanneau(x, y, w, h);
  fill(BLANC);
  textAlign(LEFT, CENTER);
  textSize(20);
  text("Trame UART en direct", x + 26, y + 30);
  fill(TEXTE2);
  textSize(12);
  text("F0  XH  XL  YH  YL  ZH  ZL  |  Valeurs binaires envoyees par le STM32", x + 26, y + 55);

  // Permet de figer le capteur immobile, puis de l'incliner pour observer
  // exactement quels octets changent par rapport a cet etat initial.
  float btnX = x + w - 214;
  float btnY = y + 17;
  bouton(btnX, btnY, 188, 35, "MEMORISER REF. [B]", false);

  float depart = x + 25;
  float intervalle = 10;
  float largeur = (w - 50 - 6 * intervalle) / 7.0f;
  float carteY = y + 81;
  float carteH = 128;
  int changements = 0;

  for (int i = 0; i < 7; i++) {
    float xx = depart + i * (largeur + intervalle);
    int valeur = trameDisponible ? derniereTrameUART[i] : 0;
    int base = referenceDisponible ? referenceTrameUART[i] : 0;
    boolean different = trameDisponible && referenceDisponible && valeur != base;
    if (different) changements++;

    noStroke();
    fill(different ? 0xFF314B48 : PANNEAU2);
    rect(xx, carteY, largeur, carteH, 10);
    if (different) {
      noFill();
      stroke(AXE_X);
      strokeWeight(1.5f);
      rect(xx + 0.75f, carteY + 0.75f, largeur - 1.5f, carteH - 1.5f, 9);
      noStroke();
    }

    fill(i == 0 ? AXE_Y : (i <= 2 ? AXE_X : (i <= 4 ? AXE_Y : AXE_Z)));
    textAlign(CENTER, CENTER);
    textSize(13);
    text(LIBELLES_OCTETS[i], xx + largeur / 2, carteY + 19);

    fill(BLANC);
    textSize(27);
    text(trameDisponible ? octetHex(valeur) : "--", xx + largeur / 2, carteY + 51);

    fill(TEXTE2);
    textSize(12);
    text(trameDisponible ? octetBinaire(valeur) : "--------", xx + largeur / 2, carteY + 79);

    fill(different ? AXE_X : TEXTE2);
    textSize(11);
    text(referenceDisponible ? "ref : " + octetHex(base) : "ref : --", xx + largeur / 2, carteY + 109);
  }

  fill(TEXTE2);
  textAlign(LEFT, CENTER);
  textSize(12);
  if (trameDisponible) {
    fill(AXE_X);
    text(changements + " octet(s) modifies depuis la reference", x + 26, y + 229);
    fill(TEXTE2);
    text("Trame actuelle :  " + trameTexte(derniereTrameUART), x + 330, y + 229);
    text("Reference : " + trameTexte(referenceTrameUART) +
      "   (mesure n" + numeroReference + ")", x + 26, y + 253);
  } else {
    text("En attente d'une trame F0 complete. Appuyer sur T pour tester en simulation.", x + 26, y + 233);
  }

  // La capture d'origine SPI n'est PAS fournie a Processing : cette vue
  // explique quel serait l'echange attendu sur le bus SPI, pas ce qui a ete
  // mesure directement avec l'analyseur logique.
  textSize(12);
  fill(AXE_Y);
  textAlign(LEFT, CENTER);
  text("Lecture SPI reconstituee (non mesuree sur le bus) :", x + 26, y + 279);
  fill(TEXTE2);
  text("MOSI (STM32 -> ADXL345) :  F2 00 00 00 00 00 00", x + 26, y + 303);
  text("MISO (ADXL345 -> STM32) :  " +
    (trameDisponible ? reconstruireMISO_SPI() : "-- -- -- -- -- -- --"), x + 585, y + 303);
}

// ====================== LISTE DES PORTS =========================

void ouvrirMenuPorts() {
  actualiserPorts();
  menuPortsOuvert = true;
  if (portsDisponibles.length == 0) {
    messagePort = "Aucun port disponible. Brancher l'adaptateur puis appuyer sur R.";
  }
}

void dessinerMenuPorts() {
  float x = width - 348;
  float y = 74;
  float w = 301;
  float itemH = 37;
  int n = min(portsDisponibles.length, 12);
  float h = 47 + max(1, n) * itemH;
  noStroke();
  fill(0, 100);
  rect(x + 4, y + 4, w, h, 9);
  fill(PANNEAU2);
  rect(x, y, w, h, 9);

  fill(AXE_X);
  textAlign(LEFT, CENTER);
  textSize(12);
  text("Choisir un port (R = actualiser)", x + 14, y + 21);

  if (n == 0) {
    fill(TEXTE2);
    text("Aucun port detecte", x + 14, y + 57);
    return;
  }
  for (int i = 0; i < n; i++) {
    float itemY = y + 43 + i * itemH;
    if (surRectangle(x + 5, itemY, w - 10, itemH)) {
      fill(0xFF35435A);
      rect(x + 5, itemY, w - 10, itemH, 5);
    }
    fill(portsDisponibles[i].equals(portActuel) ? AXE_X : BLANC);
    textSize(13);
    String nom = portsDisponibles[i];
    if (nom.length() > 36) nom = nom.substring(0, 33) + "...";
    text(nom, x + 15, itemY + itemH / 2);
    if (portsDisponibles[i].equals(portActuel)) {
      textAlign(RIGHT, CENTER);
      text("connecte", x + w - 12, itemY + itemH / 2);
      textAlign(LEFT, CENTER);
    }
  }
}

// ====================== CONTROLES ==============================

void mousePressed() {
  float bx = width - 348;
  // Les deux boutons du bandeau servent a ouvrir la liste des ports.
  // "R" ne se contente plus d'actualiser silencieusement la liste.
  if (surRectangle(width - 77, 27, 41, 42)) {
    ouvrirMenuPorts();
    return;
  }
  if (surRectangle(bx, 27, 260, 42)) {
    if (menuPortsOuvert) menuPortsOuvert = false;
    else ouvrirMenuPorts();
    return;
  }

  if (menuPortsOuvert) {
    int n = min(portsDisponibles.length, 12);
    float x = width - 348;
    float y = 74 + 43;
    if (surRectangle(x, y, 301, n * 37)) {
      int index = (int)((mouseY - y) / 37);
      if (index >= 0 && index < n) {
        String choix = portsDisponibles[index];
        menuPortsOuvert = false;
        connecter(choix);  // arrete l'ancien port, puis ouvre le nouveau.
        return;
      }
    }
    menuPortsOuvert = false;
    return;
  }

  // Bouton pour figer une nouvelle reference avant d'incliner le capteur.
  if (surRectangle(36 + (width - 72) - 214, 698 + 17, 188, 35)) {
    memoriserReference();
  }
}

void keyPressed() {
  if (key == 'r' || key == 'R') ouvrirMenuPorts();
  if (key == 'b' || key == 'B') memoriserReference();
  if (key == 'e' || key == 'E') reinitialiserMesures();
  if (key == 't' || key == 'T') {
    demonstration = !demonstration;
    menuPortsOuvert = false;
    reinitialiserMesures();
    dernierPasDemoMs = millis();
    if (liaison != null) liaison.clear();
    messagePort = "Simulation terminee : attente des trames reelles";
  }
}

void alimenterDemonstration() {
  // Preview facultative : seules ces valeurs sont simulees.
  int maintenant = millis();
  int retard = maintenant - dernierPasDemoMs;
  int aProduire = min(20, retard / 10);  // 100 mesures/s (simulation)
  for (int i = 0; i < aProduire; i++) {
    float t = (nombreMesures + 1) * 0.01f;
    int x = round((0.17f * sin(TWO_PI * 0.65f * t) + random(-0.01f, 0.01f)) / G_PAR_LSB);
    int y = round((0.10f * cos(TWO_PI * 0.27f * t) + random(-0.01f, 0.01f)) / G_PAR_LSB);
    int z = round((-1.00f + 0.05f * sin(TWO_PI * 0.48f * t)) / G_PAR_LSB);
    ajouterMesure(x, y, z);
    enregistrerTrameSimulee(x, y, z);
    dernierPasDemoMs += 10;
  }
}

public void dispose() {
  fermerPort();
  super.dispose();
}
