# Filman / zaluknij downloader
Pobieranie filmów działa 2 etapowo:
 - pobranie linków do filmu/serialu z serwisu [filman.cc](https://filman.cc/) (tmUserScript_filman.js) lub z serwisu [zaluknij.cc](https://zaluknij.cc/) (tmUserScript_zaluknij.js)
 - uruchomienie skryptu bash (ripvid.sh)
   
# Wymagania
 - przeglądarka z zainstalowanym dodatkiem [Tampermonkey](https://www.tampermonkey.net/)
 - konto w serwisie [filman.cc](https://filman.cc/)
 - [zaluknij.cc](https://zaluknij.cc/) nie wymaga konta (póki co)
 - jakiś Linux z curl'em oraz openssl (testowane na: Debian 12 i 13, CentOS Stream, openSUSE, Raspberry Pi OS). **openssl** jest wymagany przy pobieraniu filmów z [luluStream](https://lulustream.com/) ponieważ video jest (zazwyczaj) szyfrowane i trzeba je odkodować.
   
# Użytkowanie
- w Tampermonkey dodajemy skrypt (jeden lub obydwa) `tmUserScript_filman.js` `tmUserScript_zaluknij.js` i uruchaiamy **Tryb developera** w przeglądarce: opis [tutaj](https://www.tampermonkey.net/faq.php?locale=en#Q209).
- logujemy się do [filman.cc](https://filman.cc/) / [zaluknij.cc](https://zaluknij.cc/)
- przechodzimy na stronę z interesującym nas filmem / odcinkiem serialu
- w górnej części strony pojawi się pole z linkami do video oraz innymi danymi, pod oknem znajduje się przycisk **Kopiuj do schowka**. Kopiujemy zawartość.
- wklejamy zawartość do pliku, na przykład:
  ```
  /tmp/katalog-z-linkami/linki
  ```
- modyfikujemy odpowiednie linijki w skrypcie **ripvid.sh**, które odpowiadają za ścieżki do obsługi plików tymczasowych oraz plików wyjściowych:
  ```
  outDir=TU-WPISZ-SWOJĄ-ŚCIEŻKĘ-DO-ZAPISU-POBRANYCH-VIDEO
  fTmp=TU-WPISZ-SWOJĄ-ŚCIEŻKĘ-DO-OBRÓWKI-PLIKÓW-TYMCZASOWYCH
  ```
- nadajemy prawo wykonywania do skryptu **ripvid.sh**
- uruchamiamy skrypt w następujący sposób
  ```
  ripvid.sh -p /tmp/katalog-z-linkami/
  ```
  Podajemy ścieżkę do katalogu gdzie znajduje się nasz plik w którym zapisaliśmy dane ze strony. **Nie podajemy ścieżki do samego pliku**.
- opcjonalnie możemy podać również parametr **-t**
  ```
  ripvid.sh -p /tmp/katalog-z-linkami/ -t l
  ```
  Parametr ten oznacza typ filmu jaki nas interesuje
  ```
  l lub L - lektor
  n lub N - napisy
  d lub D - dubbing
  e lub E - wersja angielska
  p lub P - wersja polska (dotyczy głównie polskich filmów)
  ```
  Domyślnie wyszukiwana i pobierana jest wersja z lektorem. Występują również jakieś niszowe opcje typu Dubbing_Kino itd., ale raczej nie są one warte uwagi ;)
- czekamy ;)

Jeśli wszystko pójdzie dobrze to po kilku(-nastu) minutach (w zależności od prędkości łącza) mamy pobrany film do wskazanego katalogu. Pobieranie plików jest zrównoleglone, to znaczy, że odpala się 50 pobierań na raz, żeby przyspieszyć cały proces ;)

# Ściąganie całych seriali
Jest możliwość ściągnięcia całych sezonów seriali, słuzy do tego skrypt `get-full-serises.sh`. Użycie:
```
./get-full-series.sh -l https://zaluknij.cc/serial-online/JAKIEŚ_NUMERKI/TYTUŁ_SERIALU
```
W wyniku powiniśmy otrzymać odpowiednio sformatowane dane wejsciowe dla skryptu `ripvid.sh`. Dane powinny pojawić się w `/tmp/series/links`. Wtedy wystarczy uruchomić:
```
./ripvid.sh -p /tmp/series/
```
i poczekać ;)

>[!NOTE]  
>To działa tylko z `zaluknij.cc`. Na `filman.cc` reCaptcha skutecznie utrudnia dostęp. ALE ;) da się dostosować ten skrypt żeby opierdzielić `filman.cc` też - przynajmniej dopóki sesje nie wygasną. Potrzeba tylko wyciągnąć nagłówki z przeglądarki i wkleić w odpowiednie miejsce w skrypcie :)  

Seriale są zaisywane w strukturze katalogów przedstawionej poniżej:

```
/folder/do/zapisu/pobranych/TYTUŁ-SERIALU/
├── s01
│   ├── [s01e01]_TYTUŁ-ODCINKA-1.(ts/mp4)
│   ├── [s01e02]_TYTUŁ-ODCINKA-2.(ts/mp4)
│   ├── [s01e03]_TYTUŁ-ODCINKA-3.(ts/mp4)
|   ...
├── s02
│   ├── [s02e01]_TYTUŁ-ODCINKA-1.(ts/mp4)
│   ├── [s02e02]_TYTUŁ-ODCINKA-2.(ts/mp4)
│   ├── [s02e03]_TYTUŁ-ODCINKA-3.(ts/mp4)
├── s03
│   ├── [s03e01]_TYTUŁ-ODCINKA-1.(ts/mp4)
│   ├── [s03e02]_TYTUŁ-ODCINKA-2.(ts/mp4)
│   ├── [s03e03]_TYTUŁ-ODCINKA-3.(ts/mp4)
...
```

# Uwagi
Do katalogu gdzie wrzucamy pliki z danymi ze strony (w przykładzie powyżej `/tmp/katalog-z-linkami/`) możemy umieścić dowolną ilość plików do filmów i/lub seriali. Mogą być wymieszane pliki z serialami oraz filmami. Ważne, żeby nie były to pliki **ukryte**. Zawartość pliku powinien stanowić **czysty tekst**.
Przykład:
```
https://luluvdo.com/d/LULU-ID@Lektor@Serial@TYTUŁ-SERIALU@_s02_e05@TYTUŁ-ODCINKA
https://doodstream.com/d/DOOD-ID@Lektor@Serial@TYTUŁ-SERIALU@_s02_e05@TYTUŁ-ODCINKA
https://vidmoly.me/w/VIDMOLY-ID@Napisy@Serial@TYTUŁ-SERIALU@_s02_e05@TYTUŁ-ODCINKA
...
```

Najlepsze rozwiązanie: wrzucić wszystke do jednego pliku. Mogą być wymieszane dane serialowe oraz filmowe. Skrypt rozpozna i sformatuje tak jak powinno być.

Obsługiwane jest pobieranie z najpopularniejszych serwisów dostępnych na `filman.cc` i `zaluknij.cc`: lulustream, vidoza, vidmoly, streamtape, savefiles, bigshare jednakże nie zawsze intersujący nas typ video może być wszędzie dostępny. Dodatkowo ze względu na to, że serwisy często zmieniają strukturę HTML istnieje możliwość, że pojawią się błędy. Staram się to modyfikować na bieżąco w miarę możliwości ;)

# TODO

**Vidmoly** do dopracowania sprawdzanie czy plik istnieje.

# Archive
Archiwalny, elegancki ;) automagiczy skrypt, który działał dopóki `filman.cc` nie włączył reCaptcha ¯\\\_(ツ)_/¯. Mogę udostępnić na życzenie.
