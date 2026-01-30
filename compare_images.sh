: '
#!/bin/bash

reference="/Users/mdh/Documents/xxxx-2025/resized-frames-2mp/000039943.jpg"
folder="/Users/mdh/Documents/xxxx-2025/resized-frames-2mp"

counter=0

# Loop through all images in the folder
for file in "$folder"/*.jpg; do
    # Ensure the file exists and is not the reference image
    if [[ -f "$file" && "$file" != "$reference" ]]; then
        ((counter++))
        echo -ne "Processed: $counter files\r"
        similarity=$(magick compare -metric RMSE "$reference" "$file" null: 2>&1)
        echo "$similarity $file"
    fi
done | sort -n

echo -e "\nDone! Processed $counter files."
'

#!/bin/bash

reference="/Users/mdh/Documents/xxxx-2025/resized-frames-2mp/000039943.jpg"
folder="/Users/mdh/Documents/xxxx-2025/resized-frames-2mp"

counter=0

echo "Debug: Checking files in $folder"
ls -l "$folder"

for file in "$folder"/*.jpg; do
    if [[ -f "$file" && "$file" != "$reference" ]]; then
        ((counter++))
        echo "Processing file #$counter: $file"
        similarity=$(magick compare -metric RMSE "$reference" "$file" null: 2>&1)
        echo "Similarity score: $similarity"
    else
        echo "Skipping: $file (Not a valid file or is the reference image)"
    fi
done

echo -e "\nDone! Processed $counter files."