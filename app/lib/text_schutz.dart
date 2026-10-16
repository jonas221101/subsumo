/// Geschuetzte Leerzeichen in Normzitaten, damit "§" oder "Art." nicht allein
/// am Zeilenende stehen ("§ / 123 Abs. 2 BGB", Nutzertest W10).
String normUmbruchschutz(String text) => text.replaceAllMapped(
      RegExp(r'(§§?|Art\.|Abs\.|Nr\.|S\.|Alt\.|lit\.)[ ]+(?=[0-9IVX])'),
      (m) => '${m.group(1)} ',
    );
