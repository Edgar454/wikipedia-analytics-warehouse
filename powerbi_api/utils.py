from pathlib import Path
import hashlib

def check_pbix(pbix_path , logger):
    path = Path(pbix_path)

    logger.info("PBIX path: %s", path.resolve())
    logger.info("Exists: %s", path.exists())
    logger.info("Size: %.2f MB", path.stat().st_size / (1024 * 1024))

    with open(path, "rb") as f:
        first_bytes = f.read(200)
        sha256 = hashlib.sha256(f.read()).hexdigest()

    logger.info("SHA256: %s", sha256)
    logger.info(
        "First bytes: %r",
        first_bytes[:100],
    )