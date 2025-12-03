# ridiculous-coding.el

**Turn your Emacs into an arcade cabinet.**

A port of [ridiculous_coding](https://github.com/jotson/ridiculous_coding) (Godot plugin) to Emacs. Makes your coding experience absurdly dramatic with explosions, screen shake, sound effects, combo counters, and particle mayhem.

![Demo GIF coming soon](./images/ridiculous/demo.gif)

## Features

### Typing Effects
- **Rainbow trails** - Every keystroke leaves a color-cycling trail
- **Afterimage ghosts** - Characters echo and fade behind your cursor
- **Particle explosions** - Random bursts of `* + x X o O . : ! # @ $ % &`
- **Floating spirits** - Characters occasionally drift upward like escaping souls
- **Shockwave rings** - Expanding `· ○ ◯ ◎ ●` from your cursor
- **Newline animations** - Special effects when you hit Enter

### Deletion Carnage
- **Skull spawns** - 💀 ☠ ✖ appear at deletion points
- **Fire trails** - 🔥 💥 ⚡ particles spread from deletions
- **Vaporization** - Large deletions trigger screen flash, shake, and the deleted text rises as ghosts
- **Screen shake** - Because destruction should feel impactful

### Region Selection
- **Sparkle cascade** - ✦ ✧ ★ ☆ ✨ rain down along your selection
- **Pulsing glow** - Yellow/orange border pulses around selected regions

### Combo System
- Tracks consecutive keystrokes
- Every 10 keystrokes triggers **MEGA COMBO** effects:
  - Screen flash
  - Shockwave
  - Floating stars
  - Big explosion
  - "🔥 COMBO x10! 🔥" message

### Sound Effects
- Cross-platform audio (macOS: afplay, Linux: paplay/aplay/sox)
- Sounds for: typing, deletion, save, combo milestones
- Configurable volume

### Image Animations (GUI only)
- Sprite sheet support for boom, blip, and newline animations
- Falls back to text effects in terminal

## Installation

1. Copy `personal/ridiculous-coding.el` to your load path
2. Optionally add sounds to `~/.emacs.d/sounds/ridiculous/{typing,delete,save,combo}/`
3. Optionally add sprite sheets to `~/.emacs.d/images/ridiculous/`

```elisp
(use-package ridiculous-coding
  :load-path "~/.emacs.d/lisp"
  :commands (ridiculous-coding-mode
             global-ridiculous-coding-mode
             ridiculous-coding-set-intensity))

;; Enable for specific modes:
(add-hook 'prog-mode-hook #'ridiculous-coding-mode)

;; Or go full chaos:
(global-ridiculous-coding-mode 1)
```

## Usage

| Command | Description |
|---------|-------------|
| `M-x ridiculous-coding-mode` | Toggle for current buffer |
| `M-x global-ridiculous-coding-mode` | Toggle globally (prog + text modes) |
| `M-x ridiculous-coding-set-intensity` | Set to low/medium/high/insane |
| `M-x ridiculous-coding-toggle-images` | Toggle sprite animations |

### Intensity Levels

| Level | Probability | Vibe |
|-------|-------------|------|
| low | 5% | Subtle sparkles |
| medium | 15% | Default, noticeable but not overwhelming |
| high | 30% | Frequent explosions |
| insane | 60% | Constant chaos |

## Test Commands

Try these to preview effects without typing:

```
M-x ridiculous-coding-test-explosion
M-x ridiculous-coding-test-shake
M-x ridiculous-coding-test-rainbow
M-x ridiculous-coding-test-spirit
M-x ridiculous-coding-test-shockwave
M-x ridiculous-coding-test-flash
M-x ridiculous-coding-test-mega
M-x ridiculous-coding-test-all
M-x ridiculous-coding-test-blip      (GUI only)
M-x ridiculous-coding-test-boom      (GUI only)
M-x ridiculous-coding-test-newline   (GUI only)
M-x ridiculous-coding-test-deletion
M-x ridiculous-coding-test-region
```

## Customization

All options are in the `ridiculous-coding` customize group:

```elisp
(setq ridiculous-coding-intensity 0.3)        ; Base effect probability
(setq ridiculous-coding-combo-threshold 10)   ; Keystrokes per combo bonus
(setq ridiculous-coding-combo-timeout 2.0)    ; Seconds before combo resets
(setq ridiculous-coding-sound-volume 0.3)     ; 0.0 - 1.0

;; Toggle individual effects:
(setq ridiculous-coding-sound-enabled t)
(setq ridiculous-coding-shake-enabled t)
(setq ridiculous-coding-particles-enabled t)
(setq ridiculous-coding-combo-enabled t)
(setq ridiculous-coding-rainbow-enabled t)
(setq ridiculous-coding-spirits-enabled t)
(setq ridiculous-coding-shockwave-enabled t)
(setq ridiculous-coding-flash-enabled t)
(setq ridiculous-coding-afterimage-enabled t)
(setq ridiculous-coding-images-enabled t)
```

## Directory Structure

```
~/.emacs.d/
├── sounds/ridiculous/
│   ├── typing/    # .wav/.mp3/.ogg files for keystroke sounds
│   ├── delete/    # Deletion sounds
│   ├── save/      # Save sounds
│   └── combo/     # Combo milestone sounds
└── images/ridiculous/
    ├── blip.png   # 256x32 sprite sheet, 8 frames of 32x32
    ├── boom.png   # 768x256 sprite sheet, 6 frames of 128x256
    └── newline.png # 320x64 sprite sheet, 5 frames of 64x64
```

## Terminal vs GUI

| Feature | Terminal | GUI |
|---------|----------|-----|
| Text particles | ✓ | ✓ |
| Rainbow/afterimage | ✓ | ✓ |
| Screen shake | ✓ | ✓ |
| Sprite animations | ✗ | ✓ |
| Sounds | ✓ | ✓ |

## Credits

- Original concept: [jotson/ridiculous_coding](https://github.com/jotson/ridiculous_coding) for Godot
- Emacs port: Pair-programmed with Claude Code
- Code review: ChatGPT (caught some good edge cases)

## License

Do whatever you want with it. Make your editor ridiculous.

---

*"This is absolutely 'real package on MELPA' territory."* — ChatGPT, 2024
