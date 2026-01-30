import os
import numpy as np
from PIL import Image
import shutil

# Set folder paths
image_folder = "/Users/mdh/Documents/two-minute-porn-2025/resized-frames-2mp"
removed_folder = "/Users/mdh/Documents/two-minute-porn-2025/removed_folder_colour"  # Folder for images that are too different

# Ensure the removed folder exists
os.makedirs(removed_folder, exist_ok=True)

def get_average_color(image_path):
    """Returns the average color (R, G, B) of an image."""
    with Image.open(image_path) as img:
        img = img.convert("RGB")
        np_img = np.array(img)
        avg_color = np_img.mean(axis=(0, 1))  # Average across width & height
        return avg_color

# Step 1: Compute average color of all images
print("Scanning images and calculating their average colors...")  ### ADDED PRINT MESSAGE
image_files = [f for f in os.listdir(image_folder) if f.lower().endswith(('png', 'jpg', 'jpeg'))]
image_colors = []

for img_file in image_files:
    img_path = os.path.join(image_folder, img_file)
    avg_color = get_average_color(img_path)
    image_colors.append(avg_color)
    print(f"Processed {img_file}, Average Color: {avg_color}")


# Step 2: Compute overall average color
overall_avg_color = np.mean(image_colors, axis=0)
print(f"\nOverall Average Color: {overall_avg_color}")

# Step 3: Move images that are too different to the removed folder
threshold = 85 # Adjust as needed
print("\nFiltering images based on color difference...")

for img_file, avg_color in zip(image_files, image_colors):
    color_distance = np.linalg.norm(avg_color - overall_avg_color)
    
    if color_distance > threshold:
        shutil.move(os.path.join(image_folder, img_file), os.path.join(removed_folder, img_file))  # Move file
        print(f"Moved {img_file} (Color Distance: {color_distance:.2f})")
    else:
        print(f"Kept {img_file} (Color Distance: {color_distance:.2f})")

print("Filtering complete! Different-colored images moved.")
