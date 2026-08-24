import os
from PIL import Image, ImageDraw

def main():
    ev_logo_path = r"d:\evChargerApp\assets\images\ev logo.png"
    logo_path = r"d:\evChargerApp\assets\images\logo.png"

    if not os.path.exists(ev_logo_path):
        print(f"Error: {ev_logo_path} does not exist.")
        return

    # Open ev logo
    src_img = Image.open(ev_logo_path).convert("RGBA")

    # 1. Overwrite logo.png with ev logo.png so all references match
    src_img.save(logo_path, format="PNG")
    print(f"Saved {logo_path}")

    # 2. Android mipmaps
    android_res = r"d:\evChargerApp\android\app\src\main\res"
    android_sizes = {
        "mipmap-mdpi": (48, 48),
        "mipmap-hdpi": (72, 72),
        "mipmap-xhdpi": (96, 96),
        "mipmap-xxhdpi": (144, 144),
        "mipmap-xxxhdpi": (192, 192),
    }

    for folder, (w, h) in android_sizes.items():
        dir_path = os.path.join(android_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        # Create square icon with transparent or padded background
        resized = src_img.resize((w, h), Image.Resampling.LANCZOS)
        out_file = os.path.join(dir_path, "ic_launcher.png")
        resized.save(out_file, format="PNG")
        print(f"Saved {out_file} ({w}x{h})")

    # 3. iOS AppIcons
    ios_dir = r"d:\evChargerApp\ios\Runner\Assets.xcassets\AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": (20, 20),
        "Icon-App-20x20@2x.png": (40, 40),
        "Icon-App-20x20@3x.png": (60, 60),
        "Icon-App-29x29@1x.png": (29, 29),
        "Icon-App-29x29@2x.png": (58, 58),
        "Icon-App-29x29@3x.png": (87, 87),
        "Icon-App-40x40@1x.png": (40, 40),
        "Icon-App-40x40@2x.png": (80, 80),
        "Icon-App-40x40@3x.png": (120, 120),
        "Icon-App-60x60@2x.png": (120, 120),
        "Icon-App-60x60@3x.png": (180, 180),
        "Icon-App-76x76@1x.png": (76, 76),
        "Icon-App-76x76@2x.png": (152, 152),
        "Icon-App-83.5x83.5@2x.png": (167, 167),
        "Icon-App-1024x1024@1x.png": (1024, 1024),
    }

    if os.path.exists(ios_dir):
        for name, (w, h) in ios_sizes.items():
            resized = src_img.resize((w, h), Image.Resampling.LANCZOS)
            # For iOS AppIcon, ensure non-transparent background if needed, or save RGBA
            # iOS AppIcon prefers solid background (no alpha), let's composited on dark background or solid
            # But let's check if transparent RGBA is okay or composite on dark background:
            # Let's composited on the dark brand color (0x0D, 0x26, 0x19) for iOS AppIcon
            bg = Image.new("RGBA", (w, h), (13, 38, 25, 255))
            bg.paste(resized, (0, 0), resized)
            out_file = os.path.join(ios_dir, name)
            bg.convert("RGB").save(out_file, format="PNG")
            print(f"Saved iOS {out_file} ({w}x{h})")

    # 4. Web icons
    web_dir = r"d:\evChargerApp\web"
    web_sizes = {
        os.path.join(web_dir, "favicon.png"): (32, 32),
        os.path.join(web_dir, "icons", "Icon-192.png"): (192, 192),
        os.path.join(web_dir, "icons", "Icon-512.png"): (512, 512),
        os.path.join(web_dir, "icons", "Icon-maskable-192.png"): (192, 192),
        os.path.join(web_dir, "icons", "Icon-maskable-512.png"): (512, 512),
    }

    for path, (w, h) in web_sizes.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        resized = src_img.resize((w, h), Image.Resampling.LANCZOS)
        resized.save(path, format="PNG")
        print(f"Saved Web {path} ({w}x{h})")

    # 5. macOS icons
    macos_dir = r"d:\evChargerApp\macos\Runner\Assets.xcassets\AppIcon.appiconset"
    macos_sizes = {
        "app_icon_16.png": (16, 16),
        "app_icon_32.png": (32, 32),
        "app_icon_64.png": (64, 64),
        "app_icon_128.png": (128, 128),
        "app_icon_256.png": (256, 256),
        "app_icon_512.png": (512, 512),
        "app_icon_1024.png": (1024, 1024),
    }

    if os.path.exists(macos_dir):
        for name, (w, h) in macos_sizes.items():
            resized = src_img.resize((w, h), Image.Resampling.LANCZOS)
            out_file = os.path.join(macos_dir, name)
            resized.save(out_file, format="PNG")
            print(f"Saved macOS {out_file} ({w}x{h})")

    # 6. Windows icon (.ico)
    win_ico = r"d:\evChargerApp\windows\runner\resources\app_icon.ico"
    if os.path.exists(os.path.dirname(win_ico)):
        ico_img = src_img.resize((256, 256), Image.Resampling.LANCZOS)
        ico_img.save(win_ico, format="ICO", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
        print(f"Saved Windows {win_ico}")

    # 7. Store icon
    store_icon = r"d:\evChargerApp\store\play-icon-512.png"
    if os.path.exists(os.path.dirname(store_icon)):
        s_img = src_img.resize((512, 512), Image.Resampling.LANCZOS)
        s_img.save(store_icon, format="PNG")
        print(f"Saved Store icon {store_icon}")

    print("All icons successfully updated with ev logo.png!")

if __name__ == "__main__":
    main()
