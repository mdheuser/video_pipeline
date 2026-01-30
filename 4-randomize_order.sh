FRAMES_FOLDER=/Users/mdh/Documents/xxxx-2025/resized-frames-2mp/

echo "Randomizing file order and renaming sequentially..."
cd "$FRAMES_FOLDER"

# Create a temporary directory for the operation
TEMP_DIR=$(mktemp -d)

# Move all jpg files to the temporary directory with random names
find . -maxdepth 1 -type f -name "*.jpg" | while read file; do
    mv "$file" "$TEMP_DIR/$(uuidgen).jpg"
done

# Move files back with sequential names
counter=1
find "$TEMP_DIR" -type f -name "*.jpg" | sort | while read file; do
    mv "$file" "$(printf "%09d.jpg" $counter)"
    ((counter++))
done

# Remove the temporary directory
rmdir "$TEMP_DIR"

echo "Renaming complete. Files are now named sequentially from 000000001.jpg"
