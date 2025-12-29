# Demo Data Directory

This directory is for **local development and testing only**. Binary files (videos, images, audio) are **not committed** to the repository.

## Usage

Place your demo files here for testing:

- **Videos**: `.mp4`, `.mov`, `.webm`
- **Audio**: `.mp3`, `.wav`, `.m4a`
- **Images**: `.jpg`, `.png`, `.jpeg`

These files are ignored by git (see `.gitignore`).

## Example Files

For testing, you can use:

1. **Stock footage**: [Pexels Videos](https://www.pexels.com/videos/) (free, no attribution required)
2. **Audio**: [Free Music Archive](https://freemusicarchive.org/)
3. **Sample images**: Generate programmatically or use placeholder services

## Git LFS Alternative

If you need to share demo files with contributors, consider:

- Using [Git LFS](https://git-lfs.github.com/) for large binary files
- Hosting files externally (Google Drive, S3) and documenting download instructions
- Generating demo files programmatically in tests

## Current Demo Files (Not in Repo)

The following files are used in the example gallery but excluded from git:

- `12433259-uhd_3840_2160_30fps.mp4` - UHD video sample
- `highlight.mp4` - Video highlight clip
- `uhd_25fps.mp4` - 25fps video sample
- `Claimence1.mp3` - Background music
- `*.jpg`, `*.jpeg` - Image samples

Download or create your own versions for local testing.
