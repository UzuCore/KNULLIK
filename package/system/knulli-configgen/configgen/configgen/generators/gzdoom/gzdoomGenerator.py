from __future__ import annotations

import collections
import re
import shlex
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import TYPE_CHECKING, Final

from ... import Command
from ...batoceraPaths import KNULLI_SHARE_DIR, CONFIGS, LOGS, ES_SETTINGS, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_CONFIG_DIR: Final = CONFIGS / "gzdoom"
_INI_FILE: Final = _CONFIG_DIR / "gzdoom.ini"
_SCRIPT_FILE: Final = _CONFIG_DIR / "gzdoom.cfg"
_FM_BANKS_DIR: Final = _CONFIG_DIR / "fm_banks"
_SOUND_FONTS_DIR: Final = _CONFIG_DIR / "soundfonts"

_CONTROLLER_BINDING_RE: Final = re.compile(
    r"^(Joy\d+|Axis\d+(?:Plus|Minus)?|DPad\w+|POV\d+\w+|Pad_\w+|[LR](?:Thumb|Shoulder|Trigger))\s*="
)

GZDOOM_CVAR_SECTIONS: Final = (
    "[Doom.ConsoleVariables]",
    "[Heretic.ConsoleVariables]",
    "[Hexen.ConsoleVariables]",
    "[Strife.ConsoleVariables]",
    "[Chex.ConsoleVariables]",
)

DEFAULT_BINDINGS: Final = {
    "1": "slot 1", "2": "slot 2", "3": "slot 3", "4": "slot 4", "5": "slot 5",
    "6": "slot 6", "7": "slot 7", "8": "slot 8", "9": "slot 9", "0": "slot 0",
    "W": "+forward", "S": "+back", "A": "+moveleft", "D": "+moveright", "E": "+use",
    "T": "messagemode", "LeftBracket": "invprev", "RightBracket": "invnext",
    "Enter": "invuse", "Shift": "+speed", "X": "crouch", "Space": "+jump",
    "Tab": "togglemap", "`": "toggleconsole", "\\": "+showscores", "CapsLock": "toggle cl_run",
    "F1": "menu_help", "F2": "menu_save", "F3": "menu_load", "F4": "menu_options",
    "F5": "menu_display", "F6": "quicksave", "F7": "menu_endgame", "F8": "togglemessages",
    "F9": "quickload", "F10": "menu_quit", "F11": "bumpgamma", "F12": "spynext",
    "SysRq": "screenshot", "Pause": "pause", "Home": "land", "PgUp": "+moveup",
    "End": "centerview", "PgDn": "+lookup", "Ins": "+movedown", "Del": "+lookdown",
    "Mouse1": "+attack", "Mouse2": "+altattack", "MWheelUp": "weapprev",
    "MWheelDown": "weapnext", "MWheelRight": "invnext", "MWheelLeft": "invprev",
}

DEFAULT_AUTOMAP_BINDINGS: Final = {
    "0": "am_gobig", "=": "+am_zoomin", "-": "+am_zoomout",
    "P": "am_toggletexture", "F": "am_togglefollow", "G": "am_togglegrid",
    "C": "am_clearmarks", "M": "am_setmark",
    "KP-": "+am_zoomout", "KP+": "+am_zoomin",
    "UpArrow": "+am_panup", "LeftArrow": "+am_panleft",
    "RightArrow": "+am_panright", "DownArrow": "+am_pandown",
    "MWheelUp": "am_zoom 1.2", "MWheelDown": "am_zoom -1.2",
}

GZDOOM_JOY_BINDINGS_CLASSIC: Final = {
    "a": "+use",
    "b": "+attack",
    "x": "turn180",
    "y": "toggle cl_run",
    "pageup": "weapprev",
    "pagedown": "weapnext",
    "l2": "+strafe",
    "r2": "+attack",
    "start": "menu_main",
    "select": "togglemap",
}

GZDOOM_JOY_BINDINGS_MODERN: Final = {
    "a": "+use",
    "b": "+jump",
    "y": "reload",
    "x": "grenadetoss",
    "pageup": "weapprev",
    "pagedown": "weapnext",
    "l2": "+altattack",
    "r2": "+attack",
    "l3": "crouch",
    "r3": "kickem",
    "start": "menu_main",
    "select": "togglemap",
}

GZDOOM_AXIS_MAP_CLASSIC: Final = {
    "joystick1left": {"map": 0, "scale": "1"},  # turn
    "joystick1up":   {"map": 2, "scale": "1"},  # forward/back
}

GZDOOM_AXIS_MAP_MODERN_DUAL: Final = {
    "joystick1left": {"map": 3, "scale": "1"},  # strafe
    "joystick1up":   {"map": 2, "scale": "1"},  # forward/back
    "joystick2left": {"map": 0, "scale": "1"},  # turn
    "joystick2up":   {"map": 1, "scale": "1"},  # look
}

GZDOOM_AXIS_MAP_MODERN_SINGLE: Final = {
    "joystick1left": {"map": 0, "scale": "1"},  # turn
    "joystick1up":   {"map": 2, "scale": "1"},  # forward/back
}

GZDOOM_DPAD_BINDINGS: Final = {
    "up":    {"suffix": "Up",    "doom": "centerview", "automap": "+am_panup"},
    "down":  {"suffix": "Down",  "doom": "invuse",     "automap": "+am_pandown"},
    "left":  {"suffix": "Left",  "doom": "invprev",    "automap": "+am_panleft"},
    "right": {"suffix": "Right", "doom": "invnext",    "automap": "+am_panright"},
}

GZDOOM_DPAD_BINDINGS_MODERN: Final = {
    "up":    {"suffix": "Up",    "doom": "flashlightswitch", "automap": "+am_panup"},
    "down":  {"suffix": "Down",  "doom": "dual",             "automap": "+am_pandown"},
    "left":  {"suffix": "Left",  "doom": "invuse",           "automap": "+am_panleft"},
    "right": {"suffix": "Right", "doom": "invnext",          "automap": "+am_panright"},
}

GZDOOM_JOY_AUTOMAP_BINDINGS: Final = {
    "a":        "am_setmark",
    "b":        "am_clearmarks",
    "x":        "am_togglefollow",
    "y":        "am_togglegrid",
    "pageup":   "+am_zoomout",
    "pagedown": "+am_zoomin",
}

class IniFileEditor:

    def __init__(self, path: Path):
        self.path = path
        self.sections: dict[str, list[str]] = collections.defaultdict(list)
        if self.path.exists():
            self._parse()

    def _parse(self) -> None:
        current_section = ""
        with self.path.open("r", encoding="utf-8") as f:
            for line in f:
                stripped_line = line.strip()
                if stripped_line.startswith("[") and stripped_line.endswith("]"):
                    current_section = stripped_line
                    # Ensure the section key exists even if it's empty
                    if current_section not in self.sections:
                        self.sections[current_section] = []
                elif current_section and stripped_line:
                    self.sections[current_section].append(line)

    def ensure_section_exists(self, section_name: str) -> None:
        if section_name not in self.sections:
            self.sections[section_name] = []

    def set_value(self, section: str, key: str, value: str) -> None:
        self.ensure_section_exists(section)
        full_line = f"{key}={value}\n"
        # Find and replace existing key
        for i, line in enumerate(self.sections[section]):
            if line.strip().startswith(f"{key}="):
                self.sections[section][i] = full_line
                return
        # Or add if it doesn't exist
        self.sections[section].append(full_line)

    def set_value_if_missing(self, section: str, key: str, value: str) -> None:
        self.ensure_section_exists(section)
        # Check if the key already exists
        for line in self.sections[section]:
            if line.strip().startswith(f"{key}="):
                return  # Key found, so we do nothing
        # Key was not found, add it
        self.sections[section].append(f"{key}={value}\n")

    def add_line_if_missing(self, section: str, line_to_add: str) -> None:
        self.ensure_section_exists(section)
        # Ensure the line ends with a newline
        line_with_newline = line_to_add.strip() + "\n"
        if line_with_newline not in self.sections[section]:
            self.sections[section].append(line_with_newline)

    def write(self) -> None:
        with self.path.open("w", encoding="utf-8") as f:
            for section_name, lines in self.sections.items():
                f.write(f"{section_name}\n")
                for line in lines:
                    f.write(line)
                f.write("\n")

class GZDoomGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "gzdoom",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"], "save_store": "KEY_F6", "restore_store": "KEY_F9" }
        }

    # Return value for es invert buttons
    def _get_es_invert_buttons(self) -> bool:
        try:
            tree = ET.parse(ES_SETTINGS)
            root = tree.getroot()
            elem = root.find(".//bool[@name='InvertButtons']")
            return elem is not None and elem.get("value") == "true"
        except Exception:
            return False

    def _determine_api_config(self, system) -> str:
        gzdoom_api = system.config.get("gz_api", "0")
        arch_path = KNULLI_SHARE_DIR / "knulli.arch"

        # Default to GLES on non-x86_64 architectures if API is auto ("0")
        if gzdoom_api == "0" and arch_path.exists():
            arch = arch_path.read_text().strip()
            if arch != "x86_64":
                gzdoom_api = "3"

        if gzdoom_api == "3":
            # OpenGL ES settings for performance
            return (
                "gl_es 1\n"
                "vid_preferbackend 3\n"
                "gles_use_mapped_buffer true\n"
            )
        return f"vid_preferbackend {gzdoom_api}\n"

    def _create_script_file(self, system, api_config: str) -> None:
        content = (
            "# This file is automatically generated by gzdoomGenerator.py\n"
            f"logfile \"{LOGS / 'gzdoom.log'}\"\n"
            f"vid_fps {'true' if system.getOptBoolean('showFPS') else 'false'}\n"
            f"{api_config}"
            "echo BATOCERA\n"
        )
        _SCRIPT_FILE.write_text(content, encoding="utf-8")

    def _clear_generated_input_bindings(self, ini: IniFileEditor) -> None:
        for section in ("[Doom.Bindings]", "[Doom.AutomapBindings]"):
            ini.sections[section] = [
                line for line in ini.sections[section]
                if not _CONTROLLER_BINDING_RE.match(line.strip())
            ]

        ini.sections["[GlobalSettings]"] = [
            line for line in ini.sections["[GlobalSettings]"]
            if not line.strip().startswith(("menu_confirm=", "menu_back="))
        ]

    def _copy_axis_map_with_sensitivity(self, system, axis_template: dict) -> dict:
        axis_map = {
            name: dict(mapping)
            for name, mapping in axis_template.items()
        }

        look_h = system.config.get("gz_look_sensitivity_h", "0.90")
        look_v = system.config.get("gz_look_sensitivity_v", "0.25")

        if system.getOptBoolean("gz_look_invert_y"):
            look_v = f"-{look_v}"

        for mapping in axis_map.values():
            if mapping["map"] == 0:  # turn
                mapping["scale"] = look_h
            elif mapping["map"] == 1:  # look up/down
                mapping["scale"] = look_v

        return axis_map

    def _apply_controller_bindings(
        self,
        ini: IniFileEditor,
        system,
        playersControllers,
        modern_input: bool,
        confirm_button: str,
        back_button: str,
    ) -> None:
        # GZDoom's internal joystick handler for controllers is not dynamic.
        # We need to set the Joy values for controllers i.e. Joy1=+use Joy4=+jump etc.
        for n, pad in enumerate(playersControllers.values()):
            if n != 0:
                ini.set_value(f"[Joy:JS:{n}]", "Enabled", "0")
                continue

            ini.set_value(f"[Joy:JS:{n}]", "Enabled", "1")

            has_left_stick = any(
                inp.type == "axis" and inp.name in ("joystick1left", "joystick1up")
                for inp in pad.inputs.values()
            )

            has_right_stick = any(
                inp.type == "axis" and inp.name in ("joystick2left", "joystick2up")
                for inp in pad.inputs.values()
            )

            dual_stick = has_left_stick and has_right_stick

            if modern_input:
                joy_bindings = dict(GZDOOM_JOY_BINDINGS_MODERN)
                dpad_bindings = GZDOOM_DPAD_BINDINGS_MODERN

                if dual_stick:
                    axis_template = GZDOOM_AXIS_MAP_MODERN_DUAL
                else:
                    axis_template = GZDOOM_AXIS_MAP_MODERN_SINGLE
                    joy_bindings["l2"] = "+strafe"
            else:
                joy_bindings = GZDOOM_JOY_BINDINGS_CLASSIC
                dpad_bindings = GZDOOM_DPAD_BINDINGS
                axis_template = GZDOOM_AXIS_MAP_CLASSIC

            axis_map = self._copy_axis_map_with_sensitivity(system, axis_template)

            for inp in pad.inputs.values():
                if inp.type == "button":
                    joynum = int(inp.id) + 1

                    # For menu navigation
                    if inp.name == confirm_button:
                        ini.set_value("[GlobalSettings]", "menu_confirm", f"Joy{joynum}")
                    elif inp.name == back_button:
                        ini.set_value("[GlobalSettings]", "menu_back", f"Joy{joynum}")

                    if inp.name in joy_bindings:
                        ini.set_value(
                            "[Doom.Bindings]",
                            f"Joy{joynum}",
                            joy_bindings[inp.name],
                        )

                    if inp.name in GZDOOM_JOY_AUTOMAP_BINDINGS:
                        ini.set_value(
                            "[Doom.AutomapBindings]",
                            f"Joy{joynum}",
                            GZDOOM_JOY_AUTOMAP_BINDINGS[inp.name],
                        )

                    # Some controllers dpad are buttons instead of hat
                    if inp.name in dpad_bindings:
                        binding = dpad_bindings[inp.name]

                        ini.set_value(
                            "[Doom.Bindings]",
                            f"Joy{joynum}",
                            binding["doom"],
                        )
                        ini.set_value(
                            "[Doom.AutomapBindings]",
                            f"Joy{joynum}",
                            binding["automap"],
                        )

                elif inp.type == "hat" and inp.name in dpad_bindings:
                    binding = dpad_bindings[inp.name]
                    hatnum = int(inp.id) + 1
                    suffix = binding["suffix"]

                    ini.set_value(
                        "[Doom.Bindings]",
                        f"POV{hatnum}{suffix}",
                        binding["doom"],
                    )
                    ini.set_value(
                        "[Doom.AutomapBindings]",
                        f"POV{hatnum}{suffix}",
                        binding["automap"],
                    )

                    if hatnum == 1:
                        ini.set_value(
                            "[Doom.Bindings]",
                            f"DPad{suffix}",
                            binding["doom"],
                        )
                        ini.set_value(
                            "[Doom.AutomapBindings]",
                            f"DPad{suffix}",
                            binding["automap"],
                        )

                elif inp.type == "axis" and inp.name in axis_map:
                    mapping = axis_map[inp.name]
                    axisnum = int(inp.id)

                    ini.set_value("[Joy:JS:0]", f"Axis{axisnum}deadzone", "0.25")
                    ini.set_value("[Joy:JS:0]", f"Axis{axisnum}scale", mapping["scale"])
                    ini.set_value("[Joy:JS:0]", f"Axis{axisnum}map", str(mapping["map"]))

    def _update_ini_file(self, system, rom: Path, playersControllers) -> None:
        ini = IniFileEditor(_INI_FILE)

        # Add ROM path to search directories
        rom_path_line = f"Path={rom.parent}"
        ini.add_line_if_missing("[IWADSearch.Directories]", rom_path_line)
        ini.add_line_if_missing("[FileSearch.Directories]", rom_path_line)

        # Add sound and music paths (system paths first, for precedence)
        sound_paths = [
            "Path=/usr/share/gzdoom/soundfonts",
            "Path=/usr/share/gzdoom/fm_banks",
            f"Path={_SOUND_FONTS_DIR}",
            f"Path={_FM_BANKS_DIR}",
        ]
        for path_line in sound_paths:
            ini.add_line_if_missing("[SoundfontSearch.Directories]", path_line)

        # ES Settings
        # Set joystick option
        ini.set_value("[GlobalSettings]", "use_joystick", "true")

        # Input Mode
        gz_input_mode = system.config.get("gz_input_mode", "modern")
        modern_input = gz_input_mode == "modern"

        # Video sync
        set_gz_vsync = system.config.get("gz_vsync", "false")
        ini.set_value("[GlobalSettings]", "vid_vsync", set_gz_vsync)

        # FPS mode
        gz_fps_mode = system.config.get("gz_fps_mode", "classic")
        ini.set_value("[GlobalSettings]", "cl_capfps", "false" if gz_fps_mode == "smooth" else "true")
        ini.set_value("[GlobalSettings]", "vid_maxfps", "60")

        # Texture Filtering
        set_gz_texture_filter = system.config.get("gz_texture_filter", "5")
        ini.set_value("[GlobalSettings]", "gl_texture_filter", set_gz_texture_filter)

        # Anisotropic filtering
        set_gz_texture_filter_anisotropic = system.config.get("gz_anisotropic", "8")
        ini.set_value("[GlobalSettings]", "gl_texture_filter_anisotropic", set_gz_texture_filter_anisotropic)

        # Sprite shadows
        set_gz_sprite_shadows = system.config.get("gz_sprite_shadows", "1")
        ini.set_value("[GlobalSettings]", "r_actorspriteshadow", set_gz_sprite_shadows)

        # UI
        # Mode
        set_gz_ui_mode = system.config.get("gz_ui_mode", "10")
        # Scale
        set_gz_ui_scale = system.config.get("gz_ui_scale", "2")
        set_gz_message_scale = "0" if set_gz_ui_scale == "0" else str(int(set_gz_ui_scale) + 1)

        for section in GZDOOM_CVAR_SECTIONS:
            ini.set_value(section, "uiscale", set_gz_ui_scale)
            ini.set_value(section, "con_scaletext", set_gz_message_scale)
            ini.set_value(section, "screenblocks", set_gz_ui_mode)
            ini.set_value(section, "saved_screenblocks", set_gz_ui_mode)
            ini.set_value(section, "cl_run", "true")  # autorun

        # Default all axes to disabled. ES determined axes are enabled/mapped below.
        for axis in range(0, 6):
            ini.set_value("[Joy:JS:0]", f"Axis{axis}deadzone", "1.0")
            ini.set_value("[Joy:JS:0]", f"Axis{axis}scale", "1")
            ini.set_value("[Joy:JS:0]", f"Axis{axis}map", "-1")

        # 1. Apply default bindings if they are missing (first start)
        for key, value in DEFAULT_BINDINGS.items():
            ini.set_value_if_missing("[Doom.Bindings]", key, value)
        for key, value in DEFAULT_AUTOMAP_BINDINGS.items():
            ini.set_value_if_missing("[Doom.AutomapBindings]", key, value)

        # 2. Set/Overwrite dynamic controller bindings
        self._clear_generated_input_bindings(ini)

        # Match ES confirm/back buttons.
        if self._get_es_invert_buttons():
            confirm_button = "a"
            back_button = "b"
        else:
            confirm_button = "b"
            back_button = "a"

        self._apply_controller_bindings(
            ini,
            system,
            playersControllers,
            modern_input,
            confirm_button,
            back_button,
        )

        ini.write()

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        rom_path = Path(rom)

        mkdir_if_not_exists(_CONFIG_DIR)
        mkdir_if_not_exists(_SOUND_FONTS_DIR)
        mkdir_if_not_exists(_FM_BANKS_DIR)

        api_config = self._determine_api_config(system)
        self._create_script_file(system, api_config)
        self._update_ini_file(system, rom_path, playersControllers)

        commandArray = ["gzdoom"]

        if rom_path.suffix == ".gzdoom":
            wad_args = shlex.split(rom_path.read_text())
            commandArray.extend(wad_args)
        else:
            commandArray.extend(["-iwad", rom_path.name])

        commandArray.extend([
            "-exec", str(_SCRIPT_FILE),
            "-width", str(gameResolution["width"]),
            "-height", str(gameResolution["height"]),
        ])

        if system.getOptBoolean("nologo"):
            commandArray.append("-nologo")

        sdl_config = generate_sdl_game_controller_config(playersControllers)

        return Command.Command(array=commandArray, env={
            "SDL_GAMECONTROLLERCONFIG": sdl_config,
            "SDL_JOYSTICK_HIDAPI": "0"
        })

    def getInGameRatio(self, config, gameResolution, rom):
        return 16/9
