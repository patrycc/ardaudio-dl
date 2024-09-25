#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

url=""
naming_pattern="e"  # Default to just episode title
single_episode=false
keep_images=false
audio_only=false
meta_autofill=false
episode_counter=1
trim_ms=-1  # -1 means no trimming
audiobook_cover_downloaded=false
meta_number=false
zip_contents=false
download_location="."

# Check if ffmpeg is installed
if command -v ffmpeg &> /dev/null; then
    ffmpeg_installed=true
else
    ffmpeg_installed=false
    echo "Warning: ffmpeg is not installed. Some features will be disabled."
fi

# Check for parameters
while [[ $# -gt 0 ]]; do
    case $1 in
        --naming-pattern)
            if [[ -n $2 && $2 != -* ]]; then
                naming_pattern=$2
                shift 2
            else
                echo "Error: --naming-pattern requires a value. Using default (episode title only)."
                shift
            fi
            ;;
        --single-episode)
            single_episode=true
            echo "Single episode mode activated. Only the specified episode will be downloaded."
            shift
            ;;
        --keep-images)
            keep_images=true
            if [ "$ffmpeg_installed" = false ]; then
                echo "Warning: ffmpeg is not installed. Images will be kept but not embedded."
            else
                echo "Keep images mode activated. Episode images will not be deleted after embedding."
            fi
            shift
            ;;
        --audio-only)
            audio_only=true
            echo "Audio-only mode activated. No images will be downloaded or embedded."
            shift
            ;;
        --meta-autofill)
            if [ "$ffmpeg_installed" = true ]; then
                meta_autofill=true
                echo "Metadata autofill activated. Empty tags will be filled with available information."
            else
                echo "Warning: ffmpeg is not installed. Metadata autofill is not available."
            fi
            shift
            ;;
        --meta-number)
            if [ "$ffmpeg_installed" = true ]; then
                meta_number=true
                echo "Track number metadata activated. Incrementing numbers will be set as track titles."
            else
                echo "Warning: ffmpeg is not installed. Track number metadata is not available."
            fi
            shift
            ;;
        --zip)
            zip_contents=true
            echo "Zip mode activated. Contents will be zipped after download."
            shift
            ;;
        --trim)
            if [ "$ffmpeg_installed" = false ]; then
                echo "Warning: ffmpeg is not installed. Trim feature is not available."
                shift
            else
                if [[ -n $2 && $2 =~ ^[0-9]+$ ]]; then
                    trim_ms=$2
                    echo "Trim mode activated. Trimming $trim_ms milliseconds from the start of each audio file."
                    shift 2
                else
                    trim_ms=5000
                    echo "Trim mode activated with default value. Trimming 5000 milliseconds from the start of each audio file."
                    shift
                fi
            fi
            ;;
        --download-location)
            if [[ -n $2 && $2 != -* ]]; then
                download_location=$2
                shift 2
            else
                echo "Warning: No value provided for --download-location. Using current directory."
                shift
            fi
            ;;
        *)
            if [ -z "$url" ]; then
                url="$1"
            else
                echo "Error: Unexpected argument '$1'"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$url" ]; then
    echo "Error: Please provide a URL as the last parameter."
    exit 1
fi

initial_url=${url#view-source:}

echo "Naming pattern set to: $naming_pattern"

# Validate download location
if [ ! -d "$download_location" ]; then
    echo "Error: Specified download location does not exist or is not a directory."
    exit 1
fi

if [ ! -w "$download_location" ]; then
    echo "Error: No write permission in the specified download location."
    exit 1
fi

echo "Download location set to: $download_location"

# Function to create safe names for folders and files
create_safe_name() {
    echo "$1" | tr -d '[:cntrl:]' | tr -s ' ' | tr '/' '_'
}

# Create folder based on show name
webpage_content=$(wget -4 --no-check-certificate --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" -qO- "$initial_url" 2>/dev/null)

show_name=$(grep -oP '"show":"[^"]*"' <<< "$webpage_content" | sed 's/"show":"//;s/"$//')
# Unescape the show name
show_name=$(sed 's/\\\"/"/g' <<< "$show_name")

if [ -n "$show_name" ]; then
    # Remove everything after and including the "|" character
    clean_show_name=$(sed 's/ |.*$//' <<< "$show_name")
    folder_name=$(create_safe_name "$clean_show_name")
    echo "Show name found: $clean_show_name"
    echo "Folder name: $folder_name"
    mkdir -p "$download_location/$folder_name"
    echo "Folder created: $download_location/$folder_name"
else
    echo "Error: Could not find show name in the webpage."
    exit 1
fi

generate_filename() {
    local episode_title=$1
    local filename=""
    local parts=0
    
    for (( i=0; i<${#naming_pattern}; i++ )); do
        case "${naming_pattern:$i:1}" in
            n) 
                if [ $parts -gt 0 ]; then
                    filename+=" - "
                fi
                filename+="$(printf "%02d" $episode_counter)"
                ((parts++))
                ;;
            b) 
                if [ $parts -gt 0 ]; then
                    filename+=" - "
                fi
                filename+="$clean_show_name"
                ((parts++))
                ;;
            e) 
                if [ $parts -gt 0 ]; then
                    filename+=" - "
                fi
                filename+="$episode_title"
                ((parts++))
                ;;
        esac
    done
    
    # Remove leading separator if present
    filename=$(echo "$filename" | sed 's/^ - //')
    
    # Add .mp3 extension
    echo "${filename}.mp3"
}

# Function to download audiobook cover image
download_audiobook_cover() {
    local webpage_content=$1
    local base_url="https://api.ardmediathek.de/image-service/images/urn:ard:image:"
    local cover_image_url=$(echo "$webpage_content" | grep -oP '"programSet":.+?"url1X1":"[^"]+"' | grep -oP '"url1X1":"[^"]+"' | grep -oP "${base_url}[a-f0-9]{16}")
    
    if [ -n "$cover_image_url" ]; then
        echo "Detecting file type for audiobook cover image..."
        local content_type=$(wget -4 --spider --server-response "$cover_image_url" 2>&1 | grep -i "Content-Type:" | tail -1 | awk '{print $2}')
        local file_extension
        
        case "$content_type" in
            "image/jpeg") file_extension="jpg" ;;
            "image/png") file_extension="png" ;;
            "image/webp") file_extension="webp" ;;
            *) file_extension="jpg" ;; # Default to jpg if unknown
        esac
        
        local cover_filename="cover.$file_extension"
        
        if [ ! -f "$download_location/$folder_name/$cover_filename" ]; then
            echo "Downloading audiobook cover image..."
            echo "URL: $cover_image_url"
            echo "Detected file type: $content_type"
            wget -4 --no-check-certificate --progress=bar:force:noscroll -O "$download_location/$folder_name/$cover_filename" "$cover_image_url"
            if [ $? -eq 0 ]; then
                echo "Audiobook cover image downloaded: $cover_filename"
            else
                echo "Error: Failed to download audiobook cover image."
            fi
        else
            echo "Audiobook cover image already exists. Skipping download."
        fi
    else
        echo "Could not find valid audiobook cover image URL in the programSet section."
    fi
}

# Function to autofill metadata
autofill_metadata() {
    local filename="$1"
    local episode_title="$2"
    local album_name="$3"
    local track_number="$4"

    if [ "$ffmpeg_installed" = true ] && ( [ "$meta_autofill" = true ] || [ "$meta_number" = true ] ); then
        echo "Checking and autofilling metadata..."
        
        # Use full paths
        local full_path=$(cd "$(dirname "$filename")" && pwd)/$(basename "$filename")
        local dir=$(dirname "$full_path")
        local base=$(basename "$full_path")
        local temp_file="${dir}/temp_${RANDOM}_${base}"

        # Check existing metadata
        local current_title=$(ffprobe -v quiet -print_format json -show_format "$full_path" | grep -oP '"title"\s*:\s*"\K[^"]+')
        local current_album=$(ffprobe -v quiet -print_format json -show_format "$full_path" | grep -oP '"album"\s*:\s*"\K[^"]+')

        local metadata_args=()
        if [ -z "$current_title" ]; then
            metadata_args+=(-metadata "title=$episode_title")
            echo "Setting title to: $episode_title"
        else
            echo "Title already exists: $current_title"
        fi

        if [ -z "$current_album" ]; then
            metadata_args+=(-metadata "album=$album_name")
            echo "Setting album to: $album_name"
        else
            echo "Album already exists: $current_album"
        fi
        
        if [ "$meta_number" = true ] && [ -z "$current_track" ]; then
            metadata_args+=(-metadata "track=$track_number")
            echo "Setting track number to: $track_number"
        fi

        if [ ${#metadata_args[@]} -gt 0 ]; then
            ffmpeg -i "$full_path" "${metadata_args[@]}" -c copy "$temp_file" -loglevel error
            if [ $? -eq 0 ]; then
                mv "$temp_file" "$full_path"
                echo "Metadata updated successfully."
            else
                echo "Error: Failed to update metadata."
                rm "$temp_file" 2>/dev/null
            fi
        else
            echo "No metadata updates needed."
        fi
    elif [ "$meta_autofill" = true ] && [ "$ffmpeg_installed" = false ]; then
        echo "Warning: ffmpeg is not installed. Metadata autofill is not available."
    fi
}

download_episode() {
    local url=$1
    local next_url=""

    echo "Fetching webpage content from: $url"
    webpage_content=$(wget -4 --no-check-certificate --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" -qO- "$url" 2>/dev/null)

    # Download audiobook cover image if it's the first episode and not in audio-only mode
    if [ "$episode_counter" -eq 1 ] && [ "$audio_only" = false ] && [ "$audiobook_cover_downloaded" = false ]; then
        download_audiobook_cover "$webpage_content"
        audiobook_cover_downloaded=true
    fi

    # Extract the episode title
    episode_title=$(grep -o '<h1[^>]*>[^<]*</h1>' <<< "$webpage_content" | sed 's/<[^>]*>//g')

    if [ -z "$episode_title" ]; then
        echo "Error: Could not find episode title in the webpage."
        return 1
    fi

    echo "Found episode title: $episode_title"

    # Generate filename
    filename=$(generate_filename "$episode_title")
    filename=$(create_safe_name "$filename")

    # Extract and download image
    if [ "$audio_only" = false ]; then
        image_url=$(grep -oP '<meta property="og:image" content="\K[^"]+' <<< "$webpage_content" | sed 's/?.*//')
        if [ -n "$image_url" ]; then
            # Get the content type and determine the file extension
            content_type=$(wget -4 --spider --server-response -q "$image_url" 2>&1 | grep -i "Content-Type:" | tail -1 | awk '{print $2}')
            case "$content_type" in
                "image/jpeg") ext="jpg" ;;
                "image/png") ext="png" ;;
                "image/webp") ext="webp" ;;
                *) ext="jpg" ;; # Default to jpg if unknown
            esac
            
            image_filename="${filename%.*} cover.$ext"
            echo "Downloading image: $image_filename (Content-Type: $content_type)"
            wget -4 --no-check-certificate --progress=bar:force:noscroll -O "$download_location/$folder_name/$image_filename" "$image_url"
            wget_exit_code=$?
            
            if [ $wget_exit_code -eq 0 ]; then
                echo "Download completed. Checking file..."
                file_size=$(stat -c%s "$download_location/$folder_name/$image_filename")
                echo "Image downloaded successfully. Size: $(du -h "$download_location/$folder_name/$image_filename" | cut -f1)"
                
                if [ $file_size -eq 0 ]; then
                    echo "Warning: Downloaded image file is empty."
                fi
            else
                echo "Error: Image download failed with exit code $wget_exit_code"
            fi
        else
            echo "No image URL found for this episode."
        fi
    fi

    # Extract MP3 URL
    mp3_url=$(grep -o '"contentUrl":"[^"]*"' <<< "$webpage_content" | sed 's/"contentUrl":"//;s/"//')

    if [ -z "$mp3_url" ]; then
        echo "Error: Could not find MP3 URL on the page."
        return 1
    fi

    echo "Downloading: $filename"
    wget -4 --no-check-certificate --progress=bar:force:noscroll -O "$download_location/$folder_name/$filename" "$mp3_url"
    echo "Downloaded: $filename"

    # Autofill metadata
    autofill_metadata "$download_location/$folder_name/$filename" "$episode_title" "$clean_show_name" "$episode_counter"

    # Trim audio if necessary
    if [ "$ffmpeg_installed" = true ] && [ $trim_ms -ge 0 ]; then
        echo "Trimming $trim_ms milliseconds from the start of the audio..."
        trim_time=$(printf "%02d:%02d:%02d.%03d" $((trim_ms/3600000)) $((trim_ms/60000%60)) $((trim_ms/1000%60)) $((trim_ms%1000)))
        ffmpeg -i "$download_location/$folder_name/$filename" -ss "$trim_time" -acodec copy "$download_location/$folder_name/trimmed_$filename" -loglevel error
        mv "$download_location/$folder_name/trimmed_$filename" "$download_location/$folder_name/$filename"
        echo "Audio trimmed successfully."
    fi

    # Embed cover image using ffmpeg
    if [ "$ffmpeg_installed" = true ] && [ "$audio_only" = false ] && [ -f "$download_location/$folder_name/$image_filename" ] && [ -s "$download_location/$folder_name/$image_filename" ]; then
        echo "Embedding cover image into MP3..."
        ffmpeg -i "$download_location/$folder_name/$filename" -i "$download_location/$folder_name/$image_filename" -map 0:0 -map 1:0 -c copy -id3v2_version 3 "$download_location/$folder_name/tmp.mp3" -loglevel error
        if [ $? -eq 0 ]; then
            mv "$download_location/$folder_name/tmp.mp3" "$download_location/$folder_name/$filename"
            echo "Cover image embedded successfully."
            if [ "$keep_images" = false ]; then
                rm "$download_location/$folder_name/$image_filename"
                echo "Cover image file deleted."
            else
                echo "Cover image file kept as requested."
            fi
        else
            echo "Failed to embed cover image. Keeping original MP3 file."
        fi
    elif [ "$ffmpeg_installed" = false ] && [ "$audio_only" = false ]; then
        echo "ffmpeg not installed: Skipping cover image embedding."
        if [ "$keep_images" = false ]; then
            rm "$download_location/$folder_name/$image_filename"
            echo "Cover image file deleted."
        else
            echo "Cover image file kept."
        fi
    elif [ "$audio_only" = true ]; then
        echo "Audio-only mode: Skipping cover image embedding."
    else
        echo "Cover image not found or empty. Skipping embedding."
    fi

    if [ "$single_episode" = false ]; then
        # Extract next episode information from JSON data
        next_episode_json=$(grep -oP '"nextEpisode":\{[^}]*\}' <<< "$webpage_content")
        if [ -n "$next_episode_json" ]; then
            next_episode_path=$(grep -oP '"path":"[^"]*"' <<< "$next_episode_json" | sed 's/"path":"//;s/"//')
            if [ -n "$next_episode_path" ]; then
                next_url="https://www.ardaudiothek.de$next_episode_path"
                echo "Next episode URL: $next_url"
            else
                echo "No next episode path found. This might be the last episode."
            fi
        else
            echo "No next episode information found. This is the last episode."
        fi
    else
        echo "Single episode mode: Not checking for next episode."
    fi

    # Return the next URL (will be empty if there's no next episode or in single episode mode)
    echo "NEXT_URL:$next_url"
}

zip_folder_contents() {
    if [ "$zip_contents" = true ]; then
        echo "Zipping folder contents..."
        # Change to the folder containing the files
        cd "$download_location/$folder_name"
        
        # Create zip file in the parent directory
        zip_file="../${folder_name}.zip"
        if zip -r "$zip_file" *; then
            echo "Folder contents zipped successfully."
            echo "Zip file created: $download_location/$zip_file"
        else
            echo "Error: Failed to zip folder contents."
        fi
        
        # Change back to the original directory
        cd "$download_location"
    fi
}

# Start downloading episodes
current_url="$initial_url"
while [ -n "$current_url" ]; do
    # Run download_episode and capture its output
    output=$(download_episode "$current_url")
    
    # Extract the next URL from the output
    next_url=$(echo "$output" | grep "^NEXT_URL:" | sed 's/^NEXT_URL://')
    
    # Print the rest of the output (excluding the NEXT_URL line)
    echo "$output" | grep -v "^NEXT_URL:"
    
    if [ "$single_episode" = true ] || [ -z "$next_url" ]; then
        break
    fi
    current_url="$next_url"
    episode_counter=$((episode_counter + 1))
done

echo "All episodes have been processed."

# Zip contents if requested
zip_folder_contents
