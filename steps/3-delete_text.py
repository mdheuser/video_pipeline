#!/usr/bin/env python3

import argparse
import os
import re
import shutil
from multiprocessing import Pool, cpu_count

import pytesseract
from PIL import Image
from spellchecker import SpellChecker

# Regex pattern: Match words of 3+ contiguous letters
WORD_PATTERN = re.compile(r"\b[A-Za-z]{3,}\b")

# Default minimum word length (your previous MIN_WORD_LENGTH = 5)
DEFAULT_MIN_WORD_LENGTH = 5

# ATTEMPTS AT DIFFERENT TESSERACT CONFIGURATIONS
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
# PSM 11, --oem 3 -- OK -- This is what I will be using
# Default OCR config: keep your exact config string
DEFAULT_TESS_CONFIG = (
    "--psm 11 --oem 3 "
    "-c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
)

# Initialize spell checker once (safe to be global)
spell = SpellChecker()

# -------------------------------------------------------------------
# Process_image receives all needed parameters explicitly.
# This is required for multiprocessing + avoiding globals tied to a specific machine.
# -------------------------------------------------------------------
def process_image(args_tuple):
    filename, input_dir, excluded_dir, min_word_length, tess_config = args_tuple
    #images extracted by the program have the .jpg extension but .jpeg and .png are also accepted
    if not filename.lower().endswith((".jpg", ".jpeg", ".png")):
        return

    image_path = os.path.join(input_dir, filename)

    try:
        image = Image.open(image_path)

        text = pytesseract.image_to_string(image, config=tess_config)

        # Find contiguous words in text
        words = WORD_PATTERN.findall(text)

        # Filter words by minimum length
        filtered_words = [word for word in words if len(word) >= min_word_length]

        # Spell-check the filtered words
        misspelled_words = spell.unknown(filtered_words)

        # If <= 1 misspelled word, treat as "real text" and move image out
        if len(misspelled_words) <= 1:
            dest_path = os.path.join(excluded_dir, filename)
            shutil.move(image_path, dest_path)
            print(f"--MOVED {filename}: All words spelled correctly -> {filtered_words}")
        else:
            print(f"Misspelled words in {filename}: {misspelled_words}")

    except Exception as e:
        print(f"Error processing {filename}: {e}")


def parse_args():
    # Add argparse CLI so bash can call: python3 steps/3-delete_text.py --input ... --excluded ...
    p = argparse.ArgumentParser(
        description="Detect text in frames using OCR + spellcheck; move frames with likely text into an excluded folder."
    )
    p.add_argument("--input", required=True, help="Directory containing frames to scan (.jpg/.png).")
    p.add_argument(
        "--excluded",
        required=True,
        help="Directory to move frames WITH detected text into (excluded from later steps).",
    )

    # Tuning knobs, defaulting to current settings.
    p.add_argument("--min-word-length", type=int, default=DEFAULT_MIN_WORD_LENGTH)
    p.add_argument("--tess-config", default=DEFAULT_TESS_CONFIG)

    # Allow turning multiprocessing off for debugging, and make worker count configurable.
    p.add_argument("--workers", type=int, default=cpu_count(), help="Number of parallel workers (default: CPU count).")
    p.add_argument("--no-parallel", action="store_true", help="Run in a single process (easier to debug).")

    # Allow printing langs for quick diagnostics.
    p.add_argument("--print-langs", action="store_true", help="Print available tesseract languages and exit.")

    # Allow setting tesseract binary path via CLI for mac users.
    # In Docker/Linux you should NOT need this; leave it unset.
    p.add_argument(
        "--tesseract-cmd",
        default="",
        help="Optional path to the tesseract binary (e.g. /opt/homebrew/bin/tesseract).",
    )

    return p.parse_args()


def main():
    args = parse_args()

    # Pptional diagnostic
    if args.tesseract_cmd:
        pytesseract.pytesseract.tesseract_cmd = args.tesseract_cmd

    if args.print_langs:
        try:
            print(pytesseract.get_languages(config=""))
        except Exception as e:
            print(f"Could not list languages: {e}")
        return

    input_dir = os.path.abspath(args.input)
    excluded_dir = os.path.abspath(args.excluded)

    if not os.path.isdir(input_dir):
        raise SystemExit(f"--input is not a directory: {input_dir}")

    # Ensure excluded dir exists
    os.makedirs(excluded_dir, exist_ok=True)

    files = sorted(os.listdir(input_dir))

    # Pack args for each job
    jobs = [(f, input_dir, excluded_dir, args.min_word_length, args.tess_config) for f in files]

    if args.no_parallel or args.workers <= 1:
        # Single-process fallback
        for job in jobs:
            process_image(job)
    else:
        # Bound workers to at least 1
        workers = max(1, args.workers)
        with Pool(processes=workers) as pool:
            pool.map(process_image, jobs)


if __name__ == "__main__":
    main()

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
INPUT_FOLDER = "/Users/mdh/Documents/xxxx-2025/test-images"
OUTPUT_FOLDER = "/Users/mdh/Documents/xxxx-2025/test-images-excluded"

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


