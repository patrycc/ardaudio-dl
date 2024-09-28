# ardaudio-dl

A bash script for downloading audiobooks and series from the ARD Audiothek.

## Features

The script can download both series or single episodes from the ARD Audiothek. It offers customizable episode naming, allowing users to include episode numbers, book titles, and episode titles in their preferred order. Metadata management is supported, with options to autofill metatags for better organization. Cover art will be downloaded and embedded into the audio files by default.

Audio processing features include the ability to trim intros, such as removing the ARD jingle, and an option for audio-only downloads without images. After downloading, the script can create zip archives of the episodes. Users can specify custom download locations. It primarily uses built-in bash commands, making it lightweight and easy to run on *nix and macOS systems.

## Installation and Requirements

### Installation

1. Download from https://github.com/patrycc/ardaudio-dl (Download -> "Download ZIP")
2. Unzip the files.
3. Make the script executable:
   ```
   chmod +x ardaudio-dl.sh
   ```

### Requirements

#### ffmpeg

https://www.ffmpeg.org/download.html

You have to have ffmpeg installed, in order to use the trim, zip and metatag features. With no ffmpeg installed, those features will be ignored. Also, episode thumbnail images will still be downloaded, but not set as thumbnails for each episode.

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

- `--naming-pattern <pattern>`: Set the naming pattern for files. Use 'n' for number, 'b' for book title, 'e' for episode title. If no pattern value is provided, it will default is "e" (episode title). The pattern order is up to you.
- `--single-episode`: Download only the specified episode, ignore "next episode" links.
- `--keep-images`: Keep cover images after embedding them into the audio files.
- `--audio-only`: Download audio without attempting to fetch or embed images.
- `--meta-autofill`: Automatically fill in metadata for the audio files (requires ffmpeg). Currently checks for the episode title and album name. If those values are already set, they won't be overwritten.
- `--meta-number`: Use incrementing numbers as track titles in metadata (requires ffmpeg).
- `--zip`: Create a zip file of the downloaded content after completion.
- `--trim <milliseconds>`: Trim the specified number of milliseconds from the start of each audio file (requires ffmpeg). If no millisecond value is provided, 5000 milliseconds will be used as the default. (The ARD jingle is 5000 milliseconds long.) 
- `--download-location <path>`: Specify the directory where files should be downloaded. Default is the location of the script. If no path value is provided, then the current folder will be used as the location. (As is the default anyway.)

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
   
## Troubleshooting

### Red ffmpeg message 'Incorrect BOM value Error reading comment frame, skipped'

ffmpeg sometimes has problems with the meta tags of some mp3s. It won't cause issues with the download or ffmpeg related features. I might fix it eventually.

## Acknowledgements

This script was created to facilitate easy downloading of content from ARD Audiothek for personal use. Please respect copyright laws and terms of service of ARD Audiothek when using this script.
