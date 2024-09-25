# ardaudio-dl

ardaudio-dl is a bash script that allows you to download audiobooks and podcasts from the ARD Audiothek website. It provides various features such as metadata embedding, cover image downloading, and content zipping.

## Installation and Requirements

### Installation

1. Download from https://github.com/patrycc/ardaudio-dl (Download -> "Download ZIP")
2. Unzip the files.
3. Make the script executable:
   ```
   chmod +x ardaudio-dl.sh
   ```

### Requirements

- Bash shell
- wget
- ffmpeg (optional, but required for metadata embedding and audio trimming)
- zip (optional, required for creating zip archives)

## How to Use

To use the script, you need to provide a URL from the ARD Audiothek website. The URL should be for the first episode of a series or for a single episode.

Basic usage:
```
./ardaudio-dl.sh [options] <URL>
```

Example:
```
./ardaudio-dl.sh --naming-pattern "nbe" --zip https://www.ardaudiothek.de/episode/der-kleine-prinz/folge-1-von-10-der-kleine-prinz-von-antoine-de-saint-exupery/ndr-kultur/12174228/
```

Note: Only use URLs that contain a "nächste Episode" (next episode) link if you want to download an entire series. Single episodes are still able to be downloaded. Do not use the "Alle Episoden" overview, it is not compatible with this script.

## Parameters

- `--naming-pattern <pattern>`: Set the naming pattern for files. Use 'n' for number, 'b' for book title, 'e' for episode title. Default is "e".
- `--single-episode`: Download only the specified episode, ignore "next episode" links.
- `--keep-images`: Keep cover images after embedding them into the audio files.
- `--audio-only`: Download audio without attempting to fetch or embed images.
- `--meta-autofill`: Automatically fill in metadata for the audio files (requires ffmpeg).
- `--meta-number`: Use incrementing numbers as track titles in metadata (requires ffmpeg).
- `--zip`: Create a zip file of the downloaded content after completion.
- `--trim <milliseconds>`: Trim the specified number of milliseconds from the start of each audio file (requires ffmpeg). If used without a millisecond parameter, the default of 5000 milliseconds will be assumed.
- `--download-location <path>`: Specify the directory where files should be downloaded. Default is the location of the script.

## Examples

1. Download an entire series with custom naming and create a zip file:
   ```
   ./ardaudio-dl.sh --naming-pattern "nbe" --zip https://www.ardaudiothek.de/episode/your-series-url-here
   ```

2. Download a single episode and keep the cover image:
   ```
   ./ardaudio-dl.sh --single-episode --keep-images https://www.ardaudiothek.de/episode/your-episode-url-here
   ```

3. Download to a specific location and trim 5 seconds from the start of each file:
   ```
   ./ardaudio-dl.sh --download-location ~/Audiobooks --trim 5000 https://www.ardaudiothek.de/episode/your-series-url-here
   ```

## Acknowledgements

This script was created to facilitate easy downloading of content from ARD Audiothek for personal use. Please respect copyright laws and terms of service of ARD Audiothek when using this script.
