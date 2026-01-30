import pytesseract
import os

# Set the TESSDATA_PREFIX environment variable correctly
os.environ["TESSDATA_PREFIX"] = "/usr/local/Cellar/tesseract/5.5.0/share/"
print("TESSDATA_PREFIX is set to:", os.environ["TESSDATA_PREFIX"])

# Test if pytesseract can detect languages
print(pytesseract.get_languages())

# Test if Tesseract works on an image
try:
    print(pytesseract.image_to_string("/Users/mdh/Documents/xxxx-2025/test_images_small/000000002.jpg", lang="eng"))
except Exception as e:
    print("Error:", e)
