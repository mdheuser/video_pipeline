#!/usr/bin/env python3

import argparse
import os
import re
import shutil
from multiprocessing import Pool, cpu_count

import pytesseract
from pytesseract import Output

# Count letters inside a token (matches your old idea: "any word-like sequence")
LETTER_RE = re.compile(r"[A-Za-z]")

DEFAULT_MIN_LETTERS = 1
DEFAULT_MIN_CONF = 75

DEFAULT_TESS_CONFIG = (
    "--psm 11 --oem 3 "
    "-c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
)

def has_confident_text(image_path: str, tess_config: str, min_letters: int, min_conf: int) -> tuple[bool, str, float]:
    """
    Returns (has_text, token, conf) where has_text is True if any OCR token:
      - has >= min_letters alphabetic characters
      - has confidence >= min_conf
    """
    data = pytesseract.image_to_data(image_path, config=tess_config, output_type=Output.DICT)

    texts = data.get("text", [])
    confs = data.get("conf", [])

    for token, conf_raw in zip(texts, confs):
        token = (token or "").strip()
        if not token:
            continue

        try:
            conf = float(conf_raw)
        except Exception:
            continue

        # Tesseract uses -1 for "no confidence"/blanks frequently
        if conf < 0:
            continue

        if conf < float(min_conf):
            continue

        # same spirit as your old check: count letters in the token
        if len(LETTER_RE.findall(token)) >= min_letters:
            return True, token, conf

    return False, "", -1.0


def process_image(args_tuple):
    filename, input_dir, excluded_dir, tess_config, min_letters, min_conf = args_tuple

    if not filename.lower().endswith((".jpg", ".jpeg", ".png")):
        return

    image_path = os.path.join(input_dir, filename)

    # If the file disappeared (already moved), skip quietly
    if not os.path.exists(image_path):
        return

    try:
        has_text, token, conf = has_confident_text(
            image_path=image_path,
            tess_config=tess_config,
            min_letters=min_letters,
            min_conf=min_conf,
        )

        if has_text:
            dest_path = os.path.join(excluded_dir, filename)
            shutil.move(image_path, dest_path)
            print(f"--MOVED {filename}: token='{token}' conf={conf:.1f}")
        else:
            print(f"KEEP  {filename}")

    except Exception as e:
        print(f"Error processing {filename}: {e}")


def parse_args():
    p = argparse.ArgumentParser(
        description="Detect text in frames using Tesseract word confidences; move frames with likely text into an excluded folder."
    )

    p.add_argument("--input", required=True, help="Directory containing frames to scan (.jpg/.png).")
    p.add_argument("--excluded", required=True, help="Directory to move frames WITH detected text into.")

    p.add_argument("--tess-config", default=DEFAULT_TESS_CONFIG, help="Tesseract config string (e.g. '--psm 11 --oem 3 ...').")
    p.add_argument("--min-conf", type=int, default=DEFAULT_MIN_CONF, help="Minimum confidence (0-100) for a token to count.")
    p.add_argument("--min-letters", type=int, default=DEFAULT_MIN_LETTERS, help="Minimum number of A-Z letters in a token to count as text.")

    p.add_argument("--workers", type=int, default=cpu_count(), help="Number of parallel workers (default: CPU count).")
    p.add_argument("--no-parallel", action="store_true", help="Run in a single process (easier to debug).")

    p.add_argument("--print-langs", action="store_true", help="Print available tesseract languages and exit.")
    p.add_argument("--tesseract-cmd", default="", help="Optional path to the tesseract binary (macOS Homebrew etc.).")

    return p.parse_args()


def main():
    args = parse_args()

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

    os.makedirs(excluded_dir, exist_ok=True)

    files = sorted(os.listdir(input_dir))
    jobs = [(f, input_dir, excluded_dir, args.tess_config, args.min_letters, args.min_conf) for f in files]

    if args.no_parallel or args.workers <= 1:
        for job in jobs:
            process_image(job)
    else:
        workers = max(1, args.workers)
        with Pool(processes=workers) as pool:
            pool.map(process_image, jobs)


if __name__ == "__main__":
    main()
