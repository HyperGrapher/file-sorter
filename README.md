# FileSorter

File organizer in C that automatically sorts your messy downloads folder!

Just run it and it moves images to Images/, docs to Documents/, videos to Videos/ etc.

## Build

```sh
make
```

On Windows with MinGW:

```sh
gcc -Wall -Wextra -pedantic -std=c99 -O2 -o filesorter.exe file_sorter.c
```

## Usage

Preview your default Downloads folder without moving anything:

```sh
./filesorter --dry-run
```

Sort your default Downloads folder:

```sh
./filesorter
```

Sort a specific folder:

```sh
./filesorter --dry-run /path/to/folder
./filesorter /path/to/folder
```

Files are sorted into `Images`, `Documents`, `Videos`, `Music`, `Archives`,
`Installers`, `Torrents`, `Code`, and `Others`. Existing files are not
overwritten; duplicate names get a numbered suffix.

## PowerShell

```powershell
.\filesorter.ps1 -DryRun
.\filesorter.ps1
.\filesorter.ps1 -DryRun C:\path\to\folder
```

## Bash

For macOS and Linux:

```sh
chmod +x filesorter.sh
./filesorter.sh --dry-run
./filesorter.sh
./filesorter.sh --dry-run /path/to/folder
```
