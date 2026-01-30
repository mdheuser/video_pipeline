import pytesseract
#import nltk
#from nltk.corpus import words, names  # Import words and names corpora
import re
import os
import shutil

#pytesseract.pytesseract.tesseract_cmd = "/opt/homebrew/bin/tesseract"  # Adjust if needed
os.environ["TESSDATA_PREFIX"] = "/usr/local/Cellar/tesseract/5.5.0/share/"

print(pytesseract.get_languages(config=''))

# Download required NLTK datasets (only needs to be done once)
#nltk.download('words')  # For the dictionary of valid English words
#nltk.download('names')  # For the list of proper names (male and female)

def has_text_first_pass(image_path, min_length=1, confidence_threshold=58):
    """Detects if an image contains any word-like sequence (3+ letters)."""
    try:
        data = pytesseract.image_to_data(image_path, config='--psm 3 --oem 3', output_type=pytesseract.Output.DICT)

        if data['text']:
            for i in range(len(data['text'])):
                word = data['text'][i]
                confidence = data['conf'][i]

                # Check if word is a valid letter sequence (3+ letters)
                if confidence >= confidence_threshold and len(re.findall(r"[a-zA-Z]", word)) >= min_length:
                    return True  # The image contains a valid word-like sequence and should be excluded

        return False  # No valid words detected, the image can be kept
    except Exception as e:
        print(f"Error processing {image_path}: {e}")
        return False

def process_images(image_dir, destination_dir):
	"""Processes images in a directory and moves those with text to a destination directory."""

	if not os.path.exists(destination_dir):
		os.makedirs(destination_dir)  # Create destination if it doesn't exist

	image_files = [f for f in os.listdir(image_dir) if f.lower().endswith(('.jpg'))] # Add more extensions if necessary

	for image_file in image_files:
		image_path = os.path.join(image_dir, image_file)
		if has_text_first_pass(image_path):
			destination_path = os.path.join(destination_dir, image_file)
			try:
				shutil.move(image_path, destination_path)  # Efficiently move the file
				print(f"Moved {image_file} to {destination_dir}")
			except Exception as e:
				print(f"Error moving {image_file}: {e}")
		else:
			print(f"No text found in {image_file}") # Optional: Print for images without text

# Example usage:
image_directory = "/Users/mdh/Documents/xxxx-2025/images_with_text"
destination_directory = "/Users/mdh/Documents/xxxx-2025/two_passes/second_pass"
#image_directory = "/Users/mdh/Documents/xxxx-2025/resized-frames-2mp"
#destination_directory = "/Users/mdh/Documents/xxxx-2025/images_with_text_second_pass"

process_images(image_directory, destination_directory)
