# Favicon Generation

The `favicon.svg` file in the parent directory serves as the source for all favicon sizes.

## Required Sizes

For optimal browser support, generate the following sizes from favicon.svg:

1. **favicon-16x16.png** - Standard browser tab icon
2. **favicon-32x32.png** - Higher resolution tab icon
3. **apple-touch-icon.png** (180x180) - iOS home screen icon
4. **favicon-512x512.png** - PWA icon (optional)

## Generation Methods

### Option 1: Using ImageMagick (Recommended)
```bash
# Install ImageMagick if needed
# Ubuntu/Debian: sudo apt install imagemagick
# macOS: brew install imagemagick

# Generate favicons
cd docs/assets/images
convert favicon.svg -resize 16x16 favicon/favicon-16x16.png
convert favicon.svg -resize 32x32 favicon/favicon-32x32.png
convert favicon.svg -resize 180x180 favicon/apple-touch-icon.png
convert favicon.svg -resize 512x512 favicon/favicon-512x512.png
```

### Option 2: Using Inkscape
```bash
inkscape favicon.svg --export-filename=favicon/favicon-16x16.png --export-width=16 --export-height=16
inkscape favicon.svg --export-filename=favicon/favicon-32x32.png --export-width=32 --export-height=32
inkscape favicon.svg --export-filename=favicon/apple-touch-icon.png --export-width=180 --export-height=180
```

### Option 3: Using Online Tool
Visit https://realfavicongenerator.net/ and upload favicon.svg

## Placeholder Files

Temporary placeholder files are provided for immediate deployment. Replace with properly generated PNG files for production.
