
import os
import pytesseract
from PIL import Image
from spellchecker import SpellChecker
import shutil
import re
from multiprocessing import Pool

# Set folders
INPUT_FOLDER = "/Users/mdh/Documents/two-minute-porn-2025/resized-frames-2mp"
OUTPUT_FOLDER = "/Users/mdh/Documents/two-minute-porn-2025/images_with_text_second_pass"
#INPUT_FOLDER = "/Users/mdh/Documents/two-minute-porn-2025/test-images"
#OUTPUT_FOLDER = "/Users/mdh/Documents/two-minute-porn-2025/test-images-excluded"

# Ensure output folder exists
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

# Regex pattern: Match words of 3+ contiguous letters
WORD_PATTERN = re.compile(r'\b[A-Za-z]{3,}\b')
MIN_WORD_LENGTH = 5

pytesseract.pytesseract.tesseract_cmd = '/usr/local/bin/tesseract'
tessdata_dir_config = r'--tessdata-dir "/usr/local/share/tessdata"'

# Initialize the spell checker
spell = SpellChecker()

def process_image(filename):
    #Detect text in image and move it if text is found.
    if filename.lower().endswith(('.jpg', '.jpeg', '.png')):
        image_path = os.path.join(INPUT_FOLDER, filename)
        
        try:
            image = Image.open(image_path)
            
            # PSM 3, OEM 1 (LSTM only) -- did not detect anything
            # PSM 3, OEM 3 -- did not detect anything
            # PSM 3, OEM 2 (legacy + LSTM engines) - not working. Missing language data file.
            # PSM 6, OEM 3 - too sensitive, detects too much
            # PSM 11, OEM 3 -- too sensitive
            # PSM 1, OEM 3 -- nothing detected
            # PSM 2, OEM 3  - ERROR
            # PSM 4, OEM 3 -- very little detected, and the wrong ones
            # PSM 5, OEM 3 -- too sensitive
            # PSM 6, OEM 3 -- too sensitive
            # PSM 7, OEM 3 -- very little detected, and the wrong ones
            # PSM 8, OEM 3 -- moved a few, and mostly wrong
            # PSM 9, OEM 3 -- too insensitive
            # PSM 10, OEM 3 -- unreliable
            # PSM 12, OEM 3 -- too sensitive
            text = pytesseract.image_to_string(image, config="--psm 11 --oem 3 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

            # Find contiguous words in text
            words = WORD_PATTERN.findall(text)

            # Filter words by minimum length
            filtered_words = [word for word in words if len(word) >= MIN_WORD_LENGTH]

            # Spell-check the filtered words
            misspelled_words = spell.unknown(filtered_words)

            # If no words are misspelled, move the image
            if len(misspelled_words) <= 1:
                shutil.move(image_path, os.path.join(OUTPUT_FOLDER, filename))
                print(f"--MOVED {filename}: All words are spelled correctly -> {filtered_words}")
            else:
                print(f"Misspelled words in {filename}: {misspelled_words}")

        except Exception as e:
            print(f"Error processing {filename}: {e}")

# Run in parallel
if __name__ == "__main__":
    files = sorted(os.listdir(INPUT_FOLDER))
    with Pool() as pool:
        pool.map(process_image, files)


# With a dictionary check - TOO SLOW
"""
import os
from PIL import Image
import pytesseract
import shutil
from nltk.corpus import words

# Ensure nltk data path is set correctly
import nltk
nltk.data.path.append("/Users/mdh/nltk_data")

# Load the dictionary (only lowercase words)
english_words = set(word.lower() for word in words.words())

# Set your folder paths
INPUT_FOLDER = "/Users/mdh/Documents/two-minute-porn-2025/test-images"
OUTPUT_FOLDER = "/Users/mdh/Documents/two-minute-porn-2025/test-images-excluded"

# Create the output folder if it doesn't exist
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

# Get a sorted list of image files
files = sorted(f for f in os.listdir(INPUT_FOLDER) if f.lower().endswith(('.jpg', '.jpeg', '.png')))

# Process each image
for filename in files:
    image_path = os.path.join(INPUT_FOLDER, filename)
    try:
        # Run OCR
        image = Image.open(image_path)
        text = pytesseract.image_to_string(image, config="--psm 6 --oem 3")

        # Extract words and filter out short symbols
        extracted_words = [word.lower() for word in text.split() if word.isalpha() and len(word) > 2]

        # Skip images with too few words (avoid false positives)
        #if len(extracted_words) < 3:
        #    print(f"Skipping {filename}: Too few words detected.")
        #    continue

        # Count dictionary words
        dict_words = [word for word in extracted_words if word in english_words]
        dict_ratio = len(dict_words) / len(extracted_words) if extracted_words else 0

        # Move image if at least 50% of words are in the dictionary
        if dict_ratio >= 0.5:
            shutil.move(image_path, os.path.join(OUTPUT_FOLDER, filename))
            print(f"Moved {filename}: detected words -> {extracted_words}")
            print(f"{dict_ratio*100:.1f}% dictionary words.")
        else:
            print(f"Kept {filename}: {dict_ratio*100:.1f}% dictionary words.")
    
    except Exception as e:
        print(f"Error processing {filename}: {e}")
"""


