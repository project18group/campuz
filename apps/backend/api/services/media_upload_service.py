"""
Media Upload & Cloudinary Storage Service
Provides automated resource_type detection (image, video, raw document)
for seamless multi-media handling across Hub Resources, Messages, Broadcasts, and Tasks.
"""

import os
import logging
import cloudinary
import cloudinary.uploader
from django.conf import settings
from cloudinary_storage.storage import MediaCloudinaryStorage

logger = logging.getLogger(__name__)

IMAGE_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp",
    ".svg", ".heic", ".heif", ".tiff", ".ico"
}

VIDEO_AUDIO_EXTENSIONS = {
    ".mp4", ".mov", ".avi", ".mkv", ".webm", ".3gp",
    ".mp3", ".wav", ".m4a", ".aac", ".ogg", ".flac"
}


def get_cloudinary_resource_type(filename_or_path: str) -> str:
    """
    Returns the appropriate Cloudinary resource_type ('image', 'video', or 'raw')
    based on the file extension.
    """
    if not filename_or_path:
        return "raw"
    ext = os.path.splitext(filename_or_path)[1].lower()
    if ext in IMAGE_EXTENSIONS:
        return "image"
    if ext in VIDEO_AUDIO_EXTENSIONS:
        return "video"
    return "raw"


class AutoCloudinaryStorage(MediaCloudinaryStorage):
    """
    Custom Cloudinary Storage backend that automatically routes files
    to the correct Cloudinary resource_type ('image', 'video', or 'raw').
    This fixes 404 Not Found errors when storing PDFs, Docs, Videos, and Images.
    """

    def _get_resource_type(self, name):
        return get_cloudinary_resource_type(name)

    def _upload(self, name, content):
        res_type = self._get_resource_type(name)
        options = {
            "use_filename": True,
            "unique_filename": True,
            "resource_type": res_type,
            "tags": self.TAG,
        }
        folder = os.path.dirname(name)
        if folder:
            options["folder"] = folder
        return cloudinary.uploader.upload(content, **options)


def upload_file_to_cloudinary(file_obj, folder: str = "campuz_uploads") -> dict:
    """
    Directly uploads any file object to Cloudinary with automatic type detection.
    Returns:
        dict: {
            'url': str,
            'file_name': str,
            'mime_type': str or None,
            'size_bytes': int,
            'resource_type': str
        }
    """
    filename = getattr(file_obj, "name", "upload")
    mime_type = getattr(file_obj, "content_type", None)
    res_type = get_cloudinary_resource_type(filename)
    
    try:
        # Read content
        if hasattr(file_obj, "read"):
            content = file_obj.read()
            if hasattr(file_obj, "seek"):
                file_obj.seek(0)
        else:
            content = file_obj

        upload_options = {
            "folder": folder,
            "resource_type": res_type,
            "use_filename": True,
            "unique_filename": True,
        }
        
        result = cloudinary.uploader.upload(content, **upload_options)
        secure_url = result.get("secure_url") or result.get("url")
        size_bytes = result.get("bytes") or getattr(file_obj, "size", None)

        return {
            "url": secure_url,
            "file_name": filename,
            "mime_type": mime_type,
            "size_bytes": size_bytes,
            "resource_type": res_type,
        }
    except Exception as e:
        logger.error(f"Cloudinary upload failed for {filename}: {e}", exc_info=True)
        raise
