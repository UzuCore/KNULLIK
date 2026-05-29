# KNULLI-KR black bootlogo

Put your valid black BMP here:

```text
overlays/rocknixk/bootlogo/bootlogo.bmp
```

The build post-image script replaces the assembled H700 `/boot/bootlogo.bmp`
with this file before firmware signatures, boot archive, and final image creation.
Use a real BMP file, not a zero-byte placeholder.
