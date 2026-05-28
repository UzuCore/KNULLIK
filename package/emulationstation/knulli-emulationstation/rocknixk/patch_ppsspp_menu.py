#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_ppsspp_menu.py /path/to/GuiMenu.cpp")

path = Path(sys.argv[1])
text = path.read_text()

if "PPSSPP KOREAN FONT" in text:
    print(f"[OK] PPSSPP Korean font menu already exists in {path}")
    raise SystemExit(0)

marker = "\t// Load global custom features\n"
if marker not in text:
    marker = "// Load global custom features\n"

insert = r'''
	// PPSSPP Korean font toggle
	auto pspfont_enabled = std::make_shared<SwitchComponent>(mWindow);
	bool pfbaseEnabled = SystemConf::getInstance()->get("global.pspfont.enabled") == "1";
	pspfont_enabled->setState(pfbaseEnabled);
	s->addWithLabel(_("PPSSPP KOREAN FONT"), pspfont_enabled);
	s->addSaveFunc([pspfont_enabled] {
		if (pspfont_enabled->getState() == false) {
			std::system("/usr/bin/ppsspp_font.sh");
		} else {
			std::system("/usr/bin/ppsspp_font.sh enabled");
		}
		bool pspfontenabled = pspfont_enabled->getState();
		SystemConf::getInstance()->set("global.pspfont.enabled", pspfontenabled ? "1" : "0");
		SystemConf::getInstance()->saveSystemConf();
	});

'''

pos = text.find(marker)
if pos < 0:
    raise SystemExit("[ERROR] Could not find insertion marker: // Load global custom features")

text = text[:pos] + insert + text[pos:]
path.write_text(text)
print(f"[OK] inserted PPSSPP Korean font menu into {path}")
