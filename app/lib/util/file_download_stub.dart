/// Nicht-Web: kein Download-Mechanismus - Aufrufer faellt auf Kopieren zurueck.
bool downloadTextFile(String filename, String content, {String mime = 'application/json'}) => false;

bool get canDownloadFiles => false;
