# Filman downloader
Pobieranie filmów działa 2 etapowo:
 - pobranie linków do filmu/serialu z seriwsu filman (tmUserScript.js)
 - uruchomienie skryptu bash (ripvid.sh)
   
# Wymagania
 - przeglądarka z zainstalowanym dodatkiem [Tampermonkey](https://www.tampermonkey.net/)
 - konto w serwisie [Filman](https://filman.cc/)
 - jakiś Linux z curl'em ;) (testowane na: Debian, CentOS Stream, openSUSE, Raspberry Pi OS)
   
# Użytkowanie
- w Tampermonkey dodajemy skrypt tmUserScript.js
- logujemy się do filman.cc
- przechodzimy na stronę z interesującym nas filmem / odcinkiem serialu
- w górnej części strony pojawi się pole z linkami do video oraz innymi danymi, pod oknem znajduje się przycisk **Kopiuj do schowka**. Kopiujemy zawartość.
- wklejamy zawartość do pliku, na przykład:
  ```
  /tmp/jakiskatalog/film
  ```
- nadajemy prawo wykonywania do skryptu **ripvid.sh**
- uruchamiamy skrypt w następujący sposób
  ```
  ripvid.sh -p /tmp/jakiskatalog/
  ```
  Podajemy ścieżkę do katalogu gdzie znajduje się nasz plik w którym zapisaliśmy dane ze strony. **Nie podajemy ścieżki do samego pliku**.
- czekamy ;)
  
Jeśli wszystko pójdzie dobrze to po kilku(-nastu) minutach mamy pobrany film do wskazanego katalogu. 

# Inne
Do katalogu gdzie wrzucamy pliki z danymi ze strony (w przykładzie powyżej **/tmp/jakiskatalog/**) możemy umieścić dowolną ilość plików do filmów i/lub seriali. Mogą być wymieszane pliki z serialami oraz filmami. Nieistotne są też ich nazwy/rozszerzenia. Ważne jest tylko to by w jednym pliku znajdowały się dane do jednego odcinka serialu / jednego filmu.
